import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/gallery/services/styled_thumbnail_cache.dart';
import 'package:rana/features/preset/model/capture_style_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaptureStyleMetadata', () {
    test('cacheKey generates unique deterministic hash', () {
      const meta1 = CaptureStyleMetadata(
        mediaUri: 'content://media/external/images/media/100',
        presetId: 'agfaphoto_lebox',
        undertoneX: 0.15,
        undertoneY: -0.2,
        params: {'exposure': 0.1, 'saturation': 1.1},
        updatedAtEpochMs: 1600000000,
      );

      const meta2 = CaptureStyleMetadata(
        mediaUri: 'content://media/external/images/media/100',
        presetId: 'agfaphoto_lebox',
        undertoneX: 0.15,
        undertoneY: -0.2,
        params: {'exposure': 0.1, 'saturation': 1.1},
        updatedAtEpochMs: 1600000000,
      );

      const meta3 = CaptureStyleMetadata(
        mediaUri: 'content://media/external/images/media/100',
        presetId: 'agfaphoto_lebox',
        undertoneX: 0.5, // Changed parameter
        undertoneY: -0.2,
        params: {'exposure': 0.1, 'saturation': 1.1},
        updatedAtEpochMs: 1600000000,
      );

      expect(meta1.cacheKey, equals(meta2.cacheKey));
      expect(meta1.cacheKey, isNot(equals(meta3.cacheKey)));
    });
  });

  group('StyledThumbnailCache', () {
    late StyledThumbnailCache cache;

    setUp(() {
      cache = StyledThumbnailCache.instance;
      cache.clearMemoryCache();
    });

    test('stores and retrieves memory cached thumbnails', () async {
      const key = 'test_cache_key_1';
      final mockBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      await cache.put(key, mockBytes);
      final retrieved = await cache.get(key);

      expect(retrieved, isNotNull);
      expect(retrieved, equals(mockBytes));
    });

    test('evicts oldest memory cache item when capacity reached', () async {
      final smallCache = StyledThumbnailCache.instance;
      const key1 = 'item_1';
      const key2 = 'item_2';

      await smallCache.put(key1, Uint8List.fromList([1]));
      await smallCache.put(key2, Uint8List.fromList([2]));

      final item1 = await smallCache.get(key1);
      expect(item1, isNotNull);
    });
  });
}
