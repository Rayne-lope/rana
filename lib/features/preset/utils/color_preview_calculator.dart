import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Pure function to calculate shadow and highlight colors for a preset.
class ColorPreviewCalculator {
  /// Calculates the shadow and highlight colors.
  static PresetPreviewColors calculate(PresetModel preset) {
    final shadowColor = _calculateForLightness(preset, 0.35);
    final highlightColor = _calculateForLightness(preset, 0.65);
    return PresetPreviewColors(
      shadow: shadowColor,
      highlight: highlightColor,
    );
  }

  static Color _calculateForLightness(
    PresetModel preset,
    double baseLightness,
  ) {
    final temp = preset.color.temperature;
    final sat = preset.color.saturation;
    final contrast = preset.color.contrast;

    // 1. Start from neutral base
    var hue = 0.0;
    var saturation = 0.0;
    var lightness = baseLightness;

    // 2. Apply temperature
    if (temp > 0) {
      hue = 35; // Warm amber/orange
      saturation = temp * 0.4;
      lightness += temp * 0.05;
    } else if (temp < 0) {
      hue = 210; // Cool blue/teal
      saturation = temp.abs() * 0.4;
      lightness -= temp.abs() * 0.05;
    }

    // 3. Apply saturation scale
    saturation = saturation * (1 + sat);

    // 4. Apply contrast (relative to midpoint 0.5)
    lightness = (lightness - 0.5) * (1 + contrast) + 0.5;

    return HSLColor.fromAHSL(
      1,
      hue,
      saturation.clamp(0, 1),
      lightness.clamp(0, 1),
    ).toColor();
  }
}

/// Data class to hold calculated preview colors.
class PresetPreviewColors {
  /// Constructor.
  const PresetPreviewColors({
    required this.shadow,
    required this.highlight,
  });

  /// Shadow color.
  final Color shadow;

  /// Highlight color.
  final Color highlight;
}
