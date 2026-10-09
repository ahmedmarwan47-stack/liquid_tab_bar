import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar_example/examples/four_style_comparison.dart';

void main() {
  testWidgets('Native backdrop controls paint panels with full height',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FourStyleComparison()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Native'), findsOneWidget);
    expect(find.text('Native Light'), findsNothing);
    expect(find.text('Native Dark'), findsNothing);
    Finder panel(Color color) => find.byWidgetPredicate((widget) =>
        widget is ColoredBox && widget.color == color && widget.child == null);
    expect(tester.getSize(panel(Colors.white)).height, 200);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Charcoal'));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel(const Color(0xFF18191D))).height, 200);
    expect(panel(Colors.white), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Split'));
    await tester.pumpAndSettle();
    final white = tester.getRect(panel(Colors.white));
    final black = tester.getRect(panel(const Color(0xFF18191D)));
    expect(white.height, 200);
    expect(black.height, 200);
    expect(white.right, black.left);
    expect(white.width, black.width);
    expect(tester.takeException(), isNull);
  });
}
