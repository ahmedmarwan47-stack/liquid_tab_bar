import 'package:flutter/foundation.dart';

/// Non-geometric press feedback shared by the bar surface renderers.
@immutable
class SurfacePress {
  const SurfacePress({
    this.center = 0,
    this.reach = 1,
    this.amount = 0,
  });

  final double center;
  final double reach;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is SurfacePress &&
      center == other.center &&
      reach == other.reach &&
      amount == other.amount;

  @override
  int get hashCode => Object.hash(center, reach, amount);
}
