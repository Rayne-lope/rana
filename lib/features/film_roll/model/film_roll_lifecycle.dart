import 'package:flutter/foundation.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';

/// Readiness of persisted Film Roll restoration.
///
/// A new roll must never be created until this has reached [ready]. This
/// prevents a delayed SharedPreferences read from overwriting a newly-created
/// active roll after launch.
enum FilmRollRestorationStatus { restoring, ready, failed }

/// Whether the active roll's locked recipe has been applied to the camera.
///
/// The Film Roll controller owns the durable recipe and exposes this state;
/// the camera controller updates it while it applies the recipe to native
/// preview/capture. An [unavailable] recipe is a recovery state, never a cue
/// to silently fall back to the Normal preset.
enum FilmRollRecipeStatus { notRequired, applying, ready, unavailable }

/// Durable-save status for in-flight Film Roll exposures.
enum FilmRollPendingSaveState { idle, saving, recoveryRequired }

/// State of one capacity reservation.
enum FilmRollPendingExposureStatus { reserved, saving, recoveryRequired }

/// Why a Film Roll lifecycle action was not completed.
enum FilmRollActionFailure {
  restorationInProgress,
  restorationFailed,
  activeRollAlreadyExists,
  noActiveRoll,
  staleRoll,
  lifecycleBusy,
  reservationUnavailable,
  invalidReservation,
  invalidCapture,
  captureAlreadyHandled,
  persistenceFailed,
  recoveryRequired,
  recipeUnavailable,
}

/// Typed description of a Film Roll lifecycle action.
///
/// UI callers should render [message] inline rather than assuming a `bool`
/// means the action was successful. [isDuplicate] is a successful no-op for a
/// repeated terminal native event and must not be treated as another exposure.
@immutable
class FilmRollActionResult {
  const FilmRollActionResult._({
    required this.succeeded,
    this.failure,
    this.message,
    this.roll,
    this.reservation,
    this.completionEvent,
    this.isDuplicate = false,
  });

  /// A completed action.
  const FilmRollActionResult.success({
    FilmRoll? roll,
    FilmRollExposureReservation? reservation,
    FilmRollCompletionEvent? completionEvent,
    bool isDuplicate = false,
    String? message,
  }) : this._(
         succeeded: true,
         roll: roll,
         reservation: reservation,
         completionEvent: completionEvent,
         isDuplicate: isDuplicate,
         message: message,
       );

  /// A rejected or failed action.
  const FilmRollActionResult.failure(
    FilmRollActionFailure failure, {
    required String message,
    FilmRoll? roll,
  }) : this._(succeeded: false, failure: failure, message: message, roll: roll);

  /// Positional convenience form for camera lifecycle guards.
  const FilmRollActionResult.failed(
    FilmRollActionFailure failure,
    String message, {
    FilmRoll? roll,
  }) : this.failure(failure, message: message, roll: roll);

  /// Whether the requested operation completed.
  final bool succeeded;

  /// Machine-readable failure when [succeeded] is false.
  final FilmRollActionFailure? failure;

  /// User-safe, English explanation suitable for an inline error.
  final String? message;

  /// The affected roll, when one is available.
  final FilmRoll? roll;

  /// A newly-created reservation for a successful reserve operation.
  final FilmRollExposureReservation? reservation;

  /// Completion event emitted by a finalizing action.
  final FilmRollCompletionEvent? completionEvent;

  /// True when a duplicate native terminal event was safely ignored.
  final bool isDuplicate;

  /// Whether the caller can present a retry affordance.
  bool get isRetryable =>
      failure == FilmRollActionFailure.persistenceFailed ||
      failure == FilmRollActionFailure.recoveryRequired ||
      failure == FilmRollActionFailure.recipeUnavailable;

  @override
  bool operator ==(Object other) =>
      other is FilmRollActionResult &&
      other.succeeded == succeeded &&
      other.failure == failure &&
      other.message == message &&
      other.roll == roll &&
      other.reservation == reservation &&
      other.completionEvent == completionEvent &&
      other.isDuplicate == isDuplicate;

  @override
  int get hashCode => Object.hash(
    succeeded,
    failure,
    message,
    roll,
    reservation,
    completionEvent,
    isDuplicate,
  );
}

/// Transient, capacity-consuming state for one accepted native capture.
@immutable
class FilmRollPendingExposure {
  const FilmRollPendingExposure({
    required this.reservation,
    required this.status,
    this.captureId,
    this.mediaUri,
    this.errorMessage,
  });

  final FilmRollExposureReservation reservation;
  final FilmRollPendingExposureStatus status;
  final String? captureId;
  final String? mediaUri;
  final String? errorMessage;

  bool get isPersisting => status == FilmRollPendingExposureStatus.saving;
  bool get needsRecovery =>
      status == FilmRollPendingExposureStatus.recoveryRequired;

  FilmRollPendingExposure copyWith({
    FilmRollExposureReservation? reservation,
    FilmRollPendingExposureStatus? status,
    Object? captureId = _unset,
    Object? mediaUri = _unset,
    Object? errorMessage = _unset,
  }) => FilmRollPendingExposure(
    reservation: reservation ?? this.reservation,
    status: status ?? this.status,
    captureId: identical(captureId, _unset)
        ? this.captureId
        : captureId as String?,
    mediaUri: identical(mediaUri, _unset) ? this.mediaUri : mediaUri as String?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is FilmRollPendingExposure &&
      other.reservation == reservation &&
      other.status == status &&
      other.captureId == captureId &&
      other.mediaUri == mediaUri &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode =>
      Object.hash(reservation, status, captureId, mediaUri, errorMessage);
}

/// Origin of a completed Film Roll.
enum FilmRollCompletionSource { automaticCapture, manualEnd, recovery }

/// One-time completion event consumed by the camera route coordinator.
@immutable
class FilmRollCompletionEvent {
  const FilmRollCompletionEvent({
    required this.id,
    required this.roll,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final FilmRoll roll;
  final FilmRollCompletionSource source;
  final DateTime createdAt;

  bool get shouldPresentCompletionSheet =>
      source == FilmRollCompletionSource.automaticCapture;

  @override
  bool operator ==(Object other) =>
      other is FilmRollCompletionEvent &&
      other.id == id &&
      other.roll == roll &&
      other.source == source &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, roll, source, createdAt);
}
