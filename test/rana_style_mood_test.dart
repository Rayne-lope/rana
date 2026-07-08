import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';

void main() {
  group('RanaStyleMood', () {
    const kodakGold = PresetModel(
      id: 'gold_200',
      name: 'Kodak Gold 200',
      category: 'Vintage',
      color: PresetColor(temperature: 0.24, contrast: 0.12, saturation: 0.16),
      grain: PresetGrain(intensity: 0.22),
      vignette: PresetVignette(intensity: 0.04),
      style: RanaStyle(
        tone: -8,
        color: 14,
        texture: 12,
        undertoneX: -0.42,
        undertoneY: -0.04,
      ),
    );

    const ranaCool = PresetModel(
      id: 'rana_cool',
      name: 'Rana Cool',
      category: 'Classic',
      color: PresetColor(temperature: -0.3, contrast: 0, saturation: 0.05),
      grain: PresetGrain(intensity: 0),
      vignette: PresetVignette(intensity: 0),
      style: RanaStyle(tone: -8, color: 8, undertoneX: 0.45, undertoneY: 0.05),
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

    test('applies Cool Rose as a delta over Kodak Gold defaults', () {
      final style = RanaStyleMood.coolRose.resolve(kodakGold);

      expect(style.tone, equals(-8));
      expect(style.color, equals(12));
      expect(style.texture, equals(12));
      expect(style.styleStrength, equals(100));
      expect(style.undertoneX, closeTo(0.13, 0.001));
      expect(style.undertoneY, closeTo(0.14, 0.001));
    });

    test('applies Gold as a warmer Kodak-aware shift', () {
      final style = RanaStyleMood.gold.resolve(kodakGold);

      expect(style.tone, equals(-11));
      expect(style.color, equals(20));
      expect(style.undertoneX, closeTo(-0.64, 0.001));
      expect(style.undertoneY, closeTo(-0.07, 0.001));
    });

    test('cool base presets can move further cool and clamp safely', () {
      final style = RanaStyleMood.coolRose.resolve(ranaCool);

      expect(style.undertoneX, equals(1));
      expect(style.undertoneY, closeTo(0.23, 0.001));
      expect(style.color, equals(6));
    });

    test('monochrome presets expose only B&W-safe moods', () {
      final moods = RanaStyleMood.availableForPreset(triX);

      expect(moods, contains(RanaStyleMood.standard));
      expect(moods, contains(RanaStyleMood.mutedBlackAndWhite));
      expect(moods, contains(RanaStyleMood.starkBlackAndWhite));
      expect(moods, isNot(contains(RanaStyleMood.gold)));
      expect(moods, isNot(contains(RanaStyleMood.coolRose)));
    });

    test('B&W moods neutralize color casts on monochrome presets', () {
      final style = RanaStyleMood.starkBlackAndWhite.resolve(triX);

      expect(style.tone, equals(30));
      expect(style.color, equals(-100));
      expect(style.undertoneX, equals(0));
      expect(style.undertoneY, equals(0));
    });

    test('matches a mood only while style is still at the resolved value', () {
      final style = RanaStyleMood.amber.resolve(kodakGold);

      expect(
        RanaStyleMood.matchForStyle(kodakGold, style),
        equals(RanaStyleMood.amber),
      );
      expect(
        RanaStyleMood.matchForStyle(kodakGold, style.copyWith(color: 24)),
        isNull,
      );
    });
  });
}
