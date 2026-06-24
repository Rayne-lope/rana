import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';
import 'package:rana/features/preset/repository/saved_rana_style_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SavedRanaStyleRepository Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves loads replaces and deletes saved styles', () async {
      const repository = SharedPreferencesSavedRanaStyleRepository();
      final createdAt = DateTime.utc(2026, 6, 24, 10);
      final savedStyle = SavedRanaStyle(
        id: SavedRanaStyle.createId(createdAt),
        name: 'Warm Rose',
        basePresetId: 'rana_warm',
        style: const RanaStyle(
          tone: 24,
          color: 18,
          texture: 40,
          styleStrength: 82,
          undertoneX: -0.5,
          undertoneY: 0.25,
        ),
        createdAt: createdAt,
      );

      await repository.save(savedStyle);
      final loaded = await repository.loadAll();

      expect(loaded, equals([savedStyle]));

      final renamed = SavedRanaStyle(
        id: savedStyle.id,
        name: 'Warm Rose II',
        basePresetId: savedStyle.basePresetId,
        style: savedStyle.style.copyWith(tone: 12),
        createdAt: savedStyle.createdAt,
      );

      await repository.save(renamed);
      expect(await repository.loadAll(), equals([renamed]));

      await repository.delete(savedStyle.id);
      expect(await repository.loadAll(), isEmpty);
    });

    test('returns an empty list for corrupt storage', () async {
      SharedPreferences.setMockInitialValues({
        'rana.saved_styles.v1': '{broken',
      });
      const repository = SharedPreferencesSavedRanaStyleRepository();

      expect(await repository.loadAll(), isEmpty);
    });
  });
}
