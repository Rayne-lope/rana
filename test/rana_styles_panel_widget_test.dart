import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/widgets/rana_styles_panel_widget.dart';
import 'package:rana/features/preset/model/rana_style.dart';

void main() {
  group('RanaStylesPanelWidget Tests', () {
    testWidgets('renders all style sliders and action buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaStylesPanelWidget(
              activePresetName: 'Rana Warm',
              style: const RanaStyle(
                tone: 12,
                color: -8,
                texture: 40,
                styleStrength: 70,
                undertoneX: -0.35,
                undertoneY: 0.42,
              ),
              onStyleChanged: (_) {},
              onReset: () {},
              onApply: () {},
              onSaveAsStyle: () {},
            ),
          ),
        ),
      );

      expect(find.text('RANA STYLE'), findsOneWidget);
      expect(find.text('RANA WARM'), findsOneWidget);
      expect(find.text('TONE'), findsOneWidget);
      expect(find.text('COLOR'), findsOneWidget);
      expect(find.text('TEXTURE'), findsOneWidget);
      expect(find.text('STYLE STRENGTH'), findsOneWidget);
      expect(find.text('UNDERTONE'), findsOneWidget);
      expect(find.text('WARM'), findsOneWidget);
      expect(find.text('COOL'), findsOneWidget);
      expect(find.text('MAGENTA'), findsOneWidget);
      expect(find.text('GREEN'), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
      expect(find.text('-8'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('-35 / +42'), findsOneWidget);
      expect(find.text('RESET'), findsOneWidget);
      expect(find.text('APPLY'), findsOneWidget);
      expect(find.text('SAVE STYLE'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(4));
      expect(find.byKey(const Key('undertone-pad')), findsOneWidget);
    });

    testWidgets('emits updated style values from each slider', (
      WidgetTester tester,
    ) async {
      final emittedStyles = <RanaStyle>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaStylesPanelWidget(
              activePresetName: 'Rana Warm',
              style: const RanaStyle(
                tone: 1,
                color: 2,
                texture: 3,
                styleStrength: 4,
              ),
              onStyleChanged: emittedStyles.add,
              onReset: () {},
              onApply: () {},
              onSaveAsStyle: () {},
            ),
          ),
        ),
      );

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      sliders[0].onChanged!(24);
      sliders[1].onChanged!(-18);
      sliders[2].onChanged!(42);
      sliders[3].onChanged!(88);

      expect(emittedStyles[0].tone, equals(24));
      expect(emittedStyles[0].color, equals(2));
      expect(emittedStyles[1].color, equals(-18));
      expect(emittedStyles[2].texture, equals(42));
      expect(emittedStyles[3].styleStrength, equals(88));
    });

    testWidgets('emits updated undertone values from the direction pad', (
      WidgetTester tester,
    ) async {
      final emittedStyles = <RanaStyle>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaStylesPanelWidget(
              activePresetName: 'Rana Warm',
              style: const RanaStyle(
                tone: 1,
                color: 2,
                texture: 3,
                styleStrength: 4,
              ),
              onStyleChanged: emittedStyles.add,
              onReset: () {},
              onApply: () {},
              onSaveAsStyle: () {},
            ),
          ),
        ),
      );

      final pad = find.byKey(const Key('undertone-pad'));
      final rect = tester.getRect(pad);
      await tester.tapAt(rect.topRight + const Offset(-2, 2));
      await tester.pump();

      expect(emittedStyles, isNotEmpty);
      expect(emittedStyles.last.undertoneX, closeTo(1.0, 0.05));
      expect(emittedStyles.last.undertoneY, closeTo(1.0, 0.05));
      expect(emittedStyles.last.tone, equals(1));
      expect(emittedStyles.last.color, equals(2));
    });

    testWidgets('invokes reset apply and save callbacks', (
      WidgetTester tester,
    ) async {
      var resetCount = 0;
      var applyCount = 0;
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RanaStylesPanelWidget(
              activePresetName: 'Rana Warm',
              style: const RanaStyle(),
              onStyleChanged: (_) {},
              onReset: () => resetCount++,
              onApply: () => applyCount++,
              onSaveAsStyle: () => saveCount++,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('RESET'));
      await tester.tap(find.text('RESET'));
      await tester.ensureVisible(find.text('APPLY'));
      await tester.tap(find.text('APPLY'));
      await tester.ensureVisible(find.text('SAVE STYLE'));
      await tester.tap(find.text('SAVE STYLE'));

      expect(resetCount, equals(1));
      expect(applyCount, equals(1));
      expect(saveCount, equals(1));
    });
  });
}
