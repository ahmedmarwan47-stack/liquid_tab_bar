import 'dart:math' as math;
import 'dart:ui';

/// Shared outline for the selection fill, clip, reflection and optical lens.
/// Flow zero is the original capsule; moving flow changes end curvature only.
RRect liquidDropletShape(Rect bounds, double radius, double flow) {
  final r = math.min(radius, math.min(bounds.width, bounds.height) / 2);
  final bias = flow.clamp(-1.0, 1.0) * 0.28;
  final left = Radius.elliptical(math.min(r * (1 - bias), bounds.width / 2), r);
  final right =
      Radius.elliptical(math.min(r * (1 + bias), bounds.width / 2), r);
  return RRect.fromRectAndCorners(bounds,
      topLeft: left, bottomLeft: left, topRight: right, bottomRight: right);
}
