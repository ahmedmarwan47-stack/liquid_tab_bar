import 'package:flutter/material.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'showcase_content.dart';

class DarkMaterialExample extends StatefulWidget {
  const DarkMaterialExample({super.key});

  @override
  State<DarkMaterialExample> createState() => _DarkMaterialExampleState();
}

class _DarkMaterialExampleState extends State<DarkMaterialExample> {
  int _selected = 0;
  bool _glossy = false;

  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B0D11),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0A84FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        child: Builder(
          builder: (context) => Scaffold(
            extendBody: true,
            appBar: AppBar(title: const Text('Dark material')),
            body: Stack(
              children: [
                ShowcaseContent(
                  selected: _selected,
                  controls: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Normal Dark'),
                        selected: !_glossy,
                        onSelected: (_) => setState(() => _glossy = false),
                      ),
                      ChoiceChip(
                        label: const Text('Glossy Dark'),
                        selected: _glossy,
                        onSelected: (_) => setState(() => _glossy = true),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 180,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Expanded(
                          child: ColoredBox(color: const Color(0xFFE53935)),
                        ),
                        Expanded(
                          child: ColoredBox(color: const Color(0xFF2878E8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: LiquidTabBar(
              shrinkOnScroll: false,
              selectedIndex: _selected,
              onSelected: (index) => setState(() => _selected = index),
              items: showcaseItems(),
              theme: _glossy
                  ? LiquidTabBarTheme.dark(
                      barStyle: LiquidBarStyle.glossy(),
                    )
                  : const LiquidTabBarTheme.dark(),
            ),
          ),
        ),
      );
}
