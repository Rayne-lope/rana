import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final active = FilmRoll(
    id: 'active-roll',
    presetId: 'portra',
    lockedStyle: const RanaStyle(tone: 12, texture: 35),
    aspectRatioPlatformValue: 'portrait_3_4',
    size: FilmRollSize.twelve,
    exposuresTaken: 3,
    status: FilmRollStatus.active,
    startedAt: DateTime.utc(2026, 7, 15, 16),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('isolates the active roll from completed history', () async {
    const repository = SharedPreferencesFilmRollRepository();

    await repository.save(active);
    expect(await repository.loadActive(), active);
    expect(await repository.loadAll(), isEmpty);

    final completed = active.copyWith(
      status: FilmRollStatus.completed,
      completedAt: DateTime.utc(2026, 7, 15, 17),
    );
    await repository.save(completed);

    expect(await repository.loadActive(), isNull);
    expect(await repository.loadAll(), [completed]);
  });

  test(
    'upserts and deletes completed history without disturbing other rolls',
    () async {
      const repository = SharedPreferencesFilmRollRepository();
      final older = active.copyWith(
        id: 'older-roll',
        status: FilmRollStatus.completed,
        startedAt: DateTime.utc(2026, 7, 14, 16),
        completedAt: DateTime.utc(2026, 7, 14, 17),
        coverUri: 'content://rana/older-cover',
      );
      final newer = active.copyWith(
        id: 'newer-roll',
        status: FilmRollStatus.completed,
        startedAt: DateTime.utc(2026, 7, 16, 16),
        completedAt: DateTime.utc(2026, 7, 16, 17),
        coverUri: 'content://rana/newer-cover',
      );

      await repository.save(older);
      await repository.save(newer);
      final updatedNewer = newer.copyWith(
        exposuresTaken: FilmRollSize.twelve.count,
        coverUri: 'content://rana/newer-cover-updated',
      );
      await repository.save(updatedNewer);

      expect(await repository.loadAll(), [updatedNewer, older]);

      await repository.delete(updatedNewer.id);

      expect(await repository.loadAll(), [older]);
      expect(await repository.loadActive(), isNull);
    },
  );

  test('hides abandoned records persisted by an earlier build', () async {
    final abandoned = active.copyWith(status: FilmRollStatus.abandoned);
    SharedPreferences.setMockInitialValues({
      'rana.film_rolls.v1': json.encode([abandoned.toJson()]),
    });
    const repository = SharedPreferencesFilmRollRepository();

    expect(await repository.loadAll(), isEmpty);
  });

  test('reads v1 history and rewrites it as schema v2 on next save', () async {
    final completed = active.copyWith(
      status: FilmRollStatus.completed,
      completedAt: DateTime.utc(2026, 7, 15, 17),
    );
    final legacy = Map<String, dynamic>.from(completed.toJson())
      ..remove('schemaVersion')
      ..remove('lockedRecipe');
    SharedPreferences.setMockInitialValues({
      'rana.film_rolls.v1': json.encode(<Map<String, dynamic>>[legacy]),
    });
    const repository = SharedPreferencesFilmRollRepository();

    final migrated = (await repository.loadAll()).single;
    expect(migrated.lockedRecipe.presetId, completed.presetId);
    await repository.save(migrated);

    final prefs = await SharedPreferences.getInstance();
    final stored = json.decode(prefs.getString('rana.film_rolls.v2')!) as List;
    final storedRoll = Map<String, dynamic>.from(stored.single as Map);
    final storedRecipe = Map<String, dynamic>.from(
      storedRoll['lockedRecipe'] as Map,
    );
    expect(storedRoll['schemaVersion'], currentFilmRollSchemaVersion);
    expect(storedRecipe['recipeVersion'], 1);
  });

  test('deleting an active roll preserves no grouping record', () async {
    const repository = SharedPreferencesFilmRollRepository();
    await repository.save(active);

    await repository.delete(active.id);

    expect(await repository.loadActive(), isNull);
    expect(await repository.loadAll(), isEmpty);
  });
}
