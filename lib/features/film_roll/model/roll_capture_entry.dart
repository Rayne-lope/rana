import 'package:flutter/foundation.dart';

/// Ephemeral reservation for one native capture started while a roll is active.
///
/// Reservations are never persisted. They prevent concurrent processing from
/// accepting more shots than the roll permits, while still allowing a failed
/// native capture to release its reserved exposure.
@immutable
class FilmRollExposureReservation {
  const FilmRollExposureReservation({
    required this.id,
    required this.filmRollId,
  });

  /// Unique request-local identifier.
  final String id;

  /// Roll to which the in-flight capture belongs.
  final String filmRollId;

  @override
  bool operator ==(Object other) =>
      other is FilmRollExposureReservation &&
      other.id == id &&
      other.filmRollId == filmRollId;

  @override
  int get hashCode => Object.hash(id, filmRollId);
}

/// Associates a single captured image URI with a film roll.
///
/// Used by the Gallery Rolls view to group [GalleryMediaItem]s under a roll
/// without modifying the MediaStore query or the [GalleryMediaItem] model.
@immutable
class RollCaptureEntry {
  /// Main constructor.
  const RollCaptureEntry({
    required this.filmRollId,
    required this.mediaUri,
    required this.capturedAt,
    required this.exposureIndex,
  });

  /// Parses from a JSON map.
  factory RollCaptureEntry.fromJson(Map<String, dynamic> json) =>
      RollCaptureEntry(
        filmRollId: json['filmRollId'] as String,
        mediaUri: json['mediaUri'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        exposureIndex: (json['exposureIndex'] as num?)?.toInt() ?? 0,
      );

  /// The roll this capture belongs to.
  final String filmRollId;

  /// `content://` URI of the saved MediaStore image.
  final String mediaUri;

  /// When the capture was completed.
  final DateTime capturedAt;

  /// 1-based index of this exposure within the roll (1 = first shot).
  final int exposureIndex;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'filmRollId': filmRollId,
    'mediaUri': mediaUri,
    'capturedAt': capturedAt.toIso8601String(),
    'exposureIndex': exposureIndex,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollCaptureEntry &&
        other.filmRollId == filmRollId &&
        other.mediaUri == mediaUri &&
        other.capturedAt == capturedAt &&
        other.exposureIndex == exposureIndex;
  }

  @override
  int get hashCode =>
      Object.hash(filmRollId, mediaUri, capturedAt, exposureIndex);

  @override
  String toString() =>
      'RollCaptureEntry(filmRollId: $filmRollId, '
      'mediaUri: $mediaUri, exposureIndex: $exposureIndex, '
      'capturedAt: $capturedAt)';
}
