import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Internal, bounded source description shared by scaffold and controller.
class ScrollSource {
  ScrollSource._(this.scrollables, this.ancestors, this.pageViews,
      this.offstage, this.pageRoot, this.pageIndex, this.pager);

  static const discoveryLimit = 4096;
  static final _descriptions = Expando<ScrollSource>();

  final List<ScrollableState> scrollables;
  final List<Element> ancestors;
  final int pageViews;
  final bool offstage;
  final Element? pageRoot;
  final int? pageIndex;
  final ScrollableState? pager;

  ScrollPosition get position => scrollables.first.position;
  ScrollPosition? get pagerPosition => pager?.position;

  /// Null means that framework evidence cannot establish page relevance.
  bool? get activePage {
    if (pageViews == 0) return true;
    final p = pagerPosition;
    if (pageViews != 1 ||
        p == null ||
        pageRoot == null ||
        pageIndex == null ||
        !pageRoot!.mounted ||
        !p.hasContentDimensions) {
      return null;
    }
    final metrics = p.copyWith();
    if (metrics is! PageMetrics || metrics.viewportFraction != 1) return null;
    final page = metrics.page;
    if (page == null) return null;
    return !p.isScrollingNotifier.value &&
        (page - page.round()).abs() < 0.000001 &&
        page.round() == pageIndex;
  }

  static ScrollSource? describe(ScrollNotification notification) {
    final context = notification.context;
    if (context == null || !context.mounted) return null;
    final cached = _descriptions[notification];
    if (cached != null) return cached;
    final ancestors = <Element>[];
    final scrollables = <ScrollableState>[];
    final renders = <RenderObject, Element>{};
    var pageViews = 0;
    var offstage = false;
    var exhausted = false;
    ScrollableState? pager;
    RenderViewport? pageViewport;
    context.visitAncestorElements((element) {
      if (ancestors.length >= discoveryLimit) {
        exhausted = true;
        return false;
      }
      ancestors.add(element);
      if (element.widget case Offstage(offstage: true)) offstage = true;
      if (element is RenderObjectElement) {
        renders[element.renderObject] = element;
        final render = element.renderObject;
        if (pageViewport == null &&
            render is RenderViewport &&
            axisDirectionToAxis(render.axisDirection) == Axis.horizontal) {
          pageViewport = render;
        }
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        scrollables.add(state);
        if (pager == null &&
            axisDirectionToAxis(state.axisDirection) == Axis.horizontal &&
            state.position.copyWith() is PageMetrics) {
          pager = state;
        }
      }
      if (element.widget is PageView) pageViews++;
      return true;
    });
    if (exhausted || scrollables.isEmpty) return null;

    Element? pageRoot;
    int? pageIndex;
    if (pager != null &&
        pageViews == 1 &&
        pageViewport != null &&
        pageViewport!.axisDirection == pager!.axisDirection) {
      RenderObject? child = context.findRenderObject();
      for (var i = 0; child != null && i < discoveryLimit; i++) {
        final parent = child.parent;
        if (parent is RenderSliverFillViewport &&
            parent.constraints.axis == Axis.horizontal) {
          RenderObject? viewport = parent.parent;
          // PageView's optional fractional padding may wrap its fill sliver.
          for (var paddingDepth = 0;
              viewport is RenderSliverEdgeInsetsPadding &&
                  paddingDepth < discoveryLimit;
              paddingDepth++) {
            viewport = viewport.parent;
          }
          if (identical(viewport, pageViewport) &&
              child.parentData is SliverMultiBoxAdaptorParentData) {
            pageRoot = renders[child];
            pageIndex =
                (child.parentData! as SliverMultiBoxAdaptorParentData).index;
          }
          break;
        }
        child = parent;
      }
    }
    final source = ScrollSource._(scrollables, ancestors, pageViews, offstage,
        pageRoot, pageIndex, pager);
    _descriptions[notification] = source;
    return source;
  }

  bool within(BuildContext boundary) => ancestors.contains(boundary);
}

final _trackers = Expando<ScrollOwnership>();
ScrollOwnership scrollOwnershipFor(Object controller) =>
    _trackers[controller] ??= ScrollOwnership();

/// Internal ownership bookkeeping; does not alter visual fold state.
class ScrollOwnership {
  final _revoked = Expando<bool>();
  final _syntheticSource = Object();
  Object? _owner;
  Object? _scope;
  Object? _automaticScope;
  List<ScrollPosition> _pagers = [];
  List<double?> _pagerPixels = [];
  final _smartScopes = <Object, Element? Function()>{};
  final smartResolver = SmartScrollResolver();

  void registerSmartScope(Object scope, Element? Function() boundary) {
    _smartScopes[scope] = boundary;
  }

  void unregisterSmartScope(Object scope) {
    _smartScopes.remove(scope);
    releaseScope(scope);
  }

  Element? smartBoundary(ScrollSource? source) {
    Element? nearest;
    var distance = discoveryDistance;
    for (final boundary in _smartScopes.values) {
      final element = boundary();
      final index =
          element == null ? -1 : source?.ancestors.indexOf(element) ?? -1;
      if (index >= 0 && index < distance) {
        nearest = element;
        distance = index;
      }
    }
    return nearest;
  }

  static const discoveryDistance = ScrollSource.discoveryLimit + 1;
  SmartPagerChain? smartChain(ScrollNotification n, ScrollSource? source) {
    final boundary = smartBoundary(source);
    return boundary == null ? null : smartResolver.describe(n, boundary);
  }

  bool hasSmartScope(ScrollSource? source) =>
      (source == null && _smartScopes.isNotEmpty) ||
      smartBoundary(source) != null;

  void bindSmartLifetime(ScrollSource? source) {
    final boundary = smartBoundary(source);
    for (final entry in _smartScopes.entries) {
      if (boundary != null && identical(entry.value(), boundary)) {
        _scope = entry.key;
        return;
      }
    }
  }

  void dispose() {
    invalidate();
    _smartScopes.clear();
  }

  int generation = 0;

  bool accept(ScrollSource? source, ScrollNotification notification,
      {List<ScrollPosition>? pagerPositions}) {
    final key = source?.position ?? notification.context ?? _syntheticSource;
    final next = pagerPositions ??
        [if (source?.pagerPosition != null) source!.pagerPosition!];
    final changed = !identical(_owner, key) ||
        next.length != _pagers.length ||
        List.generate(next.length, (i) => !identical(next[i], _pagers[i]))
            .contains(true);
    if (changed) invalidate();
    if (source != null) {
      if (notification is ScrollStartNotification) {
        _revoked[key] = null;
      } else if (_revoked[key] == true) {
        return false;
      }
    }
    if (changed) {
      _owner = key;
      _pagers = next;
      _pagerPixels = next.map((p) => p.hasPixels ? p.pixels : null).toList();
      for (final p in next) {
        p.addListener(_onPager);
        p.isScrollingNotifier.addListener(_onPager);
      }
    }
    return true;
  }

  void _onPager() {
    for (var i = 0; i < _pagers.length; i++) {
      final p = _pagers[i];
      if (p.isScrollingNotifier.value ||
          (p.hasPixels && p.pixels != _pagerPixels[i])) {
        invalidate();
        return;
      }
    }
  }

  void bindScope(Object scope, ScrollSource? source) {
    if (source != null && identical(_owner, source.position)) {
      _scope = scope;
      _automaticScope = scope;
    }
  }

  void releaseScope(Object scope) {
    if (identical(_scope, scope)) invalidate();
  }

  void rejectSource(Object scope, ScrollSource? source) {
    if (identical(_automaticScope, scope) &&
        source != null &&
        identical(_owner, source.position)) {
      invalidate();
    }
  }

  void invalidate() {
    if (_owner is ScrollPosition) _revoked[_owner!] = true;
    for (final p in _pagers) {
      p.removeListener(_onPager);
      p.isScrollingNotifier.removeListener(_onPager);
    }
    _pagers = [];
    _pagerPixels = [];
    _owner = null;
    _scope = null;
    _automaticScope = null;
    generation++;
  }
}

class _Unresolved implements Exception {}

class _Budget {
  int visits = 0;
  void step() {
    if (++visits > 4096) throw _Unresolved();
  }
}

class SmartPagerLink {
  SmartPagerLink(this.scrollable, this.viewport);
  final ScrollableState scrollable;
  final RenderViewport viewport;
  Element? root;
  int? index;
  ScrollPosition get position => scrollable.position;

  bool get active {
    if (!scrollable.mounted ||
        !viewport.attached ||
        root?.mounted != true ||
        index == null ||
        !position.hasContentDimensions) {
      return false;
    }
    final metrics = position.copyWith();
    if (metrics is! PageMetrics || metrics.viewportFraction != 1) return false;
    final page = metrics.page;
    return page != null &&
        !position.isScrollingNotifier.value &&
        (page - page.round()).abs() < .000001 &&
        page.round() == index;
  }
}

class SmartPagerChain {
  SmartPagerChain._(this.source, this.links, this.boundary, this._budget);
  final ScrollableState source;
  final List<SmartPagerLink> links; // Innermost first.
  final Element boundary;
  final _Budget _budget;
  bool get active => links.every((link) => link.active);

  bool uniquePath() {
    bool unique(Element root, ScrollableState expected) {
      var candidates = 0;
      var found = false;
      void visit(Element element) {
        _budget.step();
        if (element.widget case Offstage(offstage: true)) return;
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          if (axisDirectionToAxis(state.axisDirection) == Axis.vertical ||
              state.position.copyWith() is PageMetrics) {
            if (++candidates > 1) throw _Unresolved();
            found = identical(expected, state);
          }
          return; // Prune at every scrollable, including horizontal carousels.
        }
        element.visitChildElements(visit);
      }

      root.visitChildElements(visit);
      return candidates == 1 && found;
    }

    try {
      var expected = source;
      for (final link in links) {
        if (!unique(link.root!, expected)) return false;
        expected = link.scrollable;
      }
      return unique(boundary, expected);
    } on _Unresolved {
      return false;
    }
  }
}

class SmartScrollResolver {
  static const maxPagers = 4;
  final _cache = Expando<SmartPagerChain>();
  int maximumVisits = 0;

  SmartPagerChain? describe(ScrollNotification n, Element boundary) {
    if (n.metrics.axis != Axis.vertical || n.context?.mounted != true) {
      return null;
    }
    final cached = _cache[n];
    if (cached != null && identical(cached.boundary, boundary)) return cached;
    final budget = _Budget();
    final scrollables = <ScrollableState>[];
    final renders = <RenderObject, Element>{};
    final links = <SmartPagerLink>[];
    final pendingViewports = <RenderViewport>[];
    final pendingPagers = <ScrollableState>[];
    var reached = false;
    try {
      n.context!.visitAncestorElements((element) {
        budget.step();
        if (identical(element, boundary)) {
          reached = true;
          return false;
        }
        if (element.widget case Offstage(offstage: true)) throw _Unresolved();
        if (element is RenderObjectElement) {
          final render = element.renderObject;
          renders[render] = element;
          if (render is RenderViewport &&
              axisDirectionToAxis(render.axisDirection) == Axis.horizontal) {
            pendingViewports.add(render);
          }
        }
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          scrollables.add(state);
          if (axisDirectionToAxis(state.axisDirection) == Axis.horizontal) {
            if (state.position.copyWith() is! PageMetrics) throw _Unresolved();
            pendingPagers.add(state);
          }
        }
        if (element.widget case PageView(scrollDirection: Axis.horizontal)) {
          if (links.length == maxPagers ||
              pendingPagers.length != 1 ||
              pendingViewports.length != 1 ||
              !identical(pendingViewports.single.offset,
                  pendingPagers.single.position) ||
              pendingViewports.single.axisDirection !=
                  pendingPagers.single.axisDirection) {
            throw _Unresolved();
          }
          links.add(
              SmartPagerLink(pendingPagers.single, pendingViewports.single));
          pendingPagers.clear();
          pendingViewports.clear();
        } else if (element.widget is PageView) {
          throw _Unresolved();
        }
        return true;
      });
      if (!reached ||
          scrollables.isEmpty ||
          scrollables
                  .where((s) =>
                      axisDirectionToAxis(s.axisDirection) == Axis.horizontal)
                  .length !=
              links.length ||
          pendingPagers.isNotEmpty ||
          pendingViewports.isNotEmpty ||
          axisDirectionToAxis(scrollables.first.axisDirection) !=
              Axis.vertical) {
        return null;
      }
      RenderObject? child = n.context!.findRenderObject();
      while (child != null && links.isNotEmpty) {
        budget.step();
        final parent = child.parent;
        if (parent is RenderSliverFillViewport) {
          RenderObject? viewport = parent.parent;
          while (viewport is RenderSliverEdgeInsetsPadding) {
            budget.step();
            viewport = viewport.parent;
          }
          for (final link in links) {
            if (identical(viewport, link.viewport) &&
                child.parentData is SliverMultiBoxAdaptorParentData) {
              link.root = renders[child];
              link.index =
                  (child.parentData! as SliverMultiBoxAdaptorParentData).index;
            }
          }
        }
        if (identical(child, links.last.viewport)) break;
        child = parent;
      }
      if (links.any((link) => link.root == null || link.index == null)) {
        return null;
      }
      final result =
          SmartPagerChain._(scrollables.first, links, boundary, budget);
      _cache[n] = result;
      return result;
    } on _Unresolved {
      return null;
    } finally {
      if (budget.visits > maximumVisits) maximumVisits = budget.visits;
    }
  }

  bool accepts(ScrollNotification n, Element boundary) {
    final chain = describe(n, boundary);
    if (chain == null || !chain.active) return false;
    final result = chain.uniquePath();
    if (chain._budget.visits > maximumVisits) {
      maximumVisits = chain._budget.visits;
    }
    return result;
  }
}
