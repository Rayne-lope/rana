import 'dart:async';
import 'dart:math';

import 'package:rana/core/services/camera_feedback_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
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
/// All durable lifecycle actions use one queue. A native capture reservation is
/// added synchronously to make capacity atomic on the Flutter isolate, then it
/// remains capacity-consuming until its saved exposure is durably persisted.
@Riverpod(keepAlive: true)
class FilmRollController extends _$FilmRollController {
  late final FilmRollRepository _repository;
  late final Future<void> _restoration;
  Future<void> _lifecycleQueue = Future<void>.value();

  /// Capture IDs accepted from native terminal events. They are transient but
  /// protect against duplicate events while this process is alive.
  final Set<String> _acceptedCaptureIds = <String>{};

  @override
  FilmRollState build() {
    _repository = ref.watch(filmRollRepositoryProvider);
    _restoration = Future<void>.microtask(
      () => _enqueueLifecycle<void>(_restoreActiveRoll),
    );
    return FilmRollState.initial();
  }

  // ── Public lifecycle API ─────────────────────────────────────────────────

  /// Starts a new roll locked to [presetId], [lockedStyle], and aspect ratio.
  ///
  /// Restoration is awaited before the operation joins the lifecycle queue, so
  /// concurrent calls can persist at most one active roll.
  Future<FilmRollActionResult> startRoll({
    required String presetId,
    required RanaStyle lockedStyle,
    required FilmRollSize size,
    required String aspectRatioPlatformValue,
  }) async {
    await _restoration;
    return _enqueueLifecycle(() async {
      if (state.restorationStatus == FilmRollRestorationStatus.restoring) {
        return _failure(
          FilmRollActionFailure.restorationInProgress,
          'Film Roll restoration is still in progress. Please wait.',
        );
      }
      if (state.restorationStatus == FilmRollRestorationStatus.failed) {
        return _failure(
          FilmRollActionFailure.restorationFailed,
          'Film Roll restoration failed. Restart the camera before '
          'starting a roll.',
        );
      }
      if (state.hasActiveRoll) {
        return _failure(
          FilmRollActionFailure.activeRollAlreadyExists,
          'Finish or abandon the active Film Roll before starting another.',
          roll: state.activeRoll,
        );
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

      try {
        await _repository.save(roll);
      } on Object catch (error, stackTrace) {
        _logError('Failed to persist a new Film Roll', error, stackTrace);
        return _failure(
          FilmRollActionFailure.persistenceFailed,
          'Could not save the Film Roll. Please try again.',
        );
      }

      _acceptedCaptureIds.clear();
      state = state.copyWith(
        activeRoll: roll,
        recipeStatus: FilmRollRecipeStatus.ready,
        pendingExposures: const <String, FilmRollPendingExposure>{},
        reconciliationRequired: false,
        completionEvent: null,
        lastActionError: null,
      );
      AppLogger.i(
        'FilmRollController',
        'Roll started: id=${roll.id} preset=$presetId '
            'size=${size.count} aspectRatio=$aspectRatioPlatformValue',
      );
      return FilmRollActionResult.success(roll: roll);
    });
  }

  /// Waits for persisted active-roll restoration after app startup.
  Future<void> waitUntilRestored() => _restoration;

  /// Atomically reserves capacity before a native capture starts.
  ///
  /// This is deliberately synchronous: Flutter event handling runs on one
  /// isolate, so inserting the reservation before returning means two close
  /// shutter presses cannot both observe the same remaining frame.
  FilmRollActionResult tryReserveExposure() {
    if (state.restorationStatus == FilmRollRestorationStatus.restoring) {
      return _failure(
        FilmRollActionFailure.restorationInProgress,
        'Film Roll restoration is still in progress.',
      );
    }
    if (state.restorationStatus == FilmRollRestorationStatus.failed) {
      return _failure(
        FilmRollActionFailure.restorationFailed,
        'Film Roll restoration failed. Reload the camera before shooting.',
      );
    }

    final current = state.activeRoll;
    if (current == null || !current.isActive) {
      return _failure(
        FilmRollActionFailure.noActiveRoll,
        'There is no active Film Roll to reserve an exposure for.',
      );
    }
    if (state.recipeStatus == FilmRollRecipeStatus.unavailable) {
      return _failure(
        FilmRollActionFailure.recipeUnavailable,
        state.lastActionError ??
            'The locked Film Roll recipe is unavailable. Recover it '
                'before shooting.',
        roll: current,
      );
    }
    if (state.recipeStatus == FilmRollRecipeStatus.applying ||
        state.reconciliationRequired) {
      return _failure(
        FilmRollActionFailure.lifecycleBusy,
        'The active Film Roll is still being restored. Please wait.',
        roll: current,
      );
    }
    if (state.hasPendingSaveRecovery) {
      return _failure(
        FilmRollActionFailure.recoveryRequired,
        state.lastActionError ??
            'A saved exposure needs recovery before another frame can '
                'be taken.',
        roll: current,
      );
    }
    if (state.cannotReserveExposure) {
      return _failure(
        FilmRollActionFailure.reservationUnavailable,
        'No Film Roll frames are available.',
        roll: current,
      );
    }

    final reservation = FilmRollExposureReservation(
      id: _generateUuid(),
      filmRollId: current.id,
    );
    state = state.copyWith(
      pendingExposures: <String, FilmRollPendingExposure>{
        ...state.pendingExposures,
        reservation.id: FilmRollPendingExposure(
          reservation: reservation,
          status: FilmRollPendingExposureStatus.reserved,
        ),
      },
      lastActionError: null,
    );
    return FilmRollActionResult.success(
      roll: current,
      reservation: reservation,
    );
  }

  /// Legacy nullable reservation API while older camera callers migrate.
  @Deprecated('Use tryReserveExposure() and handle FilmRollActionResult.')
  FilmRollExposureReservation? reserveExposure() =>
      tryReserveExposure().reservation;

  /// Releases a reservation after the matching native capture fails.
  Future<FilmRollActionResult> releaseExposure(
    FilmRollExposureReservation reservation,
  ) => _enqueueLifecycle(() async {
    final pending = state.pendingExposures[reservation.id];
    if (pending == null) {
      if (_acceptedCaptureIds.isNotEmpty) {
        return const FilmRollActionResult.success(
          isDuplicate: true,
          message: 'The capture terminal event was already handled.',
        );
      }
      return _failure(
        FilmRollActionFailure.invalidReservation,
        'This Film Roll capture is no longer active.',
      );
    }
    if (pending.reservation != reservation) {
      return _failure(
        FilmRollActionFailure.invalidReservation,
        'This capture does not belong to the active Film Roll.',
      );
    }
    if (pending.status != FilmRollPendingExposureStatus.reserved) {
      if (pending.captureId != null) {
        return const FilmRollActionResult.success(
          isDuplicate: true,
          message: 'The saved capture is already being processed.',
        );
      }
      return _failure(
        FilmRollActionFailure.recoveryRequired,
        'This exposure needs recovery before it can be released.',
        roll: state.activeRoll,
      );
    }

    _removePending(reservation.id);
    return FilmRollActionResult.success(roll: state.activeRoll);
  });

  /// Commits a successfully saved exposure for [reservation].
  ///
  /// A reservation is retained as [FilmRollPendingExposureStatus.saving] until
  /// repository persistence succeeds. On failure it becomes retryable recovery
  /// state and blocks all new Film Roll captures.
  Future<FilmRollActionResult> recordExposure({
    required String captureId,
    required FilmRollExposureReservation reservation,
    required String mediaUri,
  }) => _enqueueLifecycle(() async {
    final pending = state.pendingExposures[reservation.id];
    if (pending == null) {
      if (_acceptedCaptureIds.contains(captureId)) {
        return const FilmRollActionResult.success(
          isDuplicate: true,
          message: 'The capture completion was already recorded.',
        );
      }
      return _failure(
        FilmRollActionFailure.invalidReservation,
        'This saved capture no longer belongs to an active Film Roll.',
      );
    }
    if (pending.reservation != reservation ||
        pending.reservation.filmRollId != state.activeRoll?.id) {
      return _failure(
        FilmRollActionFailure.staleRoll,
        'The Film Roll changed before this capture was saved.',
      );
    }
    if (pending.captureId != null) {
      if (pending.captureId == captureId) {
        return const FilmRollActionResult.success(
          isDuplicate: true,
          message: 'The capture completion was already recorded.',
        );
      }
      return _failure(
        FilmRollActionFailure.invalidCapture,
        'A different capture attempted to use this Film Roll frame.',
      );
    }
    if (mediaUri.isEmpty) {
      return _markPendingRecovery(
        reservation.id,
        pending,
        'The camera did not return a saved photo URI. Retry recovery '
        'before shooting.',
      );
    }

    _acceptedCaptureIds.add(captureId);
    _replacePending(
      pending.copyWith(
        status: FilmRollPendingExposureStatus.saving,
        captureId: captureId,
        mediaUri: mediaUri,
        errorMessage: null,
      ),
    );
    return _persistPendingExposure(reservation.id);
  });

  /// Retries the durable save for an exposure in [recoveryRequired] state.
  ///
  /// If [reservationId] is omitted there must be exactly one failed exposure.
  Future<FilmRollActionResult> retryPendingSave({String? reservationId}) =>
      _enqueueLifecycle(() async {
        final failed = state.pendingExposures.values
            .where((pending) => pending.needsRecovery)
            .toList(growable: false);
        if (failed.isEmpty) {
          return _failure(
            FilmRollActionFailure.recoveryRequired,
            'There is no Film Roll exposure waiting to be retried.',
            roll: state.activeRoll,
          );
        }

        final pending = reservationId == null
            ? (failed.length == 1 ? failed.single : null)
            : state.pendingExposures[reservationId];
        if (pending == null || !pending.needsRecovery) {
          return _failure(
            FilmRollActionFailure.invalidReservation,
            'That Film Roll exposure is not available for retry.',
            roll: state.activeRoll,
          );
        }
        if (pending.captureId == null || pending.mediaUri == null) {
          return _failure(
            FilmRollActionFailure.invalidCapture,
            'The saved capture details are missing. Reopen the camera to '
            'reconcile the roll.',
            roll: state.activeRoll,
          );
        }

        _replacePending(
          pending.copyWith(
            status: FilmRollPendingExposureStatus.saving,
            errorMessage: null,
          ),
        );
        return _persistPendingExposure(pending.reservation.id);
      });

  /// Ends the active roll and archives it, even if it is incomplete.
  Future<FilmRollActionResult> endRoll({String? expectedRollId}) async {
    await _restoration;
    final current = state.activeRoll;
    if (current != null &&
        (expectedRollId == null || current.id == expectedRollId) &&
        _hasPendingFor(current.id)) {
      return _failure(
        FilmRollActionFailure.lifecycleBusy,
        'Wait for pending Film Roll captures to finish before ending '
        'the roll.',
        roll: current,
      );
    }
    return _enqueueLifecycle(
      () => _finaliseActiveRoll(
        expectedRollId: expectedRollId,
        source: FilmRollCompletionSource.manualEnd,
      ),
    );
  }

  /// Removes the active roll grouping without affecting saved photos.
  Future<FilmRollActionResult> abandonRoll({String? expectedRollId}) async {
    await _restoration;
    final current = state.activeRoll;
    if (current != null &&
        (expectedRollId == null || current.id == expectedRollId) &&
        _hasPendingFor(current.id)) {
      return _failure(
        FilmRollActionFailure.lifecycleBusy,
        'Wait for the pending Film Roll frame to finish before '
        'abandoning the roll.',
        roll: current,
      );
    }
    return _enqueueLifecycle(() async {
      final current = _activeRollForAction(expectedRollId);
      if (current is FilmRollActionResult) return current;
      final roll = current as FilmRoll;
      if (_hasPendingFor(roll.id)) {
        return _failure(
          FilmRollActionFailure.lifecycleBusy,
          'Wait for the pending Film Roll frame to finish before '
          'abandoning the roll.',
          roll: roll,
        );
      }

      try {
        await _repository.delete(roll.id);
      } on Object catch (error, stackTrace) {
        _logError('Failed to abandon Film Roll', error, stackTrace);
        return _failure(
          FilmRollActionFailure.persistenceFailed,
          'Could not remove the Film Roll grouping. Please try again.',
          roll: roll,
        );
      }

      _acceptedCaptureIds.clear();
      state = state.copyWith(
        activeRoll: null,
        pendingExposures: const <String, FilmRollPendingExposure>{},
        recipeStatus: FilmRollRecipeStatus.notRequired,
        reconciliationRequired: false,
        lastActionError: null,
      );
      AppLogger.i('FilmRollController', 'Roll abandoned: id=${roll.id}');
      return FilmRollActionResult.success(roll: roll);
    });
  }

  /// Reconciles an active roll against authoritative native capture metadata.
  ///
  /// The metadata query is intentionally read-only. It recovers count and cover
  /// URI after a pause/relaunch, clears transient failed attempts, and silently
  /// archives a recovered full roll. The resulting [FilmRollCompletionEvent]
  /// has [FilmRollCompletionSource.recovery], so Camera UX must not show the
  /// live-capture completion sheet for it.
  Future<FilmRollActionResult> reconcileCapturedMedia({
    required String rollId,
    required Iterable<RollCaptureEntry> captures,
  }) async {
    await _restoration;
    return _enqueueLifecycle(() async {
      final current = _activeRollForAction(rollId);
      if (current is FilmRollActionResult) return current;
      final roll = current as FilmRoll;

      final uniqueByUri = <String, RollCaptureEntry>{};
      for (final capture in captures) {
        if (capture.filmRollId != roll.id || capture.mediaUri.isEmpty) {
          continue;
        }
        final existing = uniqueByUri[capture.mediaUri];
        if (existing == null ||
            capture.capturedAt.isBefore(existing.capturedAt)) {
          uniqueByUri[capture.mediaUri] = capture;
        }
      }
      final recovered = uniqueByUri.values.toList()
        ..sort((a, b) {
          final byDate = a.capturedAt.compareTo(b.capturedAt);
          return byDate != 0 ? byDate : a.mediaUri.compareTo(b.mediaUri);
        });

      if (recovered.length > roll.size.count) {
        return _requireReconciliation(
          'Film Roll metadata has more saved photos than this roll allows. '
          'Do not shoot until the roll is recovered.',
          roll: roll,
        );
      }

      final next = roll.copyWith(
        exposuresTaken: recovered.length,
        coverUri: recovered.isEmpty ? null : recovered.first.mediaUri,
      );
      try {
        if (next.isFull) {
          final completed = next.copyWith(
            status: FilmRollStatus.completed,
            completedAt: DateTime.now(),
          );
          await _repository.save(completed);
          final history = await _historyAfterSave(completed);
          final event = FilmRollCompletionEvent(
            id: _generateUuid(),
            roll: completed,
            source: FilmRollCompletionSource.recovery,
            createdAt: DateTime.now(),
          );
          state = state.copyWith(
            activeRoll: null,
            history: history,
            pendingExposures: const <String, FilmRollPendingExposure>{},
            recipeStatus: FilmRollRecipeStatus.notRequired,
            reconciliationRequired: false,
            completionEvent: event,
            loadStatus: FilmRollLoadStatus.loaded,
            lastActionError: null,
          );
          return FilmRollActionResult.success(
            roll: completed,
            completionEvent: event,
          );
        }

        await _repository.save(next);
        state = state.copyWith(
          activeRoll: next,
          pendingExposures: const <String, FilmRollPendingExposure>{},
          reconciliationRequired: false,
          lastActionError: null,
        );
        return FilmRollActionResult.success(roll: next);
      } on Object catch (error, stackTrace) {
        _logError('Failed to reconcile Film Roll metadata', error, stackTrace);
        return _requireReconciliation(
          'Could not save recovered Film Roll frames. Retry recovery '
          'before shooting.',
          roll: roll,
        );
      }
    });
  }

  /// Marks an active roll as needing a native metadata reconciliation.
  FilmRollActionResult requireReconciliation({
    String? expectedRollId,
    String? message,
  }) {
    final current = _activeRollForAction(expectedRollId);
    if (current is FilmRollActionResult) return current;
    final roll = current as FilmRoll;
    state = state.copyWith(
      reconciliationRequired: true,
      lastActionError: message ?? state.lastActionError,
    );
    return FilmRollActionResult.success(roll: roll);
  }

  /// Updates the camera-facing locked-recipe readiness for the active roll.
  FilmRollActionResult setActiveRecipeStatus(
    FilmRollRecipeStatus status, {
    String? expectedRollId,
    String? message,
  }) {
    final current = _activeRollForAction(expectedRollId);
    if (current is FilmRollActionResult) return current;
    final roll = current as FilmRoll;
    state = state.copyWith(
      recipeStatus: status,
      lastActionError: status == FilmRollRecipeStatus.unavailable
          ? (message ??
                'The locked Film Roll recipe is unavailable. Recover it '
                    'before shooting.')
          : null,
    );
    if (status == FilmRollRecipeStatus.unavailable) {
      return FilmRollActionResult.failure(
        FilmRollActionFailure.recipeUnavailable,
        message: state.lastActionError!,
        roll: roll,
      );
    }
    return FilmRollActionResult.success(roll: roll);
  }

  /// Loads archived roll history into [FilmRollState.history].
  Future<void> loadHistory() => _enqueueLifecycle(() async {
    state = state.copyWith(loadStatus: FilmRollLoadStatus.loading);
    try {
      final rolls = await _repository.loadAll();
      state = state.copyWith(
        history: rolls,
        loadStatus: FilmRollLoadStatus.loaded,
        errorMessage: null,
      );
    } on Object catch (error, stackTrace) {
      _logError('Failed to load roll history', error, stackTrace);
      state = state.copyWith(
        loadStatus: FilmRollLoadStatus.error,
        errorMessage: 'Could not load Film Roll history.',
      );
    }
  });

  /// Acknowledges exactly one route-coordinator completion event.
  FilmRollActionResult acknowledgeCompletionEvent(String eventId) {
    final event = state.completionEvent;
    if (event == null || event.id != eventId) {
      return const FilmRollActionResult.success(
        isDuplicate: true,
        message: 'The Film Roll completion was already acknowledged.',
      );
    }
    state = state.copyWith(completionEvent: null);
    return FilmRollActionResult.success(roll: event.roll);
  }

  /// Legacy acknowledgement while camera callers migrate to typed events.
  @Deprecated('Use acknowledgeCompletionEvent(eventId).')
  void acknowledgeLatestCompletion() {
    final event = state.completionEvent;
    if (event != null) acknowledgeCompletionEvent(event.id);
  }

  // ── Private lifecycle helpers ────────────────────────────────────────────

  Future<void> _restoreActiveRoll() async {
    try {
      final roll = await _repository.loadActive();
      if (roll != null && roll.isActive) {
        state = state.copyWith(
          activeRoll: roll,
          restorationStatus: FilmRollRestorationStatus.ready,
          recipeStatus: FilmRollRecipeStatus.applying,
          reconciliationRequired: true,
          lastActionError: null,
        );
        AppLogger.i(
          'FilmRollController',
          'Restored active roll: id=${roll.id} '
              'shots=${roll.exposuresTaken}/${roll.size.count}',
        );
        return;
      }
      state = state.copyWith(
        restorationStatus: FilmRollRestorationStatus.ready,
        recipeStatus: FilmRollRecipeStatus.notRequired,
        reconciliationRequired: false,
        lastActionError: null,
      );
    } on Object catch (error, stackTrace) {
      _logError('Failed to restore active Film Roll', error, stackTrace);
      state = state.copyWith(
        restorationStatus: FilmRollRestorationStatus.failed,
        recipeStatus: FilmRollRecipeStatus.unavailable,
        reconciliationRequired: true,
        lastActionError: 'Could not restore the active Film Roll.',
      );
    }
  }

  Future<FilmRollActionResult> _persistPendingExposure(
    String reservationId,
  ) async {
    final pending = state.pendingExposures[reservationId];
    final current = state.activeRoll;
    if (pending == null || current == null || !current.isActive) {
      return _failure(
        FilmRollActionFailure.staleRoll,
        'The Film Roll changed before this saved capture could be recorded.',
      );
    }
    if (pending.status != FilmRollPendingExposureStatus.saving ||
        pending.mediaUri == null ||
        pending.captureId == null ||
        pending.reservation.filmRollId != current.id) {
      return _failure(
        FilmRollActionFailure.invalidCapture,
        'The saved Film Roll capture is incomplete and needs recovery.',
        roll: current,
      );
    }

    final next = current.copyWith(
      exposuresTaken: current.exposuresTaken + 1,
      coverUri: current.coverUri ?? pending.mediaUri,
    );
    if (next.exposuresTaken > next.size.count) {
      return _markPendingRecovery(
        reservationId,
        pending,
        'This capture would exceed the Film Roll capacity. Recover the '
        'roll before shooting.',
      );
    }

    try {
      if (!next.isFull) {
        await _repository.save(next);
        _removePending(reservationId);
        state = state.copyWith(activeRoll: next, lastActionError: null);
        unawaited(CameraFeedbackService.instance.playFilmWind());
        AppLogger.i(
          'FilmRollController',
          'Exposure recorded: id=${next.id} '
              'shot=${next.exposuresTaken}/${next.size.count} '
              'uri=${pending.mediaUri}',
        );
        return FilmRollActionResult.success(roll: next);
      }

      final completed = next.copyWith(
        status: FilmRollStatus.completed,
        completedAt: DateTime.now(),
      );
      await _repository.save(completed);
      final history = await _historyAfterSave(completed);
      final event = FilmRollCompletionEvent(
        id: _generateUuid(),
        roll: completed,
        source: FilmRollCompletionSource.automaticCapture,
        createdAt: DateTime.now(),
      );
      _removePending(reservationId);
      state = state.copyWith(
        activeRoll: null,
        history: history,
        recipeStatus: FilmRollRecipeStatus.notRequired,
        reconciliationRequired: false,
        completionEvent: event,
        loadStatus: FilmRollLoadStatus.loaded,
        lastActionError: null,
      );
      unawaited(CameraFeedbackService.instance.playRollComplete());
      AppLogger.i(
        'FilmRollController',
        'Film Roll automatically completed: id=${completed.id}',
      );
      return FilmRollActionResult.success(
        roll: completed,
        completionEvent: event,
      );
    } on Object catch (error, stackTrace) {
      _logError('Failed to persist Film Roll exposure', error, stackTrace);
      return _markPendingRecovery(
        reservationId,
        pending,
        'The photo was saved but its Film Roll frame could not be '
        'recorded. Retry before shooting again.',
      );
    }
  }

  Future<FilmRollActionResult> _finaliseActiveRoll({
    required String? expectedRollId,
    required FilmRollCompletionSource source,
  }) async {
    final current = _activeRollForAction(expectedRollId);
    if (current is FilmRollActionResult) return current;
    final roll = current as FilmRoll;
    if (_hasPendingFor(roll.id)) {
      return _failure(
        FilmRollActionFailure.lifecycleBusy,
        'Wait for pending Film Roll captures to finish before ending the roll.',
        roll: roll,
      );
    }

    final completed = roll.copyWith(
      status: FilmRollStatus.completed,
      completedAt: DateTime.now(),
    );
    try {
      await _repository.save(completed);
      final history = await _historyAfterSave(completed);
      final event = FilmRollCompletionEvent(
        id: _generateUuid(),
        roll: completed,
        source: source,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        activeRoll: null,
        history: history,
        pendingExposures: const <String, FilmRollPendingExposure>{},
        recipeStatus: FilmRollRecipeStatus.notRequired,
        reconciliationRequired: false,
        completionEvent: event,
        loadStatus: FilmRollLoadStatus.loaded,
        lastActionError: null,
      );
      return FilmRollActionResult.success(
        roll: completed,
        completionEvent: event,
      );
    } on Object catch (error, stackTrace) {
      _logError('Failed to finish Film Roll', error, stackTrace);
      return _failure(
        FilmRollActionFailure.persistenceFailed,
        'Could not archive the Film Roll. Please try again.',
        roll: roll,
      );
    }
  }

  FilmRollActionResult _markPendingRecovery(
    String reservationId,
    FilmRollPendingExposure pending,
    String message,
  ) {
    _replacePending(
      pending.copyWith(
        status: FilmRollPendingExposureStatus.recoveryRequired,
        errorMessage: message,
      ),
    );
    return _failure(
      FilmRollActionFailure.persistenceFailed,
      message,
      roll: state.activeRoll,
    );
  }

  FilmRollActionResult _requireReconciliation(
    String message, {
    FilmRoll? roll,
  }) {
    state = state.copyWith(
      reconciliationRequired: true,
      lastActionError: message,
    );
    return FilmRollActionResult.failure(
      FilmRollActionFailure.recoveryRequired,
      message: message,
      roll: roll ?? state.activeRoll,
    );
  }

  Object _activeRollForAction(String? expectedRollId) {
    final current = state.activeRoll;
    if (current == null || !current.isActive) {
      return _failure(
        expectedRollId == null
            ? FilmRollActionFailure.noActiveRoll
            : FilmRollActionFailure.staleRoll,
        expectedRollId == null
            ? 'There is no active Film Roll.'
            : 'That Film Roll is no longer active.',
      );
    }
    if (expectedRollId != null && current.id != expectedRollId) {
      return _failure(
        FilmRollActionFailure.staleRoll,
        'That Film Roll is no longer active.',
        roll: current,
      );
    }
    return current;
  }

  bool _hasPendingFor(String rollId) => state.pendingExposures.values.any(
    (pending) => pending.reservation.filmRollId == rollId,
  );

  void _replacePending(FilmRollPendingExposure pending) {
    state = state.copyWith(
      pendingExposures: <String, FilmRollPendingExposure>{
        ...state.pendingExposures,
        pending.reservation.id: pending,
      },
    );
  }

  void _removePending(String reservationId) {
    if (!state.pendingExposures.containsKey(reservationId)) return;
    final next = Map<String, FilmRollPendingExposure>.from(
      state.pendingExposures,
    )..remove(reservationId);
    state = state.copyWith(pendingExposures: next);
  }

  Future<List<FilmRoll>> _historyAfterSave(FilmRoll savedRoll) async {
    try {
      final loaded = await _repository.loadAll();
      if (loaded.any((roll) => roll.id == savedRoll.id)) return loaded;
      return _sortedHistory(<FilmRoll>[...loaded, savedRoll]);
    } on Object catch (error, stackTrace) {
      _logError('Failed to refresh Film Roll history', error, stackTrace);
      return _sortedHistory(<FilmRoll>[...state.history, savedRoll]);
    }
  }

  List<FilmRoll> _sortedHistory(Iterable<FilmRoll> rolls) {
    final byId = <String, FilmRoll>{for (final roll in rolls) roll.id: roll};
    final sorted = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List<FilmRoll>.unmodifiable(sorted);
  }

  FilmRollActionResult _failure(
    FilmRollActionFailure failure,
    String message, {
    FilmRoll? roll,
  }) {
    state = state.copyWith(lastActionError: message);
    return FilmRollActionResult.failure(failure, message: message, roll: roll);
  }

  Future<T> _enqueueLifecycle<T>(Future<T> Function() operation) {
    final next = _lifecycleQueue.then<T>((_) => operation());
    _lifecycleQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _logError('Film Roll lifecycle operation failed', error, stackTrace);
      },
    );
    return next;
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    AppLogger.e('FilmRollController', message, error, stackTrace);
  }
}
