import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';

/// Preset-aware quick styling option.
@immutable
class RanaStyleMood {
  const RanaStyleMood({
    required this.id,
    required this.label,
    required this.swatchColor,
    this.toneDelta = 0.0,
    this.colorDelta = 0.0,
    this.colorTarget,
    this.undertoneXDelta = 0.0,
    this.undertoneYDelta = 0.0,
    this.undertoneXTarget,
    this.undertoneYTarget,
    this.styleStrength = 100.0,
    this.isBlackAndWhite = false,
  });

  final String id;
  final String label;
  final int swatchColor;
  final double toneDelta;
  final double colorDelta;
  final double? colorTarget;
  final double undertoneXDelta;
  final double undertoneYDelta;
  final double? undertoneXTarget;
  final double? undertoneYTarget;
  final double styleStrength;
  final bool isBlackAndWhite;

  static const standard = RanaStyleMood(
    id: 'standard',
    label: 'Standard',
    swatchColor: 0xFFC9C3B6,
  );

  static const coolRose = RanaStyleMood(
    id: 'cool_rose',
    label: 'Cool Rose',
    swatchColor: 0xFFB6B8D8,
    colorDelta: -2,
    undertoneXDelta: 0.55,
    undertoneYDelta: 0.18,
  );

  static const neutral = RanaStyleMood(
    id: 'neutral',
    label: 'Neutral',
    swatchColor: 0xFFB7B4A8,
    colorDelta: -4,
    undertoneXTarget: 0,
    undertoneYTarget: 0,
  );

  static const roseGold = RanaStyleMood(
    id: 'rose_gold',
    label: 'Rose Gold',
    swatchColor: 0xFFD7A090,
    toneDelta: -2,
    colorDelta: 4,
    undertoneXDelta: -0.12,
    undertoneYDelta: 0.22,
  );

  static const gold = RanaStyleMood(
    id: 'gold',
    label: 'Gold',
    swatchColor: 0xFFD6A53A,
    toneDelta: -3,
    colorDelta: 6,
    undertoneXDelta: -0.22,
    undertoneYDelta: -0.03,
  );

  static const amber = RanaStyleMood(
    id: 'amber',
    label: 'Amber',
    swatchColor: 0xFFC06C2C,
    toneDelta: -5,
    colorDelta: 8,
    undertoneXDelta: -0.35,
    undertoneYDelta: -0.10,
  );

  static const vibrant = RanaStyleMood(
    id: 'vibrant',
    label: 'Vibrant',
    swatchColor: 0xFFCF5A62,
    toneDelta: -4,
    colorDelta: 18,
    undertoneXDelta: -0.02,
    undertoneYDelta: 0.04,
  );

  static const natural = RanaStyleMood(
    id: 'natural',
    label: 'Natural',
    swatchColor: 0xFFA9B3A1,
    colorDelta: -8,
    undertoneXTarget: 0,
    undertoneYTarget: 0,
  );

  static const luminous = RanaStyleMood(
    id: 'luminous',
    label: 'Luminous',
    swatchColor: 0xFFC9C5EA,
    toneDelta: -18,
    colorDelta: 8,
    undertoneXDelta: 0.10,
    undertoneYDelta: 0.16,
  );

  static const dramatic = RanaStyleMood(
    id: 'dramatic',
    label: 'Dramatic',
    swatchColor: 0xFF756A62,
    toneDelta: 22,
    colorDelta: 6,
    undertoneXDelta: 0.02,
  );

  static const quiet = RanaStyleMood(
    id: 'quiet',
    label: 'Quiet',
    swatchColor: 0xFF8C8F82,
    toneDelta: 8,
    colorDelta: -18,
    undertoneXDelta: 0.04,
    undertoneYDelta: -0.04,
  );

  static const cozy = RanaStyleMood(
    id: 'cozy',
    label: 'Cozy',
    swatchColor: 0xFFB8784A,
    toneDelta: 12,
    colorDelta: 2,
    undertoneXDelta: -0.20,
    undertoneYDelta: -0.02,
  );

  static const ethereal = RanaStyleMood(
    id: 'ethereal',
    label: 'Ethereal',
    swatchColor: 0xFFADBEE6,
    toneDelta: -20,
    colorDelta: -10,
    undertoneXDelta: 0.16,
    undertoneYDelta: 0.10,
  );

  static const mutedBlackAndWhite = RanaStyleMood(
    id: 'muted_bw',
    label: 'Muted B&W',
    swatchColor: 0xFF8F8F8A,
    toneDelta: 4,
    colorTarget: -100,
    undertoneXTarget: 0,
    undertoneYTarget: 0,
    isBlackAndWhite: true,
  );

  static const starkBlackAndWhite = RanaStyleMood(
    id: 'stark_bw',
    label: 'Stark B&W',
    swatchColor: 0xFFD1D1CC,
    toneDelta: 18,
    colorTarget: -100,
    undertoneXTarget: 0,
    undertoneYTarget: 0,
    isBlackAndWhite: true,
  );

  static const List<RanaStyleMood> colorMoods = <RanaStyleMood>[
    standard,
    coolRose,
    neutral,
    roseGold,
    gold,
    amber,
    vibrant,
    natural,
    luminous,
    dramatic,
    quiet,
    cozy,
    ethereal,
    mutedBlackAndWhite,
    starkBlackAndWhite,
  ];

  static const List<RanaStyleMood> monochromeMoods = <RanaStyleMood>[
    standard,
    mutedBlackAndWhite,
    starkBlackAndWhite,
  ];

  static List<RanaStyleMood> availableForPreset(PresetModel preset) =>
      isMonochromePreset(preset) ? monochromeMoods : colorMoods;

  static RanaStyleMood? byId(String id) {
    for (final mood in colorMoods) {
      if (mood.id == id) return mood;
    }
    return null;
  }

  static bool isMonochromePreset(PresetModel preset) {
    final id = preset.id.toLowerCase();
    final name = preset.name.toLowerCase();
    return preset.color.saturation <= -0.95 ||
        id.contains('mono') ||
        id.contains('tri_x') ||
        id.contains('hp5') ||
        name.contains('mono') ||
        name.contains('b&w');
  }

  static RanaStyleMood? matchForStyle(
    PresetModel preset,
    RanaStyle style, {
    double tolerance = 0.001,
  }) {
    for (final mood in availableForPreset(preset)) {
      final resolved = mood.resolve(preset);
      if (_close(resolved.tone, style.tone, tolerance) &&
          _close(resolved.color, style.color, tolerance) &&
          _close(resolved.texture, style.texture, tolerance) &&
          _close(resolved.styleStrength, style.styleStrength, tolerance) &&
          _close(resolved.undertoneX, style.undertoneX, tolerance) &&
          _close(resolved.undertoneY, style.undertoneY, tolerance)) {
        return mood;
      }
    }
    return null;
  }

  RanaStyle resolve(PresetModel preset) {
    final base = preset.style ?? const RanaStyle();
    if (id == standard.id) return base;

    final nextColor = colorTarget ?? base.color + colorDelta;
    final nextUndertoneX =
        undertoneXTarget ?? base.undertoneX + undertoneXDelta;
    final nextUndertoneY =
        undertoneYTarget ?? base.undertoneY + undertoneYDelta;

    return RanaStyle(
      tone: _clamp(base.tone + toneDelta, -100, 100),
      color: _clamp(nextColor, -100, 100),
      texture: base.texture,
      styleStrength: _clamp(styleStrength, 0, 100),
      undertoneX: _clamp(nextUndertoneX, -1, 1),
      undertoneY: _clamp(nextUndertoneY, -1, 1),
    );
  }

  static bool _close(double a, double b, double tolerance) =>
      (a - b).abs() <= tolerance;

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
