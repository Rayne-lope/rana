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
              value: 15,
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
      final trackFinder = find
          .descendant(
            of: find.byType(RanaInteractiveSlider),
            matching: find.byType(CustomPaint),
          )
          .last;
      final trackRect = tester.getRect(trackFinder);
      await tester.dragFrom(trackRect.center, const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(changedVal, isNot(15.0));
    });

    testWidgets('RanaInteractiveSlider compact options still change value', (
      WidgetTester tester,
    ) async {
      var changedVal = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 90,
                child: RanaInteractiveSlider(
                  label: 'Tone',
                  valueLabel: '0',
                  value: 0,
                  min: -100,
                  max: 100,
                  bottomPadding: 4,
                  labelGap: 4,
                  onChanged: (val) {
                    changedVal = val;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final trackFinder = find
          .descendant(
            of: find.byType(RanaInteractiveSlider),
            matching: find.byType(CustomPaint),
          )
          .last;
      final trackRect = tester.getRect(trackFinder);
      await tester.tapAt(Offset(trackRect.right - 24, trackRect.center.dy));
      await tester.pump();

      expect(changedVal, greaterThan(0));
    });

    testWidgets('RanaInteractiveSlider renders synchronized style readouts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RanaInteractiveSlider(
              label: 'Color',
              valueLabel: '+12',
              value: 12,
              min: -100,
              max: 100,
              toneReadout: '-8',
              colorReadout: '+12',
              warmthReadout: '-35',
              onChanged: _ignoreValue,
            ),
          ),
        ),
      );

      expect(find.text('TONE'), findsOneWidget);
      expect(find.text('COLOR'), findsNWidgets(2));
      expect(find.text('WARMTH'), findsOneWidget);
      expect(find.text('-8'), findsOneWidget);
      expect(find.text('+12'), findsNWidgets(2));
      expect(find.text('-35'), findsOneWidget);
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
      expect(rect.height, lessThanOrEqualTo(220));
      expect(
        tester.getRect(find.text('MAGENTA')).bottom,
        lessThanOrEqualTo(rect.top),
      );
      expect(
        tester.getRect(find.text('GREEN')).top,
        greaterThanOrEqualTo(rect.bottom),
      );
      expect(
        tester.getRect(find.text('WARM')).right,
        lessThanOrEqualTo(rect.left),
      );
      expect(
        tester.getRect(find.text('COOL')).left,
        greaterThanOrEqualTo(rect.right),
      );

      // Tap near the top-right corner
      await tester.tapAt(rect.topRight + const Offset(-10, 10));
      await tester.pump();

      expect(changedX, isNot(0));
      expect(changedY, isNot(0));
    });

    testWidgets('RanaInteractiveUndertonePad supports compact max size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                height: 230,
                child: RanaInteractiveUndertonePad(
                  undertoneX: 0.25,
                  undertoneY: -0.35,
                  styleStrength: 70,
                  maxPadSize: 188,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final padRect = tester.getRect(find.byKey(const Key('undertone-pad')));
      expect(padRect.height, lessThanOrEqualTo(188));
      expect(padRect.width, lessThanOrEqualTo(188));
    });

    testWidgets('RanaInteractiveUndertonePad snaps to the nearest grid point', (
      WidgetTester tester,
    ) async {
      double changedX = 0;
      double changedY = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaInteractiveUndertonePad(
              undertoneX: 0,
              undertoneY: 0,
              styleStrength: 100,
              onChanged: (x, y) {
                changedX = x;
                changedY = y;
              },
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('undertone-pad')));
      await tester.tapAt(Offset(rect.left + 1, rect.top + 1));
      expect(changedX, closeTo(-1, 0.0001));
      expect(changedY, closeTo(1, 0.0001));

      await tester.tapAt(rect.center);
      expect(changedX, closeTo(0, 0.0001));
      expect(changedY, closeTo(0, 0.0001));

      const paddingFraction = 0.085;
      final gridOrigin = Offset(
        rect.left + rect.width * paddingFraction,
        rect.top + rect.height * paddingFraction,
      );
      final gridSpan = rect.width * (1 - paddingFraction * 2);
      final betweenDots = gridOrigin + Offset(gridSpan * 0.35, gridSpan * 0.75);
      await tester.tapAt(betweenDots);
      expect(changedX, closeTo(-0.2, 0.0001));
      expect(changedY, closeTo(-0.6, 0.0001));

      await tester.dragFrom(
        rect.center,
        Offset(gridSpan * 0.3, -gridSpan * 0.3),
      );
      expect(changedX, closeTo(0.6, 0.0001));
      expect(changedY, closeTo(0.6, 0.0001));

      await tester.tapAt(Offset(rect.right - 1, rect.bottom - 1));
      expect(changedX, closeTo(1, 0.0001));
      expect(changedY, closeTo(-1, 0.0001));
    });

    testWidgets('RanaInteractiveUndertonePad shrinks in tight vertical space', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 180,
                child: RanaInteractiveUndertonePad(
                  undertoneX: -0.91,
                  undertoneY: 0.53,
                  styleStrength: 80,
                  onChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('UNDERTONE'), findsOneWidget);
      expect(find.text('-100 / +60'), findsOneWidget);

      final padRect = tester.getRect(find.byKey(const Key('undertone-pad')));
      expect(padRect.height, lessThanOrEqualTo(150));
    });
  });
}

void _ignoreValue(double _) {}
