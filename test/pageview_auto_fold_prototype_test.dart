import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'support/auto_fold_source_resolver.dart';

// Test-only package-boundary prototype. No application forwarding is required.

class _PrototypeScaffold extends StatelessWidget {
  const _PrototypeScaffold({required this.body, required this.controller,
    required this.resolver});
  final Widget body;
  final LiquidTabBarController controller;
  final PrototypeScrollSourceResolver resolver;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: Builder(builder: (boundary) => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final eligible = resolver.accepts(n, boundary);
        if (n is ScrollUpdateNotification && n.metrics.axis == Axis.vertical) {
          resolver.depths.add(n.depth);
          eligible ? resolver.accepted++ : resolver.rejected++;
        }
        if (eligible) controller.handleScroll(n, allowNested: true);
        return false;
      },
      child: LiquidScrollPadding(child: body),
    )),
    bottomNavigationBar: LiquidTabBar(
      controller: controller,
      selectedIndex: 0,
      items: const [
        LiquidTabItem.icon(label: 'Home', icon: Icons.home),
        LiquidTabItem.icon(label: 'Library', icon: Icons.book),
      ],
    ),
  );
}

class _Page extends StatefulWidget {
  const _Page({required this.index, required this.controller, this.nested = false});
  final int index;
  final ScrollController controller;
  final bool nested;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      key: ValueKey('page-${widget.index}'),
      controller: widget.controller,
      slivers: [
        if (widget.nested) SliverToBoxAdapter(child: SizedBox(height: 160,
          child: ListView.builder(key: const ValueKey('nested'), primary: false,
            itemCount: 50, itemBuilder: (_, i) => SizedBox(height: 50,
              child: Text('Nested $i'))))),
        SliverList.builder(itemCount: 100, itemBuilder: (_, i) =>
          SizedBox(height: 60, child: Text('Page ${widget.index}: $i'))),
      ],
    );
  }
}

class _Harness {
  _Harness({bool rejectAmbiguous = false})
    : resolver = PrototypeScrollSourceResolver(rejectAmbiguous: rejectAmbiguous);
  final pager = PageController();
  PageController? partialPager;
  final pages = List.generate(3, (_) => ScrollController());
  final bar = LiquidTabBarController();
  final PrototypeScrollSourceResolver resolver;

  Future<void> mount(WidgetTester tester, {bool rtl = false,
      bool nested = false, double fraction = 1}) async {
    await tester.pumpWidget(MaterialApp(home: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: _PrototypeScaffold(controller: bar, resolver: resolver,
        body: PageView(controller: fraction == 1 ? pager :
          (partialPager = PageController(viewportFraction: fraction)),
          children: List.generate(3, (i) => _Page(index: i,
            controller: pages[i], nested: nested && i == 0))),
      ),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    pager.dispose();
    partialPager?.dispose();
    for (final page in pages) { page.dispose(); }
    bar.dispose();
  }
}

void main() {
  for (final rtl in [false, true]) {
    testWidgets('active PageView source folds and reverses, RTL=$rtl', (tester) async {
      final h = _Harness(rejectAmbiguous: true);
      await h.mount(tester, rtl: rtl);
      final surface = find.descendant(of: find.byType(LiquidTabBar),
        matching: find.byType(ClipRRect)).first;
      final expandedWidth = tester.getSize(surface).width;
      await tester.drag(find.byKey(const ValueKey('page-0')), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isTrue);
      expect(tester.getSize(surface).width, lessThan(expandedWidth));
      expect(h.resolver.depths, contains(1));
      await tester.drag(find.byKey(const ValueKey('page-0')), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isFalse);
      expect(tester.getSize(surface).width, closeTo(expandedWidth, 0.01));
      h.pager.jumpToPage(2);
      await tester.pumpAndSettle();
      h.pages[2].jumpTo(200);
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isTrue);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }

  testWidgets('kept-alive inactive page cannot fold; active programmatic scroll can', (tester) async {
    final h = _Harness(rejectAmbiguous: true);
    await h.mount(tester);
    h.pager.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(h.pages[0].hasClients, isTrue);
    h.bar.expand();
    final rejected = h.resolver.rejected;
    h.pages[0].jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    expect(h.resolver.rejected, greaterThan(rejected));
    h.pages[1].jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('nested vertical list is rejected, page source still works', (tester) async {
    final h = _Harness(rejectAmbiguous: true);
    await h.mount(tester, nested: true);
    await tester.drag(find.byKey(const ValueKey('nested')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    expect(h.resolver.rejected, greaterThan(0));
    await tester.dragFrom(const Offset(400, 300), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('horizontal swipes and fractional page transitions do not fold', (tester) async {
    final h = _Harness(rejectAmbiguous: true);
    await h.mount(tester);
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.pager.jumpToPage(0);
    await tester.pumpAndSettle();
    final transition = h.pager.animateToPage(1,
      duration: const Duration(milliseconds: 400), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.pages[0].jumpTo(200);
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    await tester.pumpAndSettle();
    await transition;
    h.pages[1].jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('switching pages during real fling rejects stale updates', (tester) async {
    final h = _Harness(rejectAmbiguous: true);
    await h.mount(tester);
    await tester.fling(find.byKey(const ValueKey('page-0')), const Offset(0, -200), 2000);
    await tester.pump(const Duration(milliseconds: 16));
    h.pager.jumpToPage(1);
    await tester.pump();
    h.bar.expand();
    final rejected = h.resolver.rejected;
    await tester.pump(const Duration(milliseconds: 32));
    expect(h.resolver.rejected, greaterThan(rejected));
    expect(h.bar.minimized, isFalse);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    await h.dispose(tester);
  });

  testWidgets('partial-page PageView fails safely', (tester) async {
    final h = _Harness();
    await h.mount(tester, fraction: 0.8);
    h.pages[0].jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    expect(h.resolver.accepted, 0);
    await h.dispose(tester);
  });

  testWidgets('direct ListView retains existing fold behavior', (tester) async {
    final bar = LiquidTabBarController();
    final resolver = PrototypeScrollSourceResolver();
    await tester.pumpWidget(MaterialApp(home: _PrototypeScaffold(
      controller: bar, resolver: resolver,
      body: ListView.builder(itemCount: 100, itemBuilder: (_, i) =>
        SizedBox(height: 60, child: Text('Item $i'))))));
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    expect(resolver.depths, {0});
    await tester.pumpWidget(const SizedBox.shrink());
    bar.dispose();
  });

  testWidgets('default PageController works without app forwarding', (tester) async {
    final bar = LiquidTabBarController();
    final resolver = PrototypeScrollSourceResolver();
    final pages = List.generate(2, (_) => ScrollController());
    await tester.pumpWidget(MaterialApp(home: _PrototypeScaffold(
      controller: bar, resolver: resolver,
      body: PageView(children: List.generate(2, (i) =>
        _Page(index: i, controller: pages[i]))))));
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(bar.minimized, isFalse);
    pages[1].jumpTo(200);
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final page in pages) { page.dispose(); }
    bar.dispose();
  });

  testWidgets('controller no longer carries subthreshold travel across owners', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    h.pages[0].jumpTo(7);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.pager.jumpToPage(1);
    await tester.pumpAndSettle();
    h.pages[1].jumpTo(7);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.pages[1].jumpTo(14);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('documented ambiguity: sibling lists have equally valid ancestry', (tester) async {
    final pager = PageController();
    final bar = LiquidTabBarController();
    final resolver = PrototypeScrollSourceResolver();
    await tester.pumpWidget(MaterialApp(home: _PrototypeScaffold(
      controller: bar, resolver: resolver,
      body: PageView(controller: pager, children: [Column(children: [
        for (final label in ['main', 'unrelated']) Expanded(child:
          ListView.builder(key: ValueKey(label), primary: false,
            itemCount: 100, itemBuilder: (_, i) =>
              SizedBox(height: 60, child: Text('$label $i')))),
      ])]))));
    await tester.drag(find.byKey(const ValueKey('unrelated')), const Offset(0, -150));
    await tester.pumpAndSettle();
    // Public source/page identity alone cannot infer which sibling is intended.
    expect(resolver.accepted, greaterThan(0));
    expect(bar.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    pager.dispose();
    bar.dispose();
  });

  testWidgets('conservative discovery rejects both sibling sources', (tester) async {
    final pager = PageController();
    final bar = LiquidTabBarController();
    final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true);
    final pages = List.generate(2, (_) => ScrollController());
    var secondVisible = true;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: _PrototypeScaffold(
      controller: bar, resolver: resolver,
      body: PageView(controller: pager, children: [StatefulBuilder(
        builder: (_, setState) {
          rebuild = setState;
          return Column(children: [
            for (var i = 0; i < (secondVisible ? 2 : 1); i++) Expanded(child:
              ListView.builder(controller: pages[i], primary: false,
                itemCount: 100, itemBuilder: (_, row) =>
                  SizedBox(height: 60, child: Text('Source $i: $row')))),
          ]);
        },
      )]))));
    for (final page in pages) {
      page.jumpTo(100);
      await tester.pumpAndSettle();
      expect(bar.minimized, isFalse);
    }
    expect(resolver.accepted, 0);
    expect(resolver.rejected, 2);
    expect(resolver.ambiguityRejections, 6); // Start/update/end for each jump.
    rebuild(() => secondVisible = false);
    await tester.pumpAndSettle();
    pages.first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    bar.expand();
    rebuild(() => secondVisible = true);
    await tester.pumpAndSettle();
    pages.first.jumpTo(300);
    await tester.pumpAndSettle();
    expect(bar.minimized, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    pager.dispose();
    for (final page in pages) { page.dispose(); }
    bar.dispose();
  });

  for (final decorations in [0, 1000]) {
    testWidgets('measure continuous resolution: decorations=$decorations', (tester) async {
      final pager = PageController();
      final scroll = ScrollController();
      final bar = LiquidTabBarController();
      final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true, measure: true);
      await tester.pumpWidget(MaterialApp(home: _PrototypeScaffold(
        controller: bar, resolver: resolver,
        body: PageView(controller: pager, children: [Column(children: [
          if (decorations > 0) SizedBox(height: 1, child: Stack(children:
            List.generate(decorations, (_) => const Positioned(top: 0,
              child: SizedBox(width: 1, height: 1))))),
          Expanded(child: _Page(index: 0, controller: scroll)),
        ])]))));
      await tester.pumpAndSettle();
      final animation = scroll.animateTo(4000,
        duration: const Duration(seconds: 5), curve: Curves.linear);
      await tester.pump();
      for (var i = 0; i < 610; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      await animation;
      expect(bar.minimized, isTrue);
      expect(resolver.samplesMicros.length, greaterThan(590));
      final samples = resolver.samplesMicros.skip(30).toList()..sort();
      final median = samples[samples.length ~/ 2];
      final p95 = samples[(samples.length * 0.95).floor()];
      debugPrint('AUTO_FOLD_BENCH decorations=$decorations '
        'samples=${samples.length} median_us=$median p95_us=$p95 '
        'max_us=${samples.last} discovery_visits=${resolver.discoveryVisits}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      pager.dispose();
      scroll.dispose();
      bar.dispose();
    }, tags: ['benchmark']);
  }
}
