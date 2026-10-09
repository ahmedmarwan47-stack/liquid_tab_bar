import 'package:flutter/material.dart';

import 'bar.dart';
import 'auto_fold_policy.dart';
import 'controller.dart';
import 'scroll_padding.dart';
import 'scroll_source.dart';

/// A convenience [Scaffold] preconfigured for [LiquidTabBar].
///
/// Automatically sets [Scaffold.extendBody] to `true`, wraps [body] with
/// [LiquidScrollPadding] to reserve bottom space, and automatically observes
/// vertical scroll notifications from primary scrollables in [body] to drive
/// [LiquidTabBar.shrinkOnScroll] without manual `NotificationListener` configuration.
///
/// ### Example
///
/// ```dart
/// LiquidTabBarScaffold(
///   tabBar: LiquidTabBar(
///     shrinkOnScroll: true,
///     items: const [
///       LiquidTabItem.icon(label: 'Chats', icon: Icons.chat_bubble_outline),
///       LiquidTabItem.icon(label: 'Calls', icon: Icons.call_outlined),
///     ],
///     selectedIndex: _currentIndex,
///     onSelected: (i) => setState(() => _currentIndex = i),
///   ),
///   body: ListView.builder(
///     itemCount: 50,
///     itemBuilder: (context, i) => ListTile(title: Text('Chat $i')),
///   ),
/// )
/// ```
class LiquidTabBarScaffold extends StatefulWidget {
  const LiquidTabBarScaffold({
    super.key,
    required this.tabBar,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.additionalBottomPadding = 0.0,
    this.autoFoldPolicy = const LiquidAutoFoldPolicy.smart(),
  });

  /// The [LiquidTabBar] to display in the bottom navigation slot.
  final LiquidTabBar tabBar;

  /// The primary content of the scaffold.
  final Widget body;

  /// An app bar to display at the top of the scaffold.
  final PreferredSizeWidget? appBar;

  /// A button displayed floating above [body].
  final Widget? floatingActionButton;

  /// Responsible for determining where the [floatingActionButton] should go.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// The color of the [Material] widget that underlies the entire Scaffold.
  final Color? backgroundColor;

  /// A panel displayed to the side of the [body], often hidden on mobile devices.
  final Widget? drawer;

  /// A panel displayed to the side of the [body], opposite the [drawer].
  final Widget? endDrawer;

  /// A persistent bottom sheet to show on the screen.
  final Widget? bottomSheet;

  /// If true the [body] and the scaffold's floating widgets should size themselves
  /// to avoid the onscreen keyboard.
  final bool? resizeToAvoidBottomInset;

  /// Whether this scaffold is being displayed at the top of the screen.
  final bool primary;

  /// Optional extra padding in logical pixels to add beyond [LiquidTabBar.reservedHeight].
  final double additionalBottomPadding;

  /// Which body scrollables drive folding. Smart detection is the 2.x default.
  /// Use [LiquidAutoFoldPolicy.direct] for legacy depth-zero behavior.
  final LiquidAutoFoldPolicy autoFoldPolicy;

  @override
  State<LiquidTabBarScaffold> createState() => _LiquidTabBarScaffoldState();
}

class _LiquidTabBarScaffoldState extends State<LiquidTabBarScaffold> {
  LiquidTabBarController? _internalController;
  final _scrollBoundary = GlobalKey();

  LiquidTabBarController get _effectiveController {
    if (widget.tabBar.controller != null) {
      return widget.tabBar.controller!;
    }
    if (_internalController == null) {
      final controller = LiquidTabBarController();
      if (LiquidTabBarController.shared.isGovernorArmed) {
        controller.armGovernor();
      }
      _internalController = controller;
    }
    return _internalController!;
  }

  @override
  void didUpdateWidget(LiquidTabBarScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabBar.controller != widget.tabBar.controller ||
        oldWidget.autoFoldPolicy != widget.autoFoldPolicy ||
        oldWidget.tabBar.shrinkOnScroll != widget.tabBar.shrinkOnScroll) {
      final previous = oldWidget.tabBar.controller ?? _internalController;
      if (previous != null) {
        scrollOwnershipFor(previous).unregisterSmartScope(this);
      }
    }
    if (widget.tabBar.controller != null && _internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    final controller = widget.tabBar.controller ?? _internalController;
    if (controller != null) {
      scrollOwnershipFor(controller).unregisterSmartScope(this);
    }
    _internalController?.dispose();
    _internalController = null;
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.tabBar.shrinkOnScroll) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final boundary = _scrollBoundary.currentContext;
    if (boundary == null) return false;
    final source = ScrollSource.describe(notification);
    final policy = widget.autoFoldPolicy;
    final bool eligible;
    switch (policy) {
      case DirectAutoFoldPolicy():
        eligible = notification.depth == 0;
      case SmartAutoFoldPolicy():
        if (scrollOwnershipFor(_effectiveController).smartBoundary(source) !=
            boundary) {
          return false;
        }
        eligible = scrollOwnershipFor(_effectiveController)
            .smartResolver
            .accepts(notification, boundary as Element);
      case CustomAutoFoldPolicy():
        eligible = source != null &&
            source.within(boundary) &&
            !source.offstage &&
            source.activePage != false &&
            policy.predicate(notification);
    }
    if (eligible) {
      final controller = _effectiveController;
      controller.handleScroll(notification,
          allowNested: policy is! DirectAutoFoldPolicy);
      scrollOwnershipFor(controller).bindScope(this, source);
    } else {
      final controller = widget.tabBar.controller ?? _internalController;
      if (controller != null) {
        scrollOwnershipFor(controller).rejectSource(this, source);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;
    if (widget.autoFoldPolicy is SmartAutoFoldPolicy &&
        widget.tabBar.shrinkOnScroll) {
      scrollOwnershipFor(controller).registerSmartScope(
          this, () => _scrollBoundary.currentContext as Element?);
    } else {
      scrollOwnershipFor(controller).unregisterSmartScope(this);
    }
    final effectiveBar = widget.tabBar.withController(controller);

    return Scaffold(
      extendBody: true,
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      backgroundColor: widget.backgroundColor,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      bottomSheet: widget.bottomSheet,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      primary: widget.primary,
      body: NotificationListener<ScrollNotification>(
        key: _scrollBoundary,
        onNotification: _onScroll,
        child: LiquidScrollPadding(
          additionalPadding: widget.additionalBottomPadding,
          child: widget.body,
        ),
      ),
      bottomNavigationBar: effectiveBar,
    );
  }
}
