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

  group('Dismiss Icon Customization & RTL Directionality', () {
    testWidgets('default dismiss icon points left in LTR and right in RTL',
        (tester) async {
      final navLtr = LiquidTabBarController();
      addTearDown(navLtr.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            bottomNavigationBar: LiquidTabBar(
              controller: navLtr,
              material: LiquidTabBarMaterial.opaque,
              selectedIndex: 0,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home)
              ],
              separateAction: LiquidTabAction.search(),
            ),
          ),
        ),
      ));
      navLtr.openSearch();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      // In LTR, the icon is not mirrored
      final transformLtr = find.ancestor(
        of: find.byIcon(Icons.chevron_left_rounded),
        matching: find.byType(Transform),
      );
      expect(transformLtr, findsNothing);

      final navRtl = LiquidTabBarController();
      addTearDown(navRtl.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: LiquidTabBar(
              controller: navRtl,
              material: LiquidTabBarMaterial.opaque,
              selectedIndex: 0,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home)
              ],
              separateAction: LiquidTabAction.search(),
            ),
          ),
        ),
      ));
      navRtl.openSearch();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      // In RTL, Icons.chevron_left_rounded (which has matchTextDirection: true)
      // is automatically mirrored horizontally by Flutter's Icon widget (pointing right).
      final transformRtl = find.descendant(
        of: find.byIcon(Icons.chevron_left_rounded),
        matching: find.byType(Transform),
      );
      expect(transformRtl, findsOneWidget);
      final transformWidget = tester.widget<Transform>(transformRtl);
      expect(transformWidget.transform.storage[0], -1.0);
    });

    testWidgets('custom dismissIcon (IconData) via LiquidTabAction.search',
        (tester) async {
      final nav = LiquidTabBarController();
      addTearDown(nav.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            bottomNavigationBar: LiquidTabBar(
              controller: nav,
              material: LiquidTabBarMaterial.opaque,
              selectedIndex: 0,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home)
              ],
              separateAction: LiquidTabAction.search(
                dismissIcon: Icons.arrow_back,
              ),
            ),
          ),
        ),
      ));

      nav.openSearch();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets(
        'custom customDismissIcon (Widget) renders, stays centered, and dismisses search',
        (tester) async {
      final nav = LiquidTabBarController();
      addTearDown(nav.dispose);
      var closed = 0;

      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            bottomNavigationBar: LiquidTabBar(
              controller: nav,
              material: LiquidTabBarMaterial.opaque,
              selectedIndex: 0,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home)
              ],
              separateAction: LiquidTabAction.search(
                onClose: () => closed++,
                customDismissIcon: Container(
                  key: const Key('custom-box-dismiss'),
                  width: 40,
                  height: 40,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      ));

      nav.openSearch();
      await tester.pumpAndSettle();

      final customWidgetFinder = find.byKey(const Key('custom-box-dismiss'));
      expect(customWidgetFinder, findsOneWidget);

      final dismissButton = find.bySemanticsLabel('Close');
      expect(dismissButton, findsOneWidget);
      final dismissCenter = tester.getCenter(dismissButton);
      final iconCenter = tester.getCenter(customWidgetFinder);
      expect(iconCenter.dx, closeTo(dismissCenter.dx, 0.5));
      expect(iconCenter.dy, closeTo(dismissCenter.dy, 0.5));

      await tester.tap(dismissButton);
      await tester.pumpAndSettle();
      expect(nav.isSearching, isFalse);
      expect(closed, 1);
    });

    testWidgets(
        'useDismissThemeColor controls ColorFiltered on customDismissIcon',
        (tester) async {
      final navThemed = LiquidTabBarController();
      addTearDown(navThemed.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            controller: navThemed,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
            separateAction: LiquidTabAction.search(
              customDismissIcon:
                  const Icon(Icons.star, key: Key('themed-icon')),
              useDismissThemeColor: true,
            ),
          ),
        ),
      ));
      navThemed.openSearch();
      await tester.pumpAndSettle();

      final filteredFinder = find.ancestor(
        of: find.byKey(const Key('themed-icon')),
        matching: find.byType(ColorFiltered),
      );
      expect(filteredFinder, findsOneWidget);

      final navUnthemed = LiquidTabBarController();
      addTearDown(navUnthemed.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            controller: navUnthemed,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
            separateAction: LiquidTabAction.search(
              customDismissIcon:
                  const Icon(Icons.star, key: Key('unthemed-icon')),
              useDismissThemeColor: false,
            ),
          ),
        ),
      ));
      navUnthemed.openSearch();
      await tester.pumpAndSettle();

      final unthemedFiltered = find.ancestor(
        of: find.byKey(const Key('unthemed-icon')),
        matching: find.byType(ColorFiltered),
      );
      expect(unthemedFiltered, findsNothing);
    });

    testWidgets(
        'customDismissIcon takes precedence over dismissIcon when both provided',
        (tester) async {
      final nav = LiquidTabBarController();
      addTearDown(nav.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            controller: nav,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
            separateAction: LiquidTabAction.search(
              dismissIcon: Icons.close_rounded,
              customDismissIcon: const Icon(
                Icons.arrow_back_rounded,
                key: Key('precedence-icon'),
              ),
            ),
          ),
        ),
      ));

      nav.openSearch();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('precedence-icon')), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets(
        'dismissIcon and customDismissIcon configured directly on LiquidTabBarSearch work seamlessly',
        (tester) async {
      final nav = LiquidTabBarController();
      addTearDown(nav.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            controller: nav,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [LiquidTabItem.icon(label: 'Home', icon: Icons.home)],
            separateAction: LiquidTabAction(
              icon: const Icon(Icons.search),
              search: const LiquidTabBarSearch(
                dismissIcon: Icons.arrow_back_rounded,
              ),
            ),
          ),
        ),
      ));

      nav.openSearch();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets(
        'LiquidTabAction.search correctly forwards dismiss icon properties',
        (tester) async {
      final action = LiquidTabAction.search(
        dismissIcon: Icons.close_rounded,
        customDismissIcon: const SizedBox(key: Key('box')),
        useDismissThemeColor: false,
      );

      expect(action.dismissIcon, Icons.close_rounded);
      expect(action.customDismissIcon, isNotNull);
      expect(action.useDismissThemeColor, isFalse);
      expect(action.search?.dismissIcon, Icons.close_rounded);
      expect(action.search?.customDismissIcon, isNotNull);
      expect(action.search?.useDismissThemeColor, isFalse);
    });

    testWidgets(
        'navigation tabs and search leading icon work with custom and standard icons without regression',
        (tester) async {
      final nav = LiquidTabBarController();
      addTearDown(nav.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidTabBar(
            controller: nav,
            material: LiquidTabBarMaterial.opaque,
            selectedIndex: 0,
            items: const [
              LiquidTabItem.icon(label: 'Home', icon: Icons.home),
              LiquidTabItem.custom(
                label: 'Custom',
                icon: Icon(Icons.star, key: Key('custom-nav-icon')),
              ),
            ],
            separateAction: LiquidTabAction.search(
              customIcon:
                  const Icon(Icons.search, key: Key('custom-search-icon')),
              dismissIcon: Icons.arrow_back,
            ),
          ),
        ),
      ));

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byKey(const Key('custom-nav-icon')), findsOneWidget);
      expect(find.byKey(const Key('custom-search-icon')), findsOneWidget);

      nav.openSearch();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
