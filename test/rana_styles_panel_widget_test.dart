import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';

void main() {
  group('RanaStylesControls Tests', () {
    testWidgets('RanaInteractiveSlider renders label and value', (
      WidgetTester tester,
    ) async {
      var changedVal = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaInteractiveSlider(
              label: 'Test Tone',
              valueLabel: '+15',
              value: 15.0,
              min: -100,
              max: 100,
              onChanged: (val) {
                changedVal = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('TEST TONE'), findsOneWidget);
      expect(find.text('+15'), findsOneWidget);

      // Verify widget behaves correctly on drag interaction
      final slider = find.byType(RanaInteractiveSlider);
      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(changedVal, isNot(15.0));
    });

    testWidgets('RanaInteractiveUndertonePad renders labels and coordinates', (
      WidgetTester tester,
    ) async {
      double changedX = 0;
      double changedY = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaInteractiveUndertonePad(
              undertoneX: -0.2,
              undertoneY: 0.4,
              styleStrength: 80,
              onChanged: (x, y) {
                changedX = x;
                changedY = y;
              },
            ),
          ),
        ),
      );

      expect(find.text('UNDERTONE'), findsOneWidget);
      expect(find.text('-20 / +40'), findsOneWidget);
      expect(find.text('WARM'), findsOneWidget);
      expect(find.text('COOL'), findsOneWidget);
      expect(find.text('MAGENTA'), findsOneWidget);
      expect(find.text('GREEN'), findsOneWidget);

      final pad = find.byKey(const Key('undertone-pad'));
      final rect = tester.getRect(pad);

      // Tap near the top-right corner
      await tester.tapAt(rect.topRight + const Offset(-10, 10));
      await tester.pump();

      expect(changedX, isNot(0));
      expect(changedY, isNot(0));
    });
  });
}
