import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

// Exercise the compiled shader with an image sampler, without requiring an
// Impeller-only BackdropFilter in the headless test renderer.
void main() {
  testWidgets('dispersion is content-driven, bevel-local and motion-only',
      (tester) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/droplet_glass.frag',
      );
      const width = 240;
      const height = 100;
      const defaults = DropletRefractionStyle.medium();
      for (final striped in [false, true]) {
        final backdropRecorder = ui.PictureRecorder();
        final backdropCanvas = ui.Canvas(backdropRecorder);
        backdropCanvas.drawColor(const ui.Color(0xFF303030), ui.BlendMode.src);
        if (striped) {
          for (var x = 0; x < width; x += 16) {
            backdropCanvas.drawRect(
              ui.Rect.fromLTWH(x.toDouble(), 0, 8, height.toDouble()),
              ui.Paint()..color = const ui.Color(0xFFF0F0F0),
            );
          }
        }
        final backdropPicture = backdropRecorder.endRecording();
        final backdrop = await backdropPicture.toImage(width, height);
        final original = (await backdrop.toByteData())!.buffer.asUint8List();
        for (final config in [
          (
            motion: 0.35,
            dispersion: defaults.dispersion,
            strength: defaults.refractionStrength
          ),
          (
            motion: 1.0,
            dispersion: defaults.dispersion,
            strength: defaults.refractionStrength
          ),
          (
            motion: 0.0,
            dispersion: defaults.dispersion,
            strength: defaults.refractionStrength
          ),
          (motion: 1.0, dispersion: 0.0, strength: defaults.refractionStrength),
          (motion: 1.0, dispersion: defaults.dispersion, strength: 0.0),
        ]) {
          final shader = program.fragmentShader();
          final uniforms = <double>[
            width.toDouble(),
            height.toDouble(),
            40,
            18,
            160,
            64,
            32,
            defaults.thickness,
            defaults.refractiveIndex,
            defaults.baseHeight,
            config.dispersion,
            defaults.specularStrength,
            -0.55,
            -0.85,
            1,
            1,
            1,
            0,
            config.motion,
            config.strength,
          ];
          for (var i = 0; i < uniforms.length; i++) {
            shader.setFloat(i, uniforms[i]);
          }
          shader.setImageSampler(0, backdrop);
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            const ui.Rect.fromLTWH(0, 0, 240, 100),
            ui.Paint()..shader = shader,
          );
          final picture = recorder.endRecording();
          final result = await picture.toImage(width, height);
          final pixels = (await result.toByteData())!.buffer.asUint8List();
          var coloredPixels = 0;
          final disabled = config.motion == 0 || config.strength == 0;
          for (var y = 0; y < height; y++) {
            for (var x = 0; x < width; x++) {
              final i = (y * width + x) * 4;
              final spread = (pixels[i] - pixels[i + 1]).abs() +
                  (pixels[i + 1] - pixels[i + 2]).abs();
              if (spread > 3) coloredPixels++;
              // Well inside the flat lens, or outside its bounds.
              final untouched = disabled ||
                  x < 38 ||
                  x > 202 ||
                  y < 16 ||
                  y > 84 ||
                  (x > 75 && x < 165 && y > 34 && y < 66);
              if (untouched) {
                for (var channel = 0; channel < 4; channel++) {
                  expect((pixels[i + channel] - original[i + channel]).abs(),
                      lessThanOrEqualTo(1),
                      reason: 'Untouched ($x,$y), $config');
                }
              }
            }
          }
          expect(
              coloredPixels,
              striped && !disabled && config.dispersion > 0
                  ? greaterThan(20)
                  : equals(0),
              reason: 'Only sampled contrast may produce color: $config');
          result.dispose();
          picture.dispose();
          shader.dispose();
        }
        backdrop.dispose();
        backdropPicture.dispose();
      }
    });
  });
}
