import 'package:flutter/foundation.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';

/// Loading status for the gallery screen.
enum GalleryStatus { loading, loaded, empty, permissionDenied, error }

/// Immutable gallery state used by the gallery screen controller.
@immutable
class GalleryState {
  const GalleryState({
    required this.status,
    required this.items,
    required this.errorMessage,
    required this.favoriteIds,
    required this.showFavoritesOnly,
  });

  factory GalleryState.initial() => const GalleryState(
    status: GalleryStatus.loading,
    items: [],
    errorMessage: null,
    favoriteIds: {},
    showFavoritesOnly: false,
  );

  final GalleryStatus status;
  final List<GalleryMediaItem> items;
  final String? errorMessage;
  final Set<String> favoriteIds;
  final bool showFavoritesOnly;

  List<GalleryMediaItem> get visibleItems => showFavoritesOnly
      ? items
            .where((item) => favoriteIds.contains(item.id))
            .toList(growable: false)
      : items;

  bool get isLoading => status == GalleryStatus.loading;
  bool get isPermissionDenied => status == GalleryStatus.permissionDenied;
  bool get isEmpty => status == GalleryStatus.empty;
  bool get isError => status == GalleryStatus.error;
  bool isFavorite(String id) => favoriteIds.contains(id);

  GalleryState copyWith({
    GalleryStatus? status,
    List<GalleryMediaItem>? items,
    String? errorMessage,
    Set<String>? favoriteIds,
    bool? showFavoritesOnly,
  }) => GalleryState(
    status: status ?? this.status,
    items: items ?? this.items,
    errorMessage: errorMessage,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GalleryState &&
        other.status == status &&
        listEquals(other.items, items) &&
        other.errorMessage == errorMessage &&
        setEquals(other.favoriteIds, favoriteIds) &&
        other.showFavoritesOnly == showFavoritesOnly;
  }

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(items),
    errorMessage,
    Object.hashAll(favoriteIds),
    showFavoritesOnly,
  );
}
