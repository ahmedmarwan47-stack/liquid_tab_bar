# Nested pager smart auto-fold prototype

Date: 2026-10-09. Branch: `spike/pageview-auto-fold`.

## Scope and verdict

**GO WITH CONDITIONS.** A test-only generalized resolver establishes active ownership through nested horizontal PageViews, including TabBarView, on Flutter 3.29.0 and 3.47.2. It exercises the real fold controller and capsule geometry. This is evidence for implementation, not a production implementation or release approval.

No production Dart files, package dependencies, public APIs, application files, animation constants, shaders, or Search lifecycle code changed during this investigation. Existing work on this branch predates this prototype.

Files added:

- `test/support/nested_pager_chain_prototype.dart`: bounded resolver and experimental controller adapter.
- `test/nested_pager_auto_fold_prototype_test.dart`: 30 deterministic tests and dispatch measurements.
- This report.

## Confirmed current limitation

`lib/src/scroll_source.dart:28–45` returns unknown active-page ownership unless exactly one PageView encloses the source. `:93–119` associates only its nearest horizontal viewport and page child. `:129–140` permits only one vertical scrollable plus one pager for smart eligibility.

An outer PageView plus TabBarView therefore fails closed deliberately. Changing notification depth alone cannot prove ownership at either level.

`ScrollOwnership`, `lib/src/scroll_source.dart:177–239`, currently observes only one pager position. Simply relaxing eligibility would allow an outer page change to leave an inner scroll session alive. Controller accumulation resets through the ownership generation at `lib/src/controller.dart:156–167`; scaffold policy dispatch is at `lib/src/scaffold.dart:146–164`.

## Framework evidence

Installed SDK source inspected:

| SDK | TabBarView builds PageView | Nonadjacent tab warp | PageView rendering |
|---|---|---|---|
| 3.29.0 | `packages/flutter/lib/src/material/tabs.dart:2328–2343` | `:2201–2260` | `widgets/page_view.dart:928–978` |
| 3.47.2 | `packages/flutter/lib/src/material/tabs.dart:2519–2542` | `:2420–2451` | `widgets/page_view.dart:995–1048` |

TabBarView's PageController is private, but its ordinary descendant PageView/Scrollable/Viewport can be inspected using public APIs. A DefaultTabController lookup is unnecessary, and explicit TabControllers work too.

PageView uses a horizontal RenderViewport and RenderSliverFillViewport. Its fractional padding is represented by a subclass of public RenderSliverEdgeInsetsPadding. Public SliverMultiBoxAdaptorParentData exposes the actual page child index. The prototype checks viewport offset identity against ScrollableState.position and validates PageMetrics, axis, viewport fraction, settled page, child identity, and mounted state.

These are public APIs, but their composition is not a guaranteed PageView ownership contract. Unexpected structure must return unresolved, never infer an index from notification depth or widget order.

A characterization test on both SDKs found that rapid `TabController.index = 1`, pump, then `index = 0` can settle with controller index 0 while the rendered pager reports page 1. The resolver correctly follows rendered page 1. This investigation does not change Flutter's warp behavior or promise that controller intent and rendered content always agree.

## Recommended architecture

Use one generalized chain algorithm with an internal maximum of **four horizontal pagers**, rather than a specialized Library/two-level adapter. Four is a conservative prototype bound, not a new public configuration or a demonstrated universal maximum.

1. Walk notification ancestry up to the registered smart body boundary, collecting the nearest vertical source and every enclosing horizontal PageView.
2. Associate each pager with its public Scrollable, actual viewport offset, fill-sliver child, and rendered child index.
3. Require every link to be mounted, full-width (`viewportFraction == 1`), integral and settled, not scrolling, and displaying that child.
4. Establish a unique scroll branch at every scope: the inner page must have one eligible root vertical scrollable; each enclosing page must have one root pager matching the next link; the scaffold body must have one root scroll branch matching the outer link.
5. Prune traversal at Scrollables and offstage subtrees. Ignore horizontal carousels as owners. Additional vertical ancestors exclude a source from automatic selection.
6. Fail closed on ambiguity, unsupported structure, transitions, partial-width pages, more than four pagers, or exhausted discovery budget.

All ancestry, rendering, and scoped discovery work shares a **4096-visit budget** per description. Eligibility is checked live so dynamic sibling insertion cannot leave stale acceptance. A weak per-notification cache avoids repeating structural description; no persistent eligibility cache assumes a static tree.

This discovers structural root sources, not Flutter's `primary: true` property alone. PrimaryScrollController inheritance does not prove active pager ownership or sibling uniqueness.

## Ownership and invalidation

The experimental session owns a vertical ScrollPosition and the ordered identities of all enclosing pager positions. It listens to pixels and isScrollingNotifier on every pager. Any movement, ownership replacement, or invalidation revokes the old source and detaches the chain listeners.

Reset distance/direction accumulation through the existing generation mechanism; leave folded/unfolded visual state unchanged. A revoked continuation cannot become eligible again merely because its page becomes visible. Only a fresh scroll start after valid chain resolution re-arms it.

The common controller entry point must check smart-scope ownership before accumulation, including manually forwarded events arriving before the scaffold listener. Weak notification-identity deduplication prevents manual plus automatic processing twice.

Automatic rejection must revoke an automatically owned source without trampling an explicitly forwarded nested source. The prototype tests this distinction. Default direct/custom policy behavior should retain its existing guards; the new chain gate belongs to registered smart scopes only.

## Prototype coverage and results

Tests use real ListViews for all three inner tabs, CustomScrollViews for Home/Search, kept-alive pages, real LiquidScrollPadding, the real bar/controller animations, and actual ClipRRect capsule width. Folded width is asserted at 64 logical pixels and unfolded width above 64, alongside minimized state.

| Coverage | Result on both SDKs |
|---|---|
| Unmodified direct/smart/custom nested baseline | Direct and smart reject; explicit custom accepts |
| Home, all three inner tabs, default/explicit controllers, RTL/LTR | Pass |
| Generalized 3/4 pager chains; five-level rejection | Pass |
| Inactive kept-alive inner and outer pages | Pass |
| Real old-page flings after inner/outer switching and return | Pass; stale continuation rejected |
| Horizontal swipes, partial/animated transitions, nonadjacent warp | Pass; no unintended fold |
| Rapid switching, distance reset, visual fold-state preservation | Pass |
| Dynamic tab insertion/removal/reorder | Pass |
| Nested vertical lists, vertical siblings, sibling pagers | Pass; automatic ambiguity rejected |
| Dynamic sibling insertion during an active scroll | Pass; old session revoked |
| Manual forwarding, nested manual override, identity deduplication | Pass |
| Search focus, typing/results, repeated keyboard insets, close | Pass; page state preserved |
| Fractional pages and shared-budget exhaustion | Pass; fail closed |

Final package runs, serial within each SDK:

- Flutter 3.47.2: **322 passed, 1 skipped**.
- Flutter 3.29.0: **322 passed, 1 skipped**.
- New prototype coverage: **30 tests**, all passing on both.
- Analysis of the two new Dart files: **no issues** on both.
- `git diff --check`: passed.

The complete relevant package runs exclude the pre-existing unrelated `test/surface_press_test.dart`, which does not compile because its SurfacePress.insetAt calls use unsupported width/radius arguments. The seam PNG test remains skipped without `SEAM_PNG`. Full-root analysis is not clean: existing surface-press and example errors remain; this prototype neither fixes nor hides them. Earlier package load failure from a terminated pixel compiler did not recur in these serial runs. Accordingly, these results are not an unqualified clean full-suite/release declaration.

Reproduction commands:

```sh
flutter test test/nested_pager_auto_fold_prototype_test.dart --concurrency=1 --reporter expanded
flutter analyze test/nested_pager_auto_fold_prototype_test.dart test/support/nested_pager_chain_prototype.dart
flutter test test/nested_pager_auto_fold_prototype_test.dart test/auto_fold_policy_test.dart --plain-name continuous --concurrency=1 --reporter expanded
```

For the complete relevant run, enumerate all `test/*_test.dart` files except `surface_press_test.dart` and pass them to `flutter test --concurrency=1 --reporter expanded`. The 3.29 run uses a separate synced fixture without example/lock/tool state, preventing SDK dependency resolution from modifying this checkout.

## Performance

Isolated host debug widget-test measurements; 30 warm-ups, 590 measured dispatches per case. Times cover notification resolution and controller dispatch, not frame layout/raster work. Nested measurements include both the experimental chain gate and existing production controller machinery.

| SDK / path | Decorative prefix nodes | Median µs | P95 µs | Max µs | Maximum visits |
|---|---:|---:|---:|---:|---:|
| 3.29 nested | 0 | 31 | 100 | 325 | 134 |
| 3.29 nested | 1000 | 68 | 156 | 372 | 2136 |
| 3.29 existing single pager | 0 | 20 | 62 | 1007 | — |
| 3.29 existing single pager | 1000 | 55 | 87 | 650 | — |
| 3.47 nested | 0 | 37 | 105 | 593 | 137 |
| 3.47 nested | 1000 | 70 | 260 | 917 | 2139 |
| 3.47 existing single pager | 0 | 26 | 179 | 390 | — |
| 3.47 existing single pager | 1000 | 57 | 135 | 333 | — |

Typical incremental median overhead is 11–13 µs in these fixtures. Host scheduling causes variable tail latency; these samples do not establish device frame performance. Scoped traversal is bounded but still sensitive to large static prefixes. Final production dispatcher benchmarks and physical-device profiling remain gates.

## Risks and limits

| Risk | Severity / likelihood | Mitigation and regression gate |
|---|---|---|
| Stale outer fling accepted by nearest-only watcher | High / likely with naive relaxation | Watch all links; retain real fling tests |
| Inactive or ambiguous sibling source accepted | High / likely with depth-only filtering | Validate every rendered page and unique branch at every scope |
| Manual callback runs before automatic safety checks | High / possible | Register smart scope before events; gate common entry and test forwarding order |
| Multiple scaffolds/shared controller scope conflict | Medium / unresolved | Test registration, precedence, scope replacement, disposal and reparenting before production |
| Framework render composition changes | Medium / possible future SDK | Public guarded adapters, fail closed, retain two-SDK characterization |
| TabBarView warp/controller intent differs from content | Medium / observed | Follow settled physical page; refuse moving pagers; retain characterization |
| Large structural prefix increases dispatch cost | Medium / possible | Shared budget, pruning, no unbounded scan; profile actual devices |
| Unsupported partial pages, five levels, exhausted budget | Low / deliberate false negatives | Document limits; existing custom/manual explicit selection remains available |
| Search/keyboard subtree identity regression | Low / avoidable | Keep existing listener key/padding structure; production lifecycle tests |

The prototype models one smart boundary per controller. It has not proven production registration for multiple scopes, policy changes, shared controllers, or reparenting. Those are implementation conditions, not claims already validated.

## API and compatibility

No new public API is needed. Keep `direct()` default throughout current 2.x; only explicitly selected `smart()` gains nested support. Preserve `custom()` predicate semantics and intentional manual source selection. The smart behavior expansion is opt-in but still changes which nested layouts fold for existing smart users, so document it in the changelog.

No dependency, export, or minimum SDK change is proposed. Both supported SDK implementations satisfy the prototype checks today. No application-level listener is required for the ordinary nested PageView/TabBarView path.

## Smallest production plan, pending approval

1. Generalize the existing ScrollSource description to bounded pager links and unique scoped branch discovery for smart mode.
2. Add internal smart body-scope registration before notifications and deterministic lifetime handling. Do not restructure the existing Search/padding subtree.
3. Extend ownership to observe every pager, preserving generation resets, weak revocation and notification deduplication. Gate manual entry only when a relevant smart scope is registered.
4. Convert prototype acceptance cases to actual LiquidTabBarScaffold.smart tests. Add shared-controller/multiple-scope, policy-switch, disposal/reparenting tests; preserve legacy direct/custom regressions.
5. Run both SDK suites, production-dispatch benchmarks and device profiling; document intentional limitations. Resolve or explicitly isolate existing unrelated blockers before release readiness.

Exact future files:

- `lib/src/scroll_source.dart`: chain description, bounded discovery and multi-pager ownership.
- `lib/src/controller.dart`: smart-scope common-entry safety and deduplication integration.
- `lib/src/scaffold.dart`: internal scope registration/lifetime, retaining current widget identity.
- `lib/src/auto_fold_policy.dart`: documentation only; constructors unchanged.
- `test/auto_fold_policy_test.dart`: production precedence and integration regressions.
- `test/nested_pager_auto_fold_prototype_test.dart` and support fixture: migrate experimental behavior tests to production integration while retaining framework characterization.
- `README.md`, `CHANGELOG.md`: opt-in support and limits.

No shader, spring, selection gesture, search navigation, application spacing, or scroll physics changes are necessary. Do not publish, merge, or declare production readiness from this prototype alone.
