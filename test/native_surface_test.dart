import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:liquid_tab_bar/src/glass.dart';

// Optional rendered previews:
// flutter test test/native_surface_test.dart \
//   --dart-define=GLASS_PREVIEW_DIR=/private/tmp/liquid-native-preview
void main() {
  setUpAll(() async {
    // Optional SDK fonts make exported previews readable; normal tests need
    // neither machine-specific paths nor network font downloads.
    const fontDir = String.fromEnvironment('GLASS_FONT_DIR');
    if (fontDir.isEmpty) return;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File('$fontDir/${entry.value}')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'} rim stays neutral during motion',
        (tester) async {
      final cache = DropletHighlightCache();
      for (final motion in [0.0, 0.5, 1.0, 0.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(120, 64);
        final background = dark ? 32 : 220;
        canvas.drawColor(
            Color.fromARGB(255, background, background, background),
            BlendMode.src);
        LiquidDropletHighlightPainter(
          radius: 32,
          motion: motion,
          isDark: dark,
          fade: 1,
          cache: cache,
        ).paint(canvas, size);
        final picture = recorder.endRecording();
        final image = await tester.runAsync(() => picture.toImage(120, 64));
        final pixels = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        final bytes = pixels!.buffer.asUint8List();
        var changedPixels = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          expect((bytes[i] - bytes[i + 1]).abs(), lessThanOrEqualTo(1));
          expect((bytes[i + 1] - bytes[i + 2]).abs(), lessThanOrEqualTo(1));
          if (bytes[i] != background) changedPixels++;
        }
        expect(changedPixels, greaterThan(0),
            reason: 'Keep a visible reflection.');
        expect(bytes[(32 * 120 + 60) * 4], background,
            reason: 'Never add a wash over the selected glyph.');
        image!.dispose();
        picture.dispose();
      }
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      testWidgets('${platform.name} ${dark ? 'dark' : 'light'} glass fallback',
          (tester) async {
        tester.view.physicalSize = const Size(440, 220);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        var selected = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            platform: platform,
            fontFamily: 'Roboto',
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: StatefulBuilder(builder: (context, setState) {
              return Scaffold(
                extendBody: true,
                body: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF090909) : Colors.white,
                  ),
                  child: Stack(children: [
                    const Positioned(
                      left: 16,
                      bottom: 0,
                      width: 240,
                      height: 190,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6939D5), Color(0xFF251345)],
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Made for You',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 24)),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 16,
                      bottom: 0,
                      width: 154,
                      height: 190,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFEE713A), Color(0xFF60260E)],
                          ),
                        ),
                        child: Center(
                          child: Text('SOUL',
                              style: TextStyle(
                                  color: Color(0xB3FFFFFF), fontSize: 40)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 25,
                      child: ColoredBox(
                        color: dark ? const Color(0xFF090909) : Colors.white,
                      ),
                    ),
                  ]),
                ),
                bottomNavigationBar: LiquidTabBar(
                  warnOnMissingExtendBodyPadding: false,
                  shrinkOnScroll: false,
                  material: LiquidTabBarMaterial.blur,
                  selectedIndex: selected,
                  onSelected: (value) => setState(() => selected = value),
                  theme: dark
                      ? const LiquidTabBarTheme.dark(
                          activeColor: Color(0xFFFA4260))
                      : const LiquidTabBarTheme(activeColor: Color(0xFFD52348)),
                  items: const [
                    LiquidTabItem.icon(label: 'Home', icon: Icons.home_rounded),
                    LiquidTabItem.icon(
                        label: 'New', icon: Icons.grid_view_rounded),
                    LiquidTabItem.icon(label: 'Radio', icon: Icons.sensors),
                    LiquidTabItem.icon(
                        label: 'Library', icon: Icons.library_music),
                  ],
                  separateAction: LiquidTabAction.search(),
                ),
              );
            }),
          ),
        ));
        await tester.pumpAndSettle();

        Future<void> preview(String state) async {
          const dir = String.fromEnvironment('GLASS_PREVIEW_DIR');
          if (dir.isEmpty) return;
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await picture.toByteData(format: ui.ImageByteFormat.png);
            await Directory(dir).create(recursive: true);
            await File(
                    '$dir/${platform.name}-${dark ? 'dark' : 'light'}-$state.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }

        await preview('rest');
        final home = tester.getCenter(find.text('Home'));
        final library = tester.getCenter(find.text('Library'));
        final gesture = await tester.startGesture(home);
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.moveTo(Offset.lerp(home, library, 0.5)!);
        await tester.pump(const Duration(milliseconds: 16));
        await preview('drag');
        expect(tester.getCenter(find.text('Library')), library,
            reason: 'Glass moves without moving tab content.');
        await gesture.moveTo(library);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(selected, 3);
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
