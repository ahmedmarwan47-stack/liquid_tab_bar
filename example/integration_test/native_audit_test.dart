import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

const _auditCycles =
    int.fromEnvironment('NATIVE_AUDIT_CYCLES', defaultValue: 20);
const _tracked = {
  '_LiquidTabBarState',
  '_GlassSurfaceState',
  '_DropletGlassSurfaceState',
  '_BackdropContrast'
};
Future<Map<String, int>> _liveObjects() async {
  final service = await developer.Service.getInfo();
  final client = HttpClient();
  try {
    final request = await client.getUrl(service.serverUri!
        .resolve('getAllocationProfile')
        .replace(queryParameters: {
      'isolateId': developer.Service.getIsolateId(Isolate.current)!,
      'gc': 'true'
    }));
    final response = await request.close();
    final data = jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>;
    final counts = {for (final name in _tracked) name: 0};
    for (final member in result['members'] as List<dynamic>) {
      final name = member['class']['name'] as String;
      if (_tracked.contains(name)) {
        counts[name] = member['instancesCurrent'] as int;
      }
    }
    return counts;
  } finally {
    client.close(force: true);
  }
}

class _AuditPage extends StatefulWidget {
  const _AuditPage({super.key});
  static int iconBuilds = 0;
  @override
  State<_AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<_AuditPage> {
  final nav = LiquidTabBarController();
  final text = TextEditingController();
  final focus = FocusNode();
  int selected = 0;
  @override
  void dispose() {
    nav.dispose();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: ColoredBox(color: Colors.white)),
              Expanded(child: ColoredBox(color: Color(0xFF18191D))),
            ]),
        bottomNavigationBar: LiquidTabBar(
          controller: nav,
          selectedIndex: selected,
          shrinkOnScroll: false,
          theme: LiquidTabBarTheme(barStyle: LiquidBarStyle.native()),
          onSelected: (value) => setState(() => selected = value),
          items: [
            LiquidTabItem.icon(
                label: 'Home',
                icon: Icons.home,
                iconBuilder: (color, selected) {
                  _AuditPage.iconBuilds++;
                  return Icon(Icons.home, color: color);
                }),
            const LiquidTabItem.icon(label: 'Browse', icon: Icons.explore),
            const LiquidTabItem.icon(label: 'Saved', icon: Icons.bookmark)
          ],
          separateAction: LiquidTabAction.search(
              controller: text, focusNode: focus, hintText: 'Native search'),
          warnOnMissingExtendBodyPadding: false,
        ),
      );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Native shader, idle builds, keyboard and repeated disposal audit',
      (tester) async {
    await LiquidGlass.load();
    expect(LiquidGlass.supported, isTrue);
    final timings = <ui.FrameTiming>[];
    void onTimings(List<ui.FrameTiming> frames) => timings.addAll(frames);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    addTearDown(
        () => SchedulerBinding.instance.removeTimingsCallback(onTimings));
    final key = GlobalKey<_AuditPageState>();
    Future<void> mount(int cycle) async {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              brightness: cycle.isEven ? Brightness.light : Brightness.dark),
          home: _AuditPage(key: key)));
      await tester.pumpAndSettle();
    }

    Future<void> unmount() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await mount(0);
    await unmount();
    final before = await _liveObjects();
    var keyboardShown = 0;
    // A completed helper releases the keyboard context before the final GC.
    Future<void> exerciseSearch() async {
      key.currentState!.nav.openSearch();
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(TextField)));
      await tester.enterText(find.byType(TextField), 'native audit');
      expect(key.currentState!.focus.hasFocus, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      final inset =
          tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
      if (inset > 0) {
        keyboardShown++;
        expect(
            tester.getRect(find.byType(TextField)).bottom,
            lessThanOrEqualTo(
                tester.view.physicalSize.height / tester.view.devicePixelRatio -
                    inset));
      }
      key.currentState!.nav.closeSearch();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    }

    final checkpoints = <Map<String, int>>[];
    for (var cycle = 0; cycle < _auditCycles; cycle++) {
      await mount(cycle);
      final idle = _AuditPage.iconBuilds;
      await tester.pump(const Duration(milliseconds: 100));
      expect(_AuditPage.iconBuilds, idle, reason: 'idle cycle $cycle');
      for (final entry
          in {Icons.explore: 1, Icons.bookmark: 2, Icons.home: 0}.entries) {
        await tester.tapAt(tester.getCenter(find.byIcon(entry.key)));
        await tester.pumpAndSettle();
        expect(key.currentState!.selected, entry.value);
      }
      if (cycle % 5 == 0) await exerciseSearch();
      await unmount();
      expect(tester.takeException(), isNull);
      if ((cycle + 1) % 5 == 0) checkpoints.add(await _liveObjects());
    }
    // Let platform text input, gesture callbacks and retired engine frames drain.
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    final after = await _liveObjects();

    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final report = <String, Object?>{
      'environment':
          'iOS simulator debug; diagnostic timings, not a weak-device benchmark',
      'cycles': _auditCycles,
      'tabTransitions': _auditCycles * 3,
      'searchCycles': (_auditCycles / 5).ceil(),
      'nativeKeyboardShownCycles': keyboardShown,
      'retainedBefore': before,
      'retainedAfter': after,
      'retentionCheckpoints': checkpoints,
      'frames': timings.length,
      'rasterMedianMs': raster.isEmpty ? null : raster[raster.length ~/ 2],
      'rasterP95Ms':
          raster.isEmpty ? null : raster[(raster.length * 0.95).floor()],
    };
    binding.reportData = report;
    debugPrint('NATIVE_AUDIT ${jsonEncode(report)}');
    // Flutter caches its last text input connection, which can retain the last
    // disposed EditableText's semantics and one bar. Require bounded retention
    // at every checkpoint, with no retained shader state.
    for (final counts in [...checkpoints, after]) {
      expect(counts['_LiquidTabBarState'], lessThanOrEqualTo(1));
      expect(counts['_BackdropContrast'], lessThanOrEqualTo(5));
      expect(counts['_GlassSurfaceState'], before['_GlassSurfaceState']);
      expect(counts['_DropletGlassSurfaceState'],
          before['_DropletGlassSurfaceState']);
    }
  });
}
