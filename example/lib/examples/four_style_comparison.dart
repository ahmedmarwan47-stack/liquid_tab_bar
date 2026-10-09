import 'package:flutter/material.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'showcase_content.dart';

/// Compares Normal/Glossy palettes and one content-adaptive Native preset.
///
/// Same background, same navigation sequence (Home → Explore → Saved → Profile → Home)
/// so visual differences are easy to compare.
class FourStyleComparison extends StatefulWidget {
  const FourStyleComparison({super.key});
  @override
  State<FourStyleComparison> createState() => _FourStyleComparisonState();
}

class _FourStyleComparisonState extends State<FourStyleComparison> {
  int _selected = 0;
  int _styleIndex = 4;
  int _backdropIndex = 1;

  static const _backdropLabels = [
    'Artwork',
    'White',
    'Charcoal',
    'Split',
  ];

  static const _styleLabels = [
    'Normal Light',
    'Normal Dark',
    'Glossy Light',
    'Glossy Dark',
    'Native',
  ];

  LiquidTabBarTheme _themeForIndex(int index) {
    switch (index) {
      case 0: // Normal Light
        return const LiquidTabBarTheme();
      case 1: // Normal Dark
        return const LiquidTabBarTheme.dark();
      case 2: // Glossy Light
        return LiquidTabBarTheme(barStyle: LiquidBarStyle.glossy());
      case 3: // Glossy Dark
        return LiquidTabBarTheme.dark(barStyle: LiquidBarStyle.glossy());
      case 4:
        return LiquidTabBarTheme(barStyle: LiquidBarStyle.native());
      default:
        return const LiquidTabBarTheme();
    }
  }

  bool get _isDarkStyle => _styleIndex.isOdd;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkStyle
          ? ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0B0D11),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0A84FF),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
            )
          : ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8F9FA),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF007AFF),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
            ),
      child: Builder(
        builder: (context) => Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: Text(_styleLabels[_styleIndex]),
            actions: [
              TextButton(
                onPressed: () => setState(() =>
                    _styleIndex = (_styleIndex + 1) % _styleLabels.length),
                child: Text(
                  'Next →',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              ShowcaseContent(
                selected: _selected,
                controls: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, children: [
                      for (var i = 0; i < _styleLabels.length; i++)
                        ChoiceChip(
                          label: Text(_styleLabels[i]),
                          selected: _styleIndex == i,
                          onSelected: (_) => setState(() => _styleIndex = i),
                        ),
                    ]),
                    if (_styleIndex >= 4) ...[
                      const SizedBox(height: 8),
                      const Text('Content behind the bar'),
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < _backdropLabels.length; i++)
                          ChoiceChip(
                            label: Text(_backdropLabels[i]),
                            selected: _backdropIndex == i,
                            onSelected: (_) =>
                                setState(() => _backdropIndex = i),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
              if (_styleIndex >= 4 && _backdropIndex > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 200,
                  child: IgnorePointer(
                      child: Row(
                          key: const ValueKey('native-preview-backdrop'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Expanded(
                            child: ColoredBox(
                                color: _backdropIndex == 2
                                    ? const Color(0xFF18191D)
                                    : Colors.white)),
                        if (_backdropIndex == 3)
                          const Expanded(
                              child: ColoredBox(color: Color(0xFF18191D))),
                      ])),
                ),
              if (_styleIndex < 4 || _backdropIndex == 0)
                Positioned(
                  left: 30,
                  right: 30,
                  bottom: 36,
                  height: 110,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'WHITE\nTEXT',
                          style: TextStyle(
                            color: _isDarkStyle ? Colors.white : Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 88,
                          color: _isDarkStyle ? Colors.white : Colors.black,
                        ),
                        const Icon(Icons.favorite,
                            color: Color(0xFFFF3B45), size: 30),
                        const Icon(Icons.auto_awesome,
                            color: Color(0xFF4DA3FF), size: 30),
                        Text(
                          'GLASS',
                          style: TextStyle(
                            color: _isDarkStyle ? Colors.white : Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: LiquidTabBar(
            key: ValueKey('comparison-$_styleIndex'),
            shrinkOnScroll: false,
            selectedIndex: _selected,
            onSelected: (index) => setState(() => _selected = index),
            items: showcaseItems(),
            theme: _themeForIndex(_styleIndex),
          ),
        ),
      ),
    );
  }
}
