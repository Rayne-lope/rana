import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/preset/model/rana_style.dart';

class _MemoryFilmRollRepository implements FilmRollRepository {
  _MemoryFilmRollRepository({this.restoreCompleter});

  FilmRoll? active;
  final List<FilmRoll> history = <FilmRoll>[];
  final Completer<FilmRoll?>? restoreCompleter;
  int failSaveAttempts = 0;
  bool failLoadActive = false;
  int saveCalls = 0;

  @override
  Future<void> delete(String id) async {
    if (active?.id == id) {
      active = null;
      return;
    }
    history.removeWhere((roll) => roll.id == id);
  }

  @override
  Future<FilmRoll?> loadActive() async {
    if (failLoadActive) throw StateError('restore unavailable');
    final completer = restoreCompleter;
    if (completer != null) return completer.future;
    return active;
  }

  @override
  Future<List<FilmRoll>> loadAll() async => List<FilmRoll>.unmodifiable(
    history.where((roll) => roll.status == FilmRollStatus.completed),
  );

  @override
  Future<void> save(FilmRoll roll) async {
    saveCalls += 1;
    if (failSaveAttempts > 0) {
      failSaveAttempts -= 1;
      throw StateError('disk unavailable');
    }
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

  Future<FilmRollActionResult> start(FilmRollController controller) =>
      controller.startRoll(
        presetId: 'portra',
        lockedStyle: const RanaStyle(tone: 18, color: -4, texture: 30),
        size: FilmRollSize.twelve,
        aspectRatioPlatformValue: 'portrait_3_4',
      );

  test(
    'delayed restoration prevents concurrent starts from overwriting a roll',
    () async {
      final restored = Completer<FilmRoll?>();
      final repository = _MemoryFilmRollRepository(restoreCompleter: restored);
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(filmRollControllerProvider.notifier);

      expect(
        container.read(filmRollControllerProvider).restorationStatus,
        FilmRollRestorationStatus.restoring,
      );
      final firstStart = start(controller);
      final secondStart = start(controller);
      restored.complete(null);

      final results = await Future.wait([firstStart, secondStart]);
      expect(results.where((result) => result.succeeded), hasLength(1));
      expect(
        results.where((result) => !result.succeeded).single.failure,
        FilmRollActionFailure.activeRollAlreadyExists,
      );
      expect(repository.saveCalls, 1);
      expect(container.read(filmRollControllerProvider).activeRoll, isNotNull);
    },
  );

  test('restoration failure is explicit and blocks new rolls', () async {
    final repository = _MemoryFilmRollRepository()..failLoadActive = true;
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = await readyController(container);

    expect(
      container.read(filmRollControllerProvider).restorationStatus,
      FilmRollRestorationStatus.failed,
    );
    final result = await start(controller);
    expect(result.succeeded, isFalse);
    expect(result.failure, FilmRollActionFailure.restorationFailed);
  });

  test('serializes close completions without losing either exposure', () async {
    final container = containerFor(_MemoryFilmRollRepository());
    addTearDown(container.dispose);
    final controller = await readyController(container);
    expect((await start(controller)).succeeded, isTrue);

    final first = controller.tryReserveExposure().reservation!;
    final second = controller.tryReserveExposure().reservation!;
    final results = await Future.wait([
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

    expect(results.every((result) => result.succeeded), isTrue);
    final roll = container.read(filmRollControllerProvider).activeRoll!;
    expect(roll.exposuresTaken, 2);
    expect(roll.coverUri, 'content://photo/1');
    expect(container.read(filmRollControllerProvider).pendingExposureCount, 0);
  });

  test(
    'duplicate completion is idempotent and failed native capture frees slot',
    () async {
      final container = containerFor(_MemoryFilmRollRepository());
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);

      final failed = controller.tryReserveExposure().reservation!;
      expect((await controller.releaseExposure(failed)).succeeded, isTrue);
      expect(
        container.read(filmRollControllerProvider).pendingExposureCount,
        0,
      );

      final reservation = controller.tryReserveExposure().reservation!;
      expect(
        (await controller.recordExposure(
          captureId: 'capture-1',
          reservation: reservation,
          mediaUri: 'content://photo/1',
        )).succeeded,
        isTrue,
      );
      final duplicate = await controller.recordExposure(
        captureId: 'capture-1',
        reservation: reservation,
        mediaUri: 'content://photo/1',
      );

      expect(duplicate.succeeded, isTrue);
      expect(duplicate.isDuplicate, isTrue);
      expect(
        container.read(filmRollControllerProvider).activeRoll!.exposuresTaken,
        1,
      );
    },
  );

  test(
    'persistence failure retains capacity, blocks shooting, and retries',
    () async {
      final repository = _MemoryFilmRollRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);

      repository.failSaveAttempts = 1;
      final reservation = controller.tryReserveExposure().reservation!;
      final failedSave = await controller.recordExposure(
        captureId: 'capture-1',
        reservation: reservation,
        mediaUri: 'content://photo/1',
      );
      final failedState = container.read(filmRollControllerProvider);
      expect(failedSave.succeeded, isFalse);
      expect(failedSave.failure, FilmRollActionFailure.persistenceFailed);
      expect(failedState.pendingExposureCount, 1);
      expect(
        failedState.pendingSaveState,
        FilmRollPendingSaveState.recoveryRequired,
      );
      expect(
        controller.tryReserveExposure().failure,
        FilmRollActionFailure.recoveryRequired,
      );

      final retried = await controller.retryPendingSave();
      expect(retried.succeeded, isTrue);
      final recovered = container.read(filmRollControllerProvider);
      expect(recovered.pendingExposureCount, 0);
      expect(recovered.activeRoll!.exposuresTaken, 1);
    },
  );

  test('end and abandon reject a queued or pending capture', () async {
    final container = containerFor(_MemoryFilmRollRepository());
    addTearDown(container.dispose);
    final controller = await readyController(container);
    await start(controller);
    final rollId = container.read(filmRollControllerProvider).activeRoll!.id;
    final reservation = controller.tryReserveExposure().reservation!;

    final end = await controller.endRoll(expectedRollId: rollId);
    final abandon = await controller.abandonRoll(expectedRollId: rollId);

    expect(end.failure, FilmRollActionFailure.lifecycleBusy);
    expect(abandon.failure, FilmRollActionFailure.lifecycleBusy);
    await controller.releaseExposure(reservation);
    expect(
      (await controller.endRoll(expectedRollId: rollId)).succeeded,
      isTrue,
    );
  });

  test('stale actions cannot affect the current roll', () async {
    final container = containerFor(_MemoryFilmRollRepository());
    addTearDown(container.dispose);
    final controller = await readyController(container);
    await start(controller);

    final result = await controller.abandonRoll(expectedRollId: 'old-roll');
    expect(result.succeeded, isFalse);
    expect(result.failure, FilmRollActionFailure.staleRoll);
    expect(container.read(filmRollControllerProvider).activeRoll, isNotNull);
  });

  test('final exposure creates an automatic typed completion event', () async {
    final repository = _MemoryFilmRollRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = await readyController(container);
    await start(controller);

    for (var index = 0; index < 12; index += 1) {
      final reservation = controller.tryReserveExposure().reservation!;
      await controller.recordExposure(
        captureId: 'capture-$index',
        reservation: reservation,
        mediaUri: 'content://photo/$index',
      );
    }

    final state = container.read(filmRollControllerProvider);
    expect(state.activeRoll, isNull);
    expect(
      state.completionEvent!.source,
      FilmRollCompletionSource.automaticCapture,
    );
    expect(state.completionEvent!.roll.exposuresTaken, 12);
    expect(repository.history, hasLength(1));
    final eventId = state.completionEvent!.id;
    expect(controller.acknowledgeCompletionEvent(eventId).succeeded, isTrue);
    expect(container.read(filmRollControllerProvider).completionEvent, isNull);
  });

  test(
    'restored metadata reconciles count and silently archives a full roll',
    () async {
      final restored = FilmRoll(
        id: 'restored-roll',
        presetId: 'portra',
        lockedStyle: const RanaStyle(),
        aspectRatioPlatformValue: 'portrait_3_4',
        size: FilmRollSize.twelve,
        exposuresTaken: 4,
        status: FilmRollStatus.active,
        startedAt: DateTime.utc(2026, 7, 16),
      );
      final repository = _MemoryFilmRollRepository()..active = restored;
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = await readyController(container);

      final state = container.read(filmRollControllerProvider);
      expect(state.recipeStatus, FilmRollRecipeStatus.applying);
      expect(state.reconciliationRequired, isTrue);
      expect(controller.tryReserveExposure().succeeded, isFalse);
      controller.setActiveRecipeStatus(
        FilmRollRecipeStatus.ready,
        expectedRollId: restored.id,
      );

      final result = await controller.reconcileCapturedMedia(
        rollId: restored.id,
        captures: List<RollCaptureEntry>.generate(
          12,
          (index) => RollCaptureEntry(
            filmRollId: restored.id,
            mediaUri: 'content://photo/$index',
            capturedAt: DateTime.utc(2026, 7, 16, 12, index),
            exposureIndex: index + 1,
          ),
        ),
      );

      expect(result.succeeded, isTrue);
      final reconciled = container.read(filmRollControllerProvider);
      expect(reconciled.activeRoll, isNull);
      expect(
        reconciled.completionEvent!.source,
        FilmRollCompletionSource.recovery,
      );
      expect(reconciled.completionEvent!.shouldPresentCompletionSheet, isFalse);
      expect(repository.history.single.coverUri, 'content://photo/0');
    },
  );

  test(
    'unavailable locked recipe is a safe capture hold, never Normal fallback',
    () async {
      final container = containerFor(_MemoryFilmRollRepository());
      addTearDown(container.dispose);
      final controller = await readyController(container);
      await start(controller);
      final roll = container.read(filmRollControllerProvider).activeRoll!;

      final unavailable = controller.setActiveRecipeStatus(
        FilmRollRecipeStatus.unavailable,
        expectedRollId: roll.id,
        message: 'The Portra recipe is no longer available.',
      );
      expect(unavailable.failure, FilmRollActionFailure.recipeUnavailable);
      expect(
        controller.tryReserveExposure().failure,
        FilmRollActionFailure.recipeUnavailable,
      );
      expect(
        (await controller.endRoll(expectedRollId: roll.id)).succeeded,
        isTrue,
      );
    },
  );
}
