import 'package:flutter/widgets.dart';

/// Internal iteration-one calibration. Not exported as package API.
/// The Styling example can override these without changing production presets.
class MaterialTuning extends InheritedWidget {
  const MaterialTuning({
    super.key,
    required super.child,
    this.idleOptics = 0.075,
    this.verticalBulge = 3,
    this.travelStretch = 0.10,
    this.velocityStretch = 0.18,
  });

  final double idleOptics;
  final double verticalBulge;
  final double travelStretch;
  final double velocityStretch;

  static MaterialTuning of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MaterialTuning>() ??
      const MaterialTuning(child: SizedBox.shrink());

  @override
  bool updateShouldNotify(MaterialTuning oldWidget) =>
      idleOptics != oldWidget.idleOptics ||
      verticalBulge != oldWidget.verticalBulge ||
      travelStretch != oldWidget.travelStretch ||
      velocityStretch != oldWidget.velocityStretch;
}
