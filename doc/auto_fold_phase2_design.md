# Smart auto-fold — final design proposed for approval

Historical approval document. Phase 2 was subsequently approved and implemented
on `spike/pageview-auto-fold`; see [implementation results](auto_fold_phase2_results.md).
Statements below describe the pre-implementation design review.

## Proposed API

One non-null scaffold property: `autoFoldPolicy`, of type `LiquidAutoFoldPolicy`.
Named constructors encode exactly one policy:

```dart
// 2.x explicit opt-in; eventual major-release default.
autoFoldPolicy: const LiquidAutoFoldPolicy.smart(),

// Existing depth-zero behavior.
autoFoldPolicy: const LiquidAutoFoldPolicy.direct(),

// Explicit source eligibility; predicate argument is required and non-null.
autoFoldPolicy: LiquidAutoFoldPolicy.custom(selectRelevantSource),
```

This is a proposed immutable policy value, not implemented code. `custom` is a
source policy rather than an additional nullable setting. There is no omitted
versus null distinction, no nullable mode switch, and no conflicting mode/predicate
combination. Constructor null arguments fail type checking.

Precedence:

1. `shrinkOnScroll == false` retains its current behavior and disables automatic
   processing.
2. The selected policy alone determines eligibility: direct, smart, or custom.
3. A custom predicate REPLACES smart/legacy eligibility, including nested-depth
   and sibling-uniqueness rules; it is not ANDed with them.
4. Framework validity checks still apply to automatic processing: mounted source,
   descendant of this scaffold, vertical axis, and rejection of known offstage or
   inactive page sources. In unsupported layouts, custom policy is an explicit
   declaration of relevance; it cannot manufacture missing framework evidence.
5. All accepted events share deduplication and owner bookkeeping before existing
   fold thresholds/animations run. Manual `controller.handleScroll` remains an
   explicit integration path, independent of scaffold policy.

For complex layouts, custom predicates must select the intended active source,
not indiscriminately accept every vertical event. A custom predicate always
returning false disables scaffold automatic processing while leaving explicit
controller integrations and the bar's folding capability available.

## Compatibility strategy

- 2.x defaults to `direct()`. Ordinary PageViews opt in with `smart()`; no
  application listeners or controller forwarding are required.
- The next major release defaults to `smart()`, providing zero-configuration
  PageView behavior. `direct()` is the precise legacy opt-out.
- Applications that already set `smart()` do not change when the major default
  changes. Low-level manual forwarding signatures remain unchanged.
- Zero configuration for formerly ignored PageViews cannot coexist with exactly
  unchanged 2.x defaults. A 2.x smart default would require separately approved
  behavioral compatibility changes; it is not the recommended rollout.

## Ambiguity resolution

Resolve actual source/position identity, not `ScrollView.primary` or navbar index.
For smart mode, inspect only the scaffold body or the settled active page's root
subtree. Enumerate root vertical Scrollables, pruning at every Scrollable and
explicit offstage subtree. Reject intervening vertical scrollables and unrelated
horizontal containers. Exactly one root candidate must exist and match the source.
Reject zero or multiple candidates; never choose the first, last, largest, touched,
or primary-marked sibling.

Revalidate on every eligible event rather than retaining an unprovable tree cache.
Dynamic sibling insertion therefore invalidates eligibility immediately after it
is mounted; removal can restore unique ownership. Prototype tests demonstrate
both directions. Discovery stops at the second candidate and never visits a root
scrollable's list-item descendants.

Production proposal: bound discovery to 4096 element visits per event. Exhaustion
means rejection, not accepting the candidates discovered so far. This ceiling
allows the measured 1000-decoration stress fixture (about 2008 discovery visits
per update). It is a safety bound, not a claimed universal device-time budget.
Oversized/ambiguous layouts use custom source selection. Add exhaustion tests
before production integration; the prototype measurements are uncapped.

Initially support one horizontal full-page PageView. Partial-page, multiply nested
pager, or unidentifiable render arrangements fail closed in smart mode. NestedScrollView
retains root/outer behavior; coordinated inner scrolling needs an explicit policy.

## Ownership and event processing

Keep one accepted owner identity based on actual ScrollPosition, with an associated
pager identity and interaction epoch where applicable. Changing owner clears only
distance and direction accumulation; it does not call expand/minimize, notify the
bar, or change visual fold state.

Invalidate a PageView owner's session at pager movement, page changes, source
disposal/replacement, or loss of unique eligibility. Reject its stale continuation,
including switching away and back before the old fling ends. A new valid scroll
start establishes a new smart PageView session; retain it through ballistic updates.
Jump/animate scrolling has a start and remains supported for eligible active pages.
Do not require dragDetails on every update. Preserve existing direct/manual
handling, including context-less synthetic notifications used in controller tests.

Put accumulation/accepted-event bookkeeping in the controller's existing handler;
do not create a parallel threshold algorithm in the scaffold. Source/page resolution
can live in an unexported internal helper shared by these layers. Relevant pager
movement is a control signal for tracking invalidation, never a fold delta. Observe
it with bounded public position listeners and dispose/detach them with ownership.
No new public reset method or handleScroll parameter is required.

Deduplicate before resetting ownership or accumulating distance. An accepted-event
weak identity set (Expando) avoids strongly retaining notifications and handles
the same start/update/end bubbling through manual and scaffold listeners. Do not
mark rejected notifications as processed. Distinct NestedScrollView position
notifications are not identity duplicates; source selection handles those.

## Framework validation and remaining dependency

Page identity uses public ScrollableState, PageMetrics, RenderSliverFillViewport,
and SliverMultiBoxAdaptorParentData APIs. Validate that the identified render child
belongs to the actual enclosing PageView viewport rather than trusting the first
matching render type. Keep this association in one internal adapter and fail closed
when it cannot be established.

These types are public on Flutter 3.29.0 and 3.47.2. PageView's render composition
is nevertheless an implementation dependency, not a semantic page-owner contract.
Run compatibility tests at both endpoints and future stable releases.

Flutter 3.29.0 / Dart 3.7.0 was downloaded into `/tmp/liquid-auto-fold-sdk-3.29.0`.
Tests ran in an isolated package copy with a separately resolved lockfile; the
working package's installed SDK and lockfile were not changed.

- Shared resolver-only fixture on 3.29.0: 6 tests passed; analysis clean.
- Identical fixture on 3.47.2: 6 tests passed; analysis clean.
- Existing complete package on 3.29.0: fails to compile before tests because
  `lib/src/bar.dart:183` uses `@internal` without an import available on that SDK.
  Foundation 3.29 does not re-export this meta annotation; Foundation 3.47 does.
- Proposed compatibility prerequisite, subject to approval: explicitly import
  `package:meta/meta.dart` for `internal` and declare its compatible direct
  dependency. Preserve the annotation rather than delete or substitute it.
  Then rerun the complete package suite on 3.29; resolver-only success does not
  establish whole-package compatibility.

## Measurements

Apple arm64 host, debug widget tests, five seconds of simulated 120Hz programmatic
continuous scrolling. Approximately 601 real updates per fixture; discard the
first 30 timing samples. Stopwatch covers source-resolution work only, including
unique-source discovery; it excludes controller work, rasterization, and total
frame time. No performance threshold is asserted because host timings vary.

| SDK | Fixture | Samples | Median | p95 | Maximum |
| --- | --- | ---: | ---: | ---: | ---: |
| 3.29.0 | Ordinary page | 571 | 10 us | 21 us | 118 us |
| 3.29.0 | 1000 non-scroll decorations | 571 | 47 us | 68 us | 423 us |
| 3.47.2 | Ordinary page | 571 | 11 us | 35 us | 197 us |
| 3.47.2 | 1000 non-scroll decorations | 571 | 46 us | 69 us | 453 us |

These are evidence of measured host overhead, not mobile frame-rate guarantees.
The prototype also measures the resolver while driving the real package controller
and bar on 3.47. Runtime profile/device verification remains a release gate.

## Full-suite failure isolation

- Serial full run before the final compatibility fixture: 264 passed, 1 skipped,
  1 load failure, solely existing untracked `test/surface_press_test.dart`.
- That test supplies width/radius named arguments to SurfacePress.insetAt, which
  currently accepts only x. Reconcile the test with its owner separately; do not
  weaken geometry assertions or modify production press behavior in this feature.
- Pixel test passed in isolation and serial full-suite execution; its earlier
  concurrent compiler termination is not an independently reproduced pixel failure.
- All current test files except the explicitly isolated stale surface test:
  270 passed, 1 skipped. The skip requires a supplied SEAM_PNG fixture.
- Production is not declared ready while the full local suite and package's
  minimum-SDK compile gate remain unresolved.

## Implementation order after approval

1. Approve policy API and staged default rollout; resolve the minimum-SDK annotation
   prerequisite without touching visual code.
2. Convert experimental resolver checks into production acceptance tests. Add
   default/explicit policy precedence, bounded discovery, direct sibling ambiguity,
   offstage roots, dynamic changes during a held drag, custom source selection,
   and alternate render arrangement rejection.
3. Add the isolated source adapter and unique-root resolver in smart mode. Keep
   existing scaffold/padding widget ancestry unchanged.
4. Implement controller owner tracking, pager/session invalidation, distance-only
   resets, and accepted-event identity deduplication. Add 7px+7px owner-change,
   same-owner threshold continuity, switch-away-and-back fling, manual+automatic
   same-event, scroll-end, and disposal tests.
5. Run complete package tests on both SDKs, plus tap/hold/drag/release, Search page
   identity, focus/insets, rendering and keyboard regressions. Benchmark the final
   implementation, then profile on a device.
6. Document unsupported layouts, custom-policy responsibility and legacy opt-out.
   Release only after the explicit compatibility and test gates are green.

## Proposed production files (not modified)

- `lib/src/scaffold.dart`: policy parameter and automatic integration.
- `lib/src/auto_fold_policy.dart`: immutable typed policy.
- `lib/src/scroll_source.dart`: internal resolver/page adapter.
- `lib/src/controller.dart`: private owner/session/reset/deduplication bookkeeping.
- `lib/liquid_tab_bar.dart`: policy export only.
- `lib/src/bar.dart` and `pubspec.yaml`: minimum-SDK annotation import/dependency
  prerequisite only, if approved. No animation, shader or gesture changes.
- Existing and new widget tests, README/CHANGELOG, and SDK compatibility CI.

Verdict: GO WITH CONDITIONS for this final design. No Phase 2 production code
should be written until the user approves it. Whole-package 3.29 compatibility,
complete local tests, bounded-discovery tests and device performance remain gates.
