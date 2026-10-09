import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auto_fold_source_resolver.dart';

// Flutter-only fixture isolates source resolution from existing package imports.
class _KeptPage extends StatefulWidget {
  const _KeptPage(this.controller, {this.second});
  final ScrollController controller;
  final ScrollController? second;
  @override
  State<_KeptPage> createState() => _KeptPageState();
}

class _KeptPageState extends State<_KeptPage>
    with AutomaticKeepAliveClientMixin<_KeptPage> {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget list(ScrollController controller) => CustomScrollView(
      controller: controller,
      slivers: [SliverList.builder(itemCount: 100, itemBuilder: (_, i) =>
        SizedBox(height: 60, child: Text('Item $i')))],
    );
    if (widget.second == null) return list(widget.controller);
    return Column(children: [Expanded(child: list(widget.controller)),
      Expanded(child: list(widget.second!))]);
  }
}

void main() {
  for (final decorations in [0, 1000]) {
    testWidgets('measure public resolver without package imports: $decorations decorations', (tester) async {
      final pager = PageController();
      final scroll = ScrollController();
      final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true,
        measure: true);
      var accepted = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (boundary) =>
        NotificationListener<ScrollNotification>(onNotification: (n) {
          if (n is ScrollUpdateNotification && resolver.accepts(n, boundary)) {
            accepted++;
          }
          return false;
        }, child: PageView(controller: pager, children: [Column(children: [
          if (decorations > 0) SizedBox(height: 1, child: Stack(children:
            List.generate(decorations, (_) => const Positioned(top: 0,
              child: SizedBox(width: 1, height: 1))))),
          Expanded(child: _KeptPage(scroll)),
        ])]))))));
      await tester.pumpAndSettle();
      final animation = scroll.animateTo(4000,
        duration: const Duration(seconds: 5), curve: Curves.linear);
      await tester.pump();
      for (var i = 0; i < 610; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      await animation;
      expect(accepted, greaterThan(590));
      final samples = resolver.samplesMicros.skip(30).toList()..sort();
      debugPrint('AUTO_FOLD_COMPAT_BENCH decorations=$decorations '
        'samples=${samples.length} median_us=${samples[samples.length ~/ 2]} '
        'p95_us=${samples[(samples.length * 0.95).floor()]} '
        'max_us=${samples.last} discovery_visits=${resolver.discoveryVisits}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      pager.dispose();
      scroll.dispose();
    }, tags: ['benchmark']);
  }

  testWidgets('direct smart source rejects sibling lists without a PageView', (tester) async {
    final pages = List.generate(2, (_) => ScrollController());
    final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true);
    var accepted = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (boundary) =>
      NotificationListener<ScrollNotification>(onNotification: (n) {
        if (n is ScrollUpdateNotification && resolver.accepts(n, boundary)) {
          accepted++;
        }
        return false;
      }, child: Column(children: [for (final controller in pages)
        Expanded(child: ListView.builder(controller: controller,
          itemCount: 100, itemBuilder: (_, i) => SizedBox(height: 60,
            child: Text('Item $i'))))]))))));
    for (final page in pages) { page.jumpTo(100); }
    await tester.pumpAndSettle();
    expect(accepted, 0);
    expect(resolver.ambiguityRejections, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final page in pages) { page.dispose(); }
  });

  for (final rtl in [false, true]) {
    testWidgets('public source/page resolution, inactive and moving pages: RTL=$rtl', (tester) async {
      final pager = PageController();
      final pages = List.generate(3, (_) => ScrollController());
      final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true);
      var accepted = 0;
      var rejected = 0;
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: Builder(builder: (boundary) =>
          NotificationListener<ScrollNotification>(onNotification: (n) {
            if (n is ScrollUpdateNotification && n.metrics.axis == Axis.vertical) {
              resolver.accepts(n, boundary) ? accepted++ : rejected++;
            }
            return false;
          }, child: PageView(controller: pager, children:
            pages.map((controller) => _KeptPage(controller)).toList())))),
      )));
      pages.first.jumpTo(100);
      await tester.pumpAndSettle();
      expect(accepted, 1);
      pager.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(pages.first.hasClients, isTrue);
      pages.first.jumpTo(200);
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(rejected, 1);
      pages[1].jumpTo(100);
      await tester.pumpAndSettle();
      expect(accepted, 2);
      final transition = pager.animateToPage(2,
        duration: const Duration(milliseconds: 400), curve: Curves.linear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      pages[1].jumpTo(200);
      await tester.pump();
      expect(accepted, 2);
      expect(rejected, 2);
      await tester.pumpAndSettle();
      await transition;
      pages[2].jumpTo(100);
      await tester.pumpAndSettle();
      expect(accepted, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      pager.dispose();
      for (final controller in pages) { controller.dispose(); }
    });
  }

  testWidgets('both sibling sources rejected, including dynamic removal/addition', (tester) async {
    final pager = PageController();
    final first = ScrollController();
    final second = ScrollController();
    final resolver = PrototypeScrollSourceResolver(rejectAmbiguous: true);
    var showSecond = true;
    var accepted = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (boundary) =>
      NotificationListener<ScrollNotification>(onNotification: (n) {
        if (n is ScrollUpdateNotification && resolver.accepts(n, boundary)) {
          accepted++;
        }
        return false;
      }, child: PageView(controller: pager, children: [StatefulBuilder(
        builder: (_, setState) {
          rebuild = setState;
          return _KeptPage(first, second: showSecond ? second : null);
        },
      )]))))));
    first.jumpTo(100);
    second.jumpTo(100);
    await tester.pumpAndSettle();
    expect(accepted, 0);
    expect(resolver.ambiguityRejections, 2);
    rebuild(() => showSecond = false);
    await tester.pumpAndSettle();
    first.jumpTo(200);
    await tester.pumpAndSettle();
    expect(accepted, 1);
    rebuild(() => showSecond = true);
    await tester.pumpAndSettle();
    first.jumpTo(300);
    await tester.pumpAndSettle();
    expect(accepted, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pager.dispose();
    first.dispose();
    second.dispose();
  });
}
