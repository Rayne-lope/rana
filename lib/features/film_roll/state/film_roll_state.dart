import 'package:flutter/foundation.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';

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
    required this.pendingExposureReservations,
    this.latestCompletedRoll,
    this.errorMessage,
  });

  /// Initial state before any rolls are loaded.
  factory FilmRollState.initial() => const FilmRollState(
    activeRoll: null,
    history: [],
    loadStatus: FilmRollLoadStatus.initial,
    pendingExposureReservations: {},
  );

  /// The currently active roll, or null if no roll is loaded.
  final FilmRoll? activeRoll;

  /// Completed rolls retained for the Rolls archive, newest first.
  final List<FilmRoll> history;

  /// Current load status for the history list.
  final FilmRollLoadStatus loadStatus;

  /// In-flight capture reservations, keyed by reservation id.
  ///
  /// Values are roll IDs so a completion can only update the roll that was
  /// active when capture began.
  final Map<String, String> pendingExposureReservations;

  /// Most recent automatically completed roll for the Phase 4 completion UI.
  final FilmRoll? latestCompletedRoll;

  /// Error message if [loadStatus] is [FilmRollLoadStatus.error].
  final String? errorMessage;

  // ── Derived getters ────────────────────────────────────────────────────────

  /// True when a roll is actively being shot.
  bool get hasActiveRoll => activeRoll != null && activeRoll!.isActive;

  /// True when the active roll is full and no more exposures can be taken.
  bool get isActiveRollFull => activeRoll != null && activeRoll!.isFull;

  /// Number of native captures still being processed for the active roll.
  int get pendingExposureCount => pendingExposureReservations.length;

  /// True when a further capture would exceed the active roll's capacity.
  bool get cannotReserveExposure =>
      activeRoll == null ||
      !activeRoll!.isActive ||
      activeRoll!.exposuresTaken + pendingExposureCount >=
          activeRoll!.size.count;

  /// Returns a copy with the specified fields replaced.
  FilmRollState copyWith({
    Object? activeRoll = _unset,
    List<FilmRoll>? history,
    FilmRollLoadStatus? loadStatus,
    Map<String, String>? pendingExposureReservations,
    Object? latestCompletedRoll = _unset,
    Object? errorMessage = _unset,
  }) => FilmRollState(
    activeRoll: identical(activeRoll, _unset)
        ? this.activeRoll
        : activeRoll as FilmRoll?,
    history: history ?? this.history,
    loadStatus: loadStatus ?? this.loadStatus,
    pendingExposureReservations:
        pendingExposureReservations ?? this.pendingExposureReservations,
    latestCompletedRoll: identical(latestCompletedRoll, _unset)
        ? this.latestCompletedRoll
        : latestCompletedRoll as FilmRoll?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilmRollState &&
        other.activeRoll == activeRoll &&
        listEquals(other.history, history) &&
        other.loadStatus == loadStatus &&
        mapEquals(
          other.pendingExposureReservations,
          pendingExposureReservations,
        ) &&
        other.latestCompletedRoll == latestCompletedRoll &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    activeRoll,
    Object.hashAll(history),
    loadStatus,
    Object.hashAll(pendingExposureReservations.entries),
    latestCompletedRoll,
    errorMessage,
  );

  @override
  String toString() =>
      'FilmRollState(activeRoll: $activeRoll, '
      'history: ${history.length} rolls, '
      'pending: $pendingExposureCount, '
      'loadStatus: ${loadStatus.name}, '
      'errorMessage: $errorMessage)';
}
