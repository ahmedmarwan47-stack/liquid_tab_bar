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
