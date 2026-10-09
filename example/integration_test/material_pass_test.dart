import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'package:liquid_tab_bar_example/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('four material states, motion and dark stress backgrounds',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Styling'));
    await tester.pumpAndSettle();
    expect(LiquidGlass.supported, isTrue,
        reason: 'Run this optical check on Impeller.');
    expect(LiquidGlass.dropletSupported, isTrue);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    Future<void> capture(String name) async {
      await binding.takeScreenshot(name);
    }

    Future<void> choose(String text) async {
      await tester.tap(find.widgetWithText(ChoiceChip, text));
      await tester.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      if (dark) {
        await tester.tap(find.byTooltip('Switch brightness'));
        await tester.pumpAndSettle();
      }
      for (final glossy in [false, true]) {
        await choose(glossy ? 'Glossy' : 'Normal');
        await choose('Text');
        final name =
            '${dark ? 'dark' : 'light'}-${glossy ? 'glossy' : 'normal'}';
        await capture('$name-idle');
        for (final label in ['Explore', 'Saved', 'Profile', 'Home']) {
          await tester
              .tapAt(tester.getCenter(find.text(label)) - const Offset(0, 12));
          await tester.pump(const Duration(milliseconds: 90));
          if (label == 'Explore') await capture('$name-travel');
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<LiquidTabBar>(find.byType(LiquidTabBar))
                  .selectedIndex,
              ['Home', 'Explore', 'Saved', 'Profile'].indexOf(label));
        }
        await capture('$name-arrival');
        await tester.tap(find.text('Fast sequence'));
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Slow sequence'));
        // Real time also advances the example's scheduled tab changes.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 1150));
        }
        await tester.pumpAndSettle();
        if (dark) {
          for (final background in ['Gray', 'Black', 'Color']) {
            await choose(background);
            await capture('$name-${background.toLowerCase()}');
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
