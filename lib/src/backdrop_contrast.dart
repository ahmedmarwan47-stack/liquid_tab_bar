import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Composites white foreground glyphs against the already painted backdrop.
/// This tracks changing pixels without capturing the page or reading it back.
/// Glyphs with their own compositing layers use [fallbackColor] instead.
class BackdropContrast extends SingleChildRenderObjectWidget {
  const BackdropContrast({
    super.key,
    required super.child,
    this.fallbackColor = const Color(0xFF1C1C1E),
  });

  final Color fallbackColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _BackdropContrast(fallbackColor);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderProxyBox renderObject) {
    (renderObject as _BackdropContrast).fallbackColor = fallbackColor;
  }
}

class _BackdropContrast extends RenderProxyBox {
  _BackdropContrast(this._fallbackColor);
  Color _fallbackColor;

  set fallbackColor(Color value) {
    if (_fallbackColor == value) return;
    _fallbackColor = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Child layers cannot be enclosed by a canvas saveLayer. Use the solid
    // theme contrast for SVG filters, repaint boundaries, and animated artwork.
    if (child?.needsCompositing ?? false) {
      layer = context.pushColorFilter(
        offset,
        ColorFilter.mode(_fallbackColor, BlendMode.srcIn),
        super.paint,
        oldLayer: layer is ColorFilterLayer ? layer as ColorFilterLayer : null,
      );
      return;
    }
    layer = null;
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.difference,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// Maps the local painted luminance to a pair of foreground colors.
/// Four small blend passes avoid capturing the screen or reading pixels to Dart.
class BackdropPalette extends SingleChildRenderObjectWidget {
  const BackdropPalette(
      {super.key,
      required super.child,
      required this.light,
      required this.dark,
      required this.fallback});
  final Color light;
  final Color dark;
  final Color fallback;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _BackdropPalette(light, dark, fallback);
  @override
  void updateRenderObject(
      BuildContext context, covariant RenderProxyBox renderObject) {
    (renderObject as _BackdropPalette).update(light, dark, fallback);
  }
}

class _BackdropPalette extends RenderProxyBox {
  _BackdropPalette(this.light, this.dark, this.fallback);
  Color light;
  Color dark;
  Color fallback;
  void update(Color nextLight, Color nextDark, Color nextFallback) {
    if (light == nextLight && dark == nextDark && fallback == nextFallback) {
      return;
    }
    light = nextLight;
    dark = nextDark;
    fallback = nextFallback;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child?.needsCompositing ?? false) {
      layer = context.pushColorFilter(
          offset, ColorFilter.mode(fallback, BlendMode.srcIn), super.paint,
          oldLayer:
              layer is ColorFilterLayer ? layer as ColorFilterLayer : null);
      return;
    }
    layer = null;
    final bounds = offset & size;
    void pass(Color color, BlendMode mode) {
      context.canvas.saveLayer(
          bounds,
          Paint()
            ..blendMode = mode
            ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn));
      super.paint(context, offset);
      context.canvas.restore();
    }

    // First make the destination achromatic while preserving its luminosity.
    // Then map each channel: min + abs(light-dark) * (luma or 1-luma).
    Color rgb(double r, double g, double b) =>
        Color.from(alpha: 1, red: r, green: g, blue: b);
    pass(const Color(0xFFFFFFFF), BlendMode.saturation);
    pass(
        rgb(dark.r > light.r ? 1 : 0, dark.g > light.g ? 1 : 0,
            dark.b > light.b ? 1 : 0),
        BlendMode.exclusion);
    pass(
        rgb((dark.r - light.r).abs(), (dark.g - light.g).abs(),
            (dark.b - light.b).abs()),
        BlendMode.multiply);
    pass(
        rgb(
            dark.r < light.r ? dark.r : light.r,
            dark.g < light.g ? dark.g : light.g,
            dark.b < light.b ? dark.b : light.b),
        BlendMode.plus);
  }
}
