import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/widgets/compact_style_strip_widget.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';

void main() {
  const basePreset = PresetModel(
    id: 'test_preset',
    name: 'Test Preset',
    category: 'Classic',
    color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
    grain: PresetGrain(intensity: 0.4),
    vignette: PresetVignette(intensity: 0.5),
  );

  group('CompactStyleStripWidget Tests', () {
    testWidgets('renders nothing (SizedBox.shrink) when activePreset is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CompactStyleStripWidget(activePreset: null)),
        ),
      );

      expect(find.byType(CompactStyleStripWidget), findsOneWidget);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders default zeros when activePreset style block is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompactStyleStripWidget(activePreset: basePreset),
          ),
        ),
      );

      expect(find.text('TONE'), findsOneWidget);
      expect(find.text('COLOR'), findsOneWidget);
      expect(find.text('TEXTURE'), findsOneWidget);

      // Zeros formatting
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets(
      'renders correct rounded and formatted values when style has parameters',
      (WidgetTester tester) async {
        const styledPreset = PresetModel(
          id: 'test_preset',
          name: 'Test Preset',
          category: 'Classic',
          color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
          grain: PresetGrain(intensity: 0.4),
          vignette: PresetVignette(intensity: 0.5),
          style: RanaStyle(
            tone: 12.4, // Should round to +12
            color: -15.6, // Should round to -16
            texture: 25, // Should round to 25
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CompactStyleStripWidget(activePreset: styledPreset),
            ),
          ),
        );

        expect(find.text('TONE'), findsOneWidget);
        expect(find.text('+12'), findsOneWidget);

        expect(find.text('COLOR'), findsOneWidget);
        expect(find.text('-16'), findsOneWidget);

        expect(find.text('TEXTURE'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
      },
    );

    testWidgets('renders correct rounding behavior for edge values', (
      WidgetTester tester,
    ) async {
      const styledPreset = PresetModel(
        id: 'test_preset',
        name: 'Test Preset',
        category: 'Classic',
        color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
        grain: PresetGrain(intensity: 0.4),
        vignette: PresetVignette(intensity: 0.5),
        style: RanaStyle(
          tone: 0.1, // rounds to 0
          color: -0.9, // rounds to -1
          texture: 99.8, // rounds to 100
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompactStyleStripWidget(activePreset: styledPreset),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets(
      'renders effective activeStyle values over preset style defaults',
      (WidgetTester tester) async {
        const styledPreset = PresetModel(
          id: 'test_preset',
          name: 'Test Preset',
          category: 'Classic',
          color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
          grain: PresetGrain(intensity: 0.4),
          vignette: PresetVignette(intensity: 0.5),
          style: RanaStyle(tone: 10, color: 20, texture: 30),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CompactStyleStripWidget(
                activePreset: styledPreset,
                activeStyle: RanaStyle(tone: -22, color: 45, texture: 66),
              ),
            ),
          ),
        );

        expect(find.text('-22'), findsOneWidget);
        expect(find.text('+45'), findsOneWidget);
        expect(find.text('66'), findsOneWidget);
        expect(find.text('10'), findsNothing);
        expect(find.text('20'), findsNothing);
        expect(find.text('30'), findsNothing);
      },
    );
  });
}
