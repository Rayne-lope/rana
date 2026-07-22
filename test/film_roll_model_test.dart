import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/render/model/render_recipe.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 15, 16);
  const lockedStyle = RanaStyle(
    tone: 18,
    color: -12,
    texture: 42,
    styleStrength: 76,
    undertoneX: -0.2,
    undertoneY: 0.3,
  );

  FilmRoll roll(FilmRollSize size, {int exposuresTaken = 0}) => FilmRoll(
    id: 'roll-${size.count}',
    presetId: 'portra',
    lockedStyle: lockedStyle,
    aspectRatioPlatformValue: 'portrait_3_4',
    size: size,
    exposuresTaken: exposuresTaken,
    status: FilmRollStatus.active,
    startedAt: createdAt,
  );

  test('FilmRoll preserves its locked recipe through JSON', () {
    final original = roll(FilmRollSize.twentyFour, exposuresTaken: 7);

    expect(FilmRoll.fromJson(original.toJson()), original);
    expect(original.toJson()['schemaVersion'], currentFilmRollSchemaVersion);
    expect(original.lockedRecipe.presetId, 'portra');
  });

  test('Film Roll v1 reconstructs a locked v1 recipe when read', () {
    final current = roll(FilmRollSize.twelve);
    final legacy = Map<String, dynamic>.from(current.toJson())
      ..remove('schemaVersion')
      ..remove('lockedRecipe');

    final migrated = FilmRoll.fromJson(legacy);

    expect(migrated.needsRecipeMigration, isTrue);
    expect(migrated.lockedRecipe.presetId, current.presetId);
    expect(migrated.lockedRecipe.aspectRatio, current.aspectRatioPlatformValue);
    expect(migrated.lockedRecipe.tone, lockedStyle.tone);
  });

  test('unknown locked recipe is rejected without deleting the roll', () {
    final stored = roll(FilmRollSize.twelve).toJson();
    stored['lockedRecipe'] = <String, dynamic>{'recipeVersion': 50};

    expect(
      () => FilmRoll.fromJson(stored),
      throwsA(isA<UnsupportedRenderRecipeVersion>()),
    );
  });

  test('FilmRoll preserves terminal archive metadata through JSON', () {
    final archived = roll(FilmRollSize.twelve, exposuresTaken: 4).copyWith(
      status: FilmRollStatus.completed,
      completedAt: DateTime.utc(2026, 7, 15, 18),
      coverUri: 'content://rana/roll-cover',
    );

    final restored = FilmRoll.fromJson(archived.toJson());

    expect(restored.status, FilmRollStatus.completed);
    expect(restored.completedAt, archived.completedAt);
    expect(restored.coverUri, archived.coverUri);
    expect(restored.presetId, 'portra');
    expect(restored.lockedStyle, lockedStyle);
    expect(restored.aspectRatioPlatformValue, 'portrait_3_4');
  });

  test('FilmRoll reports capacity correctly for every supported size', () {
    for (final size in FilmRollSize.values) {
      final almostFull = roll(size, exposuresTaken: size.count - 1);
      final full = roll(size, exposuresTaken: size.count);

      expect(almostFull.isFull, isFalse);
      expect(almostFull.remainingExposures, 1);
      expect(full.isFull, isTrue);
      expect(full.remainingExposures, 0);
    }
  });
}
