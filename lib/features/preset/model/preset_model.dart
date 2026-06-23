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
        other.behavior == behavior;
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
      );

  @override
  String toString() =>
      'PresetModel(id: $id, name: $name, category: $category, '
      'color: $color, grain: $grain, vignette: $vignette, lut: $lut, '
      'overlay: $overlay, behavior: $behavior)';
}
