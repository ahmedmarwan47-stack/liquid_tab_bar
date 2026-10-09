import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
// ignore: implementation_imports
import 'package:liquid_tab_bar/src/glass.dart'
    show GlassSurface, DropletGlassSurface;
import 'package:liquid_tab_bar_example/examples/dark_material_example.dart';

Future<(int, int, int)> sampleRgb(List<int> png, double x, double y) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final sx = (image.width * x).round().clamp(0, image.width - 1);
  final sy = (image.height * y).round().clamp(0, image.height - 1);
  final i = (sy * image.width + sx) * 4;
  final bytes = data!.buffer.asUint8List();
  final result = (bytes[i], bytes[i + 1], bytes[i + 2]);
  image.dispose();
  codec.dispose();
  return result;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dark presets transmit red and blue across the same scene',
      (tester) async {
    await LiquidGlass.load();
    expect(LiquidGlass.supported, isTrue,
        reason: 'Inspect optical shader on Impeller.');
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DarkMaterialExample(),
    ));
    await tester.pumpAndSettle();
    for (final glossy in [false, true]) {
      if (glossy) {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Glossy Dark'));
        await tester.pumpAndSettle();
      }
      final variant = glossy ? 'glossy' : 'normal';
      final resolved = LiquidTabBarTheme(
        barStyle: glossy ? LiquidBarStyle.glossy() : const LiquidBarStyle(),
      ).resolve(Brightness.dark);
      final expected = glossy
          ? LiquidBarStyle.glossy(brightness: Brightness.dark)
          : LiquidBarStyle.dark;
      expect(resolved.barStyle, expected);
      expect(resolved.brightness, Brightness.dark);
      expect(resolved.barStyle.glass.tint.toARGB32() & 0xFFFFFF, 0x1C1C1E);
      final mountedBar = tester.widget<GlassSurface>(find.byType(GlassSurface));
      final mountedLens =
          tester.widget<DropletGlassSurface>(find.byType(DropletGlassSurface));
      expect(mountedBar.style, resolved.barStyle.glass);
      expect(mountedLens.refractionStyle, resolved.dropletRefraction);
      debugPrint(
          'DARK MATERIAL $variant: ${resolved.barStyle.glass}; lens ${resolved.dropletRefraction}');
      final idle = await binding.takeScreenshot('dark-$variant-idle');
      final red = await sampleRgb(idle, .33, .945);
      final blue = await sampleRgb(idle, .67, .945);
      debugPrint('DARK TRANSMISSION $variant: red=$red blue=$blue');
      expect(red.$1, greaterThan(red.$3 * 1.3));
      expect(blue.$3, greaterThan(blue.$1 * 1.3));
      for (final label in ['Explore', 'Saved', 'Profile', 'Home']) {
        await tester
            .tapAt(tester.getCenter(find.text(label)) - const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 90));
        if (label == 'Explore') {
          await binding.takeScreenshot('dark-$variant-travel');
        }
        await tester.pumpAndSettle();
      }
      await binding.takeScreenshot('dark-$variant-arrival');
      expect(
          tester.widget<LiquidTabBar>(find.byType(LiquidTabBar)).selectedIndex,
          0);
      expect(tester.takeException(), isNull);
    }
  });
}
