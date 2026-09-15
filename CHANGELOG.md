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
