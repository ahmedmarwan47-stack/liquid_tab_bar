import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/src/surface_press.dart';

void main() {
  test('first, middle, and last tab presses leave both end-caps unchanged', () {
    const bounds = Rect.fromLTWH(0, 0, 320, 64);
    final resting = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(32)));

    for (final center in [52.0, 160.0, 268.0]) {
      final press = SurfacePress(center: center, reach: 62, depth: 2.15);
      final held = press.contour(bounds);
      expect(
          press.insetAt(center), closeTo(2.15, 0.001));
      expect(press.insetAt(32), 0);
      expect(press.insetAt(288), 0);
      expect(press.insetAt(center + 62), 0);

      // The top and bottom pull inward at the pressed center.
      expect(held.contains(Offset(center, 1)), isFalse);
      expect(held.contains(Offset(center, 63)), isFalse);
      expect(held.contains(Offset(center, 32)), isTrue);

      // Compare the exact rounded end-caps, including their shoulders.
      for (final x in [
        0.0,
        8.0,
        20.0,
        31.0,
        32.0,
        288.0,
        289.0,
        300.0,
        312.0,
        320.0
      ]) {
        for (final y in [0.0, 1.0, 8.0, 16.0, 32.0, 48.0, 56.0, 63.0, 64.0]) {
          expect(held.contains(Offset(x, y)), resting.contains(Offset(x, y)),
              reason: 'center=$center at ($x, $y)');
        }
      }
    }
  });
}
