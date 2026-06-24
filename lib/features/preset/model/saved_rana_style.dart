import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/rana_style.dart';

/// Locally saved Rana Style metadata.
@immutable
class SavedRanaStyle {
  /// Main constructor.
  const SavedRanaStyle({
    required this.id,
    required this.name,
    required this.basePresetId,
    required this.style,
    required this.createdAt,
  });

  /// Factory to parse from a JSON map.
  factory SavedRanaStyle.fromJson(Map<String, dynamic> json) => SavedRanaStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    basePresetId: json['basePresetId'] as String,
    style: RanaStyle.fromJson(json['style'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// Category used when saved styles are shown in the preset strip.
  static const String category = 'My Styles';

  /// Prefix used to distinguish locally saved style presets.
  static const String idPrefix = 'style_';

  /// Creates a stable unique id for a new saved style.
  static String createId(DateTime createdAt) =>
      '$idPrefix${createdAt.microsecondsSinceEpoch}';

  /// Returns true when a preset id points at a locally saved style.
  static bool isSavedStylePresetId(String id) => id.startsWith(idPrefix);

  /// Unique local id.
  final String id;

  /// User-visible saved style name.
  final String name;

  /// Asset/base preset id that this style layers on top of.
  final String basePresetId;

  /// Saved editable style parameters.
  final RanaStyle style;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'basePresetId': basePresetId,
    'style': style.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedRanaStyle &&
        other.id == id &&
        other.name == name &&
        other.basePresetId == basePresetId &&
        other.style == style &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, basePresetId, style, createdAt);
}
