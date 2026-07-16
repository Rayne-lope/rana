import 'package:flutter/foundation.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';

/// Gallery-ready projection of one archived Film Roll.
///
/// Native Film Roll capture records remain the source of chronological order,
/// while [availableItems] contains only the records that are still visible in
/// the current MediaStore snapshot. This lets Gallery preserve the archived
/// roll when an individual photo has since been deleted or is not accessible.
@immutable
class GalleryFilmRoll {
  GalleryFilmRoll({
    required this.roll,
    required List<RollCaptureEntry> captures,
    required List<GalleryMediaItem> availableItems,
  }) : captures = List<RollCaptureEntry>.unmodifiable(
         _sortedCaptures(captures),
       ),
       availableItems = List<GalleryMediaItem>.unmodifiable(
         _orderedAvailableItems(captures, availableItems),
       );

  /// Persisted completed Film Roll record.
  final FilmRoll roll;

  /// Native capture records in chronological order.
  final List<RollCaptureEntry> captures;

  /// MediaStore items that remain available, in [captures] order.
  final List<GalleryMediaItem> availableItems;

  /// A displayable cover item, preferring the persisted first frame.
  ///
  /// A persisted cover URI is useful only while it remains available in the
  /// current MediaStore snapshot. If it is no longer accessible, fall back to
  /// the first remaining frame so callers can render a real thumbnail rather
  /// than attempt to load a stale URI.
  GalleryMediaItem? get preferredCover {
    final coverUri = roll.coverUri;
    if (coverUri != null) {
      for (final item in availableItems) {
        if (item.contentUri == coverUri) return item;
      }
    }
    return availableItems.isEmpty ? null : availableItems.first;
  }

  /// URI for [preferredCover], or null when no frame is currently available.
  String? get preferredCoverUri => preferredCover?.contentUri;

  /// First native frame date, or the archived roll start when no frame exists.
  DateTime get dateRangeStart =>
      captures.isEmpty ? roll.startedAt : captures.first.capturedAt;

  /// Last native frame date, or the archived completion/start date fallback.
  DateTime get dateRangeEnd => captures.isEmpty
      ? (roll.completedAt ?? roll.startedAt)
      : captures.last.capturedAt;

  /// Number of saved exposures that are no longer available in MediaStore.
  int get unavailableFrameCount {
    final unavailable = roll.exposuresTaken - availableItems.length;
    return unavailable < 0 ? 0 : unavailable;
  }

  /// Whether the user ended this archived roll before all frames were used.
  bool get isEarlyEnded => roll.exposuresTaken < roll.size.count;

  static List<RollCaptureEntry> _sortedCaptures(
    List<RollCaptureEntry> captures,
  ) {
    final sorted = List<RollCaptureEntry>.from(captures)
      ..sort((a, b) {
        final timestamp = a.capturedAt.compareTo(b.capturedAt);
        if (timestamp != 0) return timestamp;
        final exposure = a.exposureIndex.compareTo(b.exposureIndex);
        if (exposure != 0) return exposure;
        return a.mediaUri.compareTo(b.mediaUri);
      });
    return sorted;
  }

  static List<GalleryMediaItem> _orderedAvailableItems(
    List<RollCaptureEntry> captures,
    List<GalleryMediaItem> items,
  ) {
    final itemsByUri = <String, GalleryMediaItem>{
      for (final item in items) item.contentUri: item,
    };
    final seenUris = <String>{};
    final ordered = <GalleryMediaItem>[];
    for (final capture in _sortedCaptures(captures)) {
      if (!seenUris.add(capture.mediaUri)) continue;
      final item = itemsByUri[capture.mediaUri];
      if (item != null) ordered.add(item);
    }
    return ordered;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryFilmRoll &&
        other.roll == roll &&
        listEquals(other.captures, captures) &&
        listEquals(other.availableItems, availableItems);
  }

  @override
  int get hashCode => Object.hash(
    roll,
    Object.hashAll(captures),
    Object.hashAll(availableItems),
  );
}
