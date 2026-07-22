import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/utils/rana_texture_mapper.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';

/// Builds the native preview and capture parameter maps for a locked recipe.
///
/// All mutable controller inputs are supplied explicitly so callers can take
/// an atomic snapshot before an asynchronous native operation starts.
@internal
final class CameraRecipeBuilder {
  const CameraRecipeBuilder();

  RanaStyle clampStyle(RanaStyle style) => RanaStyle(
    tone: style.tone.clamp(-100.0, 100.0),
    color: style.color.clamp(-100.0, 100.0),
    texture: style.texture.clamp(0.0, 100.0),
    styleStrength: style.styleStrength.clamp(0.0, 100.0),
    undertoneX: style.undertoneX.clamp(-1.0, 1.0),
    undertoneY: style.undertoneY.clamp(-1.0, 1.0),
  );

  Map<String, dynamic> buildCaptureParams({
    required PresetModel? preset,
    required RanaStyle style,
    required int? previewVariant,
    required OutputQuality outputQuality,
    String? filmRollId,
  }) {
    final lut = preset?.lut;
    final lutPath = lut is String && lut.isNotEmpty ? lut : null;
    final analog = _buildAnalogParams(preset: preset, style: style);
    final baseStyle = preset?.style ?? const RanaStyle();

    return <String, dynamic>{
      'temperature': preset?.color.temperature ?? 0.0,
      'saturation': preset?.color.saturation ?? 0.0,
      'contrast': preset?.color.contrast ?? 0.0,
      'colorMatrix': preset?.color.matrix ?? PresetColor.identityMatrix,
      'fade': preset?.color.fade ?? 0.0,
      'grain': analog.grain,
      'vignette': preset?.vignette.intensity ?? 0.0,
      'vignetteColorR':
          preset?.vignette.color[0] ?? PresetVignette.defaultColor[0],
      'vignetteColorG':
          preset?.vignette.color[1] ?? PresetVignette.defaultColor[1],
      'vignetteColorB':
          preset?.vignette.color[2] ?? PresetVignette.defaultColor[2],
      'vignetteRoundness': preset?.vignette.roundness ?? 0.0,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': preset?.effects.lightLeak.intensity ?? 0.0,
      'lightLeakVariant': previewVariant ?? -1,
      'dustIntensity': analog.dust,
      'bloomThreshold': preset?.effects.bloom.threshold ?? 0.8,
      'bloomIntensity': preset?.effects.bloom.intensity ?? 0.0,
      'halationIntensity': preset?.effects.halation.intensity ?? 0.0,
      'halationRadius': preset?.effects.halation.radius ?? 1.0,
      'halationColorR':
          preset?.effects.halation.color[0] ?? PresetHalation.defaultColor[0],
      'halationColorG':
          preset?.effects.halation.color[1] ?? PresetHalation.defaultColor[1],
      'halationColorB':
          preset?.effects.halation.color[2] ?? PresetHalation.defaultColor[2],
      'lensDistortionStrength': preset?.effects.lensDistortion.strength ?? 0.0,
      'chromaticAberrationIntensity':
          preset?.effects.chromaticAberration?.intensity ?? 0.0,
      'highlightRollOff': preset?.effects.highlightRollOff ?? 0.0,
      'shadowRollOff': preset?.effects.shadowRollOff ?? 0.0,
      'filmBorderStyle': preset?.effects.filmBorder.style.channelValue ?? 0,
      'dateStampEnable': preset?.effects.dateStamp?.enable ?? false,
      'shadowsTintR': analog.shadowsTint[0],
      'shadowsTintG': analog.shadowsTint[1],
      'shadowsTintB': analog.shadowsTint[2],
      'highlightsTintR': analog.highlightsTint[0],
      'highlightsTintG': analog.highlightsTint[1],
      'highlightsTintB': analog.highlightsTint[2],
      'tone': style.tone,
      'color': style.color,
      'textureVal': analog.texture,
      'styleStrength': style.styleStrength,
      'undertoneX': style.undertoneX,
      'undertoneY': style.undertoneY,
      'grainSize': analog.grainSize,
      'grainShadowsLimit': analog.grainShadowsLimit,
      'grainHighlightsLimit': analog.grainHighlightsLimit,
      'softness': analog.softness,
      'outputQuality': outputQuality.storageValue,
      'presetId': preset?.id ?? 'normal',
      'isStyleModified': preset != null && style != baseStyle,
      'filmRollId': filmRollId,
    };
  }

  Map<String, dynamic> buildPreviewParams({
    required PresetModel preset,
    required RanaStyle style,
    required int? previewVariant,
  }) {
    final lutPath = preset.lut is String && (preset.lut as String).isNotEmpty
        ? preset.lut as String
        : null;
    final analog = _buildAnalogParams(preset: preset, style: style);

    return <String, dynamic>{
      'temperature': preset.color.temperature,
      'contrast': preset.color.contrast,
      'saturation': preset.color.saturation,
      'colorMatrix': preset.color.matrix,
      'fade': preset.color.fade ?? 0.0,
      'grain': analog.grain,
      'vignette': preset.vignette.intensity,
      'vignetteColorR': preset.vignette.color[0],
      'vignetteColorG': preset.vignette.color[1],
      'vignetteColorB': preset.vignette.color[2],
      'vignetteRoundness': preset.vignette.roundness,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': preset.effects.lightLeak.intensity,
      'lightLeakVariant': previewVariant ?? -1,
      'dustIntensity': analog.dust,
      'bloomThreshold': preset.effects.bloom.threshold,
      'bloomIntensity': preset.effects.bloom.intensity,
      'halationIntensity': preset.effects.halation.intensity,
      'halationRadius': preset.effects.halation.radius,
      'halationColorR': preset.effects.halation.color[0],
      'halationColorG': preset.effects.halation.color[1],
      'halationColorB': preset.effects.halation.color[2],
      'lensDistortionStrength': preset.effects.lensDistortion.strength,
      'chromaticAberrationIntensity':
          preset.effects.chromaticAberration?.intensity ?? 0.0,
      'highlightRollOff': preset.effects.highlightRollOff,
      'shadowRollOff': preset.effects.shadowRollOff,
      'filmBorderStyle': preset.effects.filmBorder.style.channelValue,
      'dateStampEnable': preset.effects.dateStamp?.enable ?? false,
      'shadowsTintR': analog.shadowsTint[0],
      'shadowsTintG': analog.shadowsTint[1],
      'shadowsTintB': analog.shadowsTint[2],
      'highlightsTintR': analog.highlightsTint[0],
      'highlightsTintG': analog.highlightsTint[1],
      'highlightsTintB': analog.highlightsTint[2],
      'tone': style.tone,
      'color': style.color,
      'textureVal': analog.texture,
      'styleStrength': style.styleStrength,
      'undertoneX': style.undertoneX,
      'undertoneY': style.undertoneY,
      'grainSize': analog.grainSize,
      'grainShadowsLimit': analog.grainShadowsLimit,
      'grainHighlightsLimit': analog.grainHighlightsLimit,
      'softness': analog.softness,
    };
  }

  _AnalogParams _buildAnalogParams({
    required PresetModel? preset,
    required RanaStyle style,
  }) {
    final presetGrain = preset?.grain.intensity ?? 0.0;
    final presetDust = preset?.effects.dust.intensity ?? 0.0;
    final presetGrainSize = preset?.grain.size ?? 1.0;
    final texture = style.textureVal ?? style.texture;
    final mapped = RanaTextureMapper.mapTexture(
      texture,
      presetGrain: presetGrain,
      presetDust: presetDust,
    );
    final blend = style.styleStrength / 100.0;

    return _AnalogParams(
      grain: presetGrain * (1.0 - blend) + (mapped['grain'] ?? 0.0) * blend,
      dust: presetDust * (1.0 - blend) + (mapped['dust'] ?? 0.0) * blend,
      grainSize:
          presetGrainSize *
          ((1.0 - blend) + (mapped['grainSize'] ?? 1.0) * blend),
      grainShadowsLimit:
          preset?.grain.shadowsLimit ?? PresetGrain.defaultShadowsLimit,
      grainHighlightsLimit:
          preset?.grain.highlightsLimit ?? PresetGrain.defaultHighlightsLimit,
      softness:
          ((preset?.effects.softness ?? 0.0) +
                  (mapped['softness'] ?? 0.0) * blend)
              .clamp(0.0, 1.0),
      texture: texture,
      shadowsTint:
          preset?.effects.splitToning?.shadowsTint ?? const <double>[0, 0, 0],
      highlightsTint:
          preset?.effects.splitToning?.highlightsTint ??
          const <double>[0, 0, 0],
    );
  }
}

final class _AnalogParams {
  const _AnalogParams({
    required this.grain,
    required this.dust,
    required this.grainSize,
    required this.grainShadowsLimit,
    required this.grainHighlightsLimit,
    required this.softness,
    required this.texture,
    required this.shadowsTint,
    required this.highlightsTint,
  });

  final double grain;
  final double dust;
  final double grainSize;
  final double grainShadowsLimit;
  final double grainHighlightsLimit;
  final double softness;
  final double texture;
  final List<double> shadowsTint;
  final List<double> highlightsTint;
}
