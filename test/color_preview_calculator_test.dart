import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/utils/color_preview_calculator.dart';

void main() {
  group('ColorPreviewCalculator Tests', () {
    test('calculates correct colors for Normal preset (neutral)', () {
      const normalPreset = PresetModel(
        id: 'normal',
        name: 'Normal',
        category: 'Classic',
        color: PresetColor(
          temperature: 0,
          contrast: 0,
          saturation: 0,
        ),
        grain: PresetGrain(intensity: 0),
        vignette: PresetVignette(intensity: 0),
      );

      final result = ColorPreviewCalculator.calculate(normalPreset);
      
      // Normal preset should have completely desaturated grey colors
      expect(result.shadow.r, equals(result.shadow.g));
      expect(result.shadow.r, equals(result.shadow.b));

      expect(result.highlight.r, equals(result.highlight.g));
      expect(result.highlight.r, equals(result.highlight.b));
      
      // Highlight should be lighter than shadow
      final shadowHSL = HSLColor.fromColor(result.shadow);
      final highlightHSL = HSLColor.fromColor(result.highlight);
      expect(highlightHSL.lightness, greaterThan(shadowHSL.lightness));
    });

    test('calculates warm orange/amber hues for Warm preset', () {
      const warmPreset = PresetModel(
        id: 'rana_warm',
        name: 'Rana Warm',
        category: 'Classic',
        color: PresetColor(
          temperature: 0.3,
          contrast: 0,
          saturation: 0.1,
        ),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
      );

      final result = ColorPreviewCalculator.calculate(warmPreset);
      final shadowHSL = HSLColor.fromColor(result.shadow);
      final highlightHSL = HSLColor.fromColor(result.highlight);

      // Hue should be warm (around 35 degrees)
      expect(shadowHSL.hue, closeTo(35.0, 3.0));
      expect(highlightHSL.hue, closeTo(35.0, 3.0));

      // Saturation should be non-zero
      expect(shadowHSL.saturation, greaterThan(0));
      expect(highlightHSL.saturation, greaterThan(0));
    });

    test('calculates cool blue/teal hues for Cool preset', () {
      const coolPreset = PresetModel(
        id: 'rana_cool',
        name: 'Rana Cool',
        category: 'Classic',
        color: PresetColor(
          temperature: -0.3,
          contrast: 0,
          saturation: 0.05,
        ),
        grain: PresetGrain(intensity: 0),
        vignette: PresetVignette(intensity: 0),
      );

      final result = ColorPreviewCalculator.calculate(coolPreset);
      final shadowHSL = HSLColor.fromColor(result.shadow);
      final highlightHSL = HSLColor.fromColor(result.highlight);

      // Hue should be cool (around 210 degrees)
      expect(shadowHSL.hue, closeTo(210.0, 3.0));
      expect(highlightHSL.hue, closeTo(210.0, 3.0));

      expect(shadowHSL.saturation, greaterThan(0));
      expect(highlightHSL.saturation, greaterThan(0));
    });

    test('calculates fully desaturated greyscale for Mono preset', () {
      const monoPreset = PresetModel(
        id: 'rana_mono',
        name: 'Rana Mono',
        category: 'Classic',
        color: PresetColor(
          temperature: 0,
          contrast: 0.1,
          saturation: -1,
        ),
        grain: PresetGrain(intensity: 0),
        vignette: PresetVignette(intensity: 0),
      );

      final result = ColorPreviewCalculator.calculate(monoPreset);
      
      // Mono should have completely desaturated grey colors
      expect(result.shadow.r, equals(result.shadow.g));
      expect(result.shadow.r, equals(result.shadow.b));

      expect(result.highlight.r, equals(result.highlight.g));
      expect(result.highlight.r, equals(result.highlight.b));
    });
  });
}
