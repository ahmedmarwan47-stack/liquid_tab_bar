import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Test-only architecture experiment, not package API.
class PrototypeScrollSourceResolver {
  PrototypeScrollSourceResolver({this.rejectAmbiguous = false, this.measure = false});
  final bool rejectAmbiguous;
  final bool measure;
  final samplesMicros = <int>[];
  int accepted = 0;
  int rejected = 0;
  final depths = <int>{};
  int discoveryVisits = 0;
  int ambiguityRejections = 0;

  bool accepts(ScrollNotification n, BuildContext boundary) {
    if (!measure) return _accepts(n, boundary);
    final watch = Stopwatch()..start();
    final result = _accepts(n, boundary);
    watch.stop();
    if (n is ScrollUpdateNotification && n.metrics.axis == Axis.vertical) {
      samplesMicros.add(watch.elapsedMicroseconds);
    }
    return result;
  }

  bool _accepts(ScrollNotification n, BuildContext boundary) {
    if (n.metrics.axis != Axis.vertical || n.context == null) return false;
    final scrollables = <ScrollableState>[];
    final pagers = <PageView>[];
    final renderElements = <RenderObject, Element>{};
    var reachedBoundary = false;
    var offstage = false;
    n.context!.visitAncestorElements((element) {
      if (element == boundary) {
        reachedBoundary = true;
        return false;
      }
      if (element.widget case Offstage(offstage: true)) offstage = true;
      if (element is StatefulElement && element.state is ScrollableState) {
        scrollables.add(element.state as ScrollableState);
      }
      if (element.widget is PageView) pagers.add(element.widget as PageView);
      if (rejectAmbiguous && element is RenderObjectElement) {
        renderElements[element.renderObject] = element;
      }
      return true;
    });
    if (!reachedBoundary || offstage || scrollables.isEmpty) return false;
    if (axisDirectionToAxis(scrollables.first.axisDirection) != Axis.vertical) {
      return false;
    }
    if (scrollables.length == 1 && pagers.isEmpty) {
      return n.depth == 0 && (!rejectAmbiguous ||
          _hasUniqueSource(boundary as Element, scrollables.first));
    }
    if (scrollables.length != 2 || pagers.length != 1) return false;
    final pager = scrollables.last;
    if (axisDirectionToAxis(pager.axisDirection) != Axis.horizontal ||
        pagers.single.scrollDirection != Axis.horizontal ||
        pager.position.isScrollingNotifier.value ||
        !pager.position.hasContentDimensions) {
      return false;
    }
    final metrics = pager.position.copyWith();
    if (metrics is! PageMetrics || metrics.viewportFraction != 1) return false;
    final page = metrics.page;
    if (page == null || (page - page.round()).abs() > 0.000001) return false;

    // Public types, but this depends on PageView's current render composition.
    RenderObject? child = n.context!.findRenderObject();
    while (child != null && child.parent is! RenderSliverFillViewport) {
      child = child.parent;
    }
    if (child == null || child.parentData is! SliverMultiBoxAdaptorParentData) {
      return false;
    }
    if ((child.parentData! as SliverMultiBoxAdaptorParentData).index !=
        page.round()) {
      return false;
    }
    if (!rejectAmbiguous) return true;
    final pageRoot = renderElements[child];
    if (pageRoot == null) return false;
    return _hasUniqueSource(pageRoot, scrollables.first);
  }

  bool _hasUniqueSource(Element root, ScrollableState source) {
    final candidates = <ScrollableState>[];
    void visit(Element element) {
      if (candidates.length > 1) return;
      discoveryVisits++;
      if (element.widget case Offstage(offstage: true)) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (axisDirectionToAxis(state.axisDirection) == Axis.vertical) {
          candidates.add(state);
        }
        // Nested scrollables cannot be root-page owners.
        return;
      }
      element.visitChildElements(visit);
    }
    root.visitChildElements(visit);
    if (candidates.length > 1) ambiguityRejections++;
    return candidates.length == 1 &&
        identical(candidates.single, source);
  }
}

