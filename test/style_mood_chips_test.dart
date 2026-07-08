import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/widgets/style_mood_chips.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';

void main() {
  group('StyleMoodChips', () {
    const kodakGold = PresetModel(
      id: 'gold_200',
      name: 'Kodak Gold 200',
      category: 'Vintage',
      color: PresetColor(temperature: 0.24, contrast: 0.12, saturation: 0.16),
      grain: PresetGrain(intensity: 0.22),
      vignette: PresetVignette(intensity: 0.04),
      style: RanaStyle(tone: -8, color: 14, undertoneX: -0.42),
    );

    const triX = PresetModel(
      id: 'tri_x_400',
      name: 'Kodak Tri-X 400',
      category: 'Classic',
      color: PresetColor(temperature: 0, contrast: 0.34, saturation: -1),
      grain: PresetGrain(intensity: 0.48),
      vignette: PresetVignette(intensity: 0.02),
      style: RanaStyle(tone: 12),
    );

    testWidgets('renders color mood chips and handles selection', (
      WidgetTester tester,
    ) async {
      RanaStyleMood? selectedMood;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StyleMoodChips(
              activePreset: kodakGold,
              activeStyle: RanaStyleMood.coolRose.resolve(kodakGold),
              onSelected: (mood) {
                selectedMood = mood;
              },
            ),
          ),
        ),
      );

      expect(find.text('STANDARD'), findsOneWidget);
      expect(find.text('COOL ROSE'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('PALETTE'), findsNothing);
      expect(find.text('TEXTURE'), findsNothing);

      await tester.tap(find.byKey(const Key('style-mood-chip-gold')));
      await tester.pump();

      expect(selectedMood, equals(RanaStyleMood.gold));
    });

    testWidgets('limits monochrome presets to B&W-safe mood chips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StyleMoodChips(
              activePreset: triX,
              activeStyle: triX.style!,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('STANDARD'), findsOneWidget);
      expect(find.text('MUTED B&W'), findsOneWidget);
      expect(find.text('STARK B&W'), findsOneWidget);
      expect(find.text('GOLD'), findsNothing);
      expect(find.text('COOL ROSE'), findsNothing);
    });
  });
}
