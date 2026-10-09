# Smart auto-fold — Phase 2 implementation results

Validated 2026-10-09 on `spike/pageview-auto-fold`. No release, tag, merge,
publication, or application change was performed.

## Public API and compatibility

`LiquidTabBarScaffold.autoFoldPolicy` is non-null and defaults to
`const LiquidAutoFoldPolicy.direct()` for 2.x. The exported sealed policy offers
`direct()`, `smart()`, and `custom(ScrollNotificationPredicate)` constructors.
Smart detection is explicitly opt-in; no nullable omission semantics exist.
Custom replaces automatic eligibility, while safety guards remain. A custom
predicate must select the active source in unsupported layouts. Use a stable
predicate when rebuilding: replacing it invalidates the old scroll session.
`shrinkOnScroll: false` bypasses automatic forwarding. Manual `handleScroll`
retains its signature and depth/allowNested policy.

Ordinary full-width horizontal PageViews need no forwarding, explicit
PageController, or page identifier. Direct scrolling retains the existing
thresholds, direction, top-boundary, and programmatic-scroll policy.

## Implementation and safety

- Public `ScrollableState`, `PageMetrics`, Element visitation, RenderViewport,
  RenderSliverFillViewport, RenderSliverEdgeInsetsPadding, and
  SliverMultiBoxAdaptorParentData establish the source and actual active page.
  No private framework types or imports are used.
- A unique root vertical scrollable is required. Scanning prunes scrollables and
  offstage subtrees; two root candidates are rejected without choosing either.
- Ancestor, render, and page/body discovery are bounded by 4,096 steps/elements.
  Page discovery aborts enumeration at ambiguity or exhaustion. Unestablished
  ownership, fractional pages, nested PageViews, and transitions fail closed.
- Discovery is reevaluated per notification so sibling changes cannot leave a
  persistent eligibility cache. The source description is shared through a weak
  notification cache between scaffold and controller.
- Ownership changes reset only accumulated distance/direction. Pager movement
  invalidates the old session; switching back cannot revive its stale fling.
  A fresh ScrollStart allows that source to control folding again.
- Accepted notifications are deduplicated by weak object identity. Rejected
  notifications are not marked processed; ScrollEnd does not erase deduplication.
  Manual forwarding still works when the automatic predicate rejects the source.
- Scaffold disposal/policy/controller changes release scoped ownership and pager
  listeners. Existing external controllers are not disposed by the scaffold.
- The existing padding ancestry remains intact. Springs, animations, shader
  files, Search lifecycle, and selection/gesture dispatch logic were not changed.
- `@internal` explicitly imports `meta`, now a direct `^1.16.0` dependency.
  The current lock retains 1.18.3; the separate 3.29 fixture resolves 1.16.0.

## Exact files

Production: `lib/src/auto_fold_policy.dart`, `lib/src/scroll_source.dart`,
`lib/src/scaffold.dart`, `lib/src/controller.dart`, `lib/liquid_tab_bar.dart`.
Compatibility only: `lib/src/bar.dart`, `pubspec.yaml`, `pubspec.lock`.
Documentation: `README.md`, `CHANGELOG.md`, this report, and historical headers
in `doc/auto_fold_phase2_design.md` and `doc/auto_fold_prototype.md`.
Phase 2 regression tests: `test/auto_fold_policy_test.dart` and the ownership
expectation in `test/pageview_auto_fold_prototype_test.dart`.
Phase 1 artifacts retained: `test/pageview_source_compatibility_test.dart`,
`test/support/auto_fold_source_resolver.dart`, and remaining prototype tests.

Pre-existing untracked material tests, test driver, material_tuning.dart, and
surface_press_test.dart were not modified.

## Verification

| Gate | Flutter 3.29.0 / Dart 3.7.0 | Flutter 3.47.2 / Dart 3.13.2 |
| --- | --- | --- |
| Full package test suite, serial | 292 passed, 1 skipped, 1 existing load failure | Same |
| All tests excluding surface_press_test.dart | 292 passed, 1 skipped | Same |
| Production + all test analysis excluding stale surface test | No issues | No issues; example/lib also analyzed |
| Full local analysis | 8 existing surface test errors | 13 existing test errors, including example integration tests |

Commands: `flutter test --concurrency=1 --reporter expanded`; filtered runs pass
every test file explicitly except `surface_press_test.dart`. Clean analysis passes
`lib` and every other test Dart file explicitly to `flutter analyze`.
The old SDK runs in `/tmp/liquid-auto-fold-phase2-3.29` to preserve the working
checkout's lockfile/tool state. `git diff --check` passes.

The 22 new tests cover default/policy precedence, real fold geometry in RTL/LTR,
explicit/implicit controllers, siblings and dynamic uniqueness, nested vertical
sources, horizontal swipes, partial pages, discovery exhaustion, real stale
flings, subthreshold owner resets, manual/automatic deduplication, repeated ends,
offstage roots, page reorder/removal, held-scroll invalidation, external-controller
disposal, Search typing/focus, and repeated keyboard-inset transitions with no
PageView recreation or page disposal.

Existing selection, gesture, spring, Search, keyboard, shader fallback, and pixel
regressions pass in the complete filtered runs.

### Failure isolation

`test/surface_press_test.dart` is a pre-existing untracked test supplying unsupported
`width` and `radius` parameters to `SurfacePress.insetAt`. This is the sole full-suite
load failure on both SDKs. The earlier concurrent pixel-test compiler failure did
not recur in either serial full suite; pixel tests pass.

Full 3.47 analysis additionally finds a missing dark_material_example.dart and
DarkMaterialExample in `example/integration_test/dark_material_test.dart`, and
undefined LiquidMaterialTestObserver in material_resolution_audit_test.dart.
Those example files were not copied into the 3.29 package fixture or altered.
The skipped seam PNG test requires `--dart-define=SEAM_PNG=...`.

## Continuous-scrolling measurements

Fresh notifications are dispatched through the real widget tree, scaffold,
resolver, ownership bookkeeping, and controller. Each iteration follows a real
scroll/frame update. Each case has 30 warm-up iterations and 590 measured samples;
the timer excludes pumping, layout/raster work, and assertions. Separate benchmark
runs use the production test's `--plain-name 'production continuous resolution measurement'`.

| SDK | Decorative elements | Median | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| 3.29.0 | 0 | 19 µs | 49 µs | 273 µs |
| 3.29.0 | 1,000 | 55 µs | 74 µs | 354 µs |
| 3.47.2 | 0 | 18 µs | 44 µs | 258 µs |
| 3.47.2 | 1,000 | 54 µs | 76 µs | 318 µs |

These are host widget-test measurements, not mobile profile results or frame-time
guarantees. Measured overhead is small, but device profiling is still required.

## Remaining risks and release decision

GO WITH CONDITIONS for the feature, not unconditional release readiness.

- Public rendering APIs still reflect Flutter's PageView composition, which is
  not a guaranteed page-identity contract. Tested on both requested SDKs; changed
  composition fails closed and needs compatibility tests on future SDK upgrades.
- Smart mode intentionally misses unsupported/oversized/ambiguous layouts.
  Use a source-specific custom predicate or existing manual integration.
- Predicate selection is application responsibility for unknown page layouts.
  A controller attached to several positions must not be treated as a single owner.
- Ownership resets and stale-fling rejection also protect manual integrations;
  new scroll sessions retain the original fold policy, but stale background
  sessions no longer accumulate distance.
- Source traversal is bounded but linear in the visited tree; profile realistic
  complex pages on target devices before enabling it by default in a later major.
- Resolve the unrelated local test/analysis errors and supply the seam PNG fixture
  before claiming a completely green release gate.

Original unconfirmed KeepAlive and image-codec issues remain separate; this work
does not claim to diagnose or fix either. Application-level device testing was not
performed. No publish, release tag, or main merge is authorized.
