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
      expect(model.color.fade, 0.0);
      expect(model.color.matrix, PresetColor.identityMatrix);
      expect(model.grain.intensity, 0.0);
      expect(model.grain.size, 1.0);
      expect(model.vignette.intensity, 0.0);
      expect(model.vignette.color, PresetVignette.defaultColor);
      expect(model.vignette.roundness, 0.0);
      expect(model.lut, isNull);
      expect(model.overlay, isNull);
      expect(model.behavior, isNull);
      expect(model.effects.lightLeak.intensity, 0.0);
      expect(model.effects.lightLeak.variant, 0);
      expect(model.effects.dust.intensity, 0.0);
      expect(model.effects.bloom.threshold, 0.8);
      expect(model.effects.bloom.intensity, 0.0);
      expect(model.effects.halation.intensity, 0.0);
      expect(model.effects.halation.radius, 1.0);
      expect(model.effects.halation.color, PresetHalation.defaultColor);
      expect(model.effects.lensDistortion.strength, 0.0);
      expect(model.effects.chromaticAberration?.intensity, 0.0);
      expect(model.effects.softness, 0.0);
      expect(model.effects.highlightRollOff, 0.0);
      expect(model.effects.shadowRollOff, 0.0);
      expect(model.effects.filmBorder.style, FilmBorderStyle.none);
      expect(model.effects.dateStamp?.enable, isFalse);
      expect(model.effects.splitToning?.shadowsTint, <double>[0, 0, 0]);
      expect(model.effects.splitToning?.highlightsTint, <double>[0, 0, 0]);
      expect(model.style, isNotNull);
      expect(model.style!.tone, 0.0);
      expect(model.style!.color, 0.0);
      expect(model.style!.styleStrength, 100.0);
      expect(model.style!.undertoneX, 0.0);
      expect(model.style!.undertoneY, 0.0);
      expect(model.style!.textureVal, 0.0);
    });

    test('instant presets opt into instant film border', () {
      for (final path in <String>[
        'assets/presets/fujifilm_instax_mini_white.json',
        'assets/presets/polaroid_color_600.json',
        'assets/presets/polaroid_color_sx70.json',
      ]) {
        final decoded = json.decode(File(path).readAsStringSync());
        final model = PresetModel.fromJson(decoded as Map<String, dynamic>);

        expect(
          model.effects.filmBorder.style,
          FilmBorderStyle.instant,
          reason: path,
        );
      }
    });

    test('successfully parses Kodak Gold photographic style defaults', () {
      final file = File('assets/presets/kodak_gold_200.json');
      final jsonStr = file.readAsStringSync();
      final decoded = json.decode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final jsonMap = decoded as Map<String, dynamic>;

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'kodak_gold_200');
      expect(model.name, 'Kodak Gold 200');
      expect(model.style, isNotNull);
      expect(model.style!.tone, -8.0);
      expect(model.style!.color, 14.0);
      expect(model.style!.texture, 0.0);
      expect(model.style!.styleStrength, 100.0);
      expect(model.style!.undertoneX, -0.42);
      expect(model.style!.undertoneY, -0.04);
    });

    test('Matte Pastel opts into a subtle light vignette', () {
      final decoded = json.decode(
        File('assets/presets/matte_pastel_100.json').readAsStringSync(),
      );
      final model = PresetModel.fromJson(decoded as Map<String, dynamic>);

      expect(model.vignette.color, <double>[1, 0.98, 0.94]);
      expect(model.vignette.roundness, 0.75);
    });

    test('successfully parses preset with style block', () {
      final jsonMap = {
        'id': 'custom_styled',
        'name': 'Custom Styled',
        'category': 'Custom',
        'color': {'temperature': 0.1, 'contrast': -0.1, 'saturation': 0.2},
        'grain': {'intensity': 0.15},
        'vignette': {'intensity': 0.3},
        'lut': 'assets/luts/custom.png',
        'effects': {
          'lightLeak': {'intensity': 0.1, 'variant': 2},
          'dust': {'intensity': 0.05},
        },
        'style': {
          'tone': 12.0,
          'color': -15.0,
          'texture': 25.0,
          'styleStrength': 85.0,
          'undertoneX': 0.35,
          'undertoneY': -0.45,
        },
      };

      final model = PresetModel.fromJson(jsonMap);

      expect(model.id, 'custom_styled');
      expect(model.style, isNotNull);
      expect(model.style!.tone, 12.0);
      expect(model.style!.color, -15.0);
      expect(model.style!.texture, 25.0);
      expect(model.style!.styleStrength, 85.0);
      expect(model.style!.undertoneX, 0.35);
      expect(model.style!.undertoneY, -0.45);

      final serialized = model.toJson();
      final styleMap = serialized['style'] as Map<String, dynamic>;
      expect(styleMap['tone'], 12.0);
      expect(styleMap['color'], -15.0);
      expect(styleMap['texture'], 25.0);
      expect(styleMap['textureVal'], 25.0);
      expect(styleMap['styleStrength'], 85.0);
      expect(styleMap['undertoneX'], 0.35);
      expect(styleMap['undertoneY'], -0.45);
    });

    test('parses and serializes optional analog effects', () {
      final model = PresetModel.fromJson(const <String, dynamic>{
        'id': 'analog_custom',
        'name': 'Analog Custom',
        'category': 'Custom',
        'color': <String, dynamic>{
          'temperature': 0.1,
          'contrast': 0.2,
          'saturation': -0.1,
          'fade': 0.3,
          'matrix': <dynamic>[1.1, 0.1, 0, 0, 0.9, 0.1, 0, 0.2, 0.8],
        },
        'grain': <String, dynamic>{'intensity': 0.4, 'size': 1.7},
        'vignette': <String, dynamic>{
          'intensity': 0.2,
          'color': <dynamic>[1.2, 0.9, 0.8],
          'roundness': 0.75,
        },
        'effects': <String, dynamic>{
          'chromaticAberration': <String, dynamic>{'intensity': 0.15},
          'halation': <String, dynamic>{
            'intensity': 0.35,
            'radius': 2.5,
            'color': <dynamic>[0.9, 0.25, 0.05],
          },
          'softness': 0.25,
          'highlightRollOff': 0.6,
          'shadowRollOff': 0.4,
          'filmBorder': <String, dynamic>{'style': '35mm'},
          'dateStamp': <String, dynamic>{'enable': true},
          'splitToning': <String, dynamic>{
            'shadowsTint': <dynamic>[0.1, 0.2],
            'highlightsTint': <dynamic>[0.7, 'invalid', 0.9],
          },
        },
        'style': <String, dynamic>{'textureVal': 30.0},
      });

      expect(model.color.fade, 0.3);
      expect(model.color.matrix, <double>[
        1.1,
        0.1,
        0,
        0,
        0.9,
        0.1,
        0,
        0.2,
        0.8,
      ]);
      expect(model.grain.size, 1.7);
      expect(model.vignette.color, <double>[1, 0.9, 0.8]);
      expect(model.vignette.roundness, 0.75);
      expect(model.effects.chromaticAberration?.intensity, 0.15);
      expect(model.effects.halation.intensity, 0.35);
      expect(model.effects.halation.radius, 2.5);
      expect(model.effects.halation.color, <double>[0.9, 0.25, 0.05]);
      expect(model.effects.softness, 0.25);
      expect(model.effects.highlightRollOff, 0.6);
      expect(model.effects.shadowRollOff, 0.4);
      expect(model.effects.filmBorder.style, FilmBorderStyle.thirtyFiveMm);
      expect(model.effects.dateStamp?.enable, isTrue);
      expect(model.effects.splitToning?.shadowsTint, <double>[0.1, 0.2, 0]);
      expect(model.effects.splitToning?.highlightsTint, <double>[0.7, 0, 0.9]);
      expect(model.style?.texture, 30.0);
      expect(model.style?.textureVal, 30.0);

      final serialized = model.toJson();
      final effects = serialized['effects'] as Map<String, dynamic>;
      final color = serialized['color'] as Map<String, dynamic>;
      final vignette = serialized['vignette'] as Map<String, dynamic>;
      expect(color['matrix'], <double>[1.1, 0.1, 0, 0, 0.9, 0.1, 0, 0.2, 0.8]);
      expect(vignette['color'], <double>[1, 0.9, 0.8]);
      expect(vignette['roundness'], 0.75);
      expect(effects['softness'], 0.25);
      expect(effects['highlightRollOff'], 0.6);
      expect(effects['shadowRollOff'], 0.4);
      expect(effects['filmBorder'], <String, dynamic>{'style': '35mm'});
      expect(effects['dateStamp'], <String, dynamic>{'enable': true});
      expect(effects['chromaticAberration'], <String, dynamic>{
        'intensity': 0.15,
      });
      expect(effects['halation'], <String, dynamic>{
        'intensity': 0.35,
        'radius': 2.5,
        'color': <double>[0.9, 0.25, 0.05],
      });
      expect(effects['splitToning'], <String, dynamic>{
        'shadowsTint': <double>[0.1, 0.2, 0],
        'highlightsTint': <double>[0.7, 0, 0.9],
      });
    });

    test('invalid film border style resolves to none', () {
      final border = PresetFilmBorder.fromJson(const <String, dynamic>{
        'style': 'unknown',
      });

      expect(border.style, FilmBorderStyle.none);
      expect(border.toJson(), <String, dynamic>{'style': 'none'});
    });

    test(
      'invalid vignette color and out of range roundness are normalized',
      () {
        final vignette = PresetVignette.fromJson(const <String, dynamic>{
          'intensity': 0.5,
          'color': <dynamic>[1, 'bad', 0],
          'roundness': 2,
        });

        expect(vignette.color, PresetVignette.defaultColor);
        expect(vignette.roundness, 1.0);
      },
    );

    test('invalid color matrix resolves to identity', () {
      final base = <String, dynamic>{
        'id': 'bad_matrix',
        'name': 'Bad Matrix',
        'category': 'Custom',
        'grain': <String, dynamic>{'intensity': 0.0},
        'vignette': <String, dynamic>{'intensity': 0.0},
      };

      for (final matrix in <dynamic>[
        <dynamic>[1, 0, 0],
        <dynamic>[1, 0, 0, 0, 1, 0, 0, 'bad', 1],
      ]) {
        final model = PresetModel.fromJson(<String, dynamic>{
          ...base,
          'color': <String, dynamic>{
            'temperature': 0.0,
            'contrast': 0.0,
            'saturation': 0.0,
            'matrix': matrix,
          },
        });

        expect(model.color.matrix, PresetColor.identityMatrix);
      }
    });

    test('invalid halation color resolves to legacy hue', () {
      final model = PresetModel.fromJson(const <String, dynamic>{
        'id': 'bad_halation',
        'name': 'Bad Halation',
        'category': 'Custom',
        'color': <String, dynamic>{
          'temperature': 0.0,
          'contrast': 0.0,
          'saturation': 0.0,
        },
        'grain': <String, dynamic>{'intensity': 0.0},
        'vignette': <String, dynamic>{'intensity': 0.0},
        'effects': <String, dynamic>{
          'halation': <String, dynamic>{
            'intensity': 0.2,
            'color': <dynamic>[1.0, 'bad', 0.0],
          },
        },
      });

      expect(model.effects.halation.radius, 1.0);
      expect(model.effects.halation.color, PresetHalation.defaultColor);
    });
  });
}
