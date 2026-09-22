import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'test_overrides.dart';
import 'surface_press.dart';

/// The glass shader — loaded once at startup, gated at runtime.
///
/// `ImageFilter.shader` only exists on Impeller (iOS, and Android where the
/// device runs it); everywhere else [supported] is false and the bar falls
/// back to its blur tier. Loading never throws into the app: a missing or
/// uncompilable shader simply leaves [ready] false.
///
/// Call [load] before the first frame (`await LiquidGlass.load()` in `main`)
/// or the bar starts on the blur tier and stays there until it rebuilds.
class LiquidGlass {
  LiquidGlass._();

  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? _dropletProgram;
  static Future<void>? _loadingFuture;

  static bool get ready => _program != null;
  static bool get dropletReady => _dropletProgram != null;

  /// The glass tier can render on this device right now.
  static bool get supported =>
      LiquidGlassTestOverrides.forceSupported ||
      (ready && ui.ImageFilter.isShaderFilterSupported);

  /// The droplet glass tier can render on this device right now.
  static bool get dropletSupported =>
      LiquidGlassTestOverrides.forceSupported ||
      (dropletReady && ui.ImageFilter.isShaderFilterSupported);

  static Future<void> load() {
    if (_program != null && _dropletProgram != null) return Future.value();
    return _loadingFuture ??= () async {
      try {
        _program ??= await ui.FragmentProgram.fromAsset(
          'packages/liquid_tab_bar/assets/shaders/nav_glass.frag',
        );
      } catch (_) {
        // Blur tier it is.
      }
      try {
        _dropletProgram ??= await ui.FragmentProgram.fromAsset(
          'packages/liquid_tab_bar/assets/shaders/droplet_glass.frag',
        );
      } catch (_) {
        // Blur tier fallback for droplet
      } finally {
        _loadingFuture = null;
      }
    }();
  }
}

ui.FragmentShader _glassShader() => LiquidGlass._program!.fragmentShader();

ui.FragmentShader _dropletShader() =>
    LiquidGlass._dropletProgram!.fragmentShader();

/// Optical refraction configuration for the moving selection droplet lens.
///
/// Controls the Snell's-law physical glass lens model that refracts underlying
/// icons and labels while the droplet is in motion.
///
/// - At rest: optical refraction strictly fades to 0.0, leaving the droplet's
///   authentic material design (gradient, border, shadow, specular hairline)
///   completely intact without static distortion.
/// - During motion: underlying content is dynamically bent according to these
///   optical parameters.
///
/// To disable optical displacement completely while retaining the authentic
/// droplet visuals, use [DropletRefractionStyle.none] or set [refractionStrength]
/// to `0.0`.
@immutable
class DropletRefractionStyle {
  /// Creates a custom droplet refraction style.
  const DropletRefractionStyle({
    this.thickness = 13.0,
    this.refractiveIndex = 1.50,
    this.baseHeight = 24.0,
    this.dispersion = 0.16,
    this.specularStrength = 0.15,
    this.refractionStrength = 0.60,
  })  : assert(thickness >= 1.0, 'thickness must be >= 1.0'),
        assert(refractiveIndex >= 1.0, 'refractiveIndex must be >= 1.0'),
        assert(baseHeight >= 0.0, 'baseHeight cannot be negative'),
        assert(dispersion >= 0.0, 'dispersion cannot be negative'),
        assert(specularStrength >= 0.0, 'specularStrength cannot be negative'),
        assert(
          refractionStrength >= 0.0,
          'refractionStrength cannot be negative',
        );

  /// Disables optical refraction displacement completely while preserving the
  /// droplet's normal visual appearance (gradient, border, shadow, resting highlight).
  const DropletRefractionStyle.none()
      : thickness = 13.0,
        refractiveIndex = 1.50,
        baseHeight = 18.0,
        dispersion = 0.0,
        specularStrength = 0.15,
        refractionStrength = 0.0;

  /// Subtle optical refraction with gentle boundary displacement.
  ///
  /// Adds a faint color split where the moving bevel crosses contrast edges.
  const DropletRefractionStyle.subtle()
      : thickness = 10.0,
        refractiveIndex = 1.35,
        baseHeight = 12.0,
        dispersion = 0.06,
        specularStrength = 0.10,
        refractionStrength = 0.35;

  /// Medium (default) optical refraction calibrated for the navigation droplet.
  ///
  /// Fine, content-driven color fringes follow the moving bevel, never a
  /// painted rainbow border. The center and resting lens remain undistorted.
  const DropletRefractionStyle.medium()
      : thickness = 13.0,
        refractiveIndex = 1.50,
        baseHeight = 24.0,
        dispersion = 0.16,
        specularStrength = 0.15,
        refractionStrength = 0.60;

  /// Strong optical refraction with pronounced lens curvature and deeper displacement.
  ///
  /// More visible edge dispersion accompanies the deeper moving lens.
  const DropletRefractionStyle.strong()
      : thickness = 16.0,
        refractiveIndex = 1.65,
        baseHeight = 32.0,
        dispersion = 0.24,
        specularStrength = 0.25,
        refractionStrength = 1.00;

  /// Optical bevel thickness (rim width) in logical pixels.
  final double thickness;

  /// Index of refraction for the optical glass model (e.g. 1.50 for standard glass).
  final double refractiveIndex;

  /// Standoff optical depth (base height) in logical pixels for ray projection.
  final double baseHeight;

  /// Chromatic dispersion spread (0.0 = disabled, > 0 splits sampled RGB).
  /// Only affects the moving curved bevel on shader-capable renderers;
  /// uniform backgrounds stay neutral and the resting lens is unchanged.
  final double dispersion;

  /// Specular highlight intensity along the moving refractive boundary rim.
  final double specularStrength;

  /// Master multiplier for optical refraction displacement during motion.
  ///
  /// - `0.0`: completely disables optical refraction (normal visuals only)
  /// - `0.6`: subtle refraction
  /// - `1.0`: default balanced refraction
  /// - `1.6`: strong, more pronounced refraction
  /// - `2.0+`: very strong dramatic refraction
  final double refractionStrength;

  /// Alias for [thickness] for consistency with [GlassStyle.rim].
  double get rim => thickness;

  /// Concise alias for [baseHeight].
  double get depth => baseHeight;

  /// Creates a copy of this style with the given fields replaced.
  DropletRefractionStyle copyWith({
    double? thickness,
    double? refractiveIndex,
    double? baseHeight,
    double? dispersion,
    double? specularStrength,
    double? refractionStrength,
  }) {
    return DropletRefractionStyle(
      thickness: thickness ?? this.thickness,
      refractiveIndex: refractiveIndex ?? this.refractiveIndex,
      baseHeight: baseHeight ?? this.baseHeight,
      dispersion: dispersion ?? this.dispersion,
      specularStrength: specularStrength ?? this.specularStrength,
      refractionStrength: refractionStrength ?? this.refractionStrength,
    );
  }

  /// Linearly interpolates between two [DropletRefractionStyle]s.
  static DropletRefractionStyle lerp(
    DropletRefractionStyle? a,
    DropletRefractionStyle? b,
    double t,
  ) {
    if (a == null && b == null) return const DropletRefractionStyle();
    if (a == null) return b!;
    if (b == null) return a;
    return DropletRefractionStyle(
      thickness: ui.lerpDouble(a.thickness, b.thickness, t)!,
      refractiveIndex: ui.lerpDouble(a.refractiveIndex, b.refractiveIndex, t)!,
      baseHeight: ui.lerpDouble(a.baseHeight, b.baseHeight, t)!,
      dispersion: ui.lerpDouble(a.dispersion, b.dispersion, t)!,
      specularStrength: ui.lerpDouble(
        a.specularStrength,
        b.specularStrength,
        t,
      )!,
      refractionStrength: ui.lerpDouble(
        a.refractionStrength,
        b.refractionStrength,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DropletRefractionStyle &&
        other.thickness == thickness &&
        other.refractiveIndex == refractiveIndex &&
        other.baseHeight == baseHeight &&
        other.dispersion == dispersion &&
        other.specularStrength == specularStrength &&
        other.refractionStrength == refractionStrength;
  }

  @override
  int get hashCode => Object.hash(
        thickness,
        refractiveIndex,
        baseHeight,
        dispersion,
        specularStrength,
        refractionStrength,
      );

  @override
  String toString() {
    return 'DropletRefractionStyle('
        'thickness: ${thickness.toStringAsFixed(1)}, '
        'refractiveIndex: ${refractiveIndex.toStringAsFixed(2)}, '
        'baseHeight: ${baseHeight.toStringAsFixed(1)}, '
        'dispersion: ${dispersion.toStringAsFixed(2)}, '
        'specularStrength: ${specularStrength.toStringAsFixed(2)}, '
        'refractionStrength: ${refractionStrength.toStringAsFixed(2)})';
  }
}

/// One outer-bar glass material — every knob the bar shader exposes, in
/// logical pixels.
class GlassStyle {
  const GlassStyle({
    this.rim = 5.0,
    this.curve = 1.0,
    this.depth = 5.0,
    this.dispersion = 0.08,
    this.blur = 25.0,
    this.saturation = 1.25,
    this.tint = const Color(0x75FFFFFF),
    this.specular = 0.32,
    this.light = const Offset(-0.55, -0.85),
    this.edgeDark = 0.025,
    this.shadow = 0.0,
    this.shadowBlur = 0.0,
    this.shadowOffset = Offset.zero,
  });

  /// The bar: measured against the iOS floating glass tab bar — a
  /// pristine, crystal-clear frost with lensing confined to a thin rim, lit from the
  /// top-left (the lit edge is the brighter one there), with soft downward ambient shadow.
  static const frosted = GlassStyle(
    rim: 5,
    curve: 1.0,
    depth: 5,
    dispersion: 0.08,
    blur: 25,
    saturation: 1.25,
    tint: Color(0x75FFFFFF),
    specular: 0.32,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.025,
    shadow: 0.08,
    shadowBlur: 20,
    shadowOffset: Offset(0, 6),
  );

  /// Classic Apple-style frosted glass with balanced diffusion, gentle
  /// rim specular, and subtle chromatic lensing.
  /// Vivid chromatic fringing with an amplified specular highlight and
  /// saturated light pass-through.
  ///
  /// Ideal for colorful, high-contrast wallpapers and vibrant photo feeds.
  static const prismaticCaustics = GlassStyle(
    rim: 5,
    curve: 1.0,
    depth: 8,
    dispersion: 0.32,
    blur: 15,
    saturation: 1.60,
    tint: Color(0x75FFFFFF),
    specular: 0.65,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.025,
    shadow: 0.08,
    shadowBlur: 20,
    shadowOffset: Offset(0, 6),
  );

  /// Crystal-clear zero-blur glass emphasizing razor-sharp refraction,
  /// pronounced rim highlights, and edge dispersion without obscuring
  /// underlying content.
  static const clearCrystal = GlassStyle(
    rim: 5,
    curve: 1.0,
    depth: 6,
    dispersion: 0.15,
    blur: 0,
    saturation: 1.10,
    tint: Color(0x75FFFFFF),
    specular: 0.50,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.025,
    shadow: 0.08,
    shadowBlur: 20,
    shadowOffset: Offset(0, 6),
  );

  /// Heavy optical slab with deep refraction displacement, high frost diffusion,
  /// and pronounced light absorption.
  static const deepRefraction = GlassStyle(
    rim: 5,
    curve: 1.0,
    depth: 14,
    dispersion: 0.20,
    blur: 40,
    saturation: 1.40,
    tint: Color(0x75FFFFFF),
    specular: 0.40,
    light: Offset(-0.55, -0.85),
    edgeDark: 0.025,
    shadow: 0.08,
    shadowBlur: 20,
    shadowOffset: Offset(0, 6),
  );

  /// Width of the lensing rim.
  final double rim;

  /// How steeply the rim's surface tilts.
  final double curve;

  /// Refraction displacement at the rim.
  final double depth;

  /// Chromatic dispersion — how far red and blue are bent apart at the rim.
  /// This is the soap-bubble fringe; the bar keeps it near zero, the lens
  /// opens it with its speed.
  final double dispersion;

  /// Frost radius; 0 is clear glass.
  final double blur;

  /// Saturation multiplier on what shows through.
  final double saturation;

  /// Straight-alpha tint laid over the sampled page.
  final Color tint;

  /// Rim light strength.
  final double specular;

  /// Light direction, in the surface's own xy.
  final Offset light;

  /// Rim shade on the side facing away from the light.
  final double edgeDark;

  /// Drop shadow alpha; 0 for none.
  final double shadow;
  final double shadowBlur;
  final Offset shadowOffset;

  GlassStyle copyWith({
    double? rim,
    double? curve,
    double? depth,
    double? dispersion,
    double? blur,
    double? saturation,
    Color? tint,
    double? specular,
    Offset? light,
    double? edgeDark,
    double? shadow,
    double? shadowBlur,
    Offset? shadowOffset,
  }) {
    final r = rim ?? this.rim;
    final c = curve ?? this.curve;
    final dp = depth ?? this.depth;
    final d = dispersion ?? this.dispersion;
    final b = blur ?? this.blur;
    final sat = saturation ?? this.saturation;
    final t = tint ?? this.tint;
    final s = specular ?? this.specular;
    final l = light ?? this.light;
    final ed = edgeDark ?? this.edgeDark;
    final sh = shadow ?? this.shadow;
    final sb = shadowBlur ?? this.shadowBlur;
    final so = shadowOffset ?? this.shadowOffset;

    if (r == this.rim &&
        c == this.curve &&
        dp == this.depth &&
        d == this.dispersion &&
        b == this.blur &&
        sat == this.saturation &&
        t == this.tint &&
        s == this.specular &&
        l == this.light &&
        ed == this.edgeDark &&
        sh == this.shadow &&
        sb == this.shadowBlur &&
        so == this.shadowOffset) {
      return this;
    }

    return GlassStyle(
      rim: r,
      curve: c,
      depth: dp,
      dispersion: d,
      blur: b,
      saturation: sat,
      tint: t,
      specular: s,
      light: l,
      edgeDark: ed,
      shadow: sh,
      shadowBlur: sb,
      shadowOffset: so,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GlassStyle &&
        other.rim == rim &&
        other.curve == curve &&
        other.depth == depth &&
        other.dispersion == dispersion &&
        other.blur == blur &&
        other.saturation == saturation &&
        other.tint == tint &&
        other.specular == specular &&
        other.light == light &&
        other.edgeDark == edgeDark &&
        other.shadow == shadow &&
        other.shadowBlur == shadowBlur &&
        other.shadowOffset == shadowOffset;
  }

  @override
  int get hashCode => Object.hash(
        rim,
        curve,
        depth,
        dispersion,
        blur,
        saturation,
        tint,
        specular,
        light,
        edgeDark,
        shadow,
        shadowBlur,
        shadowOffset,
      );
}

/// A capsule of [style] glass, [size] big with [radius] corners, rendered as a
/// backdrop filter over whatever is painted beneath it. The widget is [pad]
/// larger than the capsule on every side — that is the drop shadow's room;
/// outside the capsule the shader hands the page back untouched.
///
/// The shader is told where the capsule is in *screen* pixels, measured at
/// paint time, because the engine gives a backdrop shader the whole screen as
/// its input rather than the widget's own clip (see the comment atop
/// `nav_glass.frag`). That breaks inside a save layer whose bounds are not
/// the screen (an `Opacity` or `ShaderMask` ancestor) — never wrap it in one.
/// Only build it when [LiquidGlass.supported] is true.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.size,
    required this.radius,
    required this.pad,
    required this.style,
    this.press = const SurfacePress(),
  });

  final Size size;
  final double radius;
  final double pad;
  final GlassStyle style;
  final SurfacePress press;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  late final ui.FragmentShader? _shader =
      LiquidGlass.ready ? _glassShader() : null;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) {
      return SizedBox(
        width: widget.size.width + 2 * widget.pad,
        height: widget.size.height + 2 * widget.pad,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius + widget.pad),
          child: const SizedBox.expand(),
        ),
      );
    }
    // A BackdropFilter filters the whole ancestor clip, not just its child:
    // the ClipRRect confines it to this padded, rounded box.
    return SizedBox(
      width: widget.size.width + 2 * widget.pad,
      height: widget.size.height + 2 * widget.pad,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius + widget.pad),
        child: _GlassFilter(
          shader: _shader,
          style: widget.style,
          press: widget.press,
          radius: widget.radius,
          pad: widget.pad,
          dpr: MediaQuery.devicePixelRatioOf(context),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GlassFilter extends SingleChildRenderObjectWidget {
  const _GlassFilter({
    required this.shader,
    required this.style,
    required this.radius,
    required this.pad,
    required this.dpr,
    required this.press,
    super.child,
  });

  final ui.FragmentShader shader;
  final GlassStyle style;
  final SurfacePress press;
  final double radius;
  final double pad;
  final double dpr;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassFilter(shader, style, radius, pad, dpr, press);

  @override
  void updateRenderObject(BuildContext context, _RenderGlassFilter r) {
    r
      ..press = press
      ..style = style
      ..radius = radius
      ..pad = pad
      ..dpr = dpr;
  }
}

/// A shader backdrop whose filter is rebuilt during scene composition so
/// retained ancestor translations also update the capsule's screen rect.
class _RenderGlassFilter extends RenderProxyBox {
  _RenderGlassFilter(
    this._shader,
    this._style,
    this._radius,
    this._pad,
    this._dpr,
    this._press,
  );

  final ui.FragmentShader _shader;

  SurfacePress _press;
  set press(SurfacePress value) {
    if (value == _press) return;
    _press = value;
    markNeedsPaint();
  }

  GlassStyle _style;
  set style(GlassStyle v) {
    if (identical(v, _style)) return;
    _style = v;
    markNeedsPaint();
  }

  double _radius;
  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  double _pad;
  set pad(double v) {
    if (v == _pad) return;
    _pad = v;
    markNeedsPaint();
  }

  double _dpr;
  set dpr(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = (this.layer as _GlassBackdropLayer?) ??
        _GlassBackdropLayer(_createFilter);
    this.layer = layer;
    context.pushLayer(layer, super.paint, offset);
  }

  ui.ImageFilter _createFilter() {
    final origin = localToGlobal(Offset.zero);
    final d = _dpr;
    final s = _style;
    // Indices 0-1 (the texture size) are the engine's to set.
    _shader
      ..setFloat(2, (origin.dx + _pad) * d)
      ..setFloat(3, (origin.dy + _pad) * d)
      ..setFloat(4, (size.width - 2 * _pad) * d)
      ..setFloat(5, (size.height - 2 * _pad) * d)
      ..setFloat(6, _radius * d)
      ..setFloat(7, s.rim * d)
      ..setFloat(8, s.curve)
      ..setFloat(9, s.depth * d)
      ..setFloat(10, s.dispersion)
      ..setFloat(11, s.blur * d)
      ..setFloat(12, s.saturation)
      ..setFloat(13, s.tint.r)
      ..setFloat(14, s.tint.g)
      ..setFloat(15, s.tint.b)
      ..setFloat(16, s.tint.a)
      ..setFloat(17, s.specular)
      ..setFloat(18, s.light.dx)
      ..setFloat(19, s.light.dy)
      ..setFloat(20, s.edgeDark)
      ..setFloat(21, s.shadow)
      ..setFloat(22, s.shadowBlur * d)
      ..setFloat(23, s.shadowOffset.dx * d)
      ..setFloat(24, s.shadowOffset.dy * d)
      ..setFloat(25, (origin.dx + _pad + _press.center) * d)
      ..setFloat(26, _press.reach * d)
      ..setFloat(27, _press.depth * d)
      ..setFloat(28, _press.amount);
    // ImageFilter snapshots the shader uniforms when its native filter is
    // created. Recreate it after updating uniforms so geometry stays current.
    return ui.ImageFilter.shader(_shader);
  }
}

class _GlassBackdropLayer extends ContainerLayer {
  _GlassBackdropLayer(this.createFilter);

  final ui.ImageFilter Function() createFilter;

  // rendering backends, and arbitrary scaling. Current framebuffer coverage
  // is iOS/Metal Impeller, LTR, circular folding and route translation.
  // Refreshing uniforms here does not encode arbitrary ancestor transforms.
  // Ancestor translations can change the global shader origin without
  // repainting this render object. Refresh it when composing each scene.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    engineLayer = builder.pushBackdropFilter(
      createFilter(),
      blendMode: BlendMode.srcOver,
      oldLayer: engineLayer as ui.BackdropFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }
}

/// A moving liquid optical glass lens for the navigation bar droplet.
/// Runs as a backdrop image filter strictly confined to the droplet's bounds,
/// refracting the already-painted icons, labels, and background underneath it.
class DropletGlassSurface extends StatefulWidget {
  const DropletGlassSurface({
    super.key,
    required this.size,
    required this.radius,
    required this.style,
    this.refractionStyle,
    this.motionStrength = 1.0,
    this.heldStrength = 0.0,
  });

  final Size size;
  final double radius;
  final GlassStyle style;
  final DropletRefractionStyle? refractionStyle;
  final double motionStrength;
  final double heldStrength;

  @override
  State<DropletGlassSurface> createState() => _DropletGlassSurfaceState();
}

class _DropletGlassSurfaceState extends State<DropletGlassSurface> {
  late final ui.FragmentShader? _shader =
      LiquidGlass.dropletReady ? _dropletShader() : null;

  DropletRefractionStyle get _effectiveRefraction =>
      widget.refractionStyle ??
      DropletRefractionStyle(
        thickness: widget.style.rim,
        refractiveIndex: 1.45,
        baseHeight: 8,
        dispersion: widget.style.dispersion,
        specularStrength: widget.style.specular,
      );

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) {
      return SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: const SizedBox.expand(),
        ),
      );
    }
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: _DropletGlassFilter(
          shader: _shader,
          style: widget.style,
          refractionStyle: _effectiveRefraction,
          radius: widget.radius,
          motionStrength: widget.motionStrength,
          heldStrength: widget.heldStrength,
          dpr: MediaQuery.devicePixelRatioOf(context),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DropletGlassFilter extends SingleChildRenderObjectWidget {
  const _DropletGlassFilter({
    required this.shader,
    required this.style,
    required this.refractionStyle,
    required this.radius,
    required this.dpr,
    this.motionStrength = 1.0,
    this.heldStrength = 0.0,
    super.child,
  });

  final ui.FragmentShader shader;
  final GlassStyle style;
  final DropletRefractionStyle refractionStyle;
  final double radius;
  final double dpr;
  final double motionStrength;
  final double heldStrength;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDropletGlassFilter(
        shader,
        style,
        refractionStyle,
        radius,
        dpr,
        motionStrength,
        heldStrength,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderDropletGlassFilter r) {
    r
      ..style = style
      ..refractionStyle = refractionStyle
      ..radius = radius
      ..dpr = dpr
      ..motionStrength = motionStrength
      ..heldStrength = heldStrength;
  }
}

class _RenderDropletGlassFilter extends RenderProxyBox {
  _RenderDropletGlassFilter(
    this._shader,
    this._style,
    this._refractionStyle,
    this._radius,
    this._dpr,
    this._motionStrength,
    this._heldStrength,
  );

  final ui.FragmentShader _shader;

  GlassStyle _style;
  set style(GlassStyle v) {
    if (identical(v, _style)) return;
    _style = v;
    markNeedsPaint();
  }

  DropletRefractionStyle _refractionStyle;
  set refractionStyle(DropletRefractionStyle v) {
    if (v == _refractionStyle) return;
    _refractionStyle = v;
    markNeedsPaint();
  }

  double _radius;
  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  double _dpr;
  set dpr(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  double _heldStrength;
  set heldStrength(double value) {
    if (value == _heldStrength) return;
    _heldStrength = value;
    markNeedsPaint();
  }

  double _motionStrength;
  set motionStrength(double v) {
    if (v == _motionStrength) return;
    _motionStrength = v;
    markNeedsPaint();
  }

  double get motionStrength => _motionStrength;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = (this.layer as _GlassBackdropLayer?) ??
        _GlassBackdropLayer(_createFilter);
    this.layer = layer;
    context.pushLayer(layer, super.paint, offset);
  }

  ui.ImageFilter _createFilter() {
    final origin = localToGlobal(Offset.zero);
    final d = _dpr;
    final s = _style;
    final r = _refractionStyle;
    // Uniform contract for droplet_glass.frag:
    // 0-1:   uSize (engine-set)
    // 2-5:   uRect (origin.x, origin.y, width, height in px)
    // 6:     uRadius (px)
    // 7:     uThickness (px)
    // 8:     uRefractiveIndex
    // 9:     uBaseHeight (px)
    // 10:    uDispersion
    // 11:    uSpecular
    // 12-13: uLight (dx, dy)
    // 14-17: uTint (r, g, b, a)
    // 18:    uMotionStrength
    // 19:    uRefractionStrength
    // 20:    uHeldStrength
    _shader
      ..setFloat(2, origin.dx * d)
      ..setFloat(3, origin.dy * d)
      ..setFloat(4, size.width * d)
      ..setFloat(5, size.height * d)
      ..setFloat(6, _radius * d)
      ..setFloat(7, r.thickness * d)
      ..setFloat(8, r.refractiveIndex)
      ..setFloat(9, r.baseHeight * d)
      ..setFloat(10, r.dispersion)
      ..setFloat(11, r.specularStrength)
      ..setFloat(12, s.light.dx)
      ..setFloat(13, s.light.dy)
      ..setFloat(14, s.tint.r)
      ..setFloat(15, s.tint.g)
      ..setFloat(16, s.tint.b)
      ..setFloat(17, s.tint.a)
      ..setFloat(18, _motionStrength)
      ..setFloat(19, r.refractionStrength)
      ..setFloat(20, _heldStrength);
    return ui.ImageFilter.shader(_shader);
  }
}

/// The shader's lighting, painted — for the blur tier, which has the frost
/// and the tint but no shader to light the rim. Nothing here refracts (that
/// needs the backdrop, which only Impeller hands a shader); what it gives back
/// is the rest of what makes the capsule read as glass: the hairline of light
/// along the lit edge, the soft band of rim light inside it, the whisper of
/// shade on the far side. Numbers come from the same [GlassStyle] the shader
/// uses, so the two tiers agree on where the light is and how strong.
///
/// Paint it INSIDE the capsule's clip, over the frost and the sheen.
class GlassLightPainter extends CustomPainter {
  GlassLightPainter({
    required this.style,
    required this.radius,
    this.isDark = false,
    this.press = const SurfacePress(),
  });

  final SurfacePress press;
  final GlassStyle style;
  final double radius;

  final bool isDark;

  final Paint _bandPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _threadWarmPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _threadCoolPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  void _drawOutline(Canvas canvas, RRect outline, Paint paint) {
    if (press.depth <= 0) {
      canvas.drawRRect(outline, paint);
    } else {
      canvas.drawPath(press.contour(outline.outerRect), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(radius);
    // The gradient runs from the lit edge to the far one, along the light.
    final l = style.light;
    final len = l.distance == 0 ? 1.0 : l.distance;
    final begin = Alignment(l.dx / len, l.dy / len);
    final end = Alignment(-l.dx / len, -l.dy / len);
    final lit = (style.specular * 1.2).clamp(0.0, 1.0);
    final dark = (style.edgeDark * 1.5).clamp(0.0, 1.0);

    // The rim band: subtle internal bevel glow, strongest where
    // the edge faces the light and gently fading.
    final rimWidth = style.rim.clamp(2.0, 5.0);
    _bandPaint
      ..strokeWidth = rimWidth
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (rimWidth * 0.4).clamp(1.0, 2.5),
      )
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: lit * 0.16),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.45],
      ).createShader(rect);
    _drawOutline(
      canvas,
      RRect.fromRectAndRadius(rect.deflate(rimWidth / 2), r),
      _bandPaint,
    );

    // The hairline: one pixel of light along the lit edge, a hint of shade
    // along the far one for a razor-crisp chamfer.
    final awayColor = isDark
        ? const Color(0xFFFFFFFF)
            .withValues(alpha: (dark * 0.35).clamp(0.06, 0.20))
        : const Color(0xFF000000).withValues(alpha: dark * 0.4);

    _linePaint.shader = LinearGradient(
      begin: begin,
      end: end,
      colors: [
        const Color(0xFFFFFFFF).withValues(alpha: lit * 0.70),
        const Color(0xFFFFFFFF).withValues(alpha: lit * 0.25),
        const Color(0x00FFFFFF),
        awayColor,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ).createShader(rect);
    _drawOutline(
        canvas, RRect.fromRectAndRadius(rect.deflate(0.5), r), _linePaint);

    // Dispersing — a finger dragging the lens — the hairline splits into a
    // warm thread on the edge and a cool one just inside it: this tier's
    // share of the fringe the shader shows, since it cannot bend the page.
    // Nothing at the default outer-bar dispersion, which is below the
    // threshold. The colors are renderer calibration rather than public API.
    final k = ((style.dispersion - 0.2) / 0.6).clamp(0.0, 1.0);
    if (k > 0) {
      const fringeWarm = Color(0xFFFFB347);
      final fringeCool =
          isDark ? const Color(0xFF64D2FF) : const Color(0xFF4DA3FF);
      _threadWarmPaint.shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          fringeWarm.withValues(alpha: lit * k),
          fringeWarm.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(rect);
      _drawOutline(
        canvas,
        RRect.fromRectAndRadius(rect.deflate(0.5), r),
        _threadWarmPaint,
      );
      final inset = 0.5 + 1.5 * k;
      _threadCoolPaint.shader = LinearGradient(
        begin: begin,
        end: end,
        colors: [
          fringeCool.withValues(alpha: lit * 0.8 * k),
          fringeCool.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(rect);
      _drawOutline(
        canvas,
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(radius - inset),
        ),
        _threadCoolPaint,
      );
    }
  }

  @override
  bool shouldRepaint(GlassLightPainter old) =>
      old.style != style ||
      old.radius != radius ||
      old.isDark != isDark ||
      old.press != press;
}

/// Reuses the neutral rim shader while the droplet geometry is unchanged.
class DropletHighlightCache {
  Rect? rect;
  bool? isDark;
  double? fade;
  double? motion;
  Shader? shader;
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75;
}

/// Neutral edge reflections for the moving selection capsule.
///
/// The center stays transparent, so neither the selected glyph nor the backdrop
/// receives an artificial color wash. Optical dispersion, when explicitly
/// requested, belongs to the refraction shader rather than painted RGB stripes.
class LiquidDropletHighlightPainter extends CustomPainter {
  LiquidDropletHighlightPainter({
    required this.radius,
    required this.motion,
    required this.isDark,
    required this.fade,
    required this.cache,
  });

  final double radius;
  final double motion;
  final bool isDark;
  final double fade;
  final DropletHighlightCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || fade <= 0) return;
    final rect = Offset.zero & size;
    final movement = motion.clamp(0.0, 1.0);
    final opacity = fade.clamp(0.0, 1.0);
    if (cache.rect != rect ||
        cache.isDark != isDark ||
        cache.fade != opacity ||
        cache.motion != movement ||
        cache.shader == null) {
      // Bright opposing edges describe a curved surface. The quiet center and
      // short highlight keep the resting selection from looking outlined.
      final top = (isDark ? 0.10 : 0.28) + 0.22 * movement;
      final bottom = (isDark ? 0.04 : 0.12) + 0.12 * movement;
      cache.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 255, 255, top * opacity),
          Color.fromRGBO(255, 255, 255, top * 0.25 * opacity),
          const Color(0x00FFFFFF),
          Color.fromRGBO(255, 255, 255, bottom * opacity),
        ],
        stops: const [0.0, 0.28, 0.65, 1.0],
      ).createShader(rect);
      cache.rect = rect;
      cache.isDark = isDark;
      cache.fade = opacity;
      cache.motion = movement;
    }
    cache.paint.shader = cache.shader;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(0.5),
      cache.paint,
    );
  }

  @override
  bool shouldRepaint(LiquidDropletHighlightPainter old) =>
      old.radius != radius ||
      old.motion != motion ||
      old.isDark != isDark ||
      old.fade != fade;
}
