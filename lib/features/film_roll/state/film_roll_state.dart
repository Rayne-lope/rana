import 'package:flutter/foundation.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';

/// Load status for the roll history list.
enum FilmRollLoadStatus { initial, loading, loaded, error }

/// Immutable state for [FilmRollController].
@immutable
class FilmRollState {
  /// Main constructor.
  const FilmRollState({
    required this.activeRoll,
    required this.history,
    required this.loadStatus,
    required this.restorationStatus,
    required this.recipeStatus,
    required this.pendingExposures,
    required this.reconciliationRequired,
    this.completionEvent,
    this.errorMessage,
    this.lastActionError,
  });

  /// Initial state while persisted active-roll restoration is pending.
  factory FilmRollState.initial() => const FilmRollState(
    activeRoll: null,
    history: [],
    loadStatus: FilmRollLoadStatus.initial,
    restorationStatus: FilmRollRestorationStatus.restoring,
    recipeStatus: FilmRollRecipeStatus.notRequired,
    pendingExposures: {},
    reconciliationRequired: false,
  );

  /// The currently active roll, or null if no roll is loaded.
  final FilmRoll? activeRoll;

  /// Completed rolls retained for the Rolls archive, newest first.
  final List<FilmRoll> history;

  /// Current load status for the history list.
  final FilmRollLoadStatus loadStatus;

  /// Whether the persisted active roll has been restored.
  final FilmRollRestorationStatus restorationStatus;

  /// Whether the active roll's locked recipe can safely be used to capture.
  final FilmRollRecipeStatus recipeStatus;

  /// All native captures that still consume Film Roll capacity.
  ///
  /// A record remains here until its exposure has been durably persisted. A
  /// persistence failure deliberately remains as [recoveryRequired], keeping
  /// the capacity reserved and blocking further shooting until retry.
  final Map<String, FilmRollPendingExposure> pendingExposures;

  /// Whether native Film Roll metadata must be reconciled before capture.
  ///
  /// This starts true for a restored roll because native capture processing can
  /// outlive the previous Flutter process. It is cleared only after an
  /// authoritative metadata reconciliation succeeds.
  final bool reconciliationRequired;

  /// One-time typed completion event for the camera route coordinator.
  final FilmRollCompletionEvent? completionEvent;

  /// Error associated with loading archived roll history.
  final String? errorMessage;

  /// Last actionable lifecycle error for inline camera/sheet feedback.
  final String? lastActionError;

  // ── Compatibility/readability helpers ───────────────────────────────────

  /// Legacy lightweight view of [pendingExposures], keyed by reservation id.
  ///
  /// New code should inspect [pendingExposures] to distinguish native work,
  /// durable save work, and retryable recovery.
  Map<String, String> get pendingExposureReservations =>
      Map<String, String>.unmodifiable({
        for (final entry in pendingExposures.entries)
          entry.key: entry.value.reservation.filmRollId,
      });

  /// Legacy value retained while camera callers migrate to [completionEvent].
  FilmRoll? get latestCompletedRoll => completionEvent?.roll;

  // ── Derived getters ──────────────────────────────────────────────────────

  /// True when a roll is actively being shot.
  bool get hasActiveRoll => activeRoll != null && activeRoll!.isActive;

  /// True when the active roll is full and no more exposures can be taken.
  bool get isActiveRollFull => activeRoll != null && activeRoll!.isFull;

  /// Number of accepted native captures that still consume capacity.
  int get pendingExposureCount => pendingExposures.length;

  /// Number of exposures waiting for durable persistence.
  int get pendingSaveCount =>
      pendingExposures.values.where((pending) => pending.isPersisting).length;

  /// Aggregated durable-save state for the active roll.
  FilmRollPendingSaveState get pendingSaveState {
    if (pendingExposures.values.any((pending) => pending.needsRecovery)) {
      return FilmRollPendingSaveState.recoveryRequired;
    }
    if (pendingExposures.values.any((pending) => pending.isPersisting)) {
      return FilmRollPendingSaveState.saving;
    }
    return FilmRollPendingSaveState.idle;
  }

  /// True when a persisted exposure needs an explicit retry or reconciliation.
  bool get hasPendingSaveRecovery =>
      pendingSaveState == FilmRollPendingSaveState.recoveryRequired;

  /// Whether capture must be held until persisted state and recipe are safe.
  bool get isCaptureBlockedByRecovery =>
      restorationStatus != FilmRollRestorationStatus.ready ||
      recipeStatus == FilmRollRecipeStatus.unavailable ||
      recipeStatus == FilmRollRecipeStatus.applying ||
      reconciliationRequired ||
      hasPendingSaveRecovery;

  /// True when a further capture would exceed capacity or is unsafe to start.
  bool get cannotReserveExposure =>
      activeRoll == null ||
      !activeRoll!.isActive ||
      isCaptureBlockedByRecovery ||
      activeRoll!.exposuresTaken + pendingExposureCount >=
          activeRoll!.size.count;

  /// True when a new roll can be safely created.
  bool get canStartRoll =>
      restorationStatus == FilmRollRestorationStatus.ready && !hasActiveRoll;

  /// Returns a copy with the specified fields replaced.
  FilmRollState copyWith({
    Object? activeRoll = _unset,
    List<FilmRoll>? history,
    FilmRollLoadStatus? loadStatus,
    FilmRollRestorationStatus? restorationStatus,
    FilmRollRecipeStatus? recipeStatus,
    Map<String, FilmRollPendingExposure>? pendingExposures,
    bool? reconciliationRequired,
    Object? completionEvent = _unset,
    Object? errorMessage = _unset,
    Object? lastActionError = _unset,
  }) => FilmRollState(
    activeRoll: identical(activeRoll, _unset)
        ? this.activeRoll
        : activeRoll as FilmRoll?,
    history: history ?? this.history,
    loadStatus: loadStatus ?? this.loadStatus,
    restorationStatus: restorationStatus ?? this.restorationStatus,
    recipeStatus: recipeStatus ?? this.recipeStatus,
    pendingExposures: pendingExposures ?? this.pendingExposures,
    reconciliationRequired:
        reconciliationRequired ?? this.reconciliationRequired,
    completionEvent: identical(completionEvent, _unset)
        ? this.completionEvent
        : completionEvent as FilmRollCompletionEvent?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    lastActionError: identical(lastActionError, _unset)
        ? this.lastActionError
        : lastActionError as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilmRollState &&
        other.activeRoll == activeRoll &&
        listEquals(other.history, history) &&
        other.loadStatus == loadStatus &&
        other.restorationStatus == restorationStatus &&
        other.recipeStatus == recipeStatus &&
        mapEquals(other.pendingExposures, pendingExposures) &&
        other.reconciliationRequired == reconciliationRequired &&
        other.completionEvent == completionEvent &&
        other.errorMessage == errorMessage &&
        other.lastActionError == lastActionError;
  }

  @override
  int get hashCode => Object.hash(
    activeRoll,
    Object.hashAll(history),
    loadStatus,
    restorationStatus,
    recipeStatus,
    Object.hashAll(pendingExposures.entries),
    reconciliationRequired,
    completionEvent,
    errorMessage,
    lastActionError,
  );

  @override
  String toString() =>
      'FilmRollState(activeRoll: $activeRoll, '
      'history: ${history.length} rolls, '
      'restoration: ${restorationStatus.name}, '
      'recipe: ${recipeStatus.name}, '
      'pending: $pendingExposureCount, '
      'pendingSave: ${pendingSaveState.name}, '
      'reconciliationRequired: $reconciliationRequired, '
      'loadStatus: ${loadStatus.name}, '
      'errorMessage: $errorMessage, '
      'lastActionError: $lastActionError)';
}
