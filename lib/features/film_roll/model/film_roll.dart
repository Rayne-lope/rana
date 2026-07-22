import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/render/model/render_recipe.dart';

const int currentFilmRollSchemaVersion = 2;

final class UnsupportedFilmRollSchemaVersion implements Exception {
  const UnsupportedFilmRollSchemaVersion(this.version);

  final int version;
  String get code => 'UNSUPPORTED_FILM_ROLL_SCHEMA';
}

// ── Domain rules ────────────────────────────────────────────────────────────
//
// Film Roll v1 invariants:
//  1. A failed capture NEVER consumes an exposure. The exposure counter is
//     incremented only after the native `capture_completed` event fires and
//     the image URI is confirmed.
//  2. Only ONE roll can be active at a time.
//  3. While a roll is active the preset AND aspect ratio are locked; the user
//     must end or abandon the roll before switching either.
//  4. Abandoning a roll keeps all already-saved photos individually visible in
//     the Gallery; only the roll-grouping record is removed.
//  5. A full roll automatically completes after its final saved exposure.
// ────────────────────────────────────────────────────────────────────────────

/// Number of exposures available on a film roll.
enum FilmRollSize {
  twelve(count: 12, label: '12'),
  twentyFour(count: 24, label: '24'),
  thirtySix(count: 36, label: '36');

  const FilmRollSize({required this.count, required this.label});

  /// Maximum number of exposures for this roll size.
  final int count;

  /// Human-readable shot count label.
  final String label;

  /// Parses from the integer count stored in JSON.
  static FilmRollSize fromCount(int count) => switch (count) {
    12 => FilmRollSize.twelve,
    24 => FilmRollSize.twentyFour,
    36 => FilmRollSize.thirtySix,
    _ => FilmRollSize.thirtySix,
  };
}

/// Lifecycle status of a film roll.
enum FilmRollStatus {
  /// A roll that is currently being shot.
  active,

  /// All exposures were used and the roll was ended.
  completed,

  /// The user manually ended the roll before all exposures were used.
  abandoned;

  /// Parses from the string stored in JSON.
  static FilmRollStatus fromString(String? value) => switch (value) {
    'active' => FilmRollStatus.active,
    'completed' => FilmRollStatus.completed,
    'abandoned' => FilmRollStatus.abandoned,
    _ => FilmRollStatus.active,
  };
}

/// Immutable representation of a film roll and its progress.
@immutable
class FilmRoll {
  /// Main constructor.
  FilmRoll({
    required this.id,
    required this.presetId,
    required this.lockedStyle,
    required this.aspectRatioPlatformValue,
    required this.size,
    required this.exposuresTaken,
    required this.status,
    required this.startedAt,
    RenderRecipeV1? lockedRecipe,
    this.completedAt,
    this.coverUri,
  }) : lockedRecipe =
           lockedRecipe ??
           RenderRecipeV1(
             tone: lockedStyle.tone,
             color: lockedStyle.color,
             texture: lockedStyle.textureVal ?? lockedStyle.texture,
             styleStrength: lockedStyle.styleStrength,
             undertoneX: lockedStyle.undertoneX,
             undertoneY: lockedStyle.undertoneY,
             aspectRatio: aspectRatioPlatformValue,
             presetId: presetId,
             isStyleModified: true,
           );

  /// Parses a [FilmRoll] from a JSON map produced by [toJson].
  factory FilmRoll.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion < 1 || schemaVersion > currentFilmRollSchemaVersion) {
      throw UnsupportedFilmRollSchemaVersion(schemaVersion);
    }
    final lockedStyle = json['lockedStyle'] is Map<String, dynamic>
        ? RanaStyle.fromJson(json['lockedStyle'] as Map<String, dynamic>)
        : const RanaStyle();
    final presetId = json['presetId'] as String;
    final aspectRatio =
        json['aspectRatioPlatformValue'] as String? ?? 'portrait_3_4';
    final lockedRecipeValue = json['lockedRecipe'];
    final lockedRecipe = lockedRecipeValue is Map<dynamic, dynamic>
        ? RenderRecipeV1.fromMap(lockedRecipeValue)
        : RenderRecipeV1(
            tone: lockedStyle.tone,
            color: lockedStyle.color,
            texture: lockedStyle.textureVal ?? lockedStyle.texture,
            styleStrength: lockedStyle.styleStrength,
            undertoneX: lockedStyle.undertoneX,
            undertoneY: lockedStyle.undertoneY,
            aspectRatio: aspectRatio,
            presetId: presetId,
            isStyleModified: true,
          );
    return FilmRoll(
      id: json['id'] as String,
      presetId: presetId,
      lockedStyle: lockedStyle,
      lockedRecipe: lockedRecipe,
      aspectRatioPlatformValue: aspectRatio,
      size: FilmRollSize.fromCount((json['size'] as num?)?.toInt() ?? 36),
      exposuresTaken: (json['exposuresTaken'] as num?)?.toInt() ?? 0,
      status: FilmRollStatus.fromString(json['status'] as String?),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      coverUri: json['coverUri'] as String?,
    );
  }

  /// Universally unique identifier for this roll (UUID v4).
  final String id;

  /// Preset ID locked at roll-start time.
  final String presetId;

  /// Custom style values frozen with [presetId] when the roll was loaded.
  ///
  /// The value is stored rather than reconstructed from the current editor
  /// state so an app restart cannot change the recipe of an active roll.
  final RanaStyle lockedStyle;

  /// Full visual recipe frozen when this roll starts (Film Roll schema v2).
  final RenderRecipeV1 lockedRecipe;

  /// Platform aspect-ratio value locked at roll-start time
  /// (e.g. `'portrait_3_4'`, `'square_1_1'`, `'portrait_9_16'`).
  final String aspectRatioPlatformValue;

  /// Roll size (max exposures).
  final FilmRollSize size;

  /// Number of exposures successfully saved so far.
  ///
  /// Rule: this is incremented ONLY after native `capture_completed` confirms
  /// the image was written. A failed capture never increments this count.
  final int exposuresTaken;

  /// Current lifecycle status.
  final FilmRollStatus status;

  /// When the roll was started.
  final DateTime startedAt;

  /// When the roll was completed or abandoned (null while active).
  final DateTime? completedAt;

  /// Content URI of the first successfully captured photo (cover image).
  final String? coverUri;

  // ── Derived getters ────────────────────────────────────────────────────────

  /// True when all exposures have been used.
  bool get isFull => exposuresTaken >= size.count;

  /// True when this roll is currently being shot.
  bool get isActive => status == FilmRollStatus.active;

  /// Remaining exposures (clamps to zero).
  int get remainingExposures =>
      (size.count - exposuresTaken).clamp(0, size.count);

  // ── Serialization ──────────────────────────────────────────────────────────

  /// Converts this instance to a JSON-serializable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': currentFilmRollSchemaVersion,
    'id': id,
    'presetId': presetId,
    'lockedStyle': lockedStyle.toJson(),
    'lockedRecipe': lockedRecipe.toMap(),
    'aspectRatioPlatformValue': aspectRatioPlatformValue,
    'size': size.count,
    'exposuresTaken': exposuresTaken,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'coverUri': coverUri,
  };

  /// Returns a copy of this instance with the specified fields replaced.
  FilmRoll copyWith({
    String? id,
    String? presetId,
    RanaStyle? lockedStyle,
    RenderRecipeV1? lockedRecipe,
    String? aspectRatioPlatformValue,
    FilmRollSize? size,
    int? exposuresTaken,
    FilmRollStatus? status,
    DateTime? startedAt,
    Object? completedAt = _unset,
    Object? coverUri = _unset,
  }) => FilmRoll(
    id: id ?? this.id,
    presetId: presetId ?? this.presetId,
    lockedStyle: lockedStyle ?? this.lockedStyle,
    lockedRecipe: lockedRecipe ?? this.lockedRecipe,
    aspectRatioPlatformValue:
        aspectRatioPlatformValue ?? this.aspectRatioPlatformValue,
    size: size ?? this.size,
    exposuresTaken: exposuresTaken ?? this.exposuresTaken,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?,
    coverUri: identical(coverUri, _unset) ? this.coverUri : coverUri as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilmRoll &&
        other.id == id &&
        other.presetId == presetId &&
        other.lockedStyle == lockedStyle &&
        other.lockedRecipe == lockedRecipe &&
        other.aspectRatioPlatformValue == aspectRatioPlatformValue &&
        other.size == size &&
        other.exposuresTaken == exposuresTaken &&
        other.status == status &&
        other.startedAt == startedAt &&
        other.completedAt == completedAt &&
        other.coverUri == coverUri;
  }

  @override
  int get hashCode => Object.hash(
    id,
    presetId,
    lockedStyle,
    lockedRecipe,
    aspectRatioPlatformValue,
    size,
    exposuresTaken,
    status,
    startedAt,
    completedAt,
    coverUri,
  );

  @override
  String toString() =>
      'FilmRoll(id: $id, presetId: $presetId, '
      'lockedStyle: $lockedStyle, '
      'aspectRatio: $aspectRatioPlatformValue, '
      'size: ${size.count}, exposuresTaken: $exposuresTaken, '
      'status: ${status.name}, startedAt: $startedAt, '
      'completedAt: $completedAt, coverUri: $coverUri)';
}
