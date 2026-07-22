import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Current stable render-recipe wire version.
const int currentRenderRecipeVersion = 1;

/// Raised when persisted media references a recipe newer than this app knows.
final class UnsupportedRenderRecipeVersion implements Exception {
  const UnsupportedRenderRecipeVersion(this.version);

  final int version;
  String get code => 'UNSUPPORTED_RECIPE_VERSION';

  @override
  String toString() =>
      '$code: Render recipe version $version is not supported.';
}

/// Immutable visual recipe shared by preview, capture, metadata and re-render.
///
/// Capture identity and storage results deliberately live in [CaptureContext],
/// not in this value. The flat map conversion is a temporary compatibility
/// boundary for the pre-Pigeon native renderer.
@immutable
final class RenderRecipeV1 {
  const RenderRecipeV1({
    this.temperature = 0,
    this.saturation = 0,
    this.contrast = 0,
    this.colorMatrix = const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1],
    this.fade = 0,
    this.grain = 0,
    this.grainSize = 1,
    this.grainShadowsLimit = 0.04,
    this.grainHighlightsLimit = 0.07,
    this.vignette = 0,
    this.vignetteColor = const <double>[0, 0, 0],
    this.vignetteRoundness = 0,
    this.lutPath,
    this.lutStrength = 0,
    this.bloomThreshold = 0.8,
    this.bloomIntensity = 0,
    this.halationIntensity = 0,
    this.halationRadius = 1,
    this.halationColor = const <double>[1, 0.35, 0.15],
    this.lightLeakIntensity = 0,
    this.lightLeakVariant = -1,
    this.dustIntensity = 0,
    this.dustOffsetX = -1,
    this.dustOffsetY = -1,
    this.filmBorderStyle = 0,
    this.dateStampEnable = false,
    this.lensDistortionStrength = 0,
    this.chromaticAberrationIntensity = 0,
    this.highlightRollOff = 0,
    this.shadowRollOff = 0,
    this.softness = 0,
    this.shadowsTint = const <double>[0, 0, 0],
    this.highlightsTint = const <double>[0, 0, 0],
    this.tone = 0,
    this.color = 0,
    this.texture = 0,
    this.styleStrength = 100,
    this.undertoneX = 0,
    this.undertoneY = 0,
    this.outputQuality = 'high_jpeg',
    this.aspectRatio = 'portrait_3_4',
    this.presetId = 'normal',
    this.isStyleModified = false,
  });

  factory RenderRecipeV1.fromMap(Map<dynamic, dynamic> source) {
    final version = (source['recipeVersion'] as num?)?.toInt() ?? 0;
    if (version != 0 && version != currentRenderRecipeVersion) {
      throw UnsupportedRenderRecipeVersion(version);
    }

    double number(String key, double fallback) {
      final value = (source[key] as num?)?.toDouble();
      return value != null && value.isFinite ? value : fallback;
    }

    List<double> vector(String key, int length, List<double> fallback) {
      final value = source[key];
      if (value is! List || value.length != length) return fallback;
      final parsed = value.map((item) => (item as num?)?.toDouble()).toList();
      if (parsed.any((item) => item == null || !item.isFinite)) return fallback;
      return List<double>.unmodifiable(parsed.cast<double>());
    }

    List<double> rgb(String aggregate, String prefix, List<double> fallback) {
      if (source[aggregate] is List) {
        return vector(aggregate, 3, fallback);
      }
      return List<double>.unmodifiable(<double>[
        number('${prefix}R', fallback[0]),
        number('${prefix}G', fallback[1]),
        number('${prefix}B', fallback[2]),
      ]);
    }

    double unit(String key, double fallback) =>
        number(key, fallback).clamp(0.0, 1.0);

    return RenderRecipeV1(
      temperature: number('temperature', 0).clamp(-1.0, 1.0),
      saturation: number('saturation', 0).clamp(-1.0, 1.0),
      contrast: number('contrast', 0).clamp(-1.0, 1.0),
      colorMatrix: vector('colorMatrix', 9, const <double>[
        1,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
      ]),
      fade: unit('fade', 0),
      grain: unit('grain', 0),
      grainSize: number('grainSize', 1).clamp(0.1, 8.0),
      grainShadowsLimit: number('grainShadowsLimit', 0.04).clamp(0.0, 0.5),
      grainHighlightsLimit: number(
        'grainHighlightsLimit',
        0.07,
      ).clamp(0.0, 0.3),
      vignette: unit('vignette', 0),
      vignetteColor: rgb('vignetteColor', 'vignetteColor', const <double>[
        0,
        0,
        0,
      ]).map((value) => value.clamp(0.0, 1.0)).toList(growable: false),
      vignetteRoundness: unit('vignetteRoundness', 0),
      lutPath: switch (source['lutPath']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
      lutStrength: unit('lutStrength', 0),
      bloomThreshold: unit('bloomThreshold', 0.8),
      bloomIntensity: unit('bloomIntensity', 0),
      halationIntensity: unit('halationIntensity', 0),
      halationRadius: number('halationRadius', 1).clamp(0.25, 4.0),
      halationColor: rgb('halationColor', 'halationColor', const <double>[
        1,
        0.35,
        0.15,
      ]).map((value) => value.clamp(0.0, 1.0)).toList(growable: false),
      lightLeakIntensity: unit('lightLeakIntensity', 0),
      lightLeakVariant: (source['lightLeakVariant'] as num?)?.toInt() ?? -1,
      dustIntensity: unit('dustIntensity', 0),
      dustOffsetX: number('dustOffsetX', -1),
      dustOffsetY: number('dustOffsetY', -1),
      filmBorderStyle: ((source['filmBorderStyle'] as num?)?.toInt() ?? 0)
          .clamp(0, 3),
      dateStampEnable: source['dateStampEnable'] as bool? ?? false,
      lensDistortionStrength: unit('lensDistortionStrength', 0),
      chromaticAberrationIntensity: unit('chromaticAberrationIntensity', 0),
      highlightRollOff: unit('highlightRollOff', 0),
      shadowRollOff: unit('shadowRollOff', 0),
      softness: unit('softness', 0),
      shadowsTint: rgb('shadowsTint', 'shadowsTint', const <double>[0, 0, 0]),
      highlightsTint: rgb('highlightsTint', 'highlightsTint', const <double>[
        0,
        0,
        0,
      ]),
      tone: number('tone', 0).clamp(-100.0, 100.0),
      color: number('color', 0).clamp(-100.0, 100.0),
      texture: number('textureVal', 0).clamp(0.0, 100.0),
      styleStrength: number('styleStrength', 100).clamp(0.0, 100.0),
      undertoneX: number('undertoneX', 0).clamp(-1.0, 1.0),
      undertoneY: number('undertoneY', 0).clamp(-1.0, 1.0),
      outputQuality: source['outputQuality'] as String? ?? 'high_jpeg',
      aspectRatio: source['aspectRatio'] as String? ?? 'portrait_3_4',
      presetId: source['presetId'] as String? ?? 'normal',
      isStyleModified: source['isStyleModified'] as bool? ?? false,
    );
  }

  final double temperature;
  final double saturation;
  final double contrast;
  final List<double> colorMatrix;
  final double fade;
  final double grain;
  final double grainSize;
  final double grainShadowsLimit;
  final double grainHighlightsLimit;
  final double vignette;
  final List<double> vignetteColor;
  final double vignetteRoundness;
  final String? lutPath;
  final double lutStrength;
  final double bloomThreshold;
  final double bloomIntensity;
  final double halationIntensity;
  final double halationRadius;
  final List<double> halationColor;
  final double lightLeakIntensity;
  final int lightLeakVariant;
  final double dustIntensity;
  final double dustOffsetX;
  final double dustOffsetY;
  final int filmBorderStyle;
  final bool dateStampEnable;
  final double lensDistortionStrength;
  final double chromaticAberrationIntensity;
  final double highlightRollOff;
  final double shadowRollOff;
  final double softness;
  final List<double> shadowsTint;
  final List<double> highlightsTint;
  final double tone;
  final double color;
  final double texture;
  final double styleStrength;
  final double undertoneX;
  final double undertoneY;
  final String outputQuality;
  final String aspectRatio;
  final String presetId;
  final bool isStyleModified;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'recipeVersion': currentRenderRecipeVersion,
    'temperature': temperature,
    'saturation': saturation,
    'contrast': contrast,
    'colorMatrix': List<double>.of(colorMatrix),
    'fade': fade,
    'grain': grain,
    'grainSize': grainSize,
    'grainShadowsLimit': grainShadowsLimit,
    'grainHighlightsLimit': grainHighlightsLimit,
    'vignette': vignette,
    'vignetteColorR': vignetteColor[0],
    'vignetteColorG': vignetteColor[1],
    'vignetteColorB': vignetteColor[2],
    'vignetteRoundness': vignetteRoundness,
    'lutPath': lutPath,
    'lutStrength': lutStrength,
    'lightLeakIntensity': lightLeakIntensity,
    'lightLeakVariant': lightLeakVariant,
    'dustIntensity': dustIntensity,
    'dustOffsetX': dustOffsetX,
    'dustOffsetY': dustOffsetY,
    'bloomThreshold': bloomThreshold,
    'bloomIntensity': bloomIntensity,
    'halationIntensity': halationIntensity,
    'halationRadius': halationRadius,
    'halationColorR': halationColor[0],
    'halationColorG': halationColor[1],
    'halationColorB': halationColor[2],
    'lensDistortionStrength': lensDistortionStrength,
    'chromaticAberrationIntensity': chromaticAberrationIntensity,
    'highlightRollOff': highlightRollOff,
    'shadowRollOff': shadowRollOff,
    'filmBorderStyle': filmBorderStyle,
    'dateStampEnable': dateStampEnable,
    'shadowsTintR': shadowsTint[0],
    'shadowsTintG': shadowsTint[1],
    'shadowsTintB': shadowsTint[2],
    'highlightsTintR': highlightsTint[0],
    'highlightsTintG': highlightsTint[1],
    'highlightsTintB': highlightsTint[2],
    'tone': tone,
    'color': color,
    'textureVal': texture,
    'styleStrength': styleStrength,
    'undertoneX': undertoneX,
    'undertoneY': undertoneY,
    'softness': softness,
    'outputQuality': outputQuality,
    'aspectRatio': aspectRatio,
    'presetId': presetId,
    'isStyleModified': isStyleModified,
  };

  @override
  bool operator ==(Object other) =>
      other is RenderRecipeV1 &&
      jsonEncode(other.toMap()) == jsonEncode(toMap());

  @override
  int get hashCode => jsonEncode(toMap()).hashCode;
}

/// Non-visual values attached to one capture operation.
@immutable
final class CaptureContext {
  const CaptureContext({
    required this.captureId,
    this.filmRollId,
    this.actualOutputUri,
    this.actualOutputFormat,
  });

  final String captureId;
  final String? filmRollId;
  final String? actualOutputUri;
  final String? actualOutputFormat;
}
