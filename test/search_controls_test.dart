import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('clear and dismiss $direction at $width', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final nav = LiquidTabBarController();
        final text = TextEditingController();
        final focus = FocusNode();
        addTearDown(nav.dispose);
        addTearDown(text.dispose);
        addTearDown(focus.dispose);
        var closes = 0;
        final changes = <String>[];
        var notifications = 0;
        text.addListener(() => notifications++);
        await tester.pumpWidget(MaterialApp(
            home: Directionality(
          textDirection: direction,
          child: Scaffold(
              bottomNavigationBar: LiquidTabBar(
            controller: nav,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [
              LiquidTabItem.icon(label: 'Home', icon: Icons.home),
              LiquidTabItem.icon(label: 'Library', icon: Icons.book),
            ],
            separateAction: LiquidTabAction.search(
              controller: text,
              focusNode: focus,
              onChanged: changes.add,
              onClose: () => closes++,
            ),
          )),
        )));
        nav.openSearch();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(focus.hasFocus, isTrue);
        text.text = 'External query';
        await tester.pump();
        final clear = find.byIcon(Icons.close_rounded);
        expect(clear, findsOneWidget);
        expect(tester.getSize(clear), const Size(44, 44));
        final before = notifications;
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(text.text, isEmpty);
        expect(notifications, before + 1);
        expect(changes, ['']);
        expect(closes, 0);
        expect(nav.isSearching, isTrue);
        expect(focus.hasFocus, isTrue);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        final dismiss = find.bySemanticsLabel('Close');
        expect(tester.getSize(dismiss).width, greaterThanOrEqualTo(44));
        await tester.tap(dismiss);
        await tester.pumpAndSettle();
        expect(nav.isSearching, isFalse);
        expect(closes, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('reopening cancels keyboard pending dismissal', (tester) async {
    final nav = LiquidTabBarController();
    addTearDown(nav.dispose);
    var closes = 0;
    var inset = 250.0;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
          child: Scaffold(
              bottomNavigationBar: LiquidTabBar(
            controller: nav,
            selectedIndex: 0,
            material: LiquidTabBarMaterial.opaque,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
            separateAction: LiquidTabAction.search(onClose: () => closes++),
          )),
        );
      },
    )));
    nav.openSearch();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();
    expect(nav.isSearching, isTrue);
    nav.openSearch();
    rebuild(() => inset = 0);
    await tester.pumpAndSettle();
    expect(nav.isSearching, isTrue);
    expect(closes, 0);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(closes, 1);
  });
  testWidgets('legacy X retains close behavior', (tester) async {
    final nav = LiquidTabBarController();
    addTearDown(nav.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: LiquidTabBar(
      controller: nav,
      selectedIndex: 0,
      material: LiquidTabBarMaterial.opaque,
      items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
      separateAction:
          LiquidTabAction.search(controls: LiquidSearchControls.legacy),
    ))));
    nav.openSearch();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(nav.isSearching, isFalse);
  });
}
