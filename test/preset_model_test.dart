import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/model/preset_model.dart';

void main() {
  group('PresetModel.fromJson Tests', () {
    test('successfully parses normal.json', () {
      final file = File('assets/presets/normal.json');
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final jsonMap = decoded as Map<String, dynamic>;

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'normal');
      expect(model.name, 'Normal');
      expect(model.category, 'Classic');
      expect(model.color.temperature, 0.0);
      expect(model.color.contrast, 0.0);
      expect(model.color.saturation, 0.0);
      expect(model.grain.intensity, 0.0);
      expect(model.vignette.intensity, 0.0);
      expect(model.lut, isNull);
      expect(model.overlay, isNull);
      expect(model.behavior, isNull);
      expect(model.effects.lightLeak.intensity, 0.0);
      expect(model.effects.lightLeak.variant, -1);
      expect(model.effects.dust.intensity, 0.0);
      expect(model.effects.bloom.threshold, 0.8);
      expect(model.effects.bloom.intensity, 0.0);
      expect(model.effects.halation.intensity, 0.0);
      expect(model.effects.lensDistortion.strength, 0.0);
    });

    test('successfully parses rana_warm.json', () {
      final file = File('assets/presets/rana_warm.json');
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final jsonMap = decoded as Map<String, dynamic>;

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'rana_warm');
      expect(model.name, 'Rana Warm');
      expect(model.category, 'Classic');
      expect(model.color.temperature, 0.3);
      expect(model.color.contrast, 0.0);
      expect(model.color.saturation, 0.1);
      expect(model.grain.intensity, 0.1);
      expect(model.vignette.intensity, 0.05);
      expect(model.lut, 'assets/luts/rana_warm_v1.png');
      expect(model.overlay, isNull);
      expect(model.behavior, isNull);
      expect(model.effects.lightLeak.intensity, 0.2);
      expect(model.effects.lightLeak.variant, -1);
      expect(model.effects.dust.intensity, 0.08);
      expect(model.effects.bloom.threshold, 0.7);
      expect(model.effects.bloom.intensity, 0.10);
      expect(model.effects.halation.intensity, 0.08);
      expect(model.effects.lensDistortion.strength, 0.06);
    });

    test('successfully parses rana_cool.json', () {
      final file = File('assets/presets/rana_cool.json');
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final jsonMap = decoded as Map<String, dynamic>;

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'rana_cool');
      expect(model.name, 'Rana Cool');
      expect(model.category, 'Classic');
      expect(model.color.temperature, -0.3);
      expect(model.color.contrast, 0.0);
      expect(model.color.saturation, 0.05);
      expect(model.grain.intensity, 0.0);
      expect(model.vignette.intensity, 0.0);
      expect(model.lut, 'assets/luts/rana_cool_v1.png');
      expect(model.overlay, isNull);
      expect(model.behavior, isNull);
      expect(model.effects.lightLeak.intensity, 0.1);
      expect(model.effects.lightLeak.variant, -1);
      expect(model.effects.dust.intensity, 0.0);
      expect(model.effects.bloom.threshold, 0.8);
      expect(model.effects.bloom.intensity, 0.0);
      expect(model.effects.halation.intensity, 0.0);
      expect(model.effects.lensDistortion.strength, 0.04);
    });

    test('successfully parses rana_mono.json', () {
      final file = File('assets/presets/rana_mono.json');
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final jsonMap = decoded as Map<String, dynamic>;

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'rana_mono');
      expect(model.name, 'Rana Mono');
      expect(model.category, 'Classic');
      expect(model.color.temperature, 0.0);
      expect(model.color.contrast, 0.1);
      expect(model.color.saturation, -1.0);
      expect(model.grain.intensity, 0.0);
      expect(model.vignette.intensity, 0.0);
      expect(model.lut, isNull);
      expect(model.overlay, isNull);
      expect(model.behavior, isNull);
      expect(model.effects.lightLeak.intensity, 0.0);
      expect(model.effects.lightLeak.variant, -1);
      expect(model.effects.dust.intensity, 0.20);
      expect(model.effects.bloom.threshold, 0.8);
      expect(model.effects.bloom.intensity, 0.0);
      expect(model.effects.halation.intensity, 0.0);
      expect(model.effects.lensDistortion.strength, 0.08);
    });
  });
}
