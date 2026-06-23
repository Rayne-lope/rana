import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';

class FakeAssetBundle extends AssetBundle {
  final Map<String, String> _strings = {};
  final Map<String, ByteData> _bytes = {};

  void setString(String key, String value) {
    _strings[key] = value;
  }

  void setBytes(String key, ByteData value) {
    _bytes[key] = value;
  }

  @override
  Future<ByteData> load(String key) async {
    if (_bytes.containsKey(key)) {
      return _bytes[key]!;
    }
    if (_strings.containsKey(key)) {
      final list = utf8.encode(_strings[key]!);
      final bytes = Uint8List.fromList(list);
      return ByteData.sublistView(bytes);
    }
    throw Exception('Asset not found: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_strings.containsKey(key)) {
      return _strings[key]!;
    }
    throw Exception('Asset not found: $key');
  }
}

void main() {
  group('AssetPresetRepository Tests', () {
    test('Happy Path: loads multiple valid preset JSON files', () async {
      final manifestData = <String, List<Object>>{
        'assets/presets/normal.json': [],
        'assets/presets/rana_warm.json': [],
      };
      final encoded = const StandardMessageCodec().encodeMessage(manifestData)!;

      final bundle = FakeAssetBundle();
      bundle.setBytes('AssetManifest.bin', encoded);

      bundle.setString('assets/presets/normal.json', '''
{
  "id": "normal",
  "name": "Normal",
  "category": "Classic",
  "color": {
    "temperature": 0.0,
    "contrast": 0.0,
    "saturation": 0.0
  },
  "grain": {
    "intensity": 0.0
  },
  "vignette": {
    "intensity": 0.0
  },
  "lut": null,
  "overlay": null,
  "behavior": null
}
''');

      bundle.setString('assets/presets/rana_warm.json', '''
{
  "id": "rana_warm",
  "name": "Rana Warm",
  "category": "Classic",
  "color": {
    "temperature": 0.3,
    "contrast": 0.0,
    "saturation": 0.1
  },
  "grain": {
    "intensity": 0.1
  },
  "vignette": {
    "intensity": 0.05
  },
  "lut": null,
  "overlay": null,
  "behavior": null
}
''');

      final repository = AssetPresetRepository(assetBundle: bundle);
      final presets = await repository.loadAll();

      expect(presets.length, equals(2));
      expect(presets[0].id, equals('normal'));
      expect(presets[1].id, equals('rana_warm'));
      expect(presets[0].effects.bloom.threshold, equals(0.8));
      expect(presets[0].effects.bloom.intensity, equals(0.0));
      expect(presets[0].effects.halation.intensity, equals(0.0));
      expect(presets[1].effects.bloom.threshold, equals(0.8));
      expect(presets[1].effects.bloom.intensity, equals(0.0));
      expect(presets[1].effects.halation.intensity, equals(0.0));
    });

    test('Corrupt JSON: skips invalid files and logs error', () async {
      final manifestData = <String, List<Object>>{
        'assets/presets/normal.json': [],
        'assets/presets/corrupt.json': [],
      };
      final encoded = const StandardMessageCodec().encodeMessage(manifestData)!;

      final bundle = FakeAssetBundle();
      bundle.setBytes('AssetManifest.bin', encoded);

      bundle.setString('assets/presets/normal.json', '''
{
  "id": "normal",
  "name": "Normal",
  "category": "Classic",
  "color": {
    "temperature": 0.0,
    "contrast": 0.0,
    "saturation": 0.0
  },
  "grain": {
    "intensity": 0.0
  },
  "vignette": {
    "intensity": 0.0
  },
  "lut": null,
  "overlay": null,
  "behavior": null
}
''');

      bundle.setString('assets/presets/corrupt.json', '{invalid json}');

      final repository = AssetPresetRepository(assetBundle: bundle);
      final presets = await repository.loadAll();

      expect(presets.length, equals(1));
      expect(presets[0].id, equals('normal'));
      expect(presets[0].effects.bloom.threshold, equals(0.8));
      expect(presets[0].effects.bloom.intensity, equals(0.0));
      expect(presets[0].effects.halation.intensity, equals(0.0));
    });

    test('Missing File: skips missing files and logs error', () async {
      final manifestData = <String, List<Object>>{
        'assets/presets/normal.json': [],
        'assets/presets/missing.json': [],
      };
      final encoded = const StandardMessageCodec().encodeMessage(manifestData)!;

      final bundle = FakeAssetBundle();
      bundle.setBytes('AssetManifest.bin', encoded);

      bundle.setString('assets/presets/normal.json', '''
{
  "id": "normal",
  "name": "Normal",
  "category": "Classic",
  "color": {
    "temperature": 0.0,
    "contrast": 0.0,
    "saturation": 0.0
  },
  "grain": {
    "intensity": 0.0
  },
  "vignette": {
    "intensity": 0.0
  },
  "lut": null,
  "overlay": null,
  "behavior": null
}
''');

      // Do NOT set string for 'assets/presets/missing.json'

      final repository = AssetPresetRepository(assetBundle: bundle);
      final presets = await repository.loadAll();

      expect(presets.length, equals(1));
      expect(presets[0].id, equals('normal'));
      expect(presets[0].effects.bloom.threshold, equals(0.8));
      expect(presets[0].effects.bloom.intensity, equals(0.0));
      expect(presets[0].effects.halation.intensity, equals(0.0));
    });
  });
}
