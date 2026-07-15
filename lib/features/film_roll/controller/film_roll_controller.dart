import 'dart:math';

import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/repository/film_roll_repository.dart';
import 'package:rana/features/film_roll/state/film_roll_state.dart';
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
///  - [abandonRoll] removes the roll record; already-saved photos stay in Gallery.
@Riverpod(keepAlive: true)
class FilmRollController extends _$FilmRollController {
  late final FilmRollRepository _repository;

  @override
  FilmRollState build() {
    _repository = ref.watch(filmRollRepositoryProvider);
    // Restore active roll on startup.
    Future.microtask(_restoreActiveRoll);
    return FilmRollState.initial();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts a new roll locked to [presetId] and [aspectRatioPlatformValue].
  ///
  /// No-op (returns false) if a roll is already active.
  Future<bool> startRoll({
    required String presetId,
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
      aspectRatioPlatformValue: aspectRatioPlatformValue,
      size: size,
      exposuresTaken: 0,
      status: FilmRollStatus.active,
      startedAt: DateTime.now(),
    );

    await _repository.save(roll);
    state = state.copyWith(activeRoll: roll);
    AppLogger.i(
      'FilmRollController',
      'Roll started: id=${roll.id} preset=$presetId '
          'size=${size.count} aspectRatio=$aspectRatioPlatformValue',
    );
    return true;
  }

  /// Records a successfully saved exposure.
  ///
  /// **MUST be called only after native `capture_completed` confirms the image
  /// URI.** A failed capture must never reach this method.
  ///
  /// Returns the updated [FilmRoll], or null if no roll is active.
  Future<FilmRoll?> recordExposure(String mediaUri) async {
    final current = state.activeRoll;
    if (current == null || !current.isActive) return null;

    final next = current.copyWith(
      exposuresTaken: current.exposuresTaken + 1,
      coverUri: current.coverUri ?? mediaUri,
    );

    AppLogger.i(
      'FilmRollController',
      'Exposure recorded: id=${next.id} '
          'shot=${next.exposuresTaken}/${next.size.count} uri=$mediaUri',
    );

    await _repository.save(next);
    state = state.copyWith(activeRoll: next);
    return next;
  }

  /// Marks the active roll as [FilmRollStatus.completed] and moves it to history.
  Future<void> endRoll() async {
    await _finaliseRoll(FilmRollStatus.completed);
  }

  /// Marks the active roll as [FilmRollStatus.abandoned] and moves it to history.
  ///
  /// All already-saved photos remain individually accessible in the Gallery.
  Future<void> abandonRoll() async {
    await _finaliseRoll(FilmRollStatus.abandoned);
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
      AppLogger.e('FilmRollController', 'Failed to load roll history', e, stack);
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
      loadStatus: FilmRollLoadStatus.loaded,
    );

    AppLogger.i(
      'FilmRollController',
      'Roll finalised: id=${finalRoll.id} '
          'status=${finalStatus.name} '
          'shots=${finalRoll.exposuresTaken}/${finalRoll.size.count}',
    );
  }
}
