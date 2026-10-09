import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

const _items = [
  LiquidTabItem.icon(label: 'Home', icon: Icons.home),
  LiquidTabItem.icon(label: 'Explore', icon: Icons.explore),
  LiquidTabItem.icon(label: 'Saved', icon: Icons.bookmark),
  LiquidTabItem.icon(label: 'Profile', icon: Icons.person),
  LiquidTabItem.icon(label: 'More', icon: Icons.more_horiz),
];

class _KeyboardHarness extends StatefulWidget {
  const _KeyboardHarness({
    required this.keyboardHeight,
    required this.liftAboveKeyboard,
    required this.resizeToAvoidBottomInset,
    required this.useLiquidTabBarScaffold,
    required this.onSelected,
    super.key,
  });

  final double keyboardHeight;
  final bool liftAboveKeyboard;
  final bool resizeToAvoidBottomInset;
  final bool useLiquidTabBarScaffold;
  final ValueChanged<int> onSelected;

  @override
  State<_KeyboardHarness> createState() => _KeyboardHarnessState();
}

class _KeyboardHarnessState extends State<_KeyboardHarness> {
  final FocusNode focusNode = FocusNode();
  int selectedIndex = 0;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = LiquidTabBar(
      material: LiquidTabBarMaterial.opaque,
      items: _items,
      selectedIndex: selectedIndex,
      liftAboveKeyboard: widget.liftAboveKeyboard,
      warnOnMissingExtendBodyPadding: false,
      shrinkOnScroll: false,
      onSelected: (index) {
        widget.onSelected(index);
        setState(() => selectedIndex = index);
      },
    );
    final body = TextField(
      focusNode: focusNode,
      decoration: const InputDecoration(labelText: 'Message'),
    );

    final Widget page;
    if (widget.useLiquidTabBarScaffold) {
      page = LiquidTabBarScaffold(
        tabBar: tabBar,
        body: body,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      );
    } else {
      page = Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        body: body,
        bottomNavigationBar: tabBar,
      );
    }

    return MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        viewInsets: EdgeInsets.only(bottom: widget.keyboardHeight),
        viewPadding: const EdgeInsets.only(bottom: 24),
      ),
      child: MaterialApp(home: page),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHarness(
    WidgetTester tester, {
    required GlobalKey<_KeyboardHarnessState> key,
    required double keyboardHeight,
    bool liftAboveKeyboard = true,
    bool resizeToAvoidBottomInset = true,
    bool useLiquidTabBarScaffold = false,
    required List<int> calls,
  }) async {
    await tester.pumpWidget(
      _KeyboardHarness(
        key: key,
        keyboardHeight: keyboardHeight,
        liftAboveKeyboard: liftAboveKeyboard,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        useLiquidTabBarScaffold: useLiquidTabBarScaffold,
        onSelected: calls.add,
      ),
    );
    await tester.pump();
  }

  Future<void> focusTextField(WidgetTester tester) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
  }

  Finder dropletFinder() => find
      .descendant(
        of: find.byType(LiquidTabBar),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
            return false;
          }
          final decoration = widget.decoration as BoxDecoration;
          return decoration.borderRadius is BorderRadius &&
              decoration.boxShadow == null &&
              decoration.border == null &&
              decoration.gradient == null;
        }),
      )
      .first;

  Positioned dropletPositioned(WidgetTester tester) {
    final ancestors = tester
        .widgetList<Positioned>(
          find.ancestor(of: dropletFinder(), matching: find.byType(Positioned)),
        )
        .toList();
    expect(ancestors.length, greaterThanOrEqualTo(2));
    return ancestors[1];
  }

  Future<void> usePhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('LiquidTabBar keyboard hit testing', () {
    for (final drag in [false, true]) {
      testWidgets(
          '${drag ? 'drag' : 'held destination'} release settles visually before callback',
          (tester) async {
        await usePhoneSize(tester);
        final key = GlobalKey<_KeyboardHarnessState>();
        final calls = <int>[];
        await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);
        final restingHeight = tester.getRect(dropletFinder()).height;
        final destination =
            tester.getCenter(find.text(drag ? 'Profile' : 'Explore'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.text(drag ? 'Home' : 'Explore')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        if (drag) {
          for (final label in ['Explore', 'Saved', 'Profile']) {
            await gesture.moveTo(tester.getCenter(find.text(label)) +
                Offset(label == 'Profile' ? 12 : 0, 0));
            await tester.pump(const Duration(milliseconds: 55));
            expect(calls, isEmpty);
          }
        }
        expect(calls, isEmpty);
        await gesture.up();
        expect(calls, isEmpty);
        var elapsedMs = 0;
        var previousLens = tester.getRect(dropletFinder());
        while (calls.isEmpty && elapsedMs < 1000) {
          previousLens = tester.getRect(dropletFinder());
          await tester.pump(const Duration(milliseconds: 4));
          elapsedMs += 4;
        }
        debugPrint(
            '${drag ? 'drag' : 'hold'} release callback: ${elapsedMs}ms');
        final baselineMs = drag ? 284 : 264;
        expect(
            elapsedMs,
            inInclusiveRange(
                (baselineMs * 0.58).ceil(), (baselineMs * 0.70).floor()));
        expect(calls, [drag ? 3 : 1]);
        final lensAtCommit = tester.getRect(dropletFinder());
        expect(lensAtCommit.center.dx, closeTo(destination.dx, 5));
        expect(lensAtCommit.height, closeTo(restingHeight, 1.5));
        expect((lensAtCommit.center.dx - previousLens.center.dx).abs(),
            lessThan(0.3));
        await tester.pumpAndSettle();
        expect(calls, [drag ? 3 : 1]);
        expect(tester.getRect(dropletFinder()).center.dx,
            closeTo(destination.dx, 0.1));
      });
    }

    testWidgets(
        'centered drag release waits for a stopped expanded press to retract',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);
      final restingHeight = tester.getRect(dropletFinder()).height;
      final saved = tester.getCenter(find.text('Saved'));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(saved);
      await tester.pump(const Duration(milliseconds: 16));
      expect(calls, isEmpty);
      expect(tester.getRect(dropletFinder()).height,
          greaterThan(restingHeight + 10));
      await gesture.up();
      expect(calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 16));
      expect(calls, isEmpty);
      await tester.pumpAndSettle();
      expect(calls, [2]);
      expect(tester.getRect(dropletFinder()).center.dx, closeTo(saved.dx, 0.1));
      expect(
          tester.getRect(dropletFinder()).height, closeTo(restingHeight, 0.1));
    });

    testWidgets('lifted tab bar remains inside the visible area above IME',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);

      final keyboardTop = 800 - 300;
      for (final label in ['Home', 'Explore', 'Saved', 'Profile', 'More']) {
        expect(tester.getRect(find.text(label)).bottom, lessThan(keyboardTop));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('visible lifted coordinates receive tab pointer events',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);

      final before = dropletPositioned(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Explore')),
      );
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pump(const Duration(milliseconds: 350));

      expect(dropletPositioned(tester).left, greaterThan(before.left!));
      expect(key.currentState!.selectedIndex, 0);
      expect(calls, isEmpty);
      expect(key.currentState!.focusNode.hasFocus, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, equals([1]));
    });

    testWidgets(
        'quick tap commits on release while travel continues with IME open',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Explore')),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(key.currentState!.selectedIndex, 0);
      expect(calls, isEmpty);
      expect(key.currentState!.focusNode.hasFocus, isTrue);

      await gesture.up();
      expect(key.currentState!.selectedIndex, 1);
      expect(calls, equals([1]));

      await tester.pumpAndSettle();
      expect(key.currentState!.selectedIndex, 1);
      expect(calls, equals([1]));
      expect(
        tester.getRect(dropletFinder()).center.dx,
        closeTo(tester.getCenter(find.text('Explore')).dx, 20),
      );
    });

    testWidgets(
        'hold destination and redirect scrub without intermediate commits',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);

      final explore = tester.getCenter(find.text('Explore'));
      final saved = tester.getCenter(find.text('Saved'));
      final profile = tester.getCenter(find.text('Profile'));
      final initialDroplet = dropletPositioned(tester);
      final gesture = await tester.startGesture(explore);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(dropletPositioned(tester).left, greaterThan(initialDroplet.left!));
      expect(
        tester.getRect(dropletFinder()).center.dx,
        closeTo(explore.dx, 20),
      );
      expect(key.currentState!.selectedIndex, 0);
      expect(calls, isEmpty);
      expect(key.currentState!.focusNode.hasFocus, isTrue);

      for (final destination in [saved, profile, explore, saved]) {
        await gesture.moveTo(destination);
        await tester.pump(const Duration(milliseconds: 55));
        expect(key.currentState!.selectedIndex, 0);
        expect(calls, isEmpty);
      }

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(key.currentState!.selectedIndex, 0);
      expect(calls, isEmpty);

      await tester.pumpAndSettle();
      expect(key.currentState!.selectedIndex, 2);
      expect(calls, equals([2]));
      expect(
        tester.getRect(dropletFinder()).center.dx,
        closeTo(saved.dx, 20),
      );
    });

    testWidgets('cancelled drag returns the lens to the selected tab',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      final home = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(home);
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveTo(tester.getCenter(find.text('Saved')));
      await tester.pump(const Duration(milliseconds: 40));
      expect(calls, isEmpty);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(key.currentState!.selectedIndex, 0);
      expect(tester.getRect(dropletFinder()).center.dx, closeTo(home.dx, 20));
    });

    testWidgets('repeated selection does not dispatch twice', (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      await tester.tap(find.text('Home'), warnIfMissed: false);
      expect(calls, isEmpty);
      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      await tester.pumpAndSettle();
      expect(key.currentState!.selectedIndex, 1);
      expect(tester.getRect(dropletFinder()).center.dx,
          closeTo(tester.getCenter(find.text('Explore')).dx, 20));
    });

    testWidgets('rapid taps retarget the lens without a late callback',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      await tester.tap(find.text('Saved'), warnIfMissed: false);
      expect(calls, equals([1, 2]));
      await tester.pumpAndSettle();
      expect(calls, equals([1, 2]));
      expect(key.currentState!.selectedIndex, 2);
      expect(tester.getRect(dropletFinder()).center.dx,
          closeTo(tester.getCenter(find.text('Saved')).dx, 20));
    });

    testWidgets('new tap cancels an earlier drag release', (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Home')));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      expect(calls, isEmpty);

      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      await tester.pumpAndSettle();
      expect(calls, equals([1]));
      expect(key.currentState!.selectedIndex, 1);
      expect(tester.getRect(dropletFinder()).center.dx,
          closeTo(tester.getCenter(find.text('Explore')).dx, 20));
    });

    testWidgets('empty-space interruption restores the selected lens',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      final home = tester.getCenter(find.text('Home'));
      final explore = tester.getCenter(find.text('Explore'));
      final gesture = await tester.startGesture(home);
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      expect(calls, isEmpty);

      final emptySpace = Offset((home.dx + explore.dx) / 2, home.dy);
      final interruption = await tester.startGesture(emptySpace);
      await tester.pump(const Duration(milliseconds: 20));
      await interruption.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(key.currentState!.selectedIndex, 0);
      expect(tester.getRect(dropletFinder()).center.dx, closeTo(home.dx, 20));
    });

    testWidgets('cancel after an immediate tap restores its selected lens',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Home')));
      await gesture.moveTo(tester.getCenter(find.text('Saved')));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(calls, equals([1]));
      expect(key.currentState!.selectedIndex, 1);
      expect(tester.getRect(dropletFinder()).center.dx,
          closeTo(tester.getCenter(find.text('Explore')).dx, 20));
    });

    testWidgets('cancel after interrupting a pending drag restores selection',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      final home = tester.getCenter(find.text('Home'));
      final drag = await tester.startGesture(home);
      await tester.pump(const Duration(milliseconds: 40));
      await drag.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump(const Duration(milliseconds: 16));
      await drag.up();
      expect(calls, isEmpty);

      final interruption =
          await tester.startGesture(tester.getCenter(find.text('Explore')));
      await tester.pump(const Duration(milliseconds: 20));
      await interruption.cancel();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(key.currentState!.selectedIndex, 0);
      expect(tester.getRect(dropletFinder()).center.dx, closeTo(home.dx, 20));
    });

    testWidgets('rapid reversal through a moving droplet ends at selection',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(tester, key: key, keyboardHeight: 0, calls: calls);

      await tester.tap(find.text('Explore'), warnIfMissed: false);
      expect(calls, equals([1]));
      await tester.tap(find.text('Home'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, equals([1, 0]));
      expect(key.currentState!.selectedIndex, 0);
      expect(tester.getRect(dropletFinder()).center.dx,
          closeTo(tester.getCenter(find.text('Home')).dx, 20));
    });

    testWidgets('current droplet press works and empty space stays inert',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);

      final currentPress = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.home)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, isEmpty);
      await currentPress.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      final bar = tester.getRect(find.byType(LiquidTabBar));
      final homeCenter = tester.getCenter(find.text('Home'));
      final emptySpace = Offset(bar.left + 22, homeCenter.dy);
      final emptyPress = await tester.startGesture(emptySpace);
      await emptyPress.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(calls, isEmpty);
      expect(key.currentState!.selectedIndex, 0);
      await emptyPress.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    for (final useLiquidScaffold in [false, true]) {
      for (final resize in [false, true]) {
        testWidgets(
          'layout hit testing works with ${useLiquidScaffold ? 'LiquidTabBarScaffold' : 'Scaffold'} resizeToAvoidBottomInset=$resize',
          (tester) async {
            await usePhoneSize(tester);
            final key = GlobalKey<_KeyboardHarnessState>();
            final calls = <int>[];
            await pumpHarness(
              tester,
              key: key,
              keyboardHeight: 280,
              resizeToAvoidBottomInset: resize,
              useLiquidTabBarScaffold: useLiquidScaffold,
              calls: calls,
            );
            await focusTextField(tester);

            await tester.tapAt(tester.getCenter(find.text('Saved')));
            await tester.pumpAndSettle();
            expect(key.currentState!.selectedIndex, 2);
            expect(calls, equals([2]));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('liftAboveKeyboard false preserves normal host layout',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        liftAboveKeyboard: false,
        resizeToAvoidBottomInset: false,
        calls: calls,
      );
      await focusTextField(tester);

      final barRect = tester.getRect(find.byType(LiquidTabBar));
      expect(barRect.height, closeTo(LiquidTabBar.barHeight + 20, 0.001));
      expect(tester.getRect(find.text('Home')).bottom, greaterThan(500));
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard close and repeated transitions leave no stale state',
        (tester) async {
      await usePhoneSize(tester);
      final key = GlobalKey<_KeyboardHarnessState>();
      final calls = <int>[];
      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 0,
        calls: calls,
      );
      final homeRect = tester.getRect(find.text('Home'));

      for (var i = 0; i < 3; i++) {
        await pumpHarness(
          tester,
          key: key,
          keyboardHeight: 300,
          calls: calls,
        );
        await focusTextField(tester);
        expect(tester.getRect(find.text('Home')).bottom, lessThan(500));
        await pumpHarness(
          tester,
          key: key,
          keyboardHeight: 0,
          calls: calls,
        );
        expect(tester.getRect(find.text('Home')).top,
            closeTo(homeRect.top, 0.001));
      }

      await pumpHarness(
        tester,
        key: key,
        keyboardHeight: 300,
        calls: calls,
      );
      await focusTextField(tester);
      await tester.tap(find.text('Saved'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(key.currentState!.selectedIndex, 2);
      expect(calls, equals([2]));
      expect(tester.takeException(), isNull);
    });
  });
}
