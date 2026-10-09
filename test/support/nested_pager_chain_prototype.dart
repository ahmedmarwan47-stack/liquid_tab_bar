import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/scroll_source.dart';

// Test-only experiment. Neither this resolver nor controller is exported.
class _Unresolved implements Exception {}

class _Budget {
  int visits = 0;
  void step() {
    if (++visits > 4096) throw _Unresolved();
  }
}

class PrototypePagerLink {
  PrototypePagerLink(this.scrollable, this.viewport);
  final ScrollableState scrollable;
  final RenderViewport viewport;
  Element? root;
  int? index;
  ScrollPosition get position => scrollable.position;

  bool get active {
    if (root?.mounted != true ||
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

class PrototypePagerChain {
  PrototypePagerChain._(this.source, this.links, this.boundary, this._budget);
  final ScrollableState source;
  final List<PrototypePagerLink> links; // Innermost first.
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

class NestedPagerPrototypeResolver {
  static const maxPagers = 4;
  final _cache = Expando<PrototypePagerChain>();
  int maximumVisits = 0;

  PrototypePagerChain? describe(ScrollNotification n, Element boundary) {
    if (n.metrics.axis != Axis.vertical || n.context?.mounted != true) {
      return null;
    }
    final cached = _cache[n];
    if (cached != null && identical(cached.boundary, boundary)) return cached;
    final budget = _Budget();
    final scrollables = <ScrollableState>[];
    final renders = <RenderObject, Element>{};
    final links = <PrototypePagerLink>[];
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
          links.add(PrototypePagerLink(
              pendingPagers.single, pendingViewports.single));
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
          PrototypePagerChain._(scrollables.first, links, boundary, budget);
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

// Models smart-policy registration at the package boundary. Existing direct and
// custom policies use the real legacy controller unchanged in separate tests.
class NestedPagerPrototypeController extends LiquidTabBarController {
  final resolver = NestedPagerPrototypeResolver();
  Element? boundary;
  final _processed = Expando<bool>();
  final _revoked = Expando<bool>();
  ScrollPosition? _owner;
  ScrollPosition? _automaticOwner;
  List<ScrollPosition> _pagers = [];
  List<double> _pixels = [];
  int invalidations = 0;
  int forwarded = 0;

  void invalidate() {
    if (_owner != null) _revoked[_owner!] = true;
    for (final p in _pagers) {
      p.removeListener(_onPager);
      p.isScrollingNotifier.removeListener(_onPager);
    }
    _owner = null;
    _automaticOwner = null;
    _pagers = [];
    _pixels = [];
    invalidations++;
    // Reset real controller accumulation on its next accepted notification.
    scrollOwnershipFor(this).invalidate();
  }

  void _onPager() {
    for (var i = 0; i < _pagers.length; i++) {
      if (_pagers[i].isScrollingNotifier.value ||
          _pagers[i].pixels != _pixels[i]) {
        invalidate();
        return;
      }
    }
  }

  bool automatic(ScrollNotification n) {
    if (boundary != null && resolver.accepts(n, boundary!)) {
      handleScroll(n, allowNested: true);
      _automaticOwner = resolver.describe(n, boundary!)?.source.position;
    } else if (boundary != null) {
      final chain = resolver.describe(n, boundary!);
      if (chain != null && identical(_automaticOwner, chain.source.position)) {
        invalidate();
      }
    }
    return false;
  }

  @override
  bool handleScroll(ScrollNotification n, {bool allowNested = false}) {
    if (isDisposed || _processed[n] == true || (!allowNested && n.depth != 0)) {
      return false;
    }
    final b = boundary;
    if (b == null) return false;
    final chain = resolver.describe(n, b);
    if (chain == null || !chain.active) return false;
    final pagers = chain.links.map((link) => link.position).toList();
    final owner = chain.source.position;
    final changed = !identical(owner, _owner) ||
        pagers.length != _pagers.length ||
        List.generate(pagers.length, (i) => !identical(pagers[i], _pagers[i]))
            .contains(true);
    if (changed) invalidate();
    if (n is ScrollStartNotification) {
      _revoked[owner] = null;
    } else if (_revoked[owner] == true) {
      return false;
    }
    if (changed) {
      _owner = owner;
      _pagers = pagers;
      _pixels = pagers.map((p) => p.pixels).toList();
      for (final p in pagers) {
        p.addListener(_onPager);
        p.isScrollingNotifier.addListener(_onPager);
      }
    }
    _processed[n] = true;
    forwarded++;
    return super.handleScroll(n, allowNested: allowNested);
  }

  @override
  void dispose() {
    invalidate();
    boundary = null;
    super.dispose();
  }
}
