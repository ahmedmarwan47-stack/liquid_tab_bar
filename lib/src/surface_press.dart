import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Geometry shared by the glass shader and the fallback surface contour.
@immutable
class SurfacePress {
  const SurfacePress({
    this.center = 0,
    this.reach = 1,
    this.depth = 0,
    this.amount = 0,
  });

  final double center;
  final double reach;
  final double depth;
  final double amount;

  double insetAt(double x) {
    final distance = (x - center) / math.max(reach, 1);
    final weight = math.max(0.0, 1 - distance * distance);
    return depth * weight * weight * weight;
  }

  Path contour(Rect bounds) {
    if (bounds.isEmpty) return Path();
    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(
          bounds, Radius.circular(bounds.shortestSide / 2)));
    if (depth <= 0) return capsule;
    final metric = capsule.computeMetrics().first;
    // Sample at two logical pixels so the rounded ends remain smooth even
    // when the finger is on the first or last tab. No boolean cutout seams.
    final count = (metric.length / 2).ceil();
    final points = List.generate(count, (i) {
      final p = metric.getTangentForOffset(metric.length * i / count)!.position;
      final scale = 1 - insetAt(p.dx - bounds.left) / (bounds.height / 2);
      return Offset(p.dx, bounds.center.dy + (p.dy - bounds.center.dy) * scale);
    });
    return Path()..addPolygon(points, true);
  }

  @override
  bool operator ==(Object other) =>
      other is SurfacePress &&
      center == other.center &&
      reach == other.reach &&
      depth == other.depth &&
      amount == other.amount;

  @override
  int get hashCode => Object.hash(center, reach, depth, amount);
}

class PressedSurfaceBorder extends ShapeBorder {
  const PressedSurfaceBorder(this.press, {this.side = BorderSide.none});
  final SurfacePress press;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      press.contour(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      press.contour(rect.deflate(side.width));

  @override
  ShapeBorder scale(double t) =>
      PressedSurfaceBorder(press, side: side.scale(t));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
        press.contour(rect.deflate(side.width / 2)), side.toPaint());
  }
}
