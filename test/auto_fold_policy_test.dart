import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/scroll_source.dart';

class _Page extends StatefulWidget {
  const _Page(
      {super.key,
      required this.index,
      required this.scroll,
      required this.sibling,
      required this.showSibling,
      required this.nested,
      required this.onDispose,
      required this.decorations});
  final int index;
  final ScrollController scroll;
  final ScrollController sibling;
  final bool showSibling;
  final bool nested;
  final VoidCallback onDispose;
  final int decorations;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page>
    with AutomaticKeepAliveClientMixin<_Page> {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      if (widget.decorations > 0)
        SizedBox(
            height: 1,
            child: Stack(
                children: List.generate(
                    widget.decorations,
                    (_) => const Positioned(
                        top: 0, child: SizedBox(width: 1, height: 1))))),
      Expanded(
          child: CustomScrollView(
        key: ValueKey('scroll-${widget.index}'),
        controller: widget.scroll,
        slivers: [
          if (widget.nested)
            SliverToBoxAdapter(
                child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                        key: const ValueKey('nested'),
                        primary: false,
                        itemCount: 100,
                        itemBuilder: (_, i) =>
                            SizedBox(height: 50, child: Text('Nested $i'))))),
          SliverList.builder(
              itemCount: 100,
              itemBuilder: (_, i) => SizedBox(
                  height: 60, child: Text('Page ${widget.index}: $i'))),
        ],
      )),
      if (widget.showSibling)
        Expanded(
            child: ListView.builder(
                controller: widget.sibling,
                primary: false,
                itemCount: 100,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Sibling $i')))),
    ]);
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class _Fixture {
  _Fixture({double fraction = 1})
      : pager = PageController(viewportFraction: fraction);
  final PageController pager;
  final scrolls = List.generate(3, (_) => ScrollController());
  final siblings = List.generate(3, (_) => ScrollController());
  final bar = LiquidTabBarController();
  final searchText = TextEditingController();
  final focus = FocusNode();
  var disposals = 0;
  bool showSibling = false;
  var pageOrder = [0, 1, 2];
  late StateSetter rebuild;

  Future<void> mount(
    WidgetTester tester, {
    LiquidAutoFoldPolicy? policy,
    bool rtl = false,
    bool nested = false,
    bool manual = false,
    bool shrink = true,
    bool search = false,
    bool direct = false,
    int decorations = 0,
  }) async {
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (_, setState) {
        rebuild = setState;
        Widget body = direct
            ? ListView.builder(
                controller: scrolls.first,
                itemCount: 100,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Direct $i')))
            : PageView(
                controller: pager,
                children: pageOrder
                    .map((i) => _Page(
                        key: ValueKey('page-$i'),
                        index: i,
                        scroll: scrolls[i],
                        sibling: siblings[i],
                        showSibling: showSibling,
                        nested: nested && i == 0,
                        decorations: decorations,
                        onDispose: () => disposals++))
                    .toList());
        if (manual) {
          body = NotificationListener<ScrollNotification>(
              onNotification: (n) => bar.handleScroll(n, allowNested: true),
              child: body);
        }
        return Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: LiquidTabBarScaffold(
              autoFoldPolicy: policy ?? const LiquidAutoFoldPolicy.smart(),
              body: body,
              tabBar: LiquidTabBar(
                controller: bar,
                shrinkOnScroll: shrink,
                selectedIndex: 0,
                items: const [
                  LiquidTabItem.icon(label: 'Home', icon: Icons.home),
                  LiquidTabItem.icon(label: 'Library', icon: Icons.book)
                ],
                separateAction: search
                    ? LiquidTabAction.search(
                        controller: searchText,
                        focusNode: focus,
                        hintText: 'Search',
                        onTap: () => pager.jumpToPage(1))
                    : null,
              ),
            ));
      },
    )));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    pager.dispose();
    for (final scroll in [...scrolls, ...siblings]) {
      scroll.dispose();
    }
    bar.dispose();
    searchText.dispose();
    focus.dispose();
  }
}

void main() {
  test('policy values have stable equality without nullable mode switches', () {
    expect(LiquidAutoFoldPolicy.smart(), LiquidAutoFoldPolicy.smart());
    expect(LiquidAutoFoldPolicy.direct(), LiquidAutoFoldPolicy.direct());
    expect(const LiquidAutoFoldPolicy.smart(),
        isNot(const LiquidAutoFoldPolicy.direct()));
    bool select(ScrollNotification n) => true;
    expect(LiquidAutoFoldPolicy.custom(select),
        LiquidAutoFoldPolicy.custom(select));
  });

  testWidgets('smart default preserves direct ListView folding',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester);
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.mount(tester, direct: true);
    h.scrolls.first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  for (final rtl in [false, true]) {
    testWidgets('smart active PageView folds/unfolds and aligns, RTL=$rtl',
        (tester) async {
      final h = _Fixture();
      await h.mount(tester,
          policy: const LiquidAutoFoldPolicy.smart(), rtl: rtl);
      final surface = find
          .descendant(
              of: find.byType(LiquidTabBar), matching: find.byType(ClipRRect))
          .first;
      final width = tester.getSize(surface).width;
      await tester.drag(
          find.byKey(const ValueKey('scroll-0')), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isTrue);
      expect(tester.getSize(surface).width, 64);
      await tester.drag(
          find.byKey(const ValueKey('scroll-0')), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isFalse);
      expect(tester.getSize(surface).width, closeTo(width, .01));
      h.pager.jumpToPage(2);
      await tester.pumpAndSettle();
      h.scrolls[2].jumpTo(100);
      await tester.pumpAndSettle();
      expect(h.bar.minimized, isTrue);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }

  testWidgets('custom replaces smart eligibility and selects a sibling',
      (tester) async {
    final h = _Fixture()..showSibling = true;
    await h.mount(tester,
        policy: LiquidAutoFoldPolicy.custom((n) =>
            Scrollable.maybeOf(n.context!)?.position ==
            h.siblings.first.position));
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.siblings.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets(
      'custom false preserves manual forwarding; shrink false bypasses predicate',
      (tester) async {
    final h = _Fixture();
    var calls = 0;
    final policy = LiquidAutoFoldPolicy.custom((n) {
      calls++;
      return false;
    });
    await h.mount(tester, policy: policy, manual: true);
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    expect(calls, greaterThan(0));
    calls = 0;
    await h.mount(tester, policy: policy, shrink: false);
    h.scrolls.first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(h.bar.minimized, isFalse);
    await h.dispose(tester);
  });

  testWidgets('ambiguous siblings rejected before and after dynamic changes',
      (tester) async {
    final h = _Fixture()..showSibling = true;
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    h.scrolls.first.jumpTo(100);
    h.siblings.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.rebuild(() => h.showSibling = false);
    await tester.pumpAndSettle();
    h.scrolls.first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    h.bar.expand();
    h.rebuild(() => h.showSibling = true);
    await tester.pumpAndSettle();
    h.scrolls.first.jumpTo(300);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    await h.dispose(tester);
  });

  testWidgets('nested vertical list and horizontal swipes cannot fold',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester,
        policy: const LiquidAutoFoldPolicy.smart(), nested: true);
    await tester.drag(
        find.byKey(const ValueKey('nested')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    await h.dispose(tester);
  });

  testWidgets('new owner resets travel and direction without unfolding',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    h.scrolls.first.jumpTo(7);
    await tester.pumpAndSettle();
    h.pager.jumpToPage(1);
    await tester.pumpAndSettle();
    h.scrolls[1].jumpTo(7);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.scrolls[1].jumpTo(14);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    h.pager.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    h.scrolls.first.jumpTo(5); // New owner's 2px reversal must not expand.
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('same event forwarding is deduplicated before owner bookkeeping',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester,
        policy: const LiquidAutoFoldPolicy.smart(), manual: true);
    h.scrolls.first.jumpTo(7);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.scrolls.first.jumpTo(14);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('stale real fling cannot fold after switching away and back',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    await tester.fling(
        find.byKey(const ValueKey('scroll-0')), const Offset(0, -200), 2000);
    await tester.pump(const Duration(milliseconds: 16));
    h.pager.jumpToPage(1);
    await tester.pump();
    h.bar.expand();
    h.pager.jumpToPage(0);
    await tester.pump();
    final before = h.scrolls.first.offset;
    await tester.pump(const Duration(milliseconds: 32));
    expect(h.scrolls.first.offset, greaterThan(before));
    expect(h.bar.minimized, isFalse);
    await tester.pumpAndSettle();
    h.scrolls.first.jumpTo(h.scrolls.first.offset + 100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets(
      'inactive page and transitioning page rejected even by custom true',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: LiquidAutoFoldPolicy.custom((_) => true));
    h.pager.jumpToPage(1);
    await tester.pumpAndSettle();
    h.scrolls.first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    final transition = h.pager.animateToPage(2,
        duration: const Duration(milliseconds: 400), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.scrolls[1].jumpTo(200);
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    await tester.pumpAndSettle();
    await transition;
    h.scrolls[2].jumpTo(200);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('partial pages and discovery exhaustion fail closed',
      (tester) async {
    final h = _Fixture(fraction: .8);
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    await h.dispose(tester);
    final large = _Fixture();
    await large.mount(tester,
        policy: const LiquidAutoFoldPolicy.smart(),
        decorations: ScrollSource.discoveryLimit);
    large.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(large.bar.minimized, isFalse);
    await large.dispose(tester);
  });

  testWidgets('search, typing and keyboard insets preserve PageView lifecycle',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester,
        policy: const LiquidAutoFoldPolicy.smart(), search: true);
    final pageState = tester.state(find.byType(PageView));
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();
    expect(h.pager.page, 1);
    await tester.enterText(find.byType(TextField).first, 'Solo');
    await tester.pumpAndSettle();
    expect(h.searchText.text, 'Solo');
    for (final bottom in [300.0, 0.0, 300.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom);
      await tester.pumpAndSettle();
      expect(h.pager.page, 1);
      expect(tester.state(find.byType(PageView)), same(pageState));
      expect(h.disposals, 0);
      expect(h.bar.minimized, isFalse);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetViewInsets();
    h.bar.closeSearch();
    await tester.pumpAndSettle();
    expect(h.pager.page, 1);
    expect(h.disposals, 0);
    await h.dispose(tester);
  });

  testWidgets(
      'implicit PageController and internal tab controller work without forwarding',
      (tester) async {
    final scrolls = List.generate(2, (_) => ScrollController());
    await tester.pumpWidget(MaterialApp(
        home: LiquidTabBarScaffold(
      autoFoldPolicy: const LiquidAutoFoldPolicy.smart(),
      tabBar: LiquidTabBar(selectedIndex: 0, items: const [
        LiquidTabItem.icon(label: 'Home', icon: Icons.home),
        LiquidTabItem.icon(label: 'Library', icon: Icons.book)
      ]),
      body: PageView(children: [
        for (final scroll in scrolls)
          CustomScrollView(controller: scroll, slivers: [
            SliverList.builder(
                itemCount: 100,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Item $i')))
          ])
      ]),
    )));
    final boundBar = tester.widget<LiquidTabBar>(find.byType(LiquidTabBar));
    expect(boundBar.controller, isNotNull);
    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(boundBar.controller!.minimized, isFalse);
    scrolls[1].jumpTo(100);
    await tester.pumpAndSettle();
    expect(boundBar.controller!.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(boundBar.controller!.isDisposed, isTrue);
    for (final scroll in scrolls) {
      scroll.dispose();
    }
  });

  testWidgets(
      'page reorder uses render identity rather than navbar or former page index',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    h.scrolls.first.jumpTo(7);
    await tester.pumpAndSettle();
    h.pager.jumpToPage(1);
    await tester.pumpAndSettle();
    h.pager.jumpToPage(0);
    await tester.pumpAndSettle();
    h.rebuild(() => h.pageOrder = [1, 0, 2]);
    await tester.pumpAndSettle();
    expect(h.pager.page, 0);
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.scrolls[1].jumpTo(7);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isFalse);
    h.scrolls[1].jumpTo(14);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    h.rebuild(() => h.pageOrder = [1, 0]);
    await tester.pumpAndSettle();
    expect(h.pager.page, 0);
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets('offstage sibling is excluded; offstage source cannot fold',
      (tester) async {
    final bar = LiquidTabBarController();
    final scrolls = List.generate(2, (_) => ScrollController());
    await tester.pumpWidget(MaterialApp(
        home: LiquidTabBarScaffold(
      autoFoldPolicy: const LiquidAutoFoldPolicy.smart(),
      tabBar: LiquidTabBar(
          controller: bar,
          selectedIndex: 0,
          items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)]),
      body: Column(children: [
        for (var i = 0; i < 2; i++)
          Expanded(
              child: Offstage(
                  offstage: i == 1,
                  child: ListView.builder(
                      controller: scrolls[i],
                      itemCount: 100,
                      itemBuilder: (_, row) =>
                          SizedBox(height: 60, child: Text('Item $row')))))
      ]),
    )));
    scrolls[1].jumpTo(100);
    await tester.pumpAndSettle();
    expect(bar.minimized, isFalse);
    scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final scroll in scrolls) {
      scroll.dispose();
    }
    bar.dispose();
  });

  testWidgets(
      'repeated end and rejected-then-accepted notifications do not poison deduplication',
      (tester) async {
    final bar = LiquidTabBarController();
    await tester.pumpWidget(const SizedBox.shrink());
    final context = tester.element(find.byType(SizedBox));
    final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 500,
        pixels: 50,
        viewportDimension: 300,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1);
    final first = ScrollUpdateNotification(
        context: context, metrics: metrics, scrollDelta: 7, depth: 1);
    bar.handleScroll(first); // Rejected depth must not mark it processed.
    bar.handleScroll(first, allowNested: true);
    final end = ScrollEndNotification(context: context, metrics: metrics);
    bar.handleScroll(end);
    bar.handleScroll(end);
    bar.handleScroll(first,
        allowNested: true); // Old accepted update stays deduped.
    expect(bar.minimized, isFalse);
    bar.handleScroll(ScrollUpdateNotification(
        context: context, metrics: metrics, scrollDelta: 7));
    expect(bar.minimized, isTrue);
    bar.dispose();
  });

  testWidgets(
      'losing sibling uniqueness during a held scroll revokes its continuation',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    h.bar.expand();
    h.rebuild(() => h.showSibling = true);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    h.rebuild(() => h.showSibling = false);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    h.scrolls.first.jumpTo(h.scrolls.first.offset + 100);
    await tester.pumpAndSettle();
    expect(h.bar.minimized, isTrue);
    await h.dispose(tester);
  });

  testWidgets(
      'scaffold disposal releases external controller ownership without unfolding',
      (tester) async {
    final h = _Fixture();
    await h.mount(tester, policy: const LiquidAutoFoldPolicy.smart());
    h.scrolls.first.jumpTo(100);
    await tester.pumpAndSettle();
    final tracking = scrollOwnershipFor(h.bar);
    final before = tracking.generation;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tracking.generation, greaterThan(before));
    expect(h.bar.minimized, isTrue);
    expect(h.bar.isDisposed, isFalse);
    await h.dispose(tester);
  });

  for (final decorations in [0, 1000]) {
    testWidgets('production continuous resolution measurement: $decorations',
        (tester) async {
      final h = _Fixture();
      await h.mount(tester,
          policy: const LiquidAutoFoldPolicy.smart(), decorations: decorations);
      final sourceState = tester.state<ScrollableState>(find
          .descendant(
              of: find.byKey(const ValueKey('scroll-0')),
              matching: find.byType(Scrollable))
          .first);
      final boundary = tester.element(find
          .descendant(
              of: find.byType(LiquidTabBarScaffold),
              matching: find.byWidgetPredicate(
                  (w) => w is NotificationListener<ScrollNotification>))
          .first);
      final samples = <int>[];
      for (var i = 0; i < 620; i++) {
        h.scrolls.first.jumpTo(i + 1.0);
        await tester.pump(const Duration(microseconds: 8333));
        final n = ScrollUpdateNotification(
            context: sourceState.notificationContext!,
            metrics: sourceState.position.copyWith(),
            scrollDelta: 1);
        final watch = Stopwatch()..start();
        n.dispatch(sourceState.notificationContext);
        watch.stop();
        expect(
            scrollOwnershipFor(h.bar)
                .smartResolver
                .describe(n, boundary)!
                .active,
            isTrue);
        if (i >= 30) samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      debugPrint(
          'PRODUCTION_AUTO_FOLD_CALLBACK decorations=$decorations samples=${samples.length} '
          'median_us=${samples[samples.length ~/ 2]} '
          'p95_us=${samples[(samples.length * .95).floor()]} max_us=${samples.last}');
      expect(h.bar.minimized, isTrue);
      await h.dispose(tester);
    });
  }
}
