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
    this.errorMessage,
  });

  /// Initial state before any rolls are loaded.
  factory FilmRollState.initial() => const FilmRollState(
    activeRoll: null,
    history: [],
    loadStatus: FilmRollLoadStatus.initial,
  );

  /// The currently active roll, or null if no roll is loaded.
  final FilmRoll? activeRoll;

  /// All completed and abandoned rolls, newest first.
  final List<FilmRoll> history;

  /// Current load status for the history list.
  final FilmRollLoadStatus loadStatus;

  /// Error message if [loadStatus] is [FilmRollLoadStatus.error].
  final String? errorMessage;

  // ── Derived getters ────────────────────────────────────────────────────────

  /// True when a roll is actively being shot.
  bool get hasActiveRoll => activeRoll != null && activeRoll!.isActive;

  /// True when the active roll is full and no more exposures can be taken.
  bool get isActiveRollFull => activeRoll != null && activeRoll!.isFull;

  /// Returns a copy with the specified fields replaced.
  FilmRollState copyWith({
    Object? activeRoll = _unset,
    List<FilmRoll>? history,
    FilmRollLoadStatus? loadStatus,
    Object? errorMessage = _unset,
  }) => FilmRollState(
    activeRoll: identical(activeRoll, _unset)
        ? this.activeRoll
        : activeRoll as FilmRoll?,
    history: history ?? this.history,
    loadStatus: loadStatus ?? this.loadStatus,
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
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    activeRoll,
    Object.hashAll(history),
    loadStatus,
    errorMessage,
  );

  @override
  String toString() =>
      'FilmRollState(activeRoll: $activeRoll, '
      'history: ${history.length} rolls, '
      'loadStatus: ${loadStatus.name}, '
      'errorMessage: $errorMessage)';
}
