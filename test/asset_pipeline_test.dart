import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/utils/asset_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetConstants', () {
    test('defines non-empty directory paths', () {
      expect(AssetConstants.presetsDir, isNotEmpty);
      expect(AssetConstants.overlaysDir, isNotEmpty);
      expect(AssetConstants.stampsDir, isNotEmpty);
      expect(AssetConstants.iconsDir, isNotEmpty);
    });

    test('directory paths end with a trailing slash', () {
      expect(AssetConstants.presetsDir, endsWith('/'));
      expect(AssetConstants.overlaysDir, endsWith('/'));
      expect(AssetConstants.stampsDir, endsWith('/'));
      expect(AssetConstants.iconsDir, endsWith('/'));
    });

    test('placeholderPreset path points to a non-empty asset', () async {
      final bytes =
          await rootBundle.load(AssetConstants.placeholderPreset);
      expect(bytes.lengthInBytes, greaterThan(0));
    });

    test('placeholderPreset is valid JSON', () async {
      final raw =
          await rootBundle.loadString(AssetConstants.placeholderPreset);
      final dynamic decoded = jsonDecode(raw);
      expect(decoded, isA<Map<String, dynamic>>());
      final map = decoded as Map<String, dynamic>;
      expect(map['id'], equals('placeholder'));
      expect(map['version'], equals(1));
    });
  });
}
