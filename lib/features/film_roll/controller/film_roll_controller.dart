import 'dart:math';

import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/film_roll/state/film_roll_state.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'film_roll_controller.g.dart';

/// UUID v4 generator (no external dependency).
String _generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
      '-${hex(bytes[4])}${hex(bytes[5])}'
      '-${hex(bytes[6])}${hex(bytes[7])}'
      '-${hex(bytes[8])}${hex(bytes[9])}'
      '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
      '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

/// Controller for the Film Roll feature.
///
/// Key rules enforced here:
///  - Only one active roll at a time ([startRoll] is a no-op if one exists).
///  - [recordExposure] must only be called from the camera controller's
///    `_handleCaptureCompleted` — never on shutter press.
///  - [abandonRoll] removes the roll record; already-saved photos stay in
///    Gallery.
@Riverpod(keepAlive: true)
class FilmRollController extends _$FilmRollController {
  late final FilmRollRepository _repository;
  late final Future<void> _restoration;
  Future<void> _exposureQueue = Future<void>.value();
  final Set<String> _processedCaptureIds = <String>{};

  @override
  FilmRollState build() {
    _repository = ref.watch(filmRollRepositoryProvider);
    _restoration = Future<void>.microtask(_restoreActiveRoll);
    return FilmRollState.initial();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts a new roll locked to [presetId] and [aspectRatioPlatformValue].
  ///
  /// No-op (returns false) if a roll is already active.
  Future<bool> startRoll({
    required String presetId,
    required RanaStyle lockedStyle,
    required FilmRollSize size,
    required String aspectRatioPlatformValue,
  }) async {
    if (state.hasActiveRoll) {
      AppLogger.w(
        'FilmRollController',
        'startRoll ignored — roll ${state.activeRoll!.id} already active',
      );
      return false;
    }

    final roll = FilmRoll(
      id: _generateUuid(),
      presetId: presetId,
      lockedStyle: lockedStyle,
      aspectRatioPlatformValue: aspectRatioPlatformValue,
      size: size,
      exposuresTaken: 0,
      status: FilmRollStatus.active,
      startedAt: DateTime.now(),
    );

    await _repository.save(roll);
    state = state.copyWith(activeRoll: roll, latestCompletedRoll: null);
    AppLogger.i(
      'FilmRollController',
      'Roll started: id=${roll.id} preset=$presetId '
          'size=${size.count} aspectRatio=$aspectRatioPlatformValue',
    );
    return true;
  }

  /// Waits for persisted active-roll restoration after app startup.
  Future<void> waitUntilRestored() => _restoration;

  /// Reserves capacity before a native capture begins.
  ///
  /// The reservation is released if native capture fails and committed only
  /// when its matching completion event includes a MediaStore URI.
  FilmRollExposureReservation? reserveExposure() {
    final current = state.activeRoll;
    if (current == null || !current.isActive || state.cannotReserveExposure) {
      return null;
    }

    final reservation = FilmRollExposureReservation(
      id: _generateUuid(),
      filmRollId: current.id,
    );
    state = state.copyWith(
      pendingExposureReservations: <String, String>{
        ...state.pendingExposureReservations,
        reservation.id: reservation.filmRollId,
      },
    );
    return reservation;
  }

  /// Releases a reservation after the matching native capture fails.
  Future<void> releaseExposure(FilmRollExposureReservation reservation) =>
      _enqueueExposure(() async {
        _removeReservation(reservation);
      });

  /// Records a successfully saved exposure for [reservation].
  ///
  /// **MUST be called only after native `capture_completed` confirms the image
  /// URI.** A failed capture must never reach this method. [captureId] makes
  /// duplicate native completion events idempotent.
  ///
  /// Returns the updated [FilmRoll], or null if no roll is active.
  Future<FilmRoll?> recordExposure({
    required String captureId,
    required FilmRollExposureReservation reservation,
    required String mediaUri,
  }) => _enqueueExposure(() async {
    if (!_processedCaptureIds.add(captureId)) return null;

    final reservedRollId = state.pendingExposureReservations[reservation.id];
    _removeReservation(reservation);
    final current = state.activeRoll;
    if (reservedRollId == null ||
        current == null ||
        !current.isActive ||
        current.id != reservation.filmRollId ||
        reservedRollId != current.id) {
      return null;
    }

    final next = current.copyWith(
      exposuresTaken: current.exposuresTaken + 1,
      coverUri: current.coverUri ?? mediaUri,
    );

    AppLogger.i(
      'FilmRollController',
      'Exposure recorded: id=${next.id} '
          'shot=${next.exposuresTaken}/${next.size.count} uri=$mediaUri',
    );

    if (!next.isFull) {
      await _repository.save(next);
      state = state.copyWith(activeRoll: next);
      return next;
    }

    final completed = next.copyWith(
      status: FilmRollStatus.completed,
      completedAt: DateTime.now(),
    );
    await _repository.save(completed);
    final history = await _repository.loadAll();
    state = state.copyWith(
      activeRoll: null,
      history: history,
      latestCompletedRoll: completed,
      loadStatus: FilmRollLoadStatus.loaded,
    );
    return completed;
  });

  /// Marks the active roll as [FilmRollStatus.completed] and moves it to
  /// history.
  Future<bool> endRoll() async {
    if (state.pendingExposureCount > 0) return false;
    await _finaliseRoll(FilmRollStatus.completed);
    return true;
  }

  /// Removes the active roll grouping without affecting saved photos.
  ///
  /// All already-saved photos remain individually accessible in the Gallery.
  Future<bool> abandonRoll() async {
    if (state.pendingExposureCount > 0) return false;
    final current = state.activeRoll;
    if (current == null) return false;
    await _repository.delete(current.id);
    state = state.copyWith(
      activeRoll: null,
      pendingExposureReservations: const <String, String>{},
    );
    AppLogger.i('FilmRollController', 'Roll abandoned: id=${current.id}');
    return true;
  }

  /// Loads the roll history from the repository into [FilmRollState.history].
  Future<void> loadHistory() async {
    state = state.copyWith(loadStatus: FilmRollLoadStatus.loading);
    try {
      final rolls = await _repository.loadAll();
      state = state.copyWith(
        history: rolls,
        loadStatus: FilmRollLoadStatus.loaded,
        errorMessage: null,
      );
    } on Object catch (e, stack) {
      AppLogger.e(
        'FilmRollController',
        'Failed to load roll history',
        e,
        stack,
      );
      state = state.copyWith(
        loadStatus: FilmRollLoadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _restoreActiveRoll() async {
    try {
      final roll = await _repository.loadActive();
      if (roll != null && roll.isActive) {
        state = state.copyWith(activeRoll: roll);
        AppLogger.i(
          'FilmRollController',
          'Restored active roll: id=${roll.id} '
              'shots=${roll.exposuresTaken}/${roll.size.count}',
        );
      }
    } on Object catch (e, stack) {
      AppLogger.e(
        'FilmRollController',
        'Failed to restore active roll',
        e,
        stack,
      );
    }
  }

  Future<void> _finaliseRoll(FilmRollStatus finalStatus) async {
    final current = state.activeRoll;
    if (current == null) return;

    final finalRoll = current.copyWith(
      status: finalStatus,
      completedAt: DateTime.now(),
    );

    await _repository.save(finalRoll);

    // Refresh history to include the just-finished roll.
    final updatedHistory = await _repository.loadAll();

    state = state.copyWith(
      activeRoll: null,
      history: updatedHistory,
      latestCompletedRoll: finalStatus == FilmRollStatus.completed
          ? finalRoll
          : state.latestCompletedRoll,
      pendingExposureReservations: const <String, String>{},
      loadStatus: FilmRollLoadStatus.loaded,
    );

    AppLogger.i(
      'FilmRollController',
      'Roll finalised: id=${finalRoll.id} '
          'status=${finalStatus.name} '
          'shots=${finalRoll.exposuresTaken}/${finalRoll.size.count}',
    );
  }

  void acknowledgeLatestCompletion() {
    state = state.copyWith(latestCompletedRoll: null);
  }

  Future<T> _enqueueExposure<T>(Future<T> Function() operation) {
    final next = _exposureQueue.then((_) => operation());
    _exposureQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e(
          'FilmRollController',
          'Exposure update failed',
          error,
          stackTrace,
        );
      },
    );
    return next;
  }

  void _removeReservation(FilmRollExposureReservation reservation) {
    if (!state.pendingExposureReservations.containsKey(reservation.id)) {
      return;
    }
    final reservations = Map<String, String>.from(
      state.pendingExposureReservations,
    )..remove(reservation.id);
    state = state.copyWith(pendingExposureReservations: reservations);
  }
}
