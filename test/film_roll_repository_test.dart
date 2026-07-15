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

  test('hides abandoned records persisted by an earlier build', () async {
    final abandoned = active.copyWith(status: FilmRollStatus.abandoned);
    SharedPreferences.setMockInitialValues({
      'rana.film_rolls.v1': json.encode([abandoned.toJson()]),
    });
    const repository = SharedPreferencesFilmRollRepository();

    expect(await repository.loadAll(), isEmpty);
  });

  test('deleting an active roll preserves no grouping record', () async {
    const repository = SharedPreferencesFilmRollRepository();
    await repository.save(active);

    await repository.delete(active.id);

    expect(await repository.loadActive(), isNull);
    expect(await repository.loadAll(), isEmpty);
  });
}
