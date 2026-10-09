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

  double insetAt(double x, {Rect? bounds}) {
    final leftReach = bounds == null
        ? reach
        : math.min(reach, center - bounds.shortestSide / 2);
    final rightReach = bounds == null
        ? reach
        : math.min(reach, bounds.width - bounds.shortestSide / 2 - center);
    final sideReach = x < center ? leftReach : rightReach;
    final distance = (x - center) / math.max(sideReach, 1);
    final weight = math.max(0.0, 1 - distance * distance);
    return depth * weight * weight * weight;
  }

  Path contour(Rect bounds) {
    if (bounds.isEmpty) return Path();
    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(
          bounds, Radius.circular(bounds.shortestSide / 2)));
    if (depth <= 0) return capsule;
    final radius = bounds.shortestSide / 2;
    final left = bounds.left + radius;
    final right = bounds.right - radius;
    // A circle has no straight span to deform without touching its caps.
    if (right <= left) return capsule;
    final count = ((right - left) / 2).ceil();
    final path = Path()..moveTo(left, bounds.top);
    for (var i = 1; i <= count; i++) {
      final x = left + (right - left) * i / count;
      path.lineTo(x, bounds.top + insetAt(x - bounds.left, bounds: bounds));
    }
    // Keep both original semicircles exact; only sample the straight spans.
    path.arcToPoint(Offset(right, bounds.bottom),
        radius: Radius.circular(radius));
    for (var i = count - 1; i >= 0; i--) {
      final x = left + (right - left) * i / count;
      path.lineTo(x, bounds.bottom - insetAt(x - bounds.left, bounds: bounds));
    }
    path.arcToPoint(Offset(left, bounds.top), radius: Radius.circular(radius));
    return path..close();
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
