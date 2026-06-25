import 'package:rana/core/providers/permission_provider.dart';
import 'package:rana/core/services/media_store_service.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_controller.g.dart';

@Riverpod(keepAlive: true)
class GalleryController extends _$GalleryController {
  late final MediaStoreService _mediaStoreService;

  @override
  GalleryState build() {
    _mediaStoreService = MediaStoreService();
    return GalleryState.initial();
  }

  /// Loads the recent Rana media items from Android MediaStore.
  Future<void> loadGallery() async {
    final permissionState = ref.read(permissionControllerProvider);
    if (!permissionState.hasStorage) {
      state = state.copyWith(
        status: GalleryStatus.permissionDenied,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(status: GalleryStatus.loading, errorMessage: null);

    try {
      final items = await _mediaStoreService.loadGalleryItems();
      state = GalleryState(
        status: items.isEmpty ? GalleryStatus.empty : GalleryStatus.loaded,
        items: items,
        errorMessage: null,
      );
    } on Object catch (e) {
      state = state.copyWith(
        status: GalleryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
