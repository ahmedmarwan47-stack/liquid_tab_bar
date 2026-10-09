import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/test_overrides.dart';

class _ObservedController extends LiquidTabBarController {
  bool get observedListeners => hasListeners;
}

class _ObservedText extends TextEditingController {
  bool get observedListeners => hasListeners;
}

class _ObservedFocus extends FocusNode {
  bool get observedListeners => hasListeners;
}

void main() {
  testWidgets('Standalone Native auto material arms the shared governor',
      (tester) async {
    LiquidControllerTestOverrides.resetSharedGovernor();
    addTearDown(LiquidControllerTestOverrides.resetSharedGovernor);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LiquidTabBar(
      selectedIndex: 0,
      theme: LiquidTabBarTheme(barStyle: LiquidBarStyle.native()),
      items: const [
        LiquidTabItem.icon(label: 'Home', icon: Icons.home),
        LiquidTabItem.icon(label: 'Browse', icon: Icons.search)
      ],
    ))));
    await tester.pumpAndSettle();
    expect(LiquidTabBarController.shared.isGovernorArmed, isTrue);
  });

  testWidgets(
      'Native stays idle without glyph rebuilds and releases controller listeners',
      (tester) async {
    final controller = _ObservedController();
    addTearDown(controller.dispose);
    var builds = 0;
    final theme = LiquidTabBarTheme(barStyle: LiquidBarStyle.native());
    for (var cycle = 0; cycle < 25; cycle++) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: LiquidTabBar(
        key: ValueKey(cycle),
        controller: controller,
        selectedIndex: 0,
        theme: theme,
        shrinkOnScroll: false,
        items: [
          LiquidTabItem.icon(
              label: 'Home',
              icon: Icons.home,
              iconBuilder: (color, selected) {
                builds++;
                return Icon(Icons.home, color: color);
              }),
          const LiquidTabItem.icon(label: 'Browse', icon: Icons.search)
        ],
      ))));
      await tester.pumpAndSettle();
      expect(controller.isGovernorArmed, isFalse);
      final settledBuilds = builds;
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, settledBuilds, reason: 'idle cycle $cycle');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.observedListeners, isFalse,
          reason: 'unmounted cycle $cycle');
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Native search survives keyboard inset, dismissal and disposal cycles',
      (tester) async {
    final controller = _ObservedController();
    final text = _ObservedText();
    final focus = _ObservedFocus();
    addTearDown(controller.dispose);
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    var keyboard = 0.0;
    late StateSetter setInsets;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      setInsets = setState;
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: LiquidTabBar(
            controller: controller,
            selectedIndex: 0,
            theme: LiquidTabBarTheme(barStyle: LiquidBarStyle.native()),
            items: const [
              LiquidTabItem.icon(label: 'Home', icon: Icons.home),
              LiquidTabItem.icon(label: 'Browse', icon: Icons.explore)
            ],
            separateAction: LiquidTabAction.search(
                controller: text, focusNode: focus, hintText: 'Search'),
          ),
        ),
      );
    })));
    await tester.pumpAndSettle();
    final searchLinks = tester
        .widgetList<CompositedTransformTarget>(
            find.byType(CompositedTransformTarget))
        .map((target) => target.link)
        .toList();
    expect(searchLinks, isNotEmpty);
    for (var cycle = 0; cycle < 10; cycle++) {
      controller.openSearch();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'query $cycle');
      setInsets(() => keyboard = 280);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(600 - 280));
      controller.closeSearch();
      setInsets(() => keyboard = 0);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(controller.isSearching, isFalse);
      expect(tester.takeException(), isNull);
    }
    controller.openSearch();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(controller.observedListeners, isFalse);
    for (final link in searchLinks) {
      expect(link.leaderSize, isNull, reason: 'disposed search overlay link');
    }
    expect(text.observedListeners, isFalse);
    expect(focus.observedListeners, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
