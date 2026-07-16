import 'package:flutter/foundation.dart';
import 'package:rana/features/gallery/model/gallery_film_roll.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';

/// Loading status for the gallery screen.
enum GalleryStatus { loading, loaded, empty, permissionDenied, error }

/// Date filtering options for the gallery screen.
enum GalleryTimeFilter { all, today, thisWeek }

/// The Gallery surface currently shown to the user.
enum GalleryViewMode { photos, rolls }

/// Independent loading state for archived Film Rolls.
///
/// Rolls deliberately do not share [GalleryStatus]: native Film Roll metadata
/// can still be read when MediaStore photo access is limited or unavailable.
enum GalleryRollLoadStatus { initial, loading, loaded, empty, error }

/// Immutable gallery state used by the gallery screen controller.
@immutable
class GalleryState {
  const GalleryState({
    required this.status,
    required this.items,
    required this.errorMessage,
    required this.favoriteIds,
    required this.showFavoritesOnly,
    required this.timeFilter,
    required this.viewMode,
    required this.rollsStatus,
    required this.rolls,
    required this.rollsErrorMessage,
  });

  factory GalleryState.initial() => const GalleryState(
    status: GalleryStatus.loading,
    items: [],
    errorMessage: null,
    favoriteIds: {},
    showFavoritesOnly: false,
    timeFilter: GalleryTimeFilter.all,
    viewMode: GalleryViewMode.photos,
    rollsStatus: GalleryRollLoadStatus.initial,
    rolls: [],
    rollsErrorMessage: null,
  );

  final GalleryStatus status;
  final List<GalleryMediaItem> items;
  final String? errorMessage;
  final Set<String> favoriteIds;
  final bool showFavoritesOnly;
  final GalleryTimeFilter timeFilter;
  final GalleryViewMode viewMode;
  final GalleryRollLoadStatus rollsStatus;
  final List<GalleryFilmRoll> rolls;
  final String? rollsErrorMessage;

  List<GalleryMediaItem> get visibleItems {
    var filtered = showFavoritesOnly
        ? items.where((item) => favoriteIds.contains(item.id)).toList()
        : items.toList();

    if (timeFilter == GalleryTimeFilter.today) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      filtered = filtered
          .where((item) => item.dateTaken.isAfter(todayStart))
          .toList();
    } else if (timeFilter == GalleryTimeFilter.thisWeek) {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      filtered = filtered
          .where((item) => item.dateTaken.isAfter(oneWeekAgo))
          .toList();
    }

    return filtered;
  }

  bool get isLoading => status == GalleryStatus.loading;
  bool get isPermissionDenied => status == GalleryStatus.permissionDenied;
  bool get isEmpty => status == GalleryStatus.empty;
  bool get isError => status == GalleryStatus.error;
  bool isFavorite(String id) => favoriteIds.contains(id);
  bool get isRollsLoading => rollsStatus == GalleryRollLoadStatus.loading;
  bool get isRollsEmpty => rollsStatus == GalleryRollLoadStatus.empty;
  bool get isRollsError => rollsStatus == GalleryRollLoadStatus.error;

  /// Looks up an archived Film Roll projection by its persisted identifier.
  GalleryFilmRoll? rollForId(String rollId) {
    for (final roll in rolls) {
      if (roll.roll.id == rollId) return roll;
    }
    return null;
  }

  GalleryState copyWith({
    GalleryStatus? status,
    List<GalleryMediaItem>? items,
    Object? errorMessage = _unset,
    Set<String>? favoriteIds,
    bool? showFavoritesOnly,
    GalleryTimeFilter? timeFilter,
    GalleryViewMode? viewMode,
    GalleryRollLoadStatus? rollsStatus,
    List<GalleryFilmRoll>? rolls,
    Object? rollsErrorMessage = _unset,
  }) => GalleryState(
    status: status ?? this.status,
    items: items ?? this.items,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
    timeFilter: timeFilter ?? this.timeFilter,
    viewMode: viewMode ?? this.viewMode,
    rollsStatus: rollsStatus ?? this.rollsStatus,
    rolls: rolls ?? this.rolls,
    rollsErrorMessage: identical(rollsErrorMessage, _unset)
        ? this.rollsErrorMessage
        : rollsErrorMessage as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryState &&
        other.status == status &&
        listEquals(other.items, items) &&
        other.errorMessage == errorMessage &&
        setEquals(other.favoriteIds, favoriteIds) &&
        other.showFavoritesOnly == showFavoritesOnly &&
        other.timeFilter == timeFilter &&
        other.viewMode == viewMode &&
        other.rollsStatus == rollsStatus &&
        listEquals(other.rolls, rolls) &&
        other.rollsErrorMessage == rollsErrorMessage;
  }

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(items),
    errorMessage,
    Object.hashAll(favoriteIds),
    showFavoritesOnly,
    timeFilter,
    viewMode,
    rollsStatus,
    Object.hashAll(rolls),
    rollsErrorMessage,
  );
}
