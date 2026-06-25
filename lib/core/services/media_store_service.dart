import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/gallery/model/gallery_media_item.dart';

/// Android MediaStore access for gallery metadata and thumbnails.
class MediaStoreService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.rana.app/camera_control',
  );

  /// Loads Rana media entries from MediaStore.
  Future<List<GalleryMediaItem>> loadGalleryItems() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'listGalleryMedia',
      );
      final rawItems = result ?? const [];
      return rawItems
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (entry) =>
                GalleryMediaItem.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'MediaStoreService',
        'Failed to load gallery items from MediaStore',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Loads thumbnail bytes for a single MediaStore image URI.
  Future<Uint8List> loadThumbnailBytes(
    String uri, {
    int targetSize = 360,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Uint8List>(
        'loadGalleryThumbnailBytes',
        {'uri': uri, 'targetSize': targetSize},
      );
      return result ?? Uint8List(0);
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'MediaStoreService',
        'Failed to load gallery thumbnail: $uri',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Opens Android's share sheet for a MediaStore image URI.
  Future<void> shareGalleryMedia(String uri) async {
    try {
      await _methodChannel.invokeMethod<void>('shareGalleryMedia', {
        'uri': uri,
      });
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'MediaStoreService',
        'Failed to share gallery media: $uri',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Deletes a MediaStore image URI.
  ///
  /// Scoped-storage consent is requested by Android when needed.
  Future<void> deleteGalleryMedia(String uri) async {
    try {
      await _methodChannel.invokeMethod<void>('deleteGalleryMedia', {
        'uri': uri,
      });
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'MediaStoreService',
        'Failed to delete gallery media: $uri',
        e,
        stack,
      );
      rethrow;
    }
  }
}
