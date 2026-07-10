import 'package:flutter/foundation.dart';

/// Rana Style parameters (inspired by Photographic Styles).
@immutable
class RanaStyle {
  /// Main constructor.
  const RanaStyle({
    this.tone = 0.0,
    this.color = 0.0,
    double? texture,
    double? textureVal,
    this.styleStrength = 100.0,
    this.undertoneX = 0.0,
    this.undertoneY = 0.0,
  }) : texture = textureVal ?? texture ?? 0.0;

  /// Factory to parse from a JSON map.
  factory RanaStyle.fromJson(Map<String, dynamic> json) => RanaStyle(
    tone: (json['tone'] as num?)?.toDouble() ?? 0.0,
    color: (json['color'] as num?)?.toDouble() ?? 0.0,
    textureVal:
        (json['textureVal'] as num?)?.toDouble() ??
        (json['texture'] as num?)?.toDouble() ??
        0.0,
    styleStrength: (json['styleStrength'] as num?)?.toDouble() ?? 100.0,
    undertoneX: (json['undertoneX'] as num?)?.toDouble() ?? 0.0,
    undertoneY: (json['undertoneY'] as num?)?.toDouble() ?? 0.0,
  );

  /// Factory to create a neutral RanaStyle.
  factory RanaStyle.neutral() => const RanaStyle();

  /// Copies this instance, replacing specified fields.
  RanaStyle copyWith({
    double? tone,
    double? color,
    double? texture,
    double? textureVal,
    double? styleStrength,
    double? undertoneX,
    double? undertoneY,
  }) => RanaStyle(
    tone: tone ?? this.tone,
    color: color ?? this.color,
    textureVal: textureVal ?? texture ?? this.texture,
    styleStrength: styleStrength ?? this.styleStrength,
    undertoneX: undertoneX ?? this.undertoneX,
    undertoneY: undertoneY ?? this.undertoneY,
  );

  /// Tone parameter (-100.0 to 100.0).
  final double tone;

  /// Color parameter (-100.0 to 100.0).
  final double color;

  /// Texture parameter (0.0 to 100.0).
  final double texture;

  /// Canonical JSON alias for [texture].
  double? get textureVal => texture;

  /// Style Strength parameter (0.0 to 100.0).
  final double styleStrength;

  /// Undertone X axis (Warm-Cool: -1.0 to 1.0).
  final double undertoneX;

  /// Undertone Y axis (Green-Magenta: -1.0 to 1.0).
  final double undertoneY;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'tone': tone,
    'color': color,
    'texture': texture,
    'textureVal': texture,
    'styleStrength': styleStrength,
    'undertoneX': undertoneX,
    'undertoneY': undertoneY,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RanaStyle &&
        other.tone == tone &&
        other.color == color &&
        other.texture == texture &&
        other.styleStrength == styleStrength &&
        other.undertoneX == undertoneX &&
        other.undertoneY == undertoneY;
  }

  @override
  int get hashCode =>
      Object.hash(tone, color, texture, styleStrength, undertoneX, undertoneY);

  @override
  String toString() =>
      'RanaStyle(tone: $tone, color: $color, texture: $texture, '
      'textureVal: $textureVal, '
      'styleStrength: $styleStrength, undertoneX: $undertoneX, '
      'undertoneY: $undertoneY)';
}
