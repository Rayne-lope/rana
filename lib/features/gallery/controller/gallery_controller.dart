import 'package:rana/core/providers/permission_provider.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'gallery_controller.g.dart';

@Riverpod(keepAlive: true)
class GalleryController extends _$GalleryController {
  static const _favoriteIdsKey = 'rana_gallery_favorite_ids';

  late final MediaStoreService _mediaStoreService;
  bool _favoritesLoaded = false;

  @override
  GalleryState build() {
    _mediaStoreService = MediaStoreService();
    return GalleryState.initial();
  }

  /// Loads the recent Rana media items from Android MediaStore.
  Future<void> loadGallery() async {
    await _ensureFavoritesLoaded();

    final permissionState = ref.read(permissionControllerProvider);
    if (!permissionState.hasStorage) {
      state = GalleryState(
        status: GalleryStatus.permissionDenied,
        items: state.items,
        errorMessage: null,
        favoriteIds: state.favoriteIds,
        showFavoritesOnly: state.showFavoritesOnly,
        timeFilter: state.timeFilter,
      );
      return;
    }

    state = GalleryState(
      status: GalleryStatus.loading,
      items: state.items,
      errorMessage: null,
      favoriteIds: state.favoriteIds,
      showFavoritesOnly: state.showFavoritesOnly,
      timeFilter: state.timeFilter,
    );

    try {
      final items = await _mediaStoreService.loadGalleryItems();
      final sortedItems = List<GalleryMediaItem>.from(items)
        ..sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
      state = GalleryState(
        status: sortedItems.isEmpty
            ? GalleryStatus.empty
            : GalleryStatus.loaded,
        items: sortedItems,
        errorMessage: null,
        favoriteIds: state.favoriteIds,
        showFavoritesOnly: state.showFavoritesOnly,
        timeFilter: state.timeFilter,
      );
    } on Object catch (e) {
      state = state.copyWith(
        status: GalleryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> shareItem(String uri) =>
      _mediaStoreService.shareGalleryMedia(uri);

  Future<void> deleteItem(String uri) async {
    await _mediaStoreService.deleteGalleryMedia(uri);
    final items = state.items
        .where((item) => item.contentUri != uri)
        .toList(growable: false);
    state = GalleryState(
      status: items.isEmpty ? GalleryStatus.empty : GalleryStatus.loaded,
      items: items,
      errorMessage: null,
      favoriteIds: state.favoriteIds,
      showFavoritesOnly: state.showFavoritesOnly,
      timeFilter: state.timeFilter,
    );
  }

  Future<void> toggleFavorite(String id) async {
    await _ensureFavoritesLoaded();

    final favoriteIds = Set<String>.from(state.favoriteIds);
    if (!favoriteIds.add(id)) {
      favoriteIds.remove(id);
    }

    state = state.copyWith(favoriteIds: favoriteIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteIdsKey, favoriteIds.toList()..sort());
  }

  Future<void> setFavoritesOnly({required bool value}) async {
    await _ensureFavoritesLoaded();
    state = state.copyWith(showFavoritesOnly: value);
  }

  void setTimeFilter(GalleryTimeFilter filter) {
    state = state.copyWith(timeFilter: filter);
  }

  Future<void> _ensureFavoritesLoaded() async {
    if (_favoritesLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoriteIdsKey)?.toSet() ?? {};
    _favoritesLoaded = true;
    state = state.copyWith(favoriteIds: favoriteIds);
  }
}
