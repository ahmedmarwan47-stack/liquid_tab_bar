import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' as meta;

/// Selects which body scrollables drive automatic folding.
///
/// The 2.x default is [smart]. Use [direct] for legacy depth-zero behavior,
/// or [custom] to explicitly select a source in an ambiguous layout.
@meta.immutable
sealed class LiquidAutoFoldPolicy {
  const LiquidAutoFoldPolicy._();

  /// Preserves the existing depth-zero vertical notification policy.
  const factory LiquidAutoFoldPolicy.direct() = DirectAutoFoldPolicy;

  /// Accepts a unique vertical scroll branch through up to four active, settled
  /// horizontal PageViews (including TabBarViews), or directly in the body.
  /// Unsupported, offstage, transitioning, and ambiguous layouts fail closed.
  const factory LiquidAutoFoldPolicy.smart() = SmartAutoFoldPolicy;

  /// Replaces automatic source eligibility with [predicate].
  ///
  /// The predicate must choose the relevant active source. Vertical-axis,
  /// mounted-context, scaffold-boundary, and known inactive-page guards remain.
  /// Returning false disables scaffold forwarding, not manual controller use.
  const factory LiquidAutoFoldPolicy.custom(
      ScrollNotificationPredicate predicate) = CustomAutoFoldPolicy;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      (this is! CustomAutoFoldPolicy ||
          (other as CustomAutoFoldPolicy).predicate ==
              (this as CustomAutoFoldPolicy).predicate);

  @override
  int get hashCode => Object.hash(
      runtimeType,
      this is CustomAutoFoldPolicy
          ? (this as CustomAutoFoldPolicy).predicate
          : null);
}

@meta.internal
final class DirectAutoFoldPolicy extends LiquidAutoFoldPolicy {
  const DirectAutoFoldPolicy() : super._();
}

@meta.internal
final class SmartAutoFoldPolicy extends LiquidAutoFoldPolicy {
  const SmartAutoFoldPolicy() : super._();
}

@meta.internal
final class CustomAutoFoldPolicy extends LiquidAutoFoldPolicy {
  const CustomAutoFoldPolicy(this.predicate) : super._();
  final ScrollNotificationPredicate predicate;
}
