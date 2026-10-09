import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
// ignore: implementation_imports
import 'package:liquid_tab_bar/src/test_overrides.dart';
import 'package:liquid_tab_bar_example/main.dart' as app;

Map<String, Object> color(Color value) => {
      'argb': '0x${value.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'rgba': [value.r, value.g, value.b, value.a],
    };

Map<String, Object> glass(GlassStyle s) => {
      'rim': s.rim,
      'curve': s.curve,
      'depth': s.depth,
      'dispersion': s.dispersion,
      'blur': s.blur,
      'saturation': s.saturation,
      'tint': color(s.tint),
      'specular': s.specular,
      'light': [s.light.dx, s.light.dy],
      'edgeDark': s.edgeDark,
      'shadow': s.shadow,
      'shadowBlur': s.shadowBlur,
      'shadowOffset': [s.shadowOffset.dx, s.shadowOffset.dy],
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Map<String, Object?>? latest;
  setUp(() {
    LiquidMaterialTestObserver.onResolved = (values) => latest = values;
  });
  tearDown(() => LiquidMaterialTestObserver.onResolved = null);

  Future<void> audit(
      WidgetTester tester, String name, Brightness brightness, bool glossy,
      {bool screenshot = false}) async {
    // Observe after all theme/material animations and a submitted extra frame.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final actual = latest!;
    final theme = actual['theme']! as LiquidTabBarTheme;
    final effectiveGlass = actual['effectiveGlass']! as GlassStyle;
    final expected = glossy
        ? LiquidBarStyle.glossy(brightness: brightness)
        : brightness == Brightness.dark
            ? LiquidBarStyle.dark
            : LiquidBarStyle.light;
    final expectedTheme = LiquidTabBarTheme(
            barStyle: glossy ? LiquidBarStyle.glossy() : const LiquidBarStyle())
        .resolve(brightness);
    final barContext = tester.element(find.byType(LiquidTabBar));
    final appWidget = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final surface = theme.dropletSurfaceStyle;
    final report = <String, Object?>{
      'name': name,
      'variant': glossy ? 'Glossy' : 'Normal',
      'ambientBrightness': '${actual['ambientBrightness']}',
      'platformBrightness': '${actual['platformBrightness']}',
      'materialAppThemeMode': '${appWidget.themeMode}',
      'themeDataBrightness': '${actual['themeDataBrightness']}',
      'resolvedBrightness': '${theme.brightness}',
      'glass': glass(effectiveGlass),
      'blurTint': color(theme.barStyle.blurTint),
      'blurEdge': color(theme.barStyle.blurEdge),
      'dropletSurface': {
        'top': color(surface.gradientTop),
        'bottom': color(surface.gradientBottom),
        'border': color(surface.borderColor),
        'borderWidth': surface.borderWidth,
        'shadowColor': color(surface.shadow.color),
        'shadowBlur': surface.shadow.blurRadius,
        'shadowOffset': [surface.shadow.offset.dx, surface.shadow.offset.dy],
        'opaqueFill': color(surface.opaqueFill),
      },
      'dropletRefraction': '${theme.dropletRefraction}',
      'activeColor': color(theme.activeColor),
      'inactiveColor': color(theme.inactiveColor),
      for (final key in ['material', 'controllerMaterial'])
        key: '${actual[key]}',
      for (final key in [
        'shaderSupported',
        'shaderReady',
        'dropletSupported',
        'governorArmed',
        'governorDegraded',
        'highContrast',
        'foldProgress'
      ])
        key: actual[key],
    };
    // Exact diagnostics live only in this test, not in application logging.
    debugPrint('MATERIAL_AUDIT ${jsonEncode(report)}', wrapWidth: null);
    expect(Theme.of(barContext).brightness, brightness);
    expect(actual['ambientBrightness'], brightness);
    expect(actual['themeDataBrightness'], brightness);
    expect(theme.brightness, brightness);
    expect(theme.barStyle.glass, expected.glass);
    expect(effectiveGlass, expected.glass);
    expect(theme.barStyle.blurTint, expected.blurTint);
    expect(theme.barStyle.blurEdge, expected.blurEdge);
    expect(theme.barStyle.opaqueFill, expected.opaqueFill);
    expect(theme.dropletSurfaceStyle, expectedTheme.dropletSurfaceStyle);
    expect(theme.dropletRefraction, expectedTheme.dropletRefraction);
    expect(theme.inactiveColor, expectedTheme.inactiveColor);
    expect(theme.activeColor, Theme.of(barContext).colorScheme.primary);
    if (brightness == Brightness.dark) {
      expect(effectiveGlass.tint.toARGB32() & 0xFFFFFF, 0x1C1C1E);
      expect(theme.barStyle.blurTint.toARGB32() & 0xFFFFFF, 0x1C1C1E);
    }
    if (screenshot) {
      await binding.takeScreenshot(name);
      // Ensure capture didn't coincide with a governor/palette change.
      expect((latest!['theme']! as LiquidTabBarTheme).barStyle, theme.barStyle);
      expect(latest!['material'], actual['material']);
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets(
      'audit actual Styling materials and cached adaptive ThemeMode switching',
      (tester) async {
    await LiquidGlass.load();
    LiquidTabBarController.shared.armGovernor();
    await tester.pumpWidget(const app.LiquidTabBarExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Styling'));
    await tester.pumpAndSettle();
    expect(LiquidGlass.supported, isTrue);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    for (final brightness in [Brightness.light, Brightness.dark]) {
      if (brightness == Brightness.dark) {
        await tester.tap(find.byTooltip('Switch brightness'));
        await tester.pumpAndSettle();
      }
      for (final glossy in [false, true]) {
        await tester
            .tap(find.widgetWithText(ChoiceChip, glossy ? 'Glossy' : 'Normal'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Text'));
        await audit(
            tester,
            '${brightness.name}-${glossy ? 'glossy' : 'normal'}-resolution',
            brightness,
            glossy,
            screenshot: true);
      }
    }

    // The same objects survive light -> dark -> light and every renderer tier.
    final cachedStyles = [const LiquidBarStyle(), LiquidBarStyle.glossy()];
    final controller = LiquidTabBarController();
    addTearDown(controller.dispose);
    for (final glossy in [false, true]) {
      final cachedTheme =
          LiquidTabBarTheme(barStyle: cachedStyles[glossy ? 1 : 0]);
      for (final tier in [
        LiquidTabBarMaterial.auto,
        LiquidTabBarMaterial.blur,
        LiquidTabBarMaterial.opaque
      ]) {
        controller.material = tier;
        for (final brightness in [
          Brightness.light,
          Brightness.dark,
          Brightness.light
        ]) {
          await tester.pumpWidget(MaterialApp(
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: Scaffold(
                bottomNavigationBar: LiquidTabBar(
              key: const ValueKey('cached-material-bar'),
              controller: controller,
              shrinkOnScroll: false,
              selectedIndex: 0,
              theme: cachedTheme,
              items: const [
                LiquidTabItem.icon(label: 'Home', icon: Icons.home),
                LiquidTabItem.icon(label: 'Explore', icon: Icons.explore)
              ],
            )),
          ));
          await audit(tester, 'cached-$glossy-${tier.name}-${brightness.name}',
              brightness, glossy);
          expect(
              latest!['material'],
              tier == LiquidTabBarMaterial.auto
                  ? LiquidTabBarMaterial.glass
                  : tier);
        }
      }
    }
  });
}
