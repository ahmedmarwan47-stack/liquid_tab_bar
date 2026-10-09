# PageView auto-fold prototype — Phase 1

Historical Phase 1 findings. The API proposal below is superseded by
`auto_fold_phase2_design.md`; the test resolver now also supports conservative
sibling discovery. See `auto_fold_phase2_results.md` for the subsequently approved
production implementation. Statements below describe the original prototype.

Branch: `spike/pageview-auto-fold`. Production code and public API are unchanged.

## Scope and mechanism

`test/pageview_auto_fold_prototype_test.dart` contains a private, test-only
replacement for the package scaffold notification boundary. Its callers supply
only a body and a tab controller; pages contain no notification forwarding.
The real controller and bar are used, including rendered folding animations.
The current production `LiquidTabBarScaffold` still ignores PageView notifications.

The resolver visits ancestor elements without creating inherited dependencies.
It identifies ScrollableState instances, rejects intervening vertical scrollables,
and supports exactly one horizontal, full-page PageView. It reads public
PageMetrics and rejects fractional or actively moving page positions. Render
ancestry maps the source to the direct RenderSliverFillViewport child index via
SliverMultiBoxAdaptorParentData. Only the settled active page is eligible.

## Findings

- Active vertical CustomScrollViews fold and unfold in LTR and RTL; assertions
  cover controller state and actual capsule width.
- Explicit and default PageControllers work.
- Kept-alive inactive pages still have attached positions, but their updates are
  rejected. A real old-page fling continues emitting rejected updates after a
  page switch and cannot refold the expanded bar.
- Horizontal swipes, transitions, and nested vertical lists are rejected.
- Direct ListView behavior remains intact. Active programmatic vertical scrolling
  follows the current controller policy.
- Partial-page PageViews fail closed.
- Two sibling vertical lists on one active page have equally valid ancestry.
  A characterization test demonstrates that an unrelated sibling folds the bar.
  Source/page identity cannot infer application intent; an override is required.
- A characterization test demonstrates that 7px on page 0 plus 7px on page 1
  crosses the existing shared controller threshold. Production integration needs
  an ownership-change reset that does not change visual fold state.

## Compatibility and performance

Validated only on installed Flutter 3.47.2 / Dart 3.13.2. The package supports
Flutter >=3.29; minimum-SDK compatibility has not been tested. All accessed APIs
are public, but PageView's RenderSliverFillViewport composition is an implementation
dependency, not a guaranteed semantic page-identity contract. Fail closed if that
composition is absent; test supported Flutter SDKs before enabling a default.

Traversal is O(element ancestry + render ancestry) for each eligible notification.
There is no whole-tree scan, layout request, timer, or application rebuild added
by resolution. Runtime CPU/raster performance has not been benchmarked. Cache
only with explicit invalidation on page movement, source replacement, and disposal.

## Conditional production recommendation

Proceed only for documented standard single-main-scrollable PageViews. Preserve
direct scrolling and all animation/selection code. Do not claim universal intent
detection or automatic NestedScrollView coordination.

One optional scaffold ScrollNotificationPredicate could replace the default
eligibility policy (not be ANDed with it). True still passes through vertical-axis
safety, shared deduplication, and ownership bookkeeping; false excludes the source.
It must not bypass springs, thresholds, or selection behavior. Callers choosing
an advanced source must also express active-source intent when ancestry is ambiguous.

During 2.x, the new nullable predicate can default to Flutter's existing
defaultScrollNotificationPredicate (depth zero). Explicitly passing null opts
into smart resolution; passing a callback replaces eligibility. This requires
one property and no additional public smart-policy helper. In the next major
release, the default can become null, making ordinary PageViews zero configuration.
Alternatively, adopting smart defaults in 2.x requires an explicitly accepted
behavioral compatibility change. Zero configuration and exactly preserved 2.x
defaults cannot both be satisfied for currently ignored PageViews.

Do not implement Phase 2 until approved. Preserve LiquidScrollPadding's stable
MediaQuery ancestry. Harden controller accepted-event deduplication and reset only
source bookkeeping when owners change; manual forwarding must remain functional.

## Verification

- Prototype: 11 tests, including two limitation-characterization tests.
- Targeted analysis: no issues.
- Folding/controller/Search lifecycle/keyboard suites: 72 tests passed with the
  prototype included.
- Full test suite: 261 passed, 1 skipped, 2 load failures. Existing untracked
  surface_press_test.dart uses unsupported insetAt(width:, radius:) parameters;
  concurrent droplet_dispersion_pixels_test.dart reported compiler termination.
  Isolated droplet_dispersion_pixels_test.dart rerun: 1 test passed.

No native simulator, minimum-SDK run, or performance benchmark was performed.
