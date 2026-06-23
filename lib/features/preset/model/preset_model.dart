import 'package:flutter/foundation.dart';

/// Preset color parameters.
@immutable
class PresetColor {
  /// Main constructor.
  const PresetColor({
    required this.temperature,
    required this.contrast,
    required this.saturation,
  });

  /// Factory to parse from a JSON map.
  factory PresetColor.fromJson(Map<String, dynamic> json) => PresetColor(
        temperature: (json['temperature'] as num).toDouble(),
        contrast: (json['contrast'] as num).toDouble(),
        saturation: (json['saturation'] as num).toDouble(),
      );

  /// The temperature parameter.
  final double temperature;

  /// The contrast parameter.
  final double contrast;

  /// The saturation parameter.
  final double saturation;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperature': temperature,
        'contrast': contrast,
        'saturation': saturation,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetColor &&
        other.temperature == temperature &&
        other.contrast == contrast &&
        other.saturation == saturation;
  }

  @override
  int get hashCode => Object.hash(temperature, contrast, saturation);

  @override
  String toString() => 'PresetColor(temperature: $temperature, '
      'contrast: $contrast, saturation: $saturation)';
}

/// Preset grain parameters.
@immutable
class PresetGrain {
  /// Main constructor.
  const PresetGrain({
    required this.intensity,
  });

  /// Factory to parse from a JSON map.
  factory PresetGrain.fromJson(Map<String, dynamic> json) => PresetGrain(
        intensity: (json['intensity'] as num).toDouble(),
      );

  /// The grain intensity parameter.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'intensity': intensity,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetGrain && other.intensity == intensity;
  }

  @override
  int get hashCode => intensity.hashCode;

  @override
  String toString() => 'PresetGrain(intensity: $intensity)';
}

/// Preset vignette parameters.
@immutable
class PresetVignette {
  /// Main constructor.
  const PresetVignette({
    required this.intensity,
  });

  /// Factory to parse from a JSON map.
  factory PresetVignette.fromJson(Map<String, dynamic> json) => PresetVignette(
        intensity: (json['intensity'] as num).toDouble(),
      );

  /// The vignette intensity parameter.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'intensity': intensity,
      };

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
  const LightLeakEffect({
    required this.intensity,
    required this.variant,
  });

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
  const DustEffect({
    required this.intensity,
  });

  /// Factory to parse from a JSON map.
  factory DustEffect.fromJson(Map<String, dynamic> json) => DustEffect(
        intensity: (json['intensity'] as num).toDouble(),
      );

  /// The dust and scratches overlay intensity.
  final double intensity;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'intensity': intensity,
      };

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

/// Group of preset effects.
@immutable
class PresetEffects {
  /// Main constructor.
  const PresetEffects({
    required this.lightLeak,
    required this.dust,
  });

  /// Factory to parse from a JSON map.
  factory PresetEffects.fromJson(Map<String, dynamic> json) {
    final lightLeakJson = json['lightLeak'] as Map<String, dynamic>?;
    final dustJson = json['dust'] as Map<String, dynamic>?;
    return PresetEffects(
      lightLeak: lightLeakJson != null
          ? LightLeakEffect.fromJson(lightLeakJson)
          : const LightLeakEffect(intensity: 0, variant: -1),
      dust: dustJson != null
          ? DustEffect.fromJson(dustJson)
          : const DustEffect(intensity: 0),
    );
  }

  /// Light leak effect configurations.
  final LightLeakEffect lightLeak;

  /// Dust and scratches effect configurations.
  final DustEffect dust;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'lightLeak': lightLeak.toJson(),
        'dust': dust.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetEffects &&
        other.lightLeak == lightLeak &&
        other.dust == dust;
  }

  @override
  int get hashCode => Object.hash(lightLeak, dust);

  @override
  String toString() => 'PresetEffects(lightLeak: $lightLeak, dust: $dust)';
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
  });

  /// Factory to parse from a JSON map.
  factory PresetModel.fromJson(Map<String, dynamic> json) => PresetModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        color: PresetColor.fromJson(
          json['color'] as Map<String, dynamic>,
        ),
        grain: PresetGrain.fromJson(
          json['grain'] as Map<String, dynamic>,
        ),
        vignette: PresetVignette.fromJson(
          json['vignette'] as Map<String, dynamic>,
        ),
        lut: json['lut'],
        overlay: json['overlay'],
        behavior: json['behavior'],
        effects: json['effects'] != null
            ? PresetEffects.fromJson(json['effects'] as Map<String, dynamic>)
            : const PresetEffects(
                lightLeak: LightLeakEffect(intensity: 0, variant: -1),
                dust: DustEffect(intensity: 0),
              ),
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
        other.effects == effects;
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
      );

  @override
  String toString() =>
      'PresetModel(id: $id, name: $name, category: $category, '
      'color: $color, grain: $grain, vignette: $vignette, lut: $lut, '
      'overlay: $overlay, behavior: $behavior, effects: $effects)';
}
