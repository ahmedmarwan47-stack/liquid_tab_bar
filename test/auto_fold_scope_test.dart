import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/scroll_source.dart';

LiquidTabBar _bar(LiquidTabBarController controller) => LiquidTabBar(
    controller: controller,
    selectedIndex: 0,
    items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)]);
Widget _list(int id, ScrollController scroll) => ListView.builder(
    key: ValueKey(id),
    controller: scroll,
    itemCount: 100,
    itemBuilder: (_, i) => SizedBox(height: 60, child: Text('$id $i')));

void main() {
  testWidgets('shared controller keeps nearest scaffold scope independent',
      (tester) async {
    final bar = LiquidTabBarController();
    final scroll = ScrollController();
    var nested = true;
    late StateSetter rebuild;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      final child = _list(0, scroll);
      return LiquidTabBarScaffold(
          tabBar: _bar(bar),
          body: nested
              ? LiquidTabBarScaffold(
                  key: const ValueKey('inner'), tabBar: _bar(bar), body: child)
              : child);
    })));
    await tester.pumpAndSettle();
    scroll.jumpTo(200);
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    final generation = scrollOwnershipFor(bar).generation;
    rebuild(() => nested = false);
    await tester.pumpAndSettle();
    expect(scrollOwnershipFor(bar).generation, greaterThan(generation));
    expect(bar.minimized, isTrue);
    bar.expand();
    await tester.drag(find.byKey(const ValueKey(0)), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
    bar.dispose();
  });

  testWidgets('sibling scaffold disposal does not invalidate another scope',
      (tester) async {
    final bar = LiquidTabBarController();
    final scrolls = [ScrollController(), ScrollController()];
    var show = true;
    late StateSetter rebuild;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return Row(children: [
        Expanded(
            child: LiquidTabBarScaffold(
                key: const ValueKey('first'),
                tabBar: _bar(bar),
                body: _list(0, scrolls[0]))),
        if (show)
          Expanded(
              child: LiquidTabBarScaffold(
                  key: const ValueKey('second'),
                  tabBar: _bar(bar),
                  body: _list(1, scrolls[1])))
      ]);
    })));
    await tester.pumpAndSettle();
    scrolls[0].jumpTo(200);
    await tester.pumpAndSettle();
    final generation = scrollOwnershipFor(bar).generation;
    rebuild(() => show = false);
    await tester.pumpAndSettle();
    expect(scrollOwnershipFor(bar).generation, generation);
    expect(bar.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final scroll in scrolls) {
      scroll.dispose();
    }
    bar.dispose();
  });

  testWidgets('manual nested owner is revoked on smart policy replacement',
      (tester) async {
    final bar = LiquidTabBarController();
    final outer = ScrollController();
    final inner = ScrollController();
    var policy = const LiquidAutoFoldPolicy.smart();
    late StateSetter rebuild;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return LiquidTabBarScaffold(
          autoFoldPolicy: policy,
          tabBar: _bar(bar),
          body: NotificationListener<ScrollNotification>(
              onNotification: (n) => bar.handleScroll(n, allowNested: true),
              child: ListView(controller: outer, children: [
                SizedBox(height: 200, child: _list(1, inner)),
                const SizedBox(height: 4000)
              ])));
    })));
    await tester.pumpAndSettle();
    inner.jumpTo(150);
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    final generation = scrollOwnershipFor(bar).generation;
    rebuild(() => policy = const LiquidAutoFoldPolicy.direct());
    await tester.pumpAndSettle();
    expect(scrollOwnershipFor(bar).generation, greaterThan(generation));
    expect(bar.minimized, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    inner.dispose();
    outer.dispose();
    bar.dispose();
  });
  testWidgets('controller replacement revokes old held owner without unfolding',
      (tester) async {
    final first = LiquidTabBarController();
    final second = LiquidTabBarController();
    var current = first;
    final scroll = ScrollController();
    late StateSetter rebuild;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return LiquidTabBarScaffold(
          tabBar: _bar(current), body: _list(0, scroll));
    })));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey(0))));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(first.minimized, isTrue);
    final generation = scrollOwnershipFor(first).generation;
    rebuild(() => current = second);
    await tester.pump();
    expect(scrollOwnershipFor(first).generation, greaterThan(generation));
    expect(first.minimized, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    second.expand();
    await tester.drag(find.byKey(const ValueKey(0)), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(second.minimized, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
    first.dispose();
    second.dispose();
  });
  testWidgets(
      'reparented scrollable preserves offset and rearms after pager replacement',
      (tester) async {
    final bar = LiquidTabBarController();
    final scroll = ScrollController();
    final pagers = [PageController(), PageController()];
    final listKey = GlobalKey();
    var pager = 0;
    late StateSetter rebuild;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return LiquidTabBarScaffold(
          tabBar: _bar(bar),
          body: PageView(
              key: ValueKey(pager),
              controller: pagers[pager],
              children: [
                ListView.builder(
                    key: listKey,
                    controller: scroll,
                    itemCount: 100,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 60, child: Text('$i')))
              ]));
    })));
    await tester.pumpAndSettle();
    scroll.jumpTo(200);
    await tester.pumpAndSettle();
    final original = tester.state<ScrollableState>(find
        .descendant(of: find.byKey(listKey), matching: find.byType(Scrollable))
        .first);
    expect(bar.minimized, isTrue);
    rebuild(() => pager = 1);
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, 200);
    expect(
        tester.state<ScrollableState>(find
            .descendant(
                of: find.byKey(listKey), matching: find.byType(Scrollable))
            .first),
        same(original));
    expect(bar.minimized, isTrue);
    bar.expand();
    await tester.drag(find.byKey(listKey), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(bar.minimized, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final p in pagers) {
      p.dispose();
    }
    scroll.dispose();
    bar.dispose();
  });
  testWidgets(
      'same source with replaced pager chain rearms before continuation',
      (tester) async {
    final scroll = ScrollController();
    final pagers = [PageController(), PageController()];
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [
      Expanded(child: _list(0, scroll)),
      for (final pager in pagers)
        SizedBox(
            height: 40,
            child: PageView(
                controller: pager, children: const [SizedBox.shrink()]))
    ])));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const ValueKey(0)),
            matching: find.byType(Scrollable))
        .first);
    final start = ScrollStartNotification(
        context: state.notificationContext!,
        metrics: state.position.copyWith());
    final source = ScrollSource.describe(start)!;
    final ownership = ScrollOwnership();
    expect(
        ownership.accept(source, start, pagerPositions: [pagers[0].position]),
        isTrue);
    expect(
        ownership.accept(
            source,
            ScrollStartNotification(
                context: state.notificationContext!,
                metrics: state.position.copyWith()),
            pagerPositions: [pagers[1].position]),
        isTrue);
    expect(
        ownership.accept(
            source,
            ScrollUpdateNotification(
                context: state.notificationContext!,
                metrics: state.position.copyWith(),
                scrollDelta: 7),
            pagerPositions: [pagers[1].position]),
        isTrue);
    ownership.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    for (final pager in pagers) {
      pager.dispose();
    }
    scroll.dispose();
  });
}
