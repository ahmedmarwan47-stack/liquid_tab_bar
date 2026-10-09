import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass.dart';

/// Builds a tab's glyph in [color]; [selected] is true for the active tab, so
/// a filled variant can stand in for the outline.
typedef LiquidTabIconBuilder = Widget Function(Color color, bool selected);

/// Placement of a separate action button relative to the main tab bar.
enum LiquidTabActionPlacement {
  /// The tab bar is pinned to the leading edge and the separate action is pinned to the trailing edge.
  split,

  /// The tab bar and separate action are placed adjacent to each other and centered together.
  together,
}

/// The geometric shape of the tab bar capsule when folded or minimized on scroll.
enum LiquidFoldedShape {
  /// Folds into an equilateral true circle matching the separate action button's geometry.
  ///
  /// In this mode, width equals height at full fold, and the border radius equals half that diameter.
  circle,

  /// Folds into an elongated stadium pill/oval shape.
  ///
  /// In this mode, the bar maintains its full height and smooth border radius while retaining
  /// an elongated horizontal pill silhouette.
  oval,
}

/// Search editing and dismissal controls.
enum LiquidSearchControls {
  /// Contextual text clear button and a separate glass back action.
  clearAndDismiss,

  /// The internal X closes Search and the glass circle shows the selected tab.
  legacy,
}

/// Configuration for the interactive search field transition in [LiquidTabBar].
class LiquidTabBarSearch {
  const LiquidTabBarSearch({
    this.controller,
    this.focusNode,
    this.hintText,
    this.style,
    this.hintStyle,
    this.onChanged,
    this.onSubmitted,
    this.onClose,
    this.autofocus = true,
    this.textInputAction = TextInputAction.search,
    this.clearOnClose = false,
    this.controls = LiquidSearchControls.clearAndDismiss,
    this.onTapOutside,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClose;
  final bool autofocus;
  final TextInputAction textInputAction;

  /// Whether the search query text should be automatically cleared when
  /// the search field collapses. Defaults to `false`.
  final bool clearOnClose;

  final LiquidSearchControls controls;

  /// Callback when a tap is detected outside the search input field.
  /// If not provided, defaults to unfocusing via [FocusManager.primaryFocus].
  final TapRegionCallback? onTapOutside;
}

/// Visual styling for a separate action's selected marker.
@immutable
class LiquidTabActionStyle {
  const LiquidTabActionStyle({required this.selectedFill});

  static const light = LiquidTabActionStyle(selectedFill: Color(0x55FFFFFF));

  static const dark = LiquidTabActionStyle(selectedFill: Color(0x38FFFFFF));

  final Color selectedFill;

  LiquidTabActionStyle copyWith({Color? selectedFill}) =>
      LiquidTabActionStyle(selectedFill: selectedFill ?? this.selectedFill);

  static LiquidTabActionStyle lerp(
    LiquidTabActionStyle a,
    LiquidTabActionStyle b,
    double t,
  ) =>
      LiquidTabActionStyle(
        selectedFill: Color.lerp(a.selectedFill, b.selectedFill, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidTabActionStyle && other.selectedFill == selectedFill;

  @override
  int get hashCode => selectedFill.hashCode;

  @override
  String toString() => 'LiquidTabActionStyle(selectedFill: $selectedFill)';
}

/// Visual styling configuration for badges in [LiquidTabBar] and [LiquidTabItem].
@immutable
class LiquidBadgeStyle {
  const LiquidBadgeStyle({
    this.color,
    this.textColor,
    this.textStyle,
    this.size = 18.0,
    this.dotSize = 8.0,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 1.5,
    this.offset,
    this.padding,
    this.borderRadius,
  });

  /// The background fill color of the badge.
  final Color? color;

  /// The text color for the badge number/label (defaults to white).
  final Color? textColor;

  /// The typography style for the badge count or text.
  final TextStyle? textStyle;

  /// The minimum width and height of text badges (defaults to 18.0).
  /// Text and padding may make the final badge larger.
  final double size;

  /// The diameter of dot badges when no count/text is set (defaults to 8.0).
  final double dotSize;

  /// Whether to render a border around the badge. Defaults to `true`.
  /// Set to `false` to remove the border completely.
  final bool showBorder;

  /// The border stroke color. Defaults to the renderer's white fallback.
  final Color? borderColor;

  /// The border stroke width. Defaults to 1.5.
  final double borderWidth;

  /// Custom positioning offset for the badge relative to the tab icon.
  final Offset? offset;

  /// Custom padding inside the badge container.
  final EdgeInsetsGeometry? padding;

  /// Custom border radius for pill badges (defaults to circular).
  final BorderRadiusGeometry? borderRadius;

  LiquidBadgeStyle copyWith({
    Color? color,
    Color? textColor,
    TextStyle? textStyle,
    double? size,
    double? dotSize,
    bool? showBorder,
    Color? borderColor,
    double? borderWidth,
    Offset? offset,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
  }) {
    return LiquidBadgeStyle(
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      textStyle: textStyle ?? this.textStyle,
      size: size ?? this.size,
      dotSize: dotSize ?? this.dotSize,
      showBorder: showBorder ?? this.showBorder,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      offset: offset ?? this.offset,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  static LiquidBadgeStyle? lerp(
    LiquidBadgeStyle? a,
    LiquidBadgeStyle? b,
    double t,
  ) {
    if (identical(a, b)) return a;
    if (a == null) return b;
    if (b == null) return a;
    return LiquidBadgeStyle(
      color: Color.lerp(a.color, b.color, t),
      textColor: Color.lerp(a.textColor, b.textColor, t),
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
      size: ui.lerpDouble(a.size, b.size, t) ?? a.size,
      dotSize: ui.lerpDouble(a.dotSize, b.dotSize, t) ?? a.dotSize,
      showBorder: t < 0.5 ? a.showBorder : b.showBorder,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t),
      borderWidth:
          ui.lerpDouble(a.borderWidth, b.borderWidth, t) ?? a.borderWidth,
      offset: Offset.lerp(a.offset, b.offset, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      borderRadius: BorderRadiusGeometry.lerp(
        a.borderRadius,
        b.borderRadius,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiquidBadgeStyle &&
        other.color == color &&
        other.textColor == textColor &&
        other.textStyle == textStyle &&
        other.size == size &&
        other.dotSize == dotSize &&
        other.showBorder == showBorder &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.offset == offset &&
        other.padding == padding &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(
        color,
        textColor,
        textStyle,
        size,
        dotSize,
        showBorder,
        borderColor,
        borderWidth,
        offset,
        padding,
        borderRadius,
      );

  @override
  String toString() => 'LiquidBadgeStyle(color: $color, textColor: $textColor, '
      'size: $size, dotSize: $dotSize, showBorder: $showBorder, '
      'borderColor: $borderColor, borderWidth: $borderWidth, offset: $offset, '
      'padding: $padding, borderRadius: $borderRadius)';
}

/// A standalone action button displayed alongside the [LiquidTabBar]
/// (such as a search, filter, or create button), styled with the exact same
/// liquid glass / surface material as the bar.
class LiquidTabAction {
  const LiquidTabAction({
    required this.icon,
    this.onTap,
    this.selected = false,
    this.badge = false,
    this.badgeText,
    this.badgeStyle,
    this.tooltip,
    this.size = 64.0,
    this.iconSize,
    this.color,
    this.activeColor,
    this.search,
    this.customIcon,
    this.useThemeColor = true,
    this.searchIcon,
  });

  /// A convenience constructor that wraps an [IconData] in an [Icon] widget.
  LiquidTabAction.icon({
    required IconData icon,
    IconData? activeIcon,
    double iconSize = 23.0,
    VoidCallback? onTap,
    bool selected = false,
    bool badge = false,
    String? badgeText,
    LiquidBadgeStyle? badgeStyle,
    String? tooltip,
    double size = 64.0,
    Color? color,
    Color? activeColor,
  }) : this(
          icon: Builder(
            builder: (context) {
              final iconColor = IconTheme.of(context).color;
              return Icon(
                selected ? (activeIcon ?? icon) : icon,
                color: iconColor,
                size: iconSize,
              );
            },
          ),
          onTap: onTap,
          selected: selected,
          badge: badge,
          badgeText: badgeText,
          badgeStyle: badgeStyle,
          tooltip: tooltip,
          size: size,
          iconSize: iconSize,
          color: color,
          activeColor: activeColor,
        );

  /// Creates a search action button that automatically morphs the bar into
  /// an expanded liquid-glass search input field when tapped.
  factory LiquidTabAction.search({
    String? hintText,
    TextStyle? style,
    TextStyle? hintStyle,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onClose,
    bool autofocus = true,
    IconData icon = Icons.search_rounded,
    Widget? customIcon,
    bool useThemeColor = true,
    double? iconSize,
    double size = 64.0,
    String? tooltip = 'Search',
    VoidCallback? onTap,
    TapRegionCallback? onTapOutside,
    bool clearOnClose = false,
    LiquidSearchControls controls = LiquidSearchControls.clearAndDismiss,
  }) {
    return LiquidTabAction(
      icon: Builder(
        builder: (context) {
          final iconColor =
              IconTheme.of(context).color ?? const Color(0xFF1C1C1E);
          final glyphSize = iconSize ?? 24.0;
          if (customIcon != null) {
            Widget glyph = customIcon;
            if (useThemeColor) {
              glyph = ColorFiltered(
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                child: glyph,
              );
            }
            return SizedBox(
              width: glyphSize,
              height: glyphSize,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: glyph,
                ),
              ),
            );
          }
          return Icon(icon, color: iconColor, size: glyphSize);
        },
      ),
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      customIcon: customIcon,
      useThemeColor: useThemeColor,
      searchIcon: icon,
      search: LiquidTabBarSearch(
        controller: controller,
        focusNode: focusNode,
        hintText: hintText,
        style: style,
        hintStyle: hintStyle,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onClose: onClose,
        autofocus: autofocus,
        onTapOutside: onTapOutside,
        clearOnClose: clearOnClose,
        controls: controls,
      ),
      onTap: onTap,
    );
  }

  final Widget icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool badge;
  final String? badgeText;
  final LiquidBadgeStyle? badgeStyle;
  final String? tooltip;
  final double size;
  final double? iconSize;
  final Color? color;
  final Color? activeColor;
  final LiquidTabBarSearch? search;
  final Widget? customIcon;
  final bool useThemeColor;
  final IconData? searchIcon;
}

/// One tab of a [LiquidTabBar].
@immutable
class LiquidTabItem {
  /// A tab drawn with [IconData]: [icon] at rest, [activeIcon] (or [icon])
  /// when selected.
  const LiquidTabItem.icon({
    required this.label,
    required IconData icon,
    IconData? activeIcon,
    this.badge = false,
    this.badgeText,
    this.badgeCount,
    this.badgeStyle,
    this.badgeWidget,
    this.iconSize = 23.0,
    LiquidTabIconBuilder? iconBuilder,
  })  : _icon = icon,
        _activeIcon = activeIcon,
        _customIcon = null,
        _customActiveIcon = null,
        _useThemeColor = true,
        assert(iconSize > 0, 'iconSize must be greater than zero.'),
        assert(
          badge || badgeCount == null,
          'badgeCount cannot be set when badge is false. Set badge: true to display a badge with a count.',
        ),
        assert(
          badge || badgeText == null,
          'badgeText cannot be set when badge is false. Set badge: true to display a badge with text.',
        ),
        _customIconBuilder = iconBuilder;

  /// A tab drawn with custom [Widget]s (e.g. SvgPicture, Image, custom artwork).
  const LiquidTabItem.custom({
    required this.label,
    required Widget icon,
    Widget? activeIcon,
    this.badge = false,
    this.badgeText,
    this.badgeCount,
    this.badgeStyle,
    this.badgeWidget,
    this.iconSize = 23.0,
    bool useThemeColor = true,
  })  : _icon = null,
        _activeIcon = null,
        _customIcon = icon,
        _customActiveIcon = activeIcon,
        _useThemeColor = useThemeColor,
        _customIconBuilder = null,
        assert(iconSize > 0, 'iconSize must be greater than zero.'),
        assert(
          badge || badgeCount == null,
          'badgeCount cannot be set when badge is false. Set badge: true to display a badge with a count.',
        ),
        assert(
          badge || badgeText == null,
          'badgeText cannot be set when badge is false. Set badge: true to display a badge with text.',
        );

  final String label;
  final IconData? _icon;
  final IconData? _activeIcon;
  final Widget? _customIcon;
  final Widget? _customActiveIcon;
  final bool _useThemeColor;

  /// The logical width and height available to this tab's glyph.
  ///
  /// Defaults to 23.0. This also constrains a custom [iconBuilder] result.
  final double iconSize;
  final LiquidTabIconBuilder? _customIconBuilder;

  /// The [IconData] glyph for tabs constructed via [LiquidTabItem.icon].
  ///
  /// Throws an [UnsupportedError] if this item was constructed via [LiquidTabItem.custom].
  IconData get icon {
    final val = _icon;
    if (val != null) return val;
    throw UnsupportedError(
      'LiquidTabItem.custom does not have an IconData. '
      'Use customIcon or iconBuilder instead.',
    );
  }

  /// The active [IconData] glyph for tabs constructed via [LiquidTabItem.icon].
  IconData? get activeIcon => _activeIcon;

  /// The custom widget glyph for tabs constructed via [LiquidTabItem.custom].
  Widget? get customIcon => _customIcon;

  /// The custom active widget glyph for tabs constructed via [LiquidTabItem.custom].
  Widget? get customActiveIcon => _customActiveIcon;

  /// Whether this tab item is driven by custom widget glyphs rather than [IconData].
  bool get isCustom => _customIcon != null;

  /// The builder used to render this tab's icon.
  LiquidTabIconBuilder get iconBuilder {
    if (_customIconBuilder != null) return _customIconBuilder;
    if (_customIcon != null) {
      return (color, selected) {
        Widget w = selected ? (_customActiveIcon ?? _customIcon) : _customIcon;
        if (_useThemeColor) {
          w = ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: w,
          );
        }
        return SizedBox(
          width: iconSize,
          height: iconSize,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: w,
            ),
          ),
        );
      };
    }
    return (color, selected) => Icon(
          selected ? (_activeIcon ?? _icon!) : _icon!,
          color: color,
          size: iconSize,
        );
  }

  /// A small dot on the glyph's top-trailing corner — "something is waiting".
  final bool badge;

  /// Text or number to display in a notification badge pill (e.g. '3', '99+').
  /// Requires [badge] to be `true`.
  final String? badgeText;

  /// Numeric notification count. When set and [badgeText] is null, formatted automatically.
  /// Requires [badge] to be `true`.
  final int? badgeCount;

  /// Visual styling configuration for this tab's notification badge
  /// (e.g. size, colors, whether to remove border, text style, padding).
  final LiquidBadgeStyle? badgeStyle;

  /// Custom widget to display as the badge, replacing the standard dot/number pill.
  final Widget? badgeWidget;

  /// Effective text shown in the badge, if any.
  String? get effectiveBadgeText {
    if (!badge) return null;
    if (badgeText != null && badgeText!.isNotEmpty) return badgeText;
    if (badgeCount != null && badgeCount! > 0) {
      return badgeCount! > 99 ? '99+' : badgeCount.toString();
    }
    return null;
  }

  /// Whether a badge (dot or text pill) is visible.
  bool get hasBadge => badge;
}

/// The shadow controls supported by the moving selection droplet renderer.
@immutable
class LiquidDropletShadow {
  const LiquidDropletShadow({
    required this.color,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
  }) : assert(blurRadius >= 0, 'blurRadius cannot be negative.');

  final Color color;
  final double blurRadius;
  final Offset offset;

  LiquidDropletShadow copyWith({
    Color? color,
    double? blurRadius,
    Offset? offset,
  }) =>
      LiquidDropletShadow(
        color: color ?? this.color,
        blurRadius: blurRadius ?? this.blurRadius,
        offset: offset ?? this.offset,
      );

  static LiquidDropletShadow lerp(
    LiquidDropletShadow a,
    LiquidDropletShadow b,
    double t,
  ) =>
      LiquidDropletShadow(
        color: Color.lerp(a.color, b.color, t)!,
        blurRadius: ui.lerpDouble(a.blurRadius, b.blurRadius, t)!,
        offset: Offset.lerp(a.offset, b.offset, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidDropletShadow &&
      other.color == color &&
      other.blurRadius == blurRadius &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(color, blurRadius, offset);

  @override
  String toString() =>
      'LiquidDropletShadow(color: $color, blurRadius: $blurRadius, offset: $offset)';
}

/// Surface styling for the moving selection droplet across material tiers.
///
/// The gradient, border, and shadow are used by glass and blur rendering;
/// [opaqueFill] is used by opaque rendering.
@immutable
class LiquidDropletSurfaceStyle {
  const LiquidDropletSurfaceStyle({
    required this.gradientTop,
    required this.gradientBottom,
    required this.borderColor,
    this.borderWidth = 0.65,
    required this.shadow,
    required this.opaqueFill,
  });

  static const light = LiquidDropletSurfaceStyle(
    gradientTop: Color(0x12000000),
    gradientBottom: Color(0x0C000000),
    borderColor: Color(0x00000000),
    shadow: LiquidDropletShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    opaqueFill: Color(0x0F000000),
  );

  static const dark = LiquidDropletSurfaceStyle(
    gradientTop: Color(0x22FFFFFF),
    gradientBottom: Color(0x18FFFFFF),
    borderColor: Color(0x00FFFFFF),
    shadow: LiquidDropletShadow(
      color: Color(0x14000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    opaqueFill: Color(0x2BFFFFFF),
  );

  static const darkGlossy = LiquidDropletSurfaceStyle(
    gradientTop: Color(0x29FFFFFF),
    gradientBottom: Color(0x1DFFFFFF),
    borderColor: Color(0x00FFFFFF),
    shadow: LiquidDropletShadow(
      color: Color(0x18000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    opaqueFill: Color(0x2BFFFFFF),
  );

  final Color gradientTop;
  final Color gradientBottom;
  final Color borderColor;
  final double borderWidth;

  /// The droplet shadow. These are the three shadow properties the renderer
  /// supports.
  final LiquidDropletShadow shadow;
  final Color opaqueFill;

  LiquidDropletSurfaceStyle copyWith({
    Color? gradientTop,
    Color? gradientBottom,
    Color? borderColor,
    double? borderWidth,
    LiquidDropletShadow? shadow,
    Color? opaqueFill,
  }) =>
      LiquidDropletSurfaceStyle(
        gradientTop: gradientTop ?? this.gradientTop,
        gradientBottom: gradientBottom ?? this.gradientBottom,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        shadow: shadow ?? this.shadow,
        opaqueFill: opaqueFill ?? this.opaqueFill,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidDropletSurfaceStyle &&
      other.gradientTop == gradientTop &&
      other.gradientBottom == gradientBottom &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.shadow == shadow &&
      other.opaqueFill == opaqueFill;

  @override
  int get hashCode => Object.hash(
        gradientTop,
        gradientBottom,
        borderColor,
        borderWidth,
        shadow,
        opaqueFill,
      );

  static LiquidDropletSurfaceStyle lerp(
    LiquidDropletSurfaceStyle a,
    LiquidDropletSurfaceStyle b,
    double t,
  ) =>
      LiquidDropletSurfaceStyle(
        gradientTop: Color.lerp(a.gradientTop, b.gradientTop, t)!,
        gradientBottom: Color.lerp(a.gradientBottom, b.gradientBottom, t)!,
        borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
        borderWidth: ui.lerpDouble(a.borderWidth, b.borderWidth, t)!,
        shadow: LiquidDropletShadow.lerp(a.shadow, b.shadow, t),
        opaqueFill: Color.lerp(a.opaqueFill, b.opaqueFill, t)!,
      );

  @override
  String toString() => 'LiquidDropletSurfaceStyle('
      'gradientTop: $gradientTop, gradientBottom: $gradientBottom, '
      'borderColor: $borderColor, borderWidth: $borderWidth, '
      'shadow: $shadow, opaqueFill: $opaqueFill)';
}

/// Canonical surface styling for the tab bar across its material tiers.
enum _LiquidBarStyleKind { normal, glossy, fixed }

@immutable
class LiquidBarStyle {
  const LiquidBarStyle({
    GlassStyle? glass,
    Color? blurTint,
    Color? blurSheenTop,
    Color? blurSheenBottom,
    Color? blurEdge,
    Color? opaqueFill,
    Color? opaqueEdge,
    List<BoxShadow>? shadow,
  })  : glass = glass ?? lightGlass,
        blurTint = blurTint ?? const Color(0x8FFFFFFF),
        blurSheenTop = blurSheenTop ?? const Color(0x08FFFFFF),
        blurSheenBottom = blurSheenBottom ?? const Color(0x02FFFFFF),
        blurEdge = blurEdge ?? const Color(0x30FFFFFF),
        opaqueFill = opaqueFill ?? const Color(0xFFFFFFFF),
        opaqueEdge = opaqueEdge ?? const Color(0xFFE6E5E2),
        shadow = shadow ?? lightShadow,
        _kind = glass == null &&
                blurTint == null &&
                blurSheenTop == null &&
                blurSheenBottom == null &&
                blurEdge == null &&
                opaqueFill == null &&
                opaqueEdge == null &&
                shadow == null
            ? _LiquidBarStyleKind.normal
            : _LiquidBarStyleKind.fixed;

  LiquidBarStyle._adaptiveGlossy(LiquidBarStyle lightStyle)
      : glass = lightStyle.glass,
        blurTint = lightStyle.blurTint,
        blurSheenTop = lightStyle.blurSheenTop,
        blurSheenBottom = lightStyle.blurSheenBottom,
        blurEdge = lightStyle.blurEdge,
        opaqueFill = lightStyle.opaqueFill,
        opaqueEdge = lightStyle.opaqueEdge,
        shadow = lightStyle.shadow,
        _kind = _LiquidBarStyleKind.glossy;

  final _LiquidBarStyleKind _kind;

  /// A more transparent, polished capsule with a bright, neutral bevel.
  ///
  /// Applies to the bar and its separate actions in both shader and blur tiers.
  /// With no [brightness], the bar resolves this preset from the ambient theme
  /// whenever it builds. Pass [brightness] to pin a specific palette.
  /// Opaque accessibility surfaces are preserved from the base palette.
  factory LiquidBarStyle.glossy({Brightness? brightness}) {
    if (brightness == null) {
      return LiquidBarStyle._adaptiveGlossy(
        _glossyFor(Brightness.light),
      );
    }
    return _glossyFor(brightness);
  }

  static LiquidBarStyle _glossyFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? dark : light;
    final glossyRim = isDark ? 5.2 : 7.0;
    final glossyDepth = isDark ? 4.8 : 8.0;
    final glossyBlur = isDark ? 16.0 : 14.0;
    final glossySpecular = isDark ? 0.36 : 0.55;
    final tint = isDark ? darkGlass.tint : const Color(0x80FFFFFF);

    return base.copyWith(
      glass: base.glass.copyWith(
        rim: glossyRim,
        depth: glossyDepth,
        blur: glossyBlur,
        tint: tint,
        specular: glossySpecular,
        edgeDark: 0.02,
      ),
      blurTint: tint,
      blurSheenTop: isDark ? const Color(0x0BFFFFFF) : const Color(0x18FFFFFF),
      blurSheenBottom:
          isDark ? const Color(0x04FFFFFF) : const Color(0x08FFFFFF),
      blurEdge: isDark ? const Color(0x2BFFFFFF) : const Color(0x48FFFFFF),
    );
  }

  bool get _isGlossyPreset =>
      _kind == _LiquidBarStyleKind.glossy ||
      this == _glossyFor(Brightness.dark) ||
      this == _glossyFor(Brightness.light);

  /// Resolves an unpinned Normal or Glossy preset for [brightness]. Custom
  /// styles and presets created with an explicit brightness retain their values.
  LiquidBarStyle resolve(Brightness brightness) => switch (_kind) {
        _LiquidBarStyleKind.normal =>
          brightness == Brightness.dark ? dark : light,
        _LiquidBarStyleKind.glossy => _glossyFor(brightness),
        _LiquidBarStyleKind.fixed => this,
      };

  static const GlassStyle lightGlass = GlassStyle(
    rim: 5,
    curve: 1.0,
    depth: 6,
    dispersion: 0.0,
    blur: 18,
    saturation: 1.15,
    tint: Color(0x8FFFFFFF),
    specular: 0.38,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.02,
    shadow: 0.12,
    shadowBlur: 24,
    shadowOffset: Offset(0, 8),
  );

  static const GlassStyle darkGlass = GlassStyle(
    rim: 4.4,
    curve: 1.0,
    depth: 4,
    dispersion: 0.0,
    blur: 16,
    saturation: 1.08,
    tint: Color(0x7818191B),
    specular: 0.30,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.02,
    shadow: 0.08,
    shadowBlur: 20,
    shadowOffset: Offset(0, 6),
  );

  static const List<BoxShadow> lightShadow = [
    BoxShadow(
      color: Color(0x12000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -2,
    ),
    BoxShadow(color: Color(0x06000000), offset: Offset(0, 3), blurRadius: 8),
  ];

  static const List<BoxShadow> darkShadow = [
    BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 7),
      blurRadius: 22,
      spreadRadius: -2,
    ),
    BoxShadow(color: Color(0x10000000), offset: Offset(0, 2), blurRadius: 7),
  ];

  static const LiquidBarStyle light = LiquidBarStyle(glass: lightGlass);
  static const LiquidBarStyle dark = LiquidBarStyle(
    glass: darkGlass,
    blurTint: Color(0x7818191B),
    blurSheenTop: Color(0x09FFFFFF),
    blurSheenBottom: Color(0x02FFFFFF),
    blurEdge: Color(0x24FFFFFF),
    opaqueFill: Color(0xFF1C1C1E),
    opaqueEdge: Color(0xFF2C2C2E),
    shadow: darkShadow,
  );

  final GlassStyle glass;
  final Color blurTint;
  final Color blurSheenTop;
  final Color blurSheenBottom;
  final Color blurEdge;
  final Color opaqueFill;
  final Color opaqueEdge;

  /// Outer bar shadows for blur and opaque rendering. The glass shader uses
  /// `GlassStyle.shadow`, `shadowBlur`, and `shadowOffset` instead.
  final List<BoxShadow> shadow;

  LiquidBarStyle copyWith({
    GlassStyle? glass,
    Color? blurTint,
    Color? blurSheenTop,
    Color? blurSheenBottom,
    Color? blurEdge,
    Color? opaqueFill,
    Color? opaqueEdge,
    List<BoxShadow>? shadow,
  }) {
    if (glass == null &&
        blurTint == null &&
        blurSheenTop == null &&
        blurSheenBottom == null &&
        blurEdge == null &&
        opaqueFill == null &&
        opaqueEdge == null &&
        shadow == null) {
      return this;
    }
    return LiquidBarStyle(
      glass: glass ?? this.glass,
      blurTint: blurTint ?? this.blurTint,
      blurSheenTop: blurSheenTop ?? this.blurSheenTop,
      blurSheenBottom: blurSheenBottom ?? this.blurSheenBottom,
      blurEdge: blurEdge ?? this.blurEdge,
      opaqueFill: opaqueFill ?? this.opaqueFill,
      opaqueEdge: opaqueEdge ?? this.opaqueEdge,
      shadow: shadow ?? this.shadow,
    );
  }

  static LiquidBarStyle lerp(LiquidBarStyle a, LiquidBarStyle b, double t) =>
      LiquidBarStyle(
        glass: t < 0.5 ? a.glass : b.glass,
        blurTint: Color.lerp(a.blurTint, b.blurTint, t)!,
        blurSheenTop: Color.lerp(a.blurSheenTop, b.blurSheenTop, t)!,
        blurSheenBottom: Color.lerp(a.blurSheenBottom, b.blurSheenBottom, t)!,
        blurEdge: Color.lerp(a.blurEdge, b.blurEdge, t)!,
        opaqueFill: Color.lerp(a.opaqueFill, b.opaqueFill, t)!,
        opaqueEdge: Color.lerp(a.opaqueEdge, b.opaqueEdge, t)!,
        shadow: BoxShadow.lerpList(a.shadow, b.shadow, t) ?? a.shadow,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidBarStyle &&
      other._kind == _kind &&
      other.glass == glass &&
      other.blurTint == blurTint &&
      other.blurSheenTop == blurSheenTop &&
      other.blurSheenBottom == blurSheenBottom &&
      other.blurEdge == blurEdge &&
      other.opaqueFill == opaqueFill &&
      other.opaqueEdge == opaqueEdge &&
      listEquals(other.shadow, shadow);

  @override
  int get hashCode => Object.hash(
        glass,
        blurTint,
        blurSheenTop,
        blurSheenBottom,
        blurEdge,
        opaqueFill,
        opaqueEdge,
        Object.hashAll(shadow),
        _kind,
      );

  @override
  String toString() => 'LiquidBarStyle('
      'glass: $glass, blurTint: $blurTint, blurSheenTop: $blurSheenTop, '
      'blurSheenBottom: $blurSheenBottom, blurEdge: $blurEdge, '
      'opaqueFill: $opaqueFill, opaqueEdge: $opaqueEdge, shadow: $shadow)';
}

/// Every colour and number a [LiquidTabBar] draws with. Unspecified palette
/// fields follow the ambient brightness when the bar builds; explicitly
/// supplied fields keep their values.
@immutable
class LiquidTabBarTheme {
  static const lightGlossyRefraction = DropletRefractionStyle(
    thickness: 13.5,
    baseHeight: 25.5,
    dispersion: 0.18,
    specularStrength: 0.17,
    refractionStrength: 0.66,
  );

  static const darkNormalRefraction = DropletRefractionStyle();

  static const darkGlossyRefraction = DropletRefractionStyle(
    thickness: 15,
    refractiveIndex: 1.52,
    baseHeight: 28,
    dispersion: 0.23,
    specularStrength: 0.23,
    refractionStrength: 0.84,
  );

  /// Default spring physics for fold and lens motions.
  static const SpringDescription defaultSpring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 30,
  );

  /// Default duration before lens stretch eases off.
  static const Duration defaultRelax = Duration(milliseconds: 120);

  const LiquidTabBarTheme({
    Color? activeColor,
    Color? inactiveColor,
    this.labelStyle = const TextStyle(),
    LiquidBarStyle? barStyle,
    LiquidTabActionStyle? actionStyle,
    LiquidDropletSurfaceStyle? dropletSurfaceStyle,
    LiquidBadgeStyle? badgeStyle,
    DropletRefractionStyle? dropletRefraction,
    this.spring = defaultSpring,
    this.relax = defaultRelax,
    this.foldedShape = LiquidFoldedShape.circle,
    this.maxWidth,
    this.brightness,
  })  : activeColor = activeColor ?? const Color(0xFF007AFF),
        inactiveColor = inactiveColor ?? const Color(0xFF1C1C1E),
        barStyle = barStyle ?? LiquidBarStyle.light,
        actionStyle = actionStyle ?? LiquidTabActionStyle.light,
        dropletSurfaceStyle =
            dropletSurfaceStyle ?? LiquidDropletSurfaceStyle.light,
        badgeStyle = badgeStyle ?? const LiquidBadgeStyle(),
        _autoActiveColor = activeColor == null,
        _autoInactiveColor = inactiveColor == null,
        _autoBarStyle = barStyle == null,
        _autoActionStyle = actionStyle == null,
        _autoDropletSurfaceStyle = dropletSurfaceStyle == null,
        _autoBadgeStyle = badgeStyle == null,
        dropletRefraction = dropletRefraction ?? const DropletRefractionStyle(),
        _autoDropletRefraction = dropletRefraction == null;

  /// A dark glass theme preset for dark mode backgrounds.
  const LiquidTabBarTheme.dark({
    this.activeColor = const Color(0xFFF2F2F7),
    this.inactiveColor = const Color(0xCCF2F2F7),
    this.labelStyle = const TextStyle(),
    this.barStyle = LiquidBarStyle.dark,
    this.actionStyle = LiquidTabActionStyle.dark,
    LiquidDropletSurfaceStyle? dropletSurfaceStyle,
    this.badgeStyle = const LiquidBadgeStyle(borderColor: Color(0xFF1C1C1E)),
    DropletRefractionStyle? dropletRefraction,
    this.spring = defaultSpring,
    this.relax = defaultRelax,
    this.foldedShape = LiquidFoldedShape.circle,
    this.maxWidth,
  })  : dropletSurfaceStyle =
            dropletSurfaceStyle ?? LiquidDropletSurfaceStyle.dark,
        brightness = Brightness.dark,
        _autoActiveColor = false,
        _autoInactiveColor = false,
        _autoBarStyle = false,
        _autoActionStyle = false,
        _autoDropletSurfaceStyle = dropletSurfaceStyle == null,
        _autoBadgeStyle = false,
        dropletRefraction = dropletRefraction ?? darkNormalRefraction,
        _autoDropletRefraction = dropletRefraction == null;

  const LiquidTabBarTheme._fromFields({
    required this.activeColor,
    required this.inactiveColor,
    required this.labelStyle,
    required this.barStyle,
    required this.actionStyle,
    required this.dropletSurfaceStyle,
    required this.badgeStyle,
    required this.dropletRefraction,
    required this.spring,
    required this.relax,
    required this.foldedShape,
    required this.maxWidth,
    required this.brightness,
    required bool autoActiveColor,
    required bool autoInactiveColor,
    required bool autoBarStyle,
    required bool autoActionStyle,
    required bool autoDropletSurfaceStyle,
    required bool autoBadgeStyle,
    required bool autoDropletRefraction,
  })  : _autoActiveColor = autoActiveColor,
        _autoInactiveColor = autoInactiveColor,
        _autoBarStyle = autoBarStyle,
        _autoActionStyle = autoActionStyle,
        _autoDropletSurfaceStyle = autoDropletSurfaceStyle,
        _autoBadgeStyle = autoBadgeStyle,
        _autoDropletRefraction = autoDropletRefraction;

  /// Automatically picks [LiquidTabBarTheme.dark] or [LiquidTabBarTheme] (light)
  /// matching the ambient app theme or platform brightness, using the app's
  /// primary color as the active tab color if available.
  factory LiquidTabBarTheme.adaptive(BuildContext context) {
    final hasTheme = context.findAncestorWidgetOfExactType<Theme>() != null;
    final Brightness brightness;
    final Color? primary;
    if (hasTheme) {
      final theme = Theme.of(context);
      brightness = theme.brightness;
      primary = theme.colorScheme.primary;
    } else {
      brightness = MediaQuery.platformBrightnessOf(context);
      primary = null;
    }

    return const LiquidTabBarTheme().resolve(brightness, primary: primary);
  }

  /// Uses [ambientBrightness] for fields the caller did not explicitly set.
  /// [brightness] can pin a light or dark palette independently of the app.
  LiquidTabBarTheme resolve(
    Brightness ambientBrightness, {
    Color? primary,
  }) {
    final effectiveBrightness = brightness ?? ambientBrightness;
    final dark = effectiveBrightness == Brightness.dark;
    final base =
        dark ? const LiquidTabBarTheme.dark() : const LiquidTabBarTheme();
    final resolvedBarStyle = _autoBarStyle
        ? (dark ? LiquidBarStyle.dark : LiquidBarStyle.light)
        : barStyle.resolve(effectiveBrightness);
    final glossy = resolvedBarStyle._isGlossyPreset;
    final darkGlossy = dark && glossy;
    return LiquidTabBarTheme._fromFields(
      activeColor: _autoActiveColor
          ? (brightness == null ? primary : null) ?? base.activeColor
          : activeColor,
      inactiveColor: _autoInactiveColor ? base.inactiveColor : inactiveColor,
      labelStyle: labelStyle,
      barStyle: resolvedBarStyle,
      actionStyle: _autoActionStyle ? base.actionStyle : actionStyle,
      dropletSurfaceStyle: _autoDropletSurfaceStyle
          ? (darkGlossy
              ? LiquidDropletSurfaceStyle.darkGlossy
              : base.dropletSurfaceStyle)
          : dropletSurfaceStyle,
      badgeStyle: _autoBadgeStyle ? base.badgeStyle : badgeStyle,
      dropletRefraction: _autoDropletRefraction
          ? (glossy
              ? (dark ? darkGlossyRefraction : lightGlossyRefraction)
              : dropletRefraction)
          : dropletRefraction,
      spring: spring,
      relax: relax,
      foldedShape: foldedShape,
      maxWidth: maxWidth,
      brightness: effectiveBrightness,
      autoActiveColor: false,
      autoInactiveColor: false,
      autoBarStyle: false,
      autoActionStyle: false,
      autoDropletSurfaceStyle: false,
      autoBadgeStyle: false,
      autoDropletRefraction: false,
    );
  }

  /// The selected tab's glyph and label; every other tab's.
  final Color activeColor;
  final Color inactiveColor;

  /// The labels' base style. The bar sets the colour and the weight (semibold
  /// selected, regular otherwise) and keeps the size when one is given —
  /// 12 logical px otherwise.
  final TextStyle labelStyle;

  /// Grouped surface styling for glass, blur, and opaque tiers.
  final LiquidBarStyle barStyle;

  /// Styling for the selected marker behind a separate action.
  final LiquidTabActionStyle actionStyle;

  /// Surface styling for the droplet on every material tier.
  final LiquidDropletSurfaceStyle dropletSurfaceStyle;

  /// Visual styling configuration for badges rendered in the tab bar.
  final LiquidBadgeStyle badgeStyle;

  /// Null follows the ambient Flutter theme; a value pins the palette.
  final Brightness? brightness;

  final bool _autoActiveColor;
  final bool _autoInactiveColor;
  final bool _autoBarStyle;
  final bool _autoActionStyle;
  final bool _autoDropletSurfaceStyle;
  final bool _autoBadgeStyle;
  final bool _autoDropletRefraction;

  /// Optical refraction configuration for the moving selection droplet lens.
  ///
  /// When omitted, the value follows the Normal or Glossy bar preset. Supplying
  /// a value explicitly always keeps that value, including the constructor
  /// defaults.
  final DropletRefractionStyle dropletRefraction;

  /// The one spring the fold and the lens run on (damping ratio .84, about
  /// 400 ms to rest), and how long the lens's stretch takes to ease off once
  /// a scrubbing finger stops.
  final SpringDescription spring;
  final Duration relax;

  /// The default shape of the tab bar capsule when folded on scroll or minimized.
  ///
  /// Defaults to [LiquidFoldedShape.circle]. Can be overridden per-bar via
  /// [LiquidTabBar.foldedShape].
  final LiquidFoldedShape foldedShape;

  /// Optional maximum width of the expanded capsule. Null preserves the
  /// tab-count-based cap.
  final double? maxWidth;

  LiquidTabBarTheme copyWith({
    Color? activeColor,
    Color? inactiveColor,
    TextStyle? labelStyle,
    LiquidBarStyle? barStyle,
    LiquidTabActionStyle? actionStyle,
    LiquidDropletSurfaceStyle? dropletSurfaceStyle,
    LiquidBadgeStyle? badgeStyle,
    DropletRefractionStyle? dropletRefraction,
    SpringDescription? spring,
    Duration? relax,
    LiquidFoldedShape? foldedShape,
    double? maxWidth,
    Brightness? brightness,

    /// Clears the current width cap and restores the tab-count-based width.
    bool clearMaxWidth = false,

    /// Clears the stored brightness pin.
    bool clearBrightness = false,

    /// Restores preset-based refraction resolution for the current Normal/Glossy style.
    bool usePresetDropletRefraction = false,
  }) {
    assert(
      dropletRefraction == null || !usePresetDropletRefraction,
      'Pass either dropletRefraction or usePresetDropletRefraction, not both.',
    );
    return LiquidTabBarTheme._fromFields(
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      labelStyle: labelStyle ?? this.labelStyle,
      barStyle: barStyle ?? this.barStyle,
      actionStyle: actionStyle ?? this.actionStyle,
      dropletSurfaceStyle: dropletSurfaceStyle ?? this.dropletSurfaceStyle,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      dropletRefraction: usePresetDropletRefraction
          ? const DropletRefractionStyle()
          : dropletRefraction ?? this.dropletRefraction,
      spring: spring ?? this.spring,
      relax: relax ?? this.relax,
      foldedShape: foldedShape ?? this.foldedShape,
      maxWidth: clearMaxWidth ? null : maxWidth ?? this.maxWidth,
      brightness: clearBrightness ? null : brightness ?? this.brightness,
      autoActiveColor: activeColor == null && _autoActiveColor,
      autoInactiveColor: inactiveColor == null && _autoInactiveColor,
      autoBarStyle: barStyle == null && _autoBarStyle,
      autoActionStyle: actionStyle == null && _autoActionStyle,
      autoDropletSurfaceStyle:
          dropletSurfaceStyle == null && _autoDropletSurfaceStyle,
      autoBadgeStyle: badgeStyle == null && _autoBadgeStyle,
      autoDropletRefraction: usePresetDropletRefraction ||
          (dropletRefraction == null && _autoDropletRefraction),
    );
  }

  static LiquidTabBarTheme lerp(
    LiquidTabBarTheme a,
    LiquidTabBarTheme b,
    double t,
  ) {
    return LiquidTabBarTheme(
      activeColor: Color.lerp(a.activeColor, b.activeColor, t)!,
      inactiveColor: Color.lerp(a.inactiveColor, b.inactiveColor, t)!,
      labelStyle: TextStyle.lerp(a.labelStyle, b.labelStyle, t)!,
      barStyle: LiquidBarStyle.lerp(a.barStyle, b.barStyle, t),
      actionStyle: LiquidTabActionStyle.lerp(a.actionStyle, b.actionStyle, t),
      dropletSurfaceStyle:
          t < 0.5 ? a.dropletSurfaceStyle : b.dropletSurfaceStyle,
      badgeStyle:
          LiquidBadgeStyle.lerp(a.badgeStyle, b.badgeStyle, t) ?? a.badgeStyle,
      dropletRefraction: DropletRefractionStyle.lerp(
        a.dropletRefraction,
        b.dropletRefraction,
        t,
      ),
      spring: t < 0.5 ? a.spring : b.spring,
      foldedShape: t < 0.5 ? a.foldedShape : b.foldedShape,
      relax: Duration(
        microseconds: ui
            .lerpDouble(a.relax.inMicroseconds, b.relax.inMicroseconds, t)!
            .round(),
      ),
      maxWidth: ui.lerpDouble(a.maxWidth, b.maxWidth, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiquidTabBarTheme &&
        other.activeColor == activeColor &&
        other.inactiveColor == inactiveColor &&
        other.labelStyle == labelStyle &&
        other.barStyle == barStyle &&
        other.actionStyle == actionStyle &&
        other.dropletSurfaceStyle == dropletSurfaceStyle &&
        other.badgeStyle == badgeStyle &&
        other.dropletRefraction == dropletRefraction &&
        other.spring == spring &&
        other.relax == relax &&
        other.foldedShape == foldedShape &&
        other.maxWidth == maxWidth &&
        other.brightness == brightness &&
        other._autoActiveColor == _autoActiveColor &&
        other._autoInactiveColor == _autoInactiveColor &&
        other._autoBarStyle == _autoBarStyle &&
        other._autoActionStyle == _autoActionStyle &&
        other._autoDropletSurfaceStyle == _autoDropletSurfaceStyle &&
        other._autoBadgeStyle == _autoBadgeStyle &&
        other._autoDropletRefraction == _autoDropletRefraction;
  }

  @override
  int get hashCode => Object.hashAll([
        activeColor,
        inactiveColor,
        labelStyle,
        actionStyle,
        dropletSurfaceStyle,
        badgeStyle,
        barStyle,
        spring,
        relax,
        foldedShape,
        maxWidth,
        dropletRefraction,
        brightness,
        _autoActiveColor,
        _autoInactiveColor,
        _autoBarStyle,
        _autoActionStyle,
        _autoDropletSurfaceStyle,
        _autoBadgeStyle,
        _autoDropletRefraction,
      ]);

  @override
  String toString() => 'LiquidTabBarTheme('
      'activeColor: $activeColor, inactiveColor: $inactiveColor, '
      'barStyle: $barStyle, actionStyle: $actionStyle, '
      'dropletSurfaceStyle: $dropletSurfaceStyle, badgeStyle: $badgeStyle, '
      'dropletRefraction: $dropletRefraction, spring: $spring, relax: $relax, '
      'foldedShape: $foldedShape, maxWidth: $maxWidth, brightness: $brightness)';
}
