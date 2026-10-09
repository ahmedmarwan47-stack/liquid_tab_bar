# Native preset audit

Native is a single preset: `LiquidBarStyle.native()`. The showcase has one Native
choice and independent White, Charcoal, Artwork and Split backdrops. The glass
and ordinary inactive icons respond to the rendered backdrop; selection keeps
its accent color. The selection fill darkens light glass and brightens dark glass.
Custom full-color artwork opts out of recoloring. Composited glyphs use a theme
contrast fallback.

## Checks

- Package suite: 387 passed, one skipped. Example suite: eight passed.
- `flutter analyze`: no issues.
- Pixel tests cover adaptive inactive glyphs and selected fill/accent on light and
  dark backdrops; accessibility uses the opaque tier.
- 25 mounting cycles: no idle glyph rebuilds, leftover navigation listeners or
  animation tickers.
- Ten search cycles: typing, dismissal, 280-pixel keyboard inset and disposal
  during animation; focus/text/controller listeners are released.
- Search overlay link cleanup clears its debug render owner. Flutter still
  caches its last text input connection and can retain one disposed bar and five
  contrast widgets through EditableText semantics; this is bounded, not zero.
  No glass shader states were retained. A regression test checks
  that disposed overlay links clear their leader size.
- Shader states dispose their shader instances. Blur filters use a bounded
  24-entry cache. Backdrop contrast uses painting, with no screen capture or
  recurring Dart timer.
- Standalone auto material arms the shared frame governor; explicitly supplied
  controllers retain app ownership. Existing governor tests cover degradation
  to blur after sustained slow frames. Unsupported shaders also use blur.

## Limits

Simulator debug frame timings are diagnostics, not a physical low-end-device
benchmark. A real weak device is needed to establish sustained FPS, GPU/thermal
behavior and OS process memory. Native keyboard focus and typing are exercised
on the simulator; keyboard geometry is additionally checked with injected
insets because the integration environment may report no software-keyboard
inset. These checks do not establish zero leaks for every application or device.

## Simulator run

20 mount/dispose cycles, 60 tab transitions and four search cycles: 910 frames;
raster median 4.856 ms, p95 6.642 ms (debug simulator). Software keyboard inset
was zero in this run. The repeated audit passed: retention stayed at one disposed bar and five
contrast widgets at cycles 5, 10, 15 and 20; zero glass shader states at all
checkpoints.
