## 2.1.0

- Add optional `LiquidNativeColors(activeLight, activeDark, inactive)` for
  selected foreground colors driven by local glass luminosity.

- Keep Native luminous in light mode over dark artwork, with a charcoal base in
  dark mode and matching blur fallback; backdrop colors still show through.
- Present Native as one adaptive preset and keep its default selected accent blue
  across ambient and pinned dark themes, preserving explicit accent overrides.
- Arm the shared governor for standalone auto-material bars while preserving
  explicit-controller ownership and scaffold governor inheritance.

- Preserve exact rounded caps in the blur press contour rather than sampling
  them as a polygon.
- Make Glossy clearer with lower frost and tint while preserving its bevel.
- Add `LiquidBarStyle.native()` with backdrop-responsive shader tint and
  contrasting unselected glyphs, retaining accent colors and solid accessibility
  surfaces. Add Native to the style comparison example.

- Match the default bar glass to the Yalla Manhwa clarity settings: blur 5.4,
  depth 20, dispersion 0.12, and 64% tint opacity, retaining the existing rim.

- Default Search to contextual text clearing plus a directional dismissal
  chevron on the existing glass circle. Keep `LiquidSearchControls.legacy` for
  the earlier combined close control; `clearOnClose` still defaults to false.
- Preserve focus on clear, observe external controller edits, and cancel stale
  keyboard-aware dismissal requests when Search is reopened.
- Default `LiquidTabBarScaffold` to `LiquidAutoFoldPolicy.smart()`; use
  `direct()` to retain legacy depth-zero behavior. `custom(predicate)` remains
  available for custom source selection.
- Detect a unique vertical scroll source on settled full-width horizontal
  PageView/TabBarView pages through up to four enclosing pagers, rejecting
  ambiguous and unsupported layouts with a shared bounded discovery budget.
- Reset scroll accumulation on source changes, reject stale page flings, and
  deduplicate manual/automatic forwarding without changing fold animations.
- Import `@internal` explicitly from the direct `meta` dependency for Flutter
  3.29 compatibility.

## 2.0.0

### Breaking: one bar, not two

`1.2.0` shipped two bars side by side — the original, whose selection lens was
a pane of glass that a press could balloon past the capsule (**the grab**), and
the deformable **droplet**. This release keeps only the droplet.

If you are on `1.2.0`:

- `package:liquid_tab_bar/droplet.dart` is gone. Its bar is now the one and
  only export of `package:liquid_tab_bar/liquid_tab_bar.dart`, so drop the
  `droplet.dart` import (and any prefix) and keep the default one.
- `LiquidTabBar` from the default import is **a different widget** with a
  different theme. Styling moves to `LiquidBarStyle`,
  `LiquidDropletSurfaceStyle`, `DropletRefractionStyle`,
  `LiquidTabActionStyle` and `LiquidBadgeStyle`.
- **The grab is gone**, and with it `LiquidTabBarTheme.pressLens` and
  `GlassStyle.zoom`. A press deforms the droplet instead.
- `LiquidTabItem`'s unnamed constructor is gone; use `LiquidTabItem.icon`.
- `forceOpaque` is gone; pass `material: LiquidTabBarMaterial.opaque`.
- `foldOnScroll` is gone; use `shrinkOnScroll`.

**Staying on the original bar is a supported choice**: `1.2.0` carries both and
remains on pub.dev. Pin `liquid_tab_bar: 1.2.0` if you want the grab.

- Cleaned up the pre-release public API: removed ineffective search options
  (`showClearButton`, `animationDuration`), the duplicate search marker
  (`LiquidTabAction.isSearch`), duplicate droplet refraction aliases, and the
  global debug warning switch. See `doc/api_cleanup_migration.md` for source
  migrations.
- Added `LiquidDropletShadow` with only the supported droplet shadow fields,
  made explicit default refraction styles remain explicit, enabled requested
  tab icon sizes above the default slot, and added nullable theme reset options.
- Corrected API documentation and debug output without changing calibrated
  Normal, Glossy, Light, or Dark rendering defaults.
- Brightened Light Glossy with a wider polished bevel and clearer frost while
  preserving Dark Glossy. Increased Medium/Strong droplet optical depth and
  spectral separation, then narrowed the color fringe for a more natural lens.
- Added opt-in `LiquidBarStyle.glossy(brightness: ...)` with a polished neutral
  bevel, clearer backdrop colors, and coordinated shader/blur palettes; exposed
  it in the styling demo without changing the default surfaces.
- Enabled subtle motion-only, content-sampled RGB dispersion in the droplet
  presets. Color splits follow the curved bevel over icons and labels, leaving
  flat centers and resting lenses unchanged; `dispersion: 0` disables the split.
- Updated light and dark surfaces with translucent glass, neutral gray selection,
  and subtle edge reflections. Removed the droplet's painted rainbow rim and
  aligned default shader/blur tint palettes across iOS and Android.
- Made the deformable droplet bar the sole public API and consolidated usage
  under `package:liquid_tab_bar/liquid_tab_bar.dart`.
- Restored bounded liquid swelling, travel deformation, current-droplet hit
  testing, destination capture, redirectable travel, and deferred final
  selection commits.
- Added stale-selection protection so scrubbing and rapid retargeting produce
  only one final `onSelected` callback.
- Added custom SVG/widget icon examples and documented the current presets,
  light/dark themes, material modes, and folded shapes.
- Fixed the example SVG assets so the custom-icons demo renders correctly.

## 1.2.0

**A second bar.** The package now ships two, side by side, and nothing about
the first one changed — this release only adds.

```dart
import 'package:liquid_tab_bar/liquid_tab_bar.dart';  // the default bar
import 'package:liquid_tab_bar/droplet.dart';         // the droplet variant
```

### The droplet variant — `package:liquid_tab_bar/droplet.dart`

Contributed by **Mohammed Hafiz**
([@MohammedHafiz27](https://github.com/MohammedHafiz27)) in
[#5](https://github.com/ahmedmarwan47-stack/orderbase_delivery_app/pull/5).

Where the default bar makes its selection lens a pane of glass in its own
right — so a press can balloon it past the capsule and magnify what it holds —
the droplet keeps the lens a contained pill and refracts the icons and labels
*behind* it through a shader of its own, only while it moves. Two different
answers to the same question; neither is the other's successor, which is why
they now sit next to each other rather than one replacing the other.

It brings, on its side of the package:

- `LiquidTabBarScaffold` — sets `extendBody: true`, reserves bottom scroll
  padding, and observes primary vertical scrolling for the fold with no
  `NotificationListener` of your own. `LiquidScrollPadding`,
  `SliverLiquidScrollPadding` and `LiquidTabBar.reservedPadding(context)`
  cover the layouts it does not.
- An expandable search field (`LiquidTabAction.search`) that morphs the bar
  edge to edge and anchors above the keyboard, with `openSearch()` /
  `closeSearch()` and Android back handling.
- Separate action buttons, placed `together` or `split`.
- Badges: unread dots, count pills that fold to `99+`, text pills and custom
  widgets — refracted by the lens as it crosses them.
- `droplet_glass.frag`, the dedicated refraction shader.
- Style objects: `LiquidBarStyle`, `LiquidDropletSurfaceStyle`,
  `DropletRefractionStyle`, `LiquidTabActionStyle`, `LiquidBadgeStyle`.
- `LiquidTabBarTheme.dark()` / `.adaptive(context)`, `GlassStyle` presets
  (`frosted`, `prismaticCaustics`, `clearCrystal`, `deepRefraction`),
  `LiquidFoldedShape.circle` / `.oval`, and `LiquidGovernorConfig`.
- Accessibility semantics across tabs, badges, search and the folded state.

The two libraries deliberately share type names (`LiquidTabBar`,
`LiquidTabBarTheme`, `LiquidTabItem`, `LiquidTabBarController`). Import one,
or prefix the other:

```dart
import 'package:liquid_tab_bar/droplet.dart' as droplet;
```

### Fixed, in both bars

- **Android Impeller/OpenGLES rendered the glass mirrored.** The backdrop tap
  flipped Y under `IMPELLER_TARGET_OPENGLES`, but Flutter already hands the
  texture in `FlutterFragCoord`'s orientation, so the flip sampled the screen
  upside down. Found by Mohammed on physical Android hardware; removed from
  every shader in the package.

### Fixed, in the droplet variant

- The glass tier is gated on `LiquidGlass.supported` rather than `.ready`, so
  Skia and OpenGL backends fall back to blur instead of rendering black.
- The frost samples four rings instead of three, clearing the ring banding the
  old spacing showed on high-contrast pages.
- Split placement no longer centres the capsule or overlaps the tabs, LTR
  or RTL.
- The frame governor degrades at its threshold rather than a frame later, and
  `resetGovernor()` truly zeroes its counters.
- The frost filter cache is a bounded 24-entry LRU with quantized keys, and
  the shader `ImageFilter` is cached per render object.
- Search keeps one persistent input, a stable reported height and a staged
  close; the action circle and the search pill share a visual centre.
- Multi-touch no longer lets a second finger jump the scrub.

### Note on numbering

The contribution branch carried `0.3.0`, which would have landed underneath
the `1.0.1` on pub.dev. Because the default bar's API is untouched and the
droplet arrives as a new library beside it, this is a **minor** bump, not the
breaking one a replacement would have been.

## 1.1.0

The grab: pressing the bar now balloons the lens past the capsule — 24pt
taller, escaping the bar's top and bottom edge evenly, a tenth wider — while the glass **magnifies** the tab
it holds (a new `zoom` knob on `GlassStyle`, ×1.18 grabbed, with the channels
zooming slightly apart so the magnified glyph fringes at its own edges) and
the dispersion opens to 0.85 with the rim light brightened under it. All of
it rides one press spring, up on touch-down and home on release, replacing
the old instant 6% swell. The lens moved out of the bar's clip to make the
overflow possible; at rest and while folding it still sizes itself inside
the bar, so nothing else changed.

Off switch: `LiquidTabBarTheme(pressLens: false)` restores the old press
exactly. The blur tier keeps the swell and the fringe threads but cannot
magnify (no shader); `zoom: 1` leaves the shader's output bit-identical to
before.

## 1.0.1

The selection lens survives a fold and unfold. Three defects in one cycle of
the bar collapsing to its pill and opening again:

- **The lens parked by LTR index in an RTL app.** Its slot was seeded from
  `initState`, where the widget cannot read `Directionality`. It resolves in
  `didChangeDependencies` now — once, so a later theme or text-scale change
  never drags the lens off wherever the user last put it.
- **On unfold the lens stayed wherever it had drifted to.** `didUpdateWidget`
  never fires on the way back open, because `selectedIndex` did not change, so
  nothing re-targeted it. It re-springs to the selected tab now, snapping
  exactly when the gap is already sub-pixel.
- **Mid-fold the lens could outgrow the shrinking bar and have its glass edge
  cut by the clip.** Its width lerps toward a pill-safe width and is clamped to
  what the current bar rect — and the lens's own position in it — can hold. The
  glass surface is also skipped entirely below 2% fade, where it was invisible
  to the eye but still painting a backdrop shader inside the fold clip, which
  cut a visible seam at the boundary.

No API changes: `LiquidTabBar`, `LiquidTabItem`, `LiquidTabBarTheme`,
`LiquidTabBarController` and `LiquidGlass` are untouched. The version moves to
1.0 because that surface is now settled, not because anything in it moved.

Thanks to Yousef Sobhy for the fixes.

## 0.1.0

- First release, extracted from the Orderbase courier app: the glass, blur and
  opaque tiers, the soap-bubble selection lens, finger scrubbing, fold on
  scroll, the frame governor.

## Pre-release development entries

The two entries below come from the droplet's own development branch and were
never published under those numbers. The releases that exist on pub.dev are
`0.1.0`, `1.0.1`, `1.1.0`, `1.2.0` and `2.0.0`.

## 0.3.0 - Unreleased

- Consolidated outer surfaces into `LiquidBarStyle`, droplet surfaces into
  `LiquidDropletSurfaceStyle` (including `BoxShadow`), selected action fill into
  `LiquidTabActionStyle`, and badge appearance into `LiquidBadgeStyle`.
- Kept all six `DropletRefractionStyle` controls and `none`/`subtle`/`medium`/`strong`
  presets; removed obsolete droplet glass/fringe configuration.
- Internalized renderer infrastructure from the supported public barrel and
  removed redundant `foldOnScroll` aliases; use `shrinkOnScroll`.
- Added zero-configuration scrolling and folding to `LiquidTabBarScaffold`:
  automatically observes primary vertical scroll notifications when `shrinkOnScroll: true`
  is set, with object-identity deduplication for existing manual listeners.
- `LiquidTabItem.icon` now supports const construction.
- Fixed expandable search and separate action surface vertical alignment, ensuring
  the action circle and search pill share an identical visual center.
- Fixed expandable search keyboard layout and input ownership: stable reported
  height, one persistent input, unified keyboard movement, and staged close.
- Replaced old showcase screens with four focused examples, including an Arabic
  RTL preview. Overhauled README with comprehensive visuals and code samples.
- Preserved default rendering against locked deterministic visual baselines.

Breaking replacements are documented in the
[0.3.0 migration guide](doc/migration_0.3.0.md).

## 0.2.0

### New Features
- **Programmatic Search API (`LiquidTabBarController` & `LiquidTabBar`):**
  - Added `LiquidTabBarController.isSearching`, `openSearch()`, and `closeSearch({bool clearText = false})` for programmatic search morph control from external widgets (app bars, buttons, shortcuts).
  - Added static convenience helpers `LiquidTabBar.openSearch(context)`, `LiquidTabBar.closeSearch(context)`, and `LiquidTabBar.isSearching(context)`.
  - Added `LiquidTabBarSearch.clearOnClose` configuration to automatically reset the search query when closing the search view.
- **Configurable Folded Shape (`foldedShape`):**
  - Added `LiquidFoldedShape` enum (`circle` vs `oval`).
  - Added `foldedShape` property to both `LiquidTabBar` and `LiquidTabBarTheme`.
  - Implemented nullable fallback resolution: `LiquidTabBar.foldedShape` defaults to `null` to seamlessly inherit from `theme.foldedShape`, cleanly resolving to `LiquidFoldedShape.circle` (matching the separate action button) if neither is set.
- **Curated Named `GlassStyle` Presets:**
  - Promoted the example app's quick optical presets into reusable, first-class compile-time constants on `GlassStyle`:
    - `GlassStyle.frosted`: Classic Apple-style frosted glass with balanced diffusion and gentle rim specular (matches baseline `bar` parameters).
    - `GlassStyle.prismaticCaustics`: Vivid chromatic dispersion (`0.32`) with sharp specular highlights (`0.65`) and enhanced saturation (`1.60`).
    - `GlassStyle.clearCrystal`: Zero-blur glass emphasizing clean refraction, rim highlights, and edge dispersion without obscuring background content.
    - `GlassStyle.deepRefraction`: Heavy optical slab with deep displacement (`depth: 14`), thick frost diffusion (`blur: 40`), and light absorption.
- **Theming & Accessibility:**
  - Added `LiquidTabBarTheme.dark()` preset for sleek dark-mode glass styling.
  - Added `LiquidTabBarTheme.adaptive(context)` factory to automatically match ambient `Brightness`.
  - Added `badgeText` and `iconSize` support to `LiquidTabItem` for notification counts and custom sizing.
  - Added comprehensive accessibility semantics for tab items, badges, and folded state ("Expand navigation bar" button).
  - Added dynamic text scaling support in `LiquidTabBar.reservedHeight(context)`.
- **Scroll Handling & Control:**
  - Added `shrinkOnScroll` (and `foldOnScroll` alias) to `LiquidTabBar` and `LiquidTabBarController` to easily toggle bar minimization on scroll.
  - `LiquidTabBarController.handleScroll` now filters out inner nested scrollables (`depth == 0`) by default, with an `allowNested: true` option.

### Fixes & Performance Improvements
- **Dark Mode Glass Tuning:**
  - Tuned `GlassStyle` and `GlassLightPainter` for dark backgrounds, preventing washed-out white bands on dark surfaces.
  - Made `GlassLightPainter` theme-aware: dark mode renders subtle translucent white rim highlights (`0.06`–`0.20` alpha) instead of harsh dark drop-shadow edges, creating a razor-crisp chamfer bevel against dark backgrounds.
  - Boosted caustics and specular clarity in `LiquidLensChromaticPainter` for dark themes.
- **Opaque Tier Selection Pill Sync & Geometry:**
  - Replaced delayed active-color droplet with a flat neutral gray/white-gray pill (`0x14000000` light / `0x24FFFFFF` dark) that updates in immediate lockstep with the selected icon, matching native iOS 26 Segmented Control behavior.
  - Eliminated desync and lag during fast scrubbing and tab tapping on the opaque tier.
- **Split Action Placement (`LiquidTabActionPlacement.split`):**
  - Fixed geometry calculation where split placement incorrectly centered the capsule or overlapped tabs. Split placement now pins the tab capsule firmly to the leading margin and the separate action button to the trailing margin in both LTR and RTL directions.
- **Frame Governor Timing & Reset Lifecycle:**
  - Fixed governor timing delay: frame degradation now triggers immediately upon reaching the slow frame threshold (`_slow >= 6`), without lingering on dropping frames.
  - Fixed governor reset path (`LiquidTabBarController.resetGovernor()`): unwatching frames and re-arming the governor now strictly resets internal counters (`_seen = 0`, `_slow = 0`) to prevent residual dropped frame counts from triggering instant re-degradation.
- **Frost Cache Memory & LRU Eviction:**
  - Added key quantization to `_frostFilter` (`qBlur = (style.blur * 10).round() / 10`, `qSat = (style.saturation * 100).round() / 100`) to prevent micro-float key proliferation during live slider tuning.
  - Replaced unbounded cache with a bounded 24-entry LRU cache featuring access promotion and least-recently-used eviction, preventing memory leaks while retaining frequently-used presets.
- **Skia & Non-Impeller Backend Fallback:**
  - Gated shader execution on `LiquidGlass.supported` (`_hasImpeller && isShaderFilterSupported`) rather than `LiquidGlass.ready`.
  - Automatically falls back to the backdrop blur tier on Skia/OpenGL backends, preventing driver crashes and corrupted black layers on non-Impeller Android devices. *(Note: Verified on Android emulator with `EnableImpeller = false`; physical device testing recommended prior to pub.dev publication).*
- **Android Back Navigation (`PopScope`):**
  - Wrapped `LiquidTabBar` in `PopScope(canPop: !_isSearching)`: when search morph is active, pressing the Android hardware back button or predictive back gesture cleanly dismisses search without popping the route or exiting the app.
- **Lifecycle & Memory Allocations:**
  - Cached `ui.ImageFilter.shader(_shader)` as `_shaderFilter` on `_RenderGlassFilter`, eliminating per-frame native handle churn.
  - Pre-allocated `Paint` objects across `GlassLightPainter` and `ChromaticShaderCache`, eliminating GC churn in paint routines.
  - Removed wrapping `Opacity` widget from `_lensSurface` to avoid offscreen save layer creation that broke backdrop screen coordinates. Replaced with direct alpha attenuation of lens tint, specular, and dispersion.
  - Added active pointer tracking to isolate touch gestures against multi-touch contention and accidental scrubbing jumps.
  - Added assertions and safe guards against empty tab item lists and out-of-bounds `selectedIndex`.
