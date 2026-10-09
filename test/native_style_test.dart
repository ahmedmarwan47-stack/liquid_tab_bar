import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/backdrop_contrast.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('Native resolves $brightness with slim rim and optical lens', () {
      final base = brightness == Brightness.dark
          ? LiquidBarStyle.dark
          : LiquidBarStyle.light;
      final native = LiquidBarStyle.native().resolve(brightness);
      expect(native, LiquidBarStyle.native(brightness: brightness));
      expect(native.adaptsToBackdrop, isTrue);
      expect(native.glass.rim, base.glass.rim);
      expect(native.glass.depth, 24);
      expect(native.glass.dispersion, 0.04);
      expect(native.glass.blur, 6);
      expect(native.opaqueFill, base.opaqueFill);
      final resolved = LiquidTabBarTheme(barStyle: LiquidBarStyle.native())
          .resolve(brightness);
      expect(resolved.dropletSurfaceStyle.adaptiveContrast, isTrue);
      expect(resolved.activeColor, const Color(0xFF0A84FF));
      expect(
          resolved.dropletRefraction,
          brightness == Brightness.dark
              ? LiquidTabBarTheme.darkGlossyRefraction
              : LiquidTabBarTheme.lightGlossyRefraction);
      expect(
          native
              .copyWith(glass: native.glass.copyWith(blur: 3))
              .adaptsToBackdrop,
          isTrue);
    });
  }

  test(
      'Native accent stays blue in pinned dark theme and honors explicit colors',
      () {
    final native = LiquidBarStyle.native();
    expect(
        LiquidTabBarTheme.dark(barStyle: native)
            .resolve(Brightness.dark)
            .activeColor,
        const Color(0xFF0A84FF));
    expect(
        LiquidTabBarTheme.dark(barStyle: native, activeColor: Colors.red)
            .resolve(Brightness.dark)
            .activeColor,
        Colors.red);
    expect(const LiquidTabBarTheme.dark().resolve(Brightness.dark).activeColor,
        const Color(0xFFF2F2F7));
  });

  test('Backdrop response participates in GlassStyle value semantics', () {
    const fixed = GlassStyle();
    final adaptive = fixed.copyWith(adaptiveTint: true);
    expect(adaptive, isNot(fixed));
    expect(adaptive.copyWith(), same(adaptive));
    expect(adaptive.copyWith(adaptiveTint: false), fixed);
  });

  testWidgets('Native bar adapts inactive glyphs and preserves selected accent',
      (tester) async {
    final boundaryKey = GlobalKey();
    const inactiveKey = ValueKey('native-inactive-pixel');
    const selectedKey = ValueKey('native-selected-pixel');
    for (final background in [Colors.white, Colors.black]) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            brightness: background == Colors.white
                ? Brightness.light
                : Brightness.dark),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            backgroundColor: background,
            body: Center(
                child: LiquidTabBar(
              material: LiquidTabBarMaterial.blur,
              selectedIndex: 0,
              shrinkOnScroll: false,
              theme: LiquidTabBarTheme(
                activeColor: Colors.red,
                barStyle: LiquidBarStyle.native(),
              ),
              items: [
                LiquidTabItem.icon(
                    label: 'Home',
                    icon: Icons.home,
                    iconBuilder: (color, selected) =>
                        ColoredBox(key: selectedKey, color: color)),
                LiquidTabItem.icon(
                    label: 'Browse',
                    icon: Icons.search,
                    iconBuilder: (color, selected) =>
                        ColoredBox(key: inactiveKey, color: color)),
              ],
            )),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final inactive = tester.getCenter(find.byKey(inactiveKey));
      final selected = tester.getCenter(find.byKey(selectedKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int channel(Offset point, int c) => data.getUint8(
            (point.dy.round() * image.width + point.dx.round()) * 4 + c);
        final inactiveRed = channel(inactive, 0);
        final selectionFill = channel(selected + const Offset(30, 0), 0);
        final barFill = channel(inactive + const Offset(30, 0), 0);
        expect(
            selectionFill,
            background == Colors.white
                ? lessThan(barFill - 20)
                : greaterThan(barFill + 20));
        expect(inactiveRed,
            background == Colors.white ? lessThan(60) : greaterThan(190));
        expect(channel(selected, 0), greaterThan(190));
        expect(channel(selected, 1), lessThan(100));
        image.dispose();
      });
    }
  });

  testWidgets('Native respects the opaque high contrast material',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(highContrast: true),
      child: Scaffold(
          body: LiquidTabBar(
        selectedIndex: 0,
        theme: LiquidTabBarTheme(barStyle: LiquidBarStyle.native()),
        items: const [
          LiquidTabItem.icon(label: 'Home', icon: Icons.home),
          LiquidTabItem.icon(label: 'Browse', icon: Icons.search),
        ],
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropContrast), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Composited artwork retains a legible theme fallback',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: BackdropContrast(
        fallbackColor: Colors.black,
        child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: SizedBox(
                width: 20, height: 20, child: ColoredBox(color: Colors.red))),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final render = tester.renderObject(find.byType(BackdropContrast));
    expect(render.debugLayer, isA<ColorFilterLayer>());
    expect((render.debugLayer! as ColorFilterLayer).colorFilter,
        const ColorFilter.mode(Colors.black, BlendMode.srcIn));
  });

  testWidgets('Native preserves custom artwork opting out of theme tint',
      (tester) async {
    const key = ValueKey('untinted-native-artwork');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LiquidTabBar(
      selectedIndex: 0,
      material: LiquidTabBarMaterial.blur,
      theme: LiquidTabBarTheme(barStyle: LiquidBarStyle.native()),
      items: const [
        LiquidTabItem.icon(label: 'Home', icon: Icons.home),
        LiquidTabItem.custom(
            label: 'Artwork',
            useThemeColor: false,
            icon: ColoredBox(
                key: key,
                color: Colors.red,
                child: SizedBox(width: 20, height: 20))),
      ],
    ))));
    await tester.pumpAndSettle();
    expect(
        find.ancestor(
            of: find.byKey(key), matching: find.byType(BackdropContrast)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Foreground responds to changing content without a theme change',
      (tester) async {
    final key = GlobalKey();
    for (final background in [Colors.white, Colors.black]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 40,
            height: 40,
            child: ColoredBox(
              color: background,
              child: const Center(
                  child: BackdropContrast(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Colors.white)),
              )),
            ),
          ),
        )),
      ));
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final red = data.getUint8((20 * 40 + 20) * 4);
        expect(red, background == Colors.white ? 0 : 255);
        image.dispose();
      });
    }
  });
}
