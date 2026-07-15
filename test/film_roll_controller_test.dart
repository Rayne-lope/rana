import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/preset/model/rana_style.dart';

class _MemoryFilmRollRepository implements FilmRollRepository {
  FilmRoll? active;
  final List<FilmRoll> history = <FilmRoll>[];

  @override
  Future<void> delete(String id) async {
    if (active?.id == id) {
      active = null;
      return;
    }
    history.removeWhere((roll) => roll.id == id);
  }

  @override
  Future<FilmRoll?> loadActive() async => active;

  @override
  Future<List<FilmRoll>> loadAll() async => List<FilmRoll>.unmodifiable(
    history.where((roll) => roll.status == FilmRollStatus.completed),
  );

  @override
  Future<void> save(FilmRoll roll) async {
    if (roll.status == FilmRollStatus.active) {
      active = roll;
      return;
    }
    if (active?.id == roll.id) active = null;
    history
      ..removeWhere((existing) => existing.id == roll.id)
      ..add(roll);
  }
}

void main() {
  ProviderContainer containerFor(_MemoryFilmRollRepository repository) =>
      ProviderContainer(
        overrides: [filmRollRepositoryProvider.overrideWithValue(repository)],
      );

  Future<FilmRollController> readyController(
    ProviderContainer container,
  ) async {
    final controller = container.read(filmRollControllerProvider.notifier);
    await controller.waitUntilRestored();
    return controller;
  }

  Future<void> start(FilmRollController controller) => controller.startRoll(
    presetId: 'portra',
    lockedStyle: const RanaStyle(tone: 18, color: -4, texture: 30),
    size: FilmRollSize.twelve,
    aspectRatioPlatformValue: 'portrait_3_4',
  );

  test(
    'serializes concurrent completions without losing an exposure',
    () async {
      final container = containerFor(_MemoryFilmRollRepository());
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);

      final first = controller.reserveExposure()!;
      final second = controller.reserveExposure()!;
      await Future.wait([
        controller.recordExposure(
          captureId: 'capture-1',
          reservation: first,
          mediaUri: 'content://photo/1',
        ),
        controller.recordExposure(
          captureId: 'capture-2',
          reservation: second,
          mediaUri: 'content://photo/2',
        ),
      ]);

      final roll = container.read(filmRollControllerProvider).activeRoll!;
      expect(roll.exposuresTaken, 2);
      expect(roll.coverUri, 'content://photo/1');
      expect(
        container.read(filmRollControllerProvider).pendingExposureCount,
        0,
      );
    },
  );

  test(
    'duplicates do not consume an exposure and failures release capacity',
    () async {
      final container = containerFor(_MemoryFilmRollRepository());
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);

      final failed = controller.reserveExposure()!;
      await controller.releaseExposure(failed);
      expect(
        container.read(filmRollControllerProvider).pendingExposureCount,
        0,
      );

      final reservation = controller.reserveExposure()!;
      await controller.recordExposure(
        captureId: 'capture-1',
        reservation: reservation,
        mediaUri: 'content://photo/1',
      );
      await controller.recordExposure(
        captureId: 'capture-1',
        reservation: reservation,
        mediaUri: 'content://photo/1',
      );

      expect(
        container.read(filmRollControllerProvider).activeRoll!.exposuresTaken,
        1,
      );
    },
  );

  test(
    'final exposure auto-completes and capacity blocks extra reservations',
    () async {
      final repository = _MemoryFilmRollRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);

      for (var index = 0; index < 11; index += 1) {
        final reservation = controller.reserveExposure()!;
        await controller.recordExposure(
          captureId: 'capture-$index',
          reservation: reservation,
          mediaUri: 'content://photo/$index',
        );
      }

      final finalReservation = controller.reserveExposure()!;
      expect(controller.reserveExposure(), isNull);
      await controller.recordExposure(
        captureId: 'capture-11',
        reservation: finalReservation,
        mediaUri: 'content://photo/11',
      );

      final state = container.read(filmRollControllerProvider);
      expect(state.activeRoll, isNull);
      expect(state.latestCompletedRoll!.exposuresTaken, 12);
      expect(repository.history, hasLength(1));
    },
  );

  test('abandon removes the grouping but preserves no archived roll', () async {
    final repository = _MemoryFilmRollRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = await readyController(container);
    await start(controller);

    expect(await controller.abandonRoll(), isTrue);
    expect(container.read(filmRollControllerProvider).activeRoll, isNull);
    expect(repository.active, isNull);
    expect(repository.history, isEmpty);
  });
}
