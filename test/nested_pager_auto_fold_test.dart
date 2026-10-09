import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'package:liquid_tab_bar/src/scroll_source.dart';

class _ProductionController extends LiquidTabBarController {
  SmartScrollResolver get resolver => scrollOwnershipFor(this).smartResolver;
  int get invalidations => scrollOwnershipFor(this).generation;
  void invalidate() => scrollOwnershipFor(this).invalidate();
}

class _Leaf extends StatefulWidget {
  const _Leaf(
      {super.key,
      required this.id,
      required this.scroll,
      this.nested = false,
      this.sibling,
      this.query = ''});
  final int id;
  final ScrollController scroll;
  final bool nested;
  final ScrollController? sibling;
  final String query;
  @override
  State<_Leaf> createState() => _LeafState();
}

class _LeafState extends State<_Leaf> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = !widget.nested && widget.id < 4
        ? ListView.builder(
            key: ValueKey('list-${widget.id}'),
            controller: widget.scroll,
            itemCount: 100,
            itemBuilder: (_, i) =>
                SizedBox(height: 60, child: Text('Page ${widget.id} row $i')))
        : CustomScrollView(
            key: ValueKey('list-${widget.id}'),
            controller: widget.scroll,
            slivers: [
              if (widget.nested)
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                            key: const ValueKey('nested-list'),
                            primary: false,
                            itemCount: 100,
                            itemBuilder: (_, i) => SizedBox(
                                height: 50, child: Text('Nested $i'))))),
              SliverList.builder(
                  itemCount: 100,
                  itemBuilder: (_, i) => SizedBox(
                      height: 60,
                      child: Text('Page ${widget.id} ${widget.query} row $i'))),
            ],
          );
    if (widget.sibling == null) return list;
    return Column(children: [
      Expanded(child: list),
      Expanded(
          child: ListView.builder(
              controller: widget.sibling,
              itemCount: 100,
              itemBuilder: (_, i) =>
                  SizedBox(height: 60, child: Text('Sibling $i'))))
    ]);
  }
}

class _Library extends StatefulWidget {
  const _Library(
      {super.key,
      required this.h,
      this.defaultTabs = false,
      this.plainPager = false,
      this.nested = false,
      this.sibling = false,
      this.outerSibling = false,
      this.decorations = 0});
  final _Harness h;
  final bool defaultTabs, plainPager, nested, sibling, outerSibling;
  final int decorations;
  @override
  State<_Library> createState() => _LibraryState();
}

class _LibraryState extends State<_Library>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController tabs;
  var ids = [0, 1, 2];
  var extraSibling = false;
  void setSibling(bool enabled) => setState(() => extraSibling = enabled);
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    if (!widget.defaultTabs) {
      tabs = TabController(length: ids.length, vsync: this);
    }
  }

  void changeTabs(List<int> next) {
    setState(() {
      ids = next;
      if (!widget.defaultTabs) {
        tabs.dispose();
        tabs = TabController(length: ids.length, vsync: this);
      }
    });
  }

  Widget _contents() {
    final children = [
      for (final id in ids)
        _Leaf(
            key: ValueKey('leaf-$id'),
            id: id,
            scroll: widget.h.lists[id],
            nested: widget.nested && id == 0,
            sibling: widget.sibling && id == 0 ? widget.h.sibling : null)
    ];
    Widget pager = widget.plainPager
        ? PageView(controller: widget.h.inner, children: children)
        : TabBarView(
            key: const ValueKey('inner-tabs'),
            controller: widget.defaultTabs ? null : tabs,
            children: children);
    pager = Column(children: [
      Expanded(child: pager),
      if (widget.outerSibling || extraSibling)
        Expanded(
            child: ListView.builder(
                controller: widget.h.sibling,
                itemCount: 100,
                itemBuilder: (_, i) => SizedBox(height: 60, child: Text('$i'))))
    ]);
    return Column(children: [
      if (widget.decorations > 0)
        SizedBox(
            height: 1,
            child: Stack(children: [
              for (var i = 0; i < widget.decorations; i++)
                const Positioned(top: 0, child: SizedBox(width: 1, height: 1))
            ])),
      Expanded(child: pager),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.defaultTabs) return _contents();
    return DefaultTabController(
        length: ids.length,
        child: Builder(builder: (context) {
          tabs = DefaultTabController.of(context);
          return _contents();
        }));
  }

  @override
  void dispose() {
    if (!widget.defaultTabs) tabs.dispose();
    super.dispose();
  }
}

class _Harness {
  _Harness({double fraction = 1})
      : outer = PageController(viewportFraction: fraction);
  final bar = _ProductionController();
  final PageController outer;
  final inner = PageController();
  final lists = List.generate(4, (_) => ScrollController());
  final home = ScrollController();
  final search = ScrollController();
  final sibling = ScrollController();
  final text = TextEditingController();
  final focus = FocusNode();
  final libraryKey = GlobalKey<_LibraryState>();
  final pageKey = GlobalKey();
  late StateSetter rebuild;

  Future<void> mount(WidgetTester tester,
      {bool rtl = false,
      bool implicitOuter = false,
      bool defaultTabs = false,
      bool plainPager = false,
      bool nested = false,
      bool sibling = false,
      bool outerSibling = false,
      bool manual = false,
      int decorations = 0,
      Widget? customBody}) async {
    await tester.pumpWidget(MaterialApp(
        home: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: StatefulBuilder(builder: (_, setState) {
        rebuild = setState;
        Widget body = customBody ??
            PageView(
                key: pageKey,
                controller: implicitOuter ? null : outer,
                children: [
                  _Leaf(id: 8, scroll: home),
                  _Library(
                      key: libraryKey,
                      h: this,
                      defaultTabs: defaultTabs,
                      plainPager: plainPager,
                      nested: nested,
                      sibling: sibling,
                      outerSibling: outerSibling,
                      decorations: decorations),
                  _Leaf(id: 9, scroll: search, query: text.text),
                ]);
        if (manual) {
          body = NotificationListener<ScrollNotification>(
              onNotification: (n) => bar.handleScroll(n, allowNested: true),
              child: body);
        }
        return LiquidTabBarScaffold(
          body: body,
          tabBar: LiquidTabBar(
              controller: bar,
              selectedIndex: 0,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home),
                LiquidTabItem.icon(label: 'Library', icon: Icons.book)
              ],
              separateAction: LiquidTabAction.search(
                  controller: text,
                  focusNode: focus,
                  hintText: 'Find',
                  onTap: () => outer.jumpToPage(2),
                  onChanged: (_) => rebuild(() {}))),
        );
      }),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> library(WidgetTester tester) async {
    outer.jumpToPage(1);
    await tester.pumpAndSettle();
  }

  Future<void> expectFold(WidgetTester tester, bool folded) async {
    await tester.pumpAndSettle();
    expect(bar.minimized, folded);
    final width = tester
        .getSize(find
            .descendant(
                of: find.byType(LiquidTabBar), matching: find.byType(ClipRRect))
            .first)
        .width;
    expect(width, folded ? closeTo(64, .01) : greaterThan(64));
    expect(tester.takeException(), isNull);
  }

  Future<void> dispose(WidgetTester tester) async {
    bar.invalidate();
    await tester.pumpWidget(const SizedBox.shrink());
    for (final c in [...lists, home, search, sibling]) {
      c.dispose();
    }
    outer.dispose();
    inner.dispose();
    text.dispose();
    focus.dispose();
    bar.dispose();
  }
}

void main() {
  for (final policy in [
    const LiquidAutoFoldPolicy.direct(),
    const LiquidAutoFoldPolicy.smart(),
    LiquidAutoFoldPolicy.custom((_) => true)
  ]) {
    testWidgets('production nested policy: ${policy.runtimeType}',
        (tester) async {
      final bar = LiquidTabBarController();
      final scroll = ScrollController();
      await tester.pumpWidget(MaterialApp(
          home: LiquidTabBarScaffold(
        autoFoldPolicy: policy,
        body: PageView(children: [
          DefaultTabController(
              length: 3,
              child: TabBarView(children: [
                _Leaf(id: 0, scroll: scroll),
                const SizedBox.shrink(),
                const SizedBox.shrink()
              ]))
        ]),
        tabBar: LiquidTabBar(
            controller: bar,
            selectedIndex: 0,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)]),
      )));
      await tester.pumpAndSettle();
      scroll.jumpTo(100);
      await tester.pumpAndSettle();
      final expected = policy != const LiquidAutoFoldPolicy.direct();
      expect(bar.minimized, expected);
      final width = tester
          .getSize(find
              .descendant(
                  of: find.byType(LiquidTabBar),
                  matching: find.byType(ClipRRect))
              .first)
          .width;
      expect(width, expected ? closeTo(64, .01) : greaterThan(64));
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      bar.dispose();
    });
  }

  testWidgets('production preserves direct CustomScrollView behavior',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, customBody: _Leaf(id: 8, scroll: h.home));
    h.home.jumpTo(100);
    await h.expectFold(tester, true);
    h.home.jumpTo(0);
    await h.expectFold(tester, false);
    await h.dispose(tester);
  });

  for (final levels in [3, 4, 5]) {
    testWidgets('generalized chain bounded at four pagers: levels=$levels',
        (tester) async {
      final h = _Harness();
      Widget body = _Leaf(id: 8, scroll: h.home);
      for (var i = 0; i < levels; i++) {
        body = PageView(children: [body, const SizedBox.shrink()]);
      }
      await h.mount(tester, customBody: body);
      h.home.jumpTo(100);
      await h.expectFold(tester, levels <= 4);
      await h.dispose(tester);
    });
  }

  testWidgets('sibling horizontal pagers fail closed at scaffold scope',
      (tester) async {
    final h = _Harness();
    await h.mount(tester,
        customBody: Column(children: [
          Expanded(
              child: PageView(children: [_Leaf(id: 0, scroll: h.lists[0])])),
          Expanded(
              child: PageView(children: [_Leaf(id: 1, scroll: h.lists[1])]))
        ]));
    h.lists[0].jumpTo(100);
    h.lists[1].jumpTo(100);
    await h.expectFold(tester, false);
    await h.dispose(tester);
  });

  testWidgets('fractional outer pager and exhausted shared budget fail closed',
      (tester) async {
    final h = _Harness(fraction: .8);
    await h.mount(tester);
    await h.library(tester);
    h.lists.first.jumpTo(100);
    await h.expectFold(tester, false);
    await h.dispose(tester);
    final huge = _Harness();
    await huge.mount(tester, decorations: 3000);
    await huge.library(tester);
    huge.lists.first.jumpTo(100);
    await huge.expectFold(tester, false);
    expect(huge.bar.resolver.maximumVisits, 4097);
    await huge.dispose(tester);
  });

  testWidgets(
      'rapid TabController index changes never select an offscreen list as owner',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    h.libraryKey.currentState!.tabs.index = 1;
    await tester.pump();
    h.libraryKey.currentState!.tabs.index = 0;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(h.libraryKey.currentState!.tabs.index, 0);
    final inner = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const ValueKey('inner-tabs')),
            matching: find.byType(Scrollable))
        .first);
    // A framework warp is still showing page 1; index 0 is merely the intent.
    expect((inner.position.copyWith() as PageMetrics).page, 1);
    h.lists[0].jumpTo(100);
    await h.expectFold(tester, false);
    h.lists[1].jumpTo(100);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  for (final rtl in [false, true]) {
    testWidgets('all inner TabBarView destinations fold and unfold, RTL=$rtl',
        (tester) async {
      final h = _Harness();
      await h.mount(tester, rtl: rtl);
      h.home.jumpTo(100);
      await h.expectFold(tester, true);
      await h.library(tester);
      await h.expectFold(
          tester, true); // Page changes preserve the visual state.
      for (var index = 0; index < 3; index++) {
        h.libraryKey.currentState!.tabs.animateTo(index);
        await tester.pumpAndSettle();
        h.bar.expand();
        await tester.drag(
            find.byKey(ValueKey('list-$index')), const Offset(0, -150));
        await h.expectFold(tester, true);
        await tester.drag(
            find.byKey(ValueKey('list-$index')), const Offset(0, 150));
        await h.expectFold(tester, false);
      }
      await h.dispose(tester);
    });
  }

  testWidgets('default outer PageController and DefaultTabController',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, implicitOuter: true, defaultTabs: true);
    final outerState = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(h.pageKey), matching: find.byType(Scrollable))
        .first);
    outerState.position.jumpTo(outerState.position.viewportDimension);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      h.libraryKey.currentState!.tabs.animateTo(i);
      await tester.pumpAndSettle();
      h.bar.expand();
      h.lists[i].jumpTo(100);
      await h.expectFold(tester, true);
    }
    await h.dispose(tester);
  });

  testWidgets('explicit nested PageControllers use the same chain adapter',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, plainPager: true);
    await h.library(tester);
    for (var i = 0; i < 3; i++) {
      h.inner.jumpToPage(i);
      await tester.pumpAndSettle();
      h.bar.expand();
      h.lists[i].jumpTo(100);
      await h.expectFold(tester, true);
    }
    await h.dispose(tester);
  });

  testWidgets(
      'kept-alive inactive inner lists and inactive outer page are rejected',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    for (var i = 0; i < 3; i++) {
      h.libraryKey.currentState!.tabs.animateTo(i);
      await tester.pumpAndSettle();
    }
    expect(h.lists[0].hasClients && h.lists[1].hasClients, isTrue);
    h.bar.expand();
    h.lists[0].jumpTo(100);
    h.lists[1].jumpTo(100);
    await h.expectFold(tester, false);
    h.lists[2].jumpTo(100);
    await h.expectFold(tester, true);
    h.outer.jumpToPage(0);
    await tester.pumpAndSettle();
    h.bar.expand();
    h.lists[2].jumpTo(200);
    await h.expectFold(tester, false);
    h.home.jumpTo(100);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  for (final changeOuter in [false, true]) {
    testWidgets(
        'real stale fling stays revoked after switching away/back, outer=$changeOuter',
        (tester) async {
      final h = _Harness();
      await h.mount(tester, manual: changeOuter);
      await h.library(tester);
      await tester.fling(
          find.byKey(const ValueKey('list-0')), const Offset(0, -600), 4000);
      await tester.pump(const Duration(milliseconds: 16));
      expect(h.lists.first.position.isScrollingNotifier.value, isTrue);
      final before = h.bar.invalidations;
      if (changeOuter) {
        h.outer.jumpToPage(0);
        await tester.pump();
        h.outer.jumpToPage(1);
        await tester.pump();
      } else {
        final inner = tester
            .state<ScrollableState>(find
                .descendant(
                    of: find.byKey(const ValueKey('inner-tabs')),
                    matching: find.byType(Scrollable))
                .first)
            .position;
        inner.jumpTo(inner.viewportDimension);
        await tester.pump();
        inner.jumpTo(0);
        await tester.pump();
      }
      expect(h.bar.invalidations, greaterThan(before));
      expect(h.lists.first.position.isScrollingNotifier.value, isTrue);
      h.bar.expand();
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.bar.minimized, isFalse);
      await h.expectFold(tester, false);
      h.lists.first.jumpTo(h.lists.first.offset + 100);
      await h.expectFold(tester, true);
      await h.dispose(tester);
    });
  }

  testWidgets(
      'moving inner/outer pagers and non-adjacent tab warps reject vertical updates',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    h.libraryKey.currentState!.tabs
        .animateTo(2, duration: const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.lists.first.jumpTo(100);
    await h.expectFold(tester, false);
    h.lists[2].jumpTo(100);
    await h.expectFold(tester, true);
    h.bar.expand();
    h.outer.animateToPage(0,
        duration: const Duration(milliseconds: 500), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.lists[2].jumpTo(200);
    h.home.jumpTo(100);
    await h.expectFold(tester, false);
    await h.dispose(tester);
  });

  testWidgets('held horizontal swipes at either level cannot fold',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    final inner = await tester.startGesture(const Offset(450, 250));
    await inner.moveBy(const Offset(-150, 0));
    await tester.pump();
    h.lists.first.jumpTo(100);
    expect(h.bar.minimized, isFalse);
    await inner.cancel();
    await h.expectFold(tester, false);
    h.outer.animateToPage(0,
        duration: const Duration(seconds: 1), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    h.lists.first.jumpTo(200);
    expect(h.bar.minimized, isFalse);
    await h.expectFold(tester, false);
    await h.dispose(tester);
  });

  testWidgets('rapid switching resets 7px accumulation and keeps fold geometry',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    h.lists.first.jumpTo(7);
    await h.expectFold(tester, false);
    h.libraryKey.currentState!.tabs.index = 2;
    await tester.pumpAndSettle();
    h.lists[2].jumpTo(7);
    await h.expectFold(tester, false);
    h.lists[2].jumpTo(14);
    await h.expectFold(tester, true);
    for (final page in [0, 1, 0, 1]) {
      h.outer.jumpToPage(page);
      await h.expectFold(tester, true);
    }
    for (final tab in [0, 2, 1, 0]) {
      h.libraryKey.currentState!.tabs.index = tab;
      await h.expectFold(tester, true);
    }
    await h.dispose(tester);
  });

  testWidgets('dynamic tabs reorder, insert and remove using rendered identity',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    h.libraryKey.currentState!.tabs.animateTo(2);
    await tester.pumpAndSettle();
    h.libraryKey.currentState!.changeTabs([2, 0, 1, 3]);
    await tester.pumpAndSettle();
    h.libraryKey.currentState!.tabs.animateTo(1);
    await tester.pumpAndSettle();
    h.libraryKey.currentState!.tabs.animateTo(0);
    await tester.pumpAndSettle();
    h.lists[0].jumpTo(100);
    await h.expectFold(tester, false);
    h.lists[2].jumpTo(100);
    await h.expectFold(tester, true);
    h.libraryKey.currentState!.tabs.animateTo(3);
    await tester.pumpAndSettle();
    h.bar.expand();
    h.lists[3].jumpTo(100);
    await h.expectFold(tester, true);
    h.libraryKey.currentState!.changeTabs([2, 0]);
    await h.expectFold(tester, true);
    h.bar.expand();
    h.lists[2].jumpTo(200);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  testWidgets('unrelated nested vertical list is excluded; root still folds',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, nested: true);
    await h.library(tester);
    await tester.drag(
        find.byKey(const ValueKey('nested-list')), const Offset(0, -100));
    await h.expectFold(tester, false);
    h.lists.first.jumpTo(200);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  for (final outerSibling in [false, true]) {
    testWidgets(
        'sibling ambiguity rejected at each page level, outer=$outerSibling',
        (tester) async {
      final h = _Harness();
      await h.mount(tester, sibling: !outerSibling, outerSibling: outerSibling);
      await h.library(tester);
      h.lists.first.jumpTo(100);
      h.sibling.jumpTo(100);
      await h.expectFold(tester, false);
      await h.dispose(tester);
    });
  }

  testWidgets(
      'Search focus, query results and keyboard preserve nested page state',
      (tester) async {
    addTearDown(tester.view.resetViewInsets);
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    final libraryState = h.libraryKey.currentState;
    final outerState = tester.state(find.byKey(h.pageKey));
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Solo');
    await tester.pumpAndSettle();
    expect(find.text('Page 9 Solo row 0'), findsOneWidget);
    for (final bottom in [300.0, 0.0, 300.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom);
      await tester.pumpAndSettle();
      expect(h.outer.page, 2);
      expect(h.libraryKey.currentState, same(libraryState));
      expect(tester.state(find.byKey(h.pageKey)), same(outerState));
      expect(h.bar.minimized, isFalse);
      expect(tester.takeException(), isNull);
    }
    h.bar.closeSearch();
    await tester.pumpAndSettle();
    h.search.jumpTo(100);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  testWidgets('manual and automatic paths process one notification once',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, manual: true);
    await h.library(tester);
    h.lists.first.jumpTo(100);
    await tester.pumpAndSettle();
    h.bar.expand();
    final source = h.lists.first.position.context;

    for (var i = 0; i < 2; i++) {
      final n = ScrollUpdateNotification(
          context: source.notificationContext!,
          metrics: h.lists.first.position.copyWith(),
          scrollDelta: 7);
      n.dispatch(source.notificationContext);
      await h.expectFold(tester, i == 1);
      expect(h.bar.minimized, i > 0);
    }
    await h.dispose(tester);
  });

  testWidgets(
      'dynamic sibling ambiguity revokes a held scroll without unfolding',
      (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.library(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(h.bar.minimized, isTrue);
    h.bar.expand();
    h.libraryKey.currentState!.setSibling(true);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    h.libraryKey.currentState!.setSibling(false);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(h.bar.minimized, isFalse);
    await gesture.up();
    await h.expectFold(tester, false);
    h.lists.first.jumpTo(h.lists.first.offset + 100);
    await h.expectFold(tester, true);
    await h.dispose(tester);
  });

  testWidgets(
      'explicit manual forwarding can select an active nested vertical list',
      (tester) async {
    final h = _Harness();
    await h.mount(tester, nested: true, manual: true);
    await h.library(tester);
    await tester.drag(
        find.byKey(const ValueKey('nested-list')), const Offset(0, -150));
    await h.expectFold(tester, true);
    await tester.drag(
        find.byKey(const ValueKey('nested-list')), const Offset(0, 150));
    await h.expectFold(tester, false);
    await h.dispose(tester);
  });

  for (final decorations in [0, 1000]) {
    testWidgets('nested continuous dispatch measurement: $decorations',
        (tester) async {
      final h = _Harness();
      await h.mount(tester, decorations: decorations);
      await h.library(tester);
      final samples = <int>[];
      for (var i = 0; i < 620; i++) {
        h.lists.first.jumpTo(i + 1.0);
        await tester.pump(const Duration(microseconds: 8333));
        final source = h.lists.first.position.context;
        final n = ScrollUpdateNotification(
            context: source.notificationContext!,
            metrics: h.lists.first.position.copyWith(),
            scrollDelta: 1);
        final watch = Stopwatch()..start();
        n.dispatch(source.notificationContext);
        watch.stop();
        if (i >= 30) samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      debugPrint(
          'NESTED_CHAIN_DISPATCH decorations=$decorations samples=${samples.length} '
          'median_us=${samples[samples.length ~/ 2]} p95_us=${samples[(samples.length * .95).floor()]} '
          'max_us=${samples.last} max_visits=${h.bar.resolver.maximumVisits}');
      await h.expectFold(tester, true);
      expect(h.bar.resolver.maximumVisits, lessThanOrEqualTo(4097));
      await h.dispose(tester);
    });
  }
}
