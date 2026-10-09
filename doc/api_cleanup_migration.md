# API cleanup migration

This guide covers the intentional API changes made before the package release.

## Search actions

Search capability now comes from a `LiquidTabBarSearch` configuration. Remove
`isSearch`; for a configured search action, use the search factory:

```dart
LiquidTabAction.search(hintText: 'Search...')
```

For a custom action icon or other direct construction, provide `search`:

```dart
LiquidTabAction(
  icon: const Icon(Icons.search),
  search: const LiquidTabBarSearch(hintText: 'Search...'),
)
```

`LiquidTabBarSearch.showClearButton` and `animationDuration` were removed.
Neither changed the rendered search field or its spring-driven transition.
In the upcoming 2.x default, the internal X clears text without leaving Search;
the existing separate glass circle uses a directional chevron to dismiss it.
`clearOnClose` still clears the query when the search field closes and defaults
to false. To preserve the earlier combined close interaction, specify
`controls: LiquidSearchControls.legacy` on `LiquidTabAction.search` or
`LiquidTabBarSearch`. No navigation callback changes are required: `onClose`
still belongs to the application.

To change transition timing, configure
`LiquidTabBarTheme.spring`, which controls the search morph as well as fold and
lens motion.

## Automatic folding

`LiquidTabBarScaffold` now defaults to `LiquidAutoFoldPolicy.smart()`. It resolves
a unique vertical scroll branch through up to four settled, full-width horizontal
PageViews, including TabBarView's internal pager. No manual forwarding is needed
for these ordinary layouts. Ambiguous or unsupported hierarchies fail closed.

Set `autoFoldPolicy: const LiquidAutoFoldPolicy.direct()` to preserve depth-zero
automatic scroll handling. Use `LiquidAutoFoldPolicy.custom(predicate)` when the
application must explicitly select a source. `shrinkOnScroll: false` still disables
automatic folding, and existing controller forwarding remains supported.

## Droplet refraction

The duplicate `DropletRefractionStyle.rim` and `.depth` getters were removed.
Use `thickness` and `baseHeight` respectively.

Omitting `dropletRefraction` follows the Normal or Glossy preset. An explicitly
supplied style is now always respected, even when it equals the constructor
defaults. To restore preset-driven behavior on a copied theme, use:

```dart
theme.copyWith(usePresetDropletRefraction: true)
```

## Droplet shadows

`LiquidDropletSurfaceStyle.shadow` now accepts `LiquidDropletShadow`, which
contains only the fields the droplet renderer supports:

```dart
LiquidDropletSurfaceStyle.light.copyWith(
  shadow: const LiquidDropletShadow(
    color: Color(0x22000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
)
```

This differs from `LiquidBarStyle.shadow`, which remains a list of Flutter
`BoxShadow`s for the bar's blur and opaque surfaces.

## Sizing and debug warnings

`LiquidTabItem.iconSize` now controls the actual glyph layout size, including
sizes above the default 23 logical pixels. Large icons can approach the label.
The global `LiquidTabBar.disableExtendBodyWarning` switch was removed; disable
the diagnostic on an individual bar with
`warnOnMissingExtendBodyPadding: false`.

## Clearing theme overrides

`LiquidTabBarTheme.copyWith` supports clearing nullable theme overrides:

```dart
theme.copyWith(clearMaxWidth: true, clearBrightness: true)
```

These clear the stored width cap or brightness pin; other theme fields retain
their current values.
