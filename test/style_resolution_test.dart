import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

void main() {
  group('ambient bar style resolution', () {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final normal = dark ? LiquidBarStyle.dark : LiquidBarStyle.light;
      final glossy = LiquidBarStyle.glossy(brightness: brightness);

      test('Normal $brightness resolves the complete matching palette', () {
        final implicit = const LiquidTabBarTheme().resolve(brightness);
        final explicitStyle = const LiquidTabBarTheme(
          barStyle: LiquidBarStyle(),
        ).resolve(brightness);

        for (final resolved in [implicit, explicitStyle]) {
          expect(resolved.brightness, brightness);
          expect(resolved.barStyle, normal);
          expect(resolved.barStyle.glass.tint,
              dark ? const Color(0xA318191B) : const Color(0xA3FFFFFF));
          expect(resolved.barStyle.glass.blur, 5.4);
          expect(resolved.barStyle.glass.rim, dark ? 4.4 : 5);
          expect(resolved.barStyle.glass.depth, 20);
          expect(resolved.barStyle.glass.dispersion, 0.12);
          expect(resolved.barStyle.glass.specular, dark ? 0.30 : 0.38);
          expect(resolved.barStyle.blurTint, resolved.barStyle.glass.tint);
          expect(resolved.barStyle.blurEdge,
              dark ? const Color(0x24FFFFFF) : const Color(0x30FFFFFF));
          expect(resolved.inactiveColor,
              dark ? const Color(0xCCF2F2F7) : const Color(0xFF1C1C1E));
          expect(
              resolved.dropletSurfaceStyle,
              dark
                  ? LiquidDropletSurfaceStyle.dark
                  : LiquidDropletSurfaceStyle.light);
          expect(resolved.dropletRefraction, const DropletRefractionStyle());
        }
      });

      test('Glossy $brightness resolves the complete matching palette', () {
        final resolved = LiquidTabBarTheme(
          barStyle: LiquidBarStyle.glossy(),
        ).resolve(brightness);

        expect(resolved.brightness, brightness);
        expect(resolved.barStyle, glossy);
        expect(resolved.barStyle.glass.tint,
            dark ? const Color(0x7818191B) : const Color(0x80FFFFFF));
        expect(resolved.barStyle.glass.blur, dark ? 16 : 14);
        expect(resolved.barStyle.glass.rim, dark ? 5.2 : 7);
        expect(resolved.barStyle.glass.depth, dark ? 4.8 : 8);
        expect(resolved.barStyle.glass.specular, dark ? 0.36 : 0.55);
        expect(resolved.barStyle.blurTint, resolved.barStyle.glass.tint);
        expect(resolved.barStyle.blurEdge,
            dark ? const Color(0x2BFFFFFF) : const Color(0x48FFFFFF));
        expect(resolved.inactiveColor,
            dark ? const Color(0xCCF2F2F7) : const Color(0xFF1C1C1E));
        expect(
            resolved.dropletSurfaceStyle,
            dark
                ? LiquidDropletSurfaceStyle.darkGlossy
                : LiquidDropletSurfaceStyle.light);
        expect(
            resolved.dropletRefraction,
            dark
                ? LiquidTabBarTheme.darkGlossyRefraction
                : LiquidTabBarTheme.lightGlossyRefraction);
      });
    }

    test('copyWith retains ambient fields and preserves explicit overrides',
        () {
      const customInactive = Color(0xFF2468AC);
      final theme = const LiquidTabBarTheme()
          .copyWith(
              barStyle: LiquidBarStyle.glossy(), inactiveColor: customInactive)
          .resolve(Brightness.dark);

      expect(
          theme.barStyle, LiquidBarStyle.glossy(brightness: Brightness.dark));
      expect(theme.inactiveColor, customInactive);
      expect(theme.dropletSurfaceStyle, LiquidDropletSurfaceStyle.darkGlossy);
      expect(theme.actionStyle, LiquidTabActionStyle.dark);
    });

    test('explicit default refraction does not trigger Glossy auto-tuning', () {
      final implicit = LiquidTabBarTheme(
        barStyle: LiquidBarStyle.glossy(),
      ).resolve(Brightness.light);
      final explicit = LiquidTabBarTheme(
        barStyle: LiquidBarStyle.glossy(),
        dropletRefraction: const DropletRefractionStyle(),
      ).resolve(Brightness.light);

      expect(
          implicit.dropletRefraction, LiquidTabBarTheme.lightGlossyRefraction);
      expect(explicit.dropletRefraction, const DropletRefractionStyle());

      final reset = LiquidTabBarTheme(
        barStyle: LiquidBarStyle.glossy(),
        dropletRefraction: const DropletRefractionStyle(),
      ).copyWith(usePresetDropletRefraction: true).resolve(Brightness.light);
      expect(reset.dropletRefraction, LiquidTabBarTheme.lightGlossyRefraction);
    });

    test('copyWith can clear nullable theme overrides', () {
      final cleared = const LiquidTabBarTheme(
        maxWidth: 320,
        brightness: Brightness.dark,
      ).copyWith(clearMaxWidth: true, clearBrightness: true);

      expect(cleared.maxWidth, isNull);
      expect(cleared.brightness, isNull);
    });

    test('pinned palettes and fully specified styles keep their values', () {
      final pinnedLight = LiquidTabBarTheme(
        brightness: Brightness.light,
        barStyle: LiquidBarStyle.glossy(),
      ).resolve(Brightness.dark);
      expect(pinnedLight.barStyle,
          LiquidBarStyle.glossy(brightness: Brightness.light));
      expect(pinnedLight.dropletSurfaceStyle, LiquidDropletSurfaceStyle.light);

      final pinnedDark = LiquidTabBarTheme.dark(
        barStyle: LiquidBarStyle.glossy(),
      ).resolve(Brightness.light);
      expect(pinnedDark.barStyle,
          LiquidBarStyle.glossy(brightness: Brightness.dark));
      expect(
          pinnedDark.dropletSurfaceStyle, LiquidDropletSurfaceStyle.darkGlossy);

      const custom = LiquidBarStyle(
        glass: GlassStyle(tint: Color(0x805522AA)),
        blurTint: Color(0x805522AA),
        opaqueFill: Color(0xFF332211),
      );
      final resolved =
          const LiquidTabBarTheme(barStyle: custom).resolve(Brightness.dark);
      expect(resolved.barStyle, custom);
      expect(resolved.inactiveColor, const Color(0xCCF2F2F7));
    });

    for (final glossy in [false, true]) {
      testWidgets(
        'mounted ${glossy ? 'Glossy' : 'Normal'} bar follows light, dark, light',
        (tester) async {
          final configuredTheme = LiquidTabBarTheme(
            barStyle: glossy ? LiquidBarStyle.glossy() : const LiquidBarStyle(),
          );
          const items = [
            LiquidTabItem.icon(label: 'Home', icon: Icons.home_outlined),
            LiquidTabItem.icon(label: 'Explore', icon: Icons.explore_outlined),
          ];

          Widget app(ThemeMode mode) => MaterialApp(
                theme: ThemeData(
                  brightness: Brightness.light,
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0066CC),
                  ),
                ),
                darkTheme: ThemeData(
                  brightness: Brightness.dark,
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFBBD7FF),
                  ),
                ),
                themeMode: mode,
                home: Scaffold(
                  bottomNavigationBar: LiquidTabBar(
                    key: const ValueKey('resolved-bar'),
                    items: items,
                    selectedIndex: 0,
                    shrinkOnScroll: false,
                    material: LiquidTabBarMaterial.blur,
                    theme: configuredTheme,
                  ),
                ),
              );

          for (final mode in [
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.light,
          ]) {
            await tester.pumpWidget(app(mode));
            await tester.pumpAndSettle();

            final dark = mode == ThemeMode.dark;
            final expectedStyle = glossy
                ? LiquidBarStyle.glossy(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  )
                : dark
                    ? LiquidBarStyle.dark
                    : LiquidBarStyle.light;
            final decorations = tester
                .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                .map((box) => box.decoration)
                .whereType<BoxDecoration>();
            expect(
              decorations.any(
                  (decoration) => decoration.color == expectedStyle.blurTint),
              isTrue,
            );

            final inactive = tester.widget<Icon>(
              find.byIcon(Icons.explore_outlined),
            );
            final active = tester.widget<Icon>(
              find.byIcon(Icons.home_outlined),
            );
            expect(inactive.color,
                dark ? const Color(0xCCF2F2F7) : const Color(0xFF1C1C1E));
            expect(active.color,
                dark ? const Color(0xFFBBD7FF) : const Color(0xFF0066CC));
            expect(inactive.color!.computeLuminance(),
                dark ? greaterThan(0.7) : lessThan(0.2));
          }
        },
      );
    }
  });
}
