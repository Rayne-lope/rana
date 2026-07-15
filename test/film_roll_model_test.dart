import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/preset/model/rana_style.dart';

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
