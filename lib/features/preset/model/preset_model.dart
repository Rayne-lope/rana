import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/rana_style.dart';

/// Preset color parameters.
@immutable
class PresetColor {
  /// Main constructor.
  const PresetColor({
    required this.temperature,
    required this.contrast,
    required this.saturation,
    this.fade,
  });

  /// Factory to parse from a JSON map.
  factory PresetColor.fromJson(Map<String, dynamic> json) => PresetColor(
    temperature: (json['temperature'] as num).toDouble(),
    contrast: (json['contrast'] as num).toDouble(),
    saturation: (json['saturation'] as num).toDouble(),
    fade: (json['fade'] as num?)?.toDouble() ?? 0.0,
  );

  /// The temperature parameter.
  final double temperature;

  /// The contrast parameter.
  final double contrast;

  /// The saturation parameter.
  final double saturation;

  /// Matte shadow lift amount.
  final double? fade;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'temperature': temperature,
    'contrast': contrast,
    'saturation': saturation,
    'fade': fade ?? 0.0,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetColor &&
        other.temperature == temperature &&
        other.contrast == contrast &&
        other.saturation == saturation &&
        other.fade == fade;
  }

  @override
  int get hashCode => Object.hash(temperature, contrast, saturation, fade);

  @override
  String toString() =>
      'PresetColor(temperature: $temperature, '
      'contrast: $contrast, saturation: $saturation, fade: $fade)';
}

/// Preset grain parameters.
@immutable
class PresetGrain {
  /// Main constructor.
  const PresetGrain({required this.intensity, this.size});

  /// Factory to parse from a JSON map.
  factory PresetGrain.fromJson(Map<String, dynamic> json) => PresetGrain(
    intensity: (json['intensity'] as num).toDouble(),
    size: (json['size'] as num?)?.toDouble() ?? 1.0,
  );

  /// The grain intensity parameter.
  final double intensity;

  /// Grain flake size multiplier.
  final double? size;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'intensity': intensity,
    'size': size ?? 1.0,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetGrain &&
        other.intensity == intensity &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(intensity, size);

  @override
  String toString() => 'PresetGrain(intensity: $intensity, size: $size)';
}

/// Preset vignette parameters.
@immutable
class PresetVignette {
  /// Main constructor.
  const PresetVignette({required this.intensity});

  /// Factory to parse from a JSON map.
  factory PresetVignette.fromJson(Map<String, dynamic> json) =>
      PresetVignette(intensity: (json['intensity'] as num).toDouble());

  /// The vignette intensity parameter.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'intensity': intensity};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetVignette && other.intensity == intensity;
  }

  @override
  int get hashCode => intensity.hashCode;

  @override
  String toString() => 'PresetVignette(intensity: $intensity)';
}

/// Preset light leak effect parameters.
@immutable
class LightLeakEffect {
  /// Main constructor.
  const LightLeakEffect({required this.intensity, required this.variant});

  /// Factory to parse from a JSON map.
  factory LightLeakEffect.fromJson(Map<String, dynamic> json) =>
      LightLeakEffect(
        intensity: (json['intensity'] as num).toDouble(),
        variant: json['variant'] as int,
      );

  /// The light leak intensity parameter.
  final double intensity;

  /// The light leak variant selection (0-3, or -1 for random).
  final int variant;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'intensity': intensity,
    'variant': variant,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LightLeakEffect &&
        other.intensity == intensity &&
        other.variant == variant;
  }

  @override
  int get hashCode => Object.hash(intensity, variant);

  @override
  String toString() =>
      'LightLeakEffect(intensity: $intensity, variant: $variant)';
}

/// Preset dust and scratches overlay parameters.
@immutable
class DustEffect {
  /// Main constructor.
  const DustEffect({required this.intensity});

  /// Factory to parse from a JSON map.
  factory DustEffect.fromJson(Map<String, dynamic> json) =>
      DustEffect(intensity: (json['intensity'] as num).toDouble());

  /// The dust and scratches overlay intensity.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'intensity': intensity};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DustEffect && other.intensity == intensity;
  }

  @override
  int get hashCode => intensity.hashCode;

  @override
  String toString() => 'DustEffect(intensity: $intensity)';
}

/// Preset bloom effect parameters.
@immutable
class PresetBloom {
  /// Main constructor.
  const PresetBloom({required this.threshold, required this.intensity});

  /// Factory to parse from a JSON map.
  factory PresetBloom.fromJson(Map<String, dynamic> json) => PresetBloom(
    threshold: (json['threshold'] as num).toDouble(),
    intensity: (json['intensity'] as num).toDouble(),
  );

  /// Bright-pass threshold.
  final double threshold;

  /// The bloom intensity.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'threshold': threshold,
    'intensity': intensity,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetBloom &&
        other.threshold == threshold &&
        other.intensity == intensity;
  }

  @override
  int get hashCode => Object.hash(threshold, intensity);

  @override
  String toString() =>
      'PresetBloom(threshold: $threshold, intensity: $intensity)';
}

/// Preset halation effect parameters.
@immutable
class PresetHalation {
  /// Main constructor.
  const PresetHalation({required this.intensity});

  /// Factory to parse from a JSON map.
  factory PresetHalation.fromJson(Map<String, dynamic> json) =>
      PresetHalation(intensity: (json['intensity'] as num).toDouble());

  /// The halation intensity.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'intensity': intensity};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetHalation && other.intensity == intensity;
  }

  @override
  int get hashCode => intensity.hashCode;

  @override
  String toString() => 'PresetHalation(intensity: $intensity)';
}

/// Preset lens distortion effect parameters.
@immutable
class PresetLensDistortion {
  /// Main constructor.
  const PresetLensDistortion({required this.strength});

  /// Factory to parse from a JSON map.
  factory PresetLensDistortion.fromJson(Map<String, dynamic> json) =>
      PresetLensDistortion(strength: (json['strength'] as num).toDouble());

  /// The barrel distortion strength.
  final double strength;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'strength': strength};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetLensDistortion && other.strength == strength;
  }

  @override
  int get hashCode => strength.hashCode;

  @override
  String toString() => 'PresetLensDistortion(strength: $strength)';
}

/// Preset chromatic aberration parameters.
@immutable
class PresetChromaticAberration {
  /// Main constructor.
  const PresetChromaticAberration({required this.intensity});

  /// Factory to parse from a JSON map.
  factory PresetChromaticAberration.fromJson(Map<String, dynamic> json) =>
      PresetChromaticAberration(
        intensity: (json['intensity'] as num?)?.toDouble() ?? 0.0,
      );

  /// Radial red/blue channel displacement intensity.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'intensity': intensity};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresetChromaticAberration && other.intensity == intensity;

  @override
  int get hashCode => intensity.hashCode;

  @override
  String toString() => 'PresetChromaticAberration(intensity: $intensity)';
}

/// Preset retro date stamp parameters.
@immutable
class PresetDateStamp {
  /// Main constructor.
  const PresetDateStamp({required this.enable});

  /// Factory to parse from a JSON map.
  factory PresetDateStamp.fromJson(Map<String, dynamic> json) =>
      PresetDateStamp(enable: json['enable'] as bool? ?? false);

  /// Whether the stamp is burned into saved captures.
  final bool enable;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{'enable': enable};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresetDateStamp && other.enable == enable;

  @override
  int get hashCode => enable.hashCode;

  @override
  String toString() => 'PresetDateStamp(enable: $enable)';
}

/// Preset split-toning parameters.
@immutable
class PresetSplitToning {
  /// Main constructor.
  const PresetSplitToning({
    required this.shadowsTint,
    required this.highlightsTint,
  });

  /// Factory to parse from a JSON map.
  factory PresetSplitToning.fromJson(Map<String, dynamic> json) =>
      PresetSplitToning(
        shadowsTint: _parseRgbList(json['shadowsTint']),
        highlightsTint: _parseRgbList(json['highlightsTint']),
      );

  /// Normalized RGB tint applied to shadows.
  final List<double> shadowsTint;

  /// Normalized RGB tint applied to highlights.
  final List<double> highlightsTint;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'shadowsTint': List<double>.of(shadowsTint),
    'highlightsTint': List<double>.of(highlightsTint),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresetSplitToning &&
          listEquals(other.shadowsTint, shadowsTint) &&
          listEquals(other.highlightsTint, highlightsTint);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(shadowsTint), Object.hashAll(highlightsTint));

  @override
  String toString() =>
      'PresetSplitToning(shadowsTint: $shadowsTint, '
      'highlightsTint: $highlightsTint)';
}

List<double> _parseRgbList(Object? value) {
  final values = value is List<dynamic> ? value : const <dynamic>[];
  return List<double>.generate(3, (index) {
    if (index >= values.length) return 0.0;
    final component = values[index];
    return component is num ? component.toDouble() : 0.0;
  }, growable: false);
}

/// Group of preset effects.
@immutable
class PresetEffects {
  /// Main constructor.
  const PresetEffects({
    required this.lightLeak,
    required this.dust,
    this.bloom = const PresetBloom(threshold: 0.8, intensity: 0),
    this.halation = const PresetHalation(intensity: 0),
    this.lensDistortion = const PresetLensDistortion(strength: 0),
    this.chromaticAberration,
    this.softness,
    this.highlightRollOff = 0.0,
    this.shadowRollOff = 0.0,
    this.dateStamp,
    this.splitToning,
  });

  /// Factory to parse from a JSON map.
  factory PresetEffects.fromJson(Map<String, dynamic> json) {
    final lightLeakJson = json['lightLeak'] as Map<String, dynamic>?;
    final dustJson = json['dust'] as Map<String, dynamic>?;
    final bloomJson = json['bloom'] as Map<String, dynamic>?;
    final halationJson = json['halation'] as Map<String, dynamic>?;
    final lensDistortionJson = json['lensDistortion'] as Map<String, dynamic>?;
    final chromaticAberrationJson =
        json['chromaticAberration'] as Map<String, dynamic>?;
    final dateStampJson = json['dateStamp'] as Map<String, dynamic>?;
    final splitToningJson = json['splitToning'] as Map<String, dynamic>?;
    return PresetEffects(
      lightLeak: lightLeakJson != null
          ? LightLeakEffect.fromJson(lightLeakJson)
          : const LightLeakEffect(intensity: 0, variant: -1),
      dust: dustJson != null
          ? DustEffect.fromJson(dustJson)
          : const DustEffect(intensity: 0),
      bloom: bloomJson != null
          ? PresetBloom.fromJson(bloomJson)
          : const PresetBloom(threshold: 0.8, intensity: 0),
      halation: halationJson != null
          ? PresetHalation.fromJson(halationJson)
          : const PresetHalation(intensity: 0),
      lensDistortion: lensDistortionJson != null
          ? PresetLensDistortion.fromJson(lensDistortionJson)
          : const PresetLensDistortion(strength: 0),
      chromaticAberration: chromaticAberrationJson != null
          ? PresetChromaticAberration.fromJson(chromaticAberrationJson)
          : const PresetChromaticAberration(intensity: 0),
      softness: (json['softness'] as num?)?.toDouble() ?? 0.0,
      highlightRollOff: (json['highlightRollOff'] as num?)?.toDouble() ?? 0.0,
      shadowRollOff: (json['shadowRollOff'] as num?)?.toDouble() ?? 0.0,
      dateStamp: dateStampJson != null
          ? PresetDateStamp.fromJson(dateStampJson)
          : const PresetDateStamp(enable: false),
      splitToning: splitToningJson != null
          ? PresetSplitToning.fromJson(splitToningJson)
          : const PresetSplitToning(
              shadowsTint: <double>[0, 0, 0],
              highlightsTint: <double>[0, 0, 0],
            ),
    );
  }

  /// Light leak effect configurations.
  final LightLeakEffect lightLeak;

  /// Dust and scratches effect configurations.
  final DustEffect dust;

  /// Bloom effect configurations.
  final PresetBloom bloom;

  /// Halation effect configurations.
  final PresetHalation halation;

  /// Lens distortion effect configurations.
  final PresetLensDistortion lensDistortion;

  /// Chromatic aberration effect configuration.
  final PresetChromaticAberration? chromaticAberration;

  /// Soft-focus amount.
  final double? softness;

  /// Highlight shoulder strength, from 0 (neutral) to 1 (maximum).
  final double highlightRollOff;

  /// Shadow toe strength, from 0 (neutral) to 1 (maximum).
  final double shadowRollOff;

  /// Retro date stamp configuration.
  final PresetDateStamp? dateStamp;

  /// Shadow and highlight tint configuration.
  final PresetSplitToning? splitToning;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'lightLeak': lightLeak.toJson(),
    'dust': dust.toJson(),
    'bloom': bloom.toJson(),
    'halation': halation.toJson(),
    'lensDistortion': lensDistortion.toJson(),
    'chromaticAberration':
        (chromaticAberration ?? const PresetChromaticAberration(intensity: 0))
            .toJson(),
    'softness': softness ?? 0.0,
    'highlightRollOff': highlightRollOff,
    'shadowRollOff': shadowRollOff,
    'dateStamp': (dateStamp ?? const PresetDateStamp(enable: false)).toJson(),
    'splitToning':
        (splitToning ??
                const PresetSplitToning(
                  shadowsTint: <double>[0, 0, 0],
                  highlightsTint: <double>[0, 0, 0],
                ))
            .toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetEffects &&
        other.lightLeak == lightLeak &&
        other.dust == dust &&
        other.bloom == bloom &&
        other.halation == halation &&
        other.lensDistortion == lensDistortion &&
        other.chromaticAberration == chromaticAberration &&
        other.softness == softness &&
        other.highlightRollOff == highlightRollOff &&
        other.shadowRollOff == shadowRollOff &&
        other.dateStamp == dateStamp &&
        other.splitToning == splitToning;
  }

  @override
  int get hashCode => Object.hash(
    lightLeak,
    dust,
    bloom,
    halation,
    lensDistortion,
    chromaticAberration,
    softness,
    highlightRollOff,
    shadowRollOff,
    dateStamp,
    splitToning,
  );

  @override
  String toString() =>
      'PresetEffects(lightLeak: $lightLeak, dust: $dust, '
      'bloom: $bloom, halation: $halation, '
      'lensDistortion: $lensDistortion, '
      'chromaticAberration: $chromaticAberration, softness: $softness, '
      'highlightRollOff: $highlightRollOff, shadowRollOff: $shadowRollOff, '
      'dateStamp: $dateStamp, splitToning: $splitToning)';
}

/// Dynamic, data-driven preset recipe model.
@immutable
class PresetModel {
  /// Main constructor.
  const PresetModel({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.grain,
    required this.vignette,
    this.lut,
    this.overlay,
    this.behavior,
    this.effects = const PresetEffects(
      lightLeak: LightLeakEffect(intensity: 0, variant: -1),
      dust: DustEffect(intensity: 0),
    ),
    this.style,
  });

  /// Factory to parse from a JSON map.
  factory PresetModel.fromJson(Map<String, dynamic> json) => PresetModel(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    color: PresetColor.fromJson(json['color'] as Map<String, dynamic>),
    grain: PresetGrain.fromJson(json['grain'] as Map<String, dynamic>),
    vignette: PresetVignette.fromJson(json['vignette'] as Map<String, dynamic>),
    lut: json['lut'],
    overlay: json['overlay'],
    behavior: json['behavior'],
    effects: json['effects'] != null
        ? PresetEffects.fromJson(json['effects'] as Map<String, dynamic>)
        : const PresetEffects(
            lightLeak: LightLeakEffect(intensity: 0, variant: -1),
            dust: DustEffect(intensity: 0),
          ),
    style: json['style'] != null
        ? RanaStyle.fromJson(json['style'] as Map<String, dynamic>)
        : null,
  );

  /// The unique identifier of the preset.
  final String id;

  /// The display name of the preset.
  final String name;

  /// The category name of the preset (e.g. Classic, Disposable, Retro).
  final String category;

  /// Color parameters.
  final PresetColor color;

  /// Grain parameters.
  final PresetGrain grain;

  /// Vignette parameters.
  final PresetVignette vignette;

  /// Future placeholder for Look-Up Table (LUT) asset paths/objects.
  final dynamic lut;

  /// Future placeholder for light leak/dust overlay asset paths/objects.
  final dynamic overlay;

  /// Future placeholder for randomization behavior parameters.
  final dynamic behavior;

  /// Preset visual effects config.
  final PresetEffects effects;

  /// Optional style parameters for Phase 6.
  final RanaStyle? style;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'category': category,
    'color': color.toJson(),
    'grain': grain.toJson(),
    'vignette': vignette.toJson(),
    'lut': lut,
    'overlay': overlay,
    'behavior': behavior,
    'effects': effects.toJson(),
    'style': style?.toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetModel &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.color == color &&
        other.grain == grain &&
        other.vignette == vignette &&
        other.lut == lut &&
        other.overlay == overlay &&
        other.behavior == behavior &&
        other.effects == effects &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    color,
    grain,
    vignette,
    lut,
    overlay,
    behavior,
    effects,
    style,
  );

  @override
  String toString() =>
      'PresetModel(id: $id, name: $name, category: $category, '
      'color: $color, grain: $grain, vignette: $vignette, lut: $lut, '
      'overlay: $overlay, behavior: $behavior, effects: $effects, '
      'style: $style)';
}
