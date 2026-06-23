import 'package:flutter/foundation.dart';

/// Available camera flash modes.
enum FlashMode {
  off,
  on,
  auto;

  /// Human-readable label.
  String get label => name.toUpperCase();
}

/// Active camera lens modes.
enum CameraLens {
  back,
  front;

  /// String descriptor for platform channels.
  String get value => name;
}

/// States representing the capturing flow animation.
enum CaptureStatus {
  idle,
  capturing,
  success,
  error,
}

/// Immutable state model containing the current camera interface configuration.
@immutable
class CameraState {
  /// Main constructor.
  const CameraState({
    required this.flashMode,
    required this.activeLens,
    required this.activePresetId,
    required this.captureStatus,
    required this.currentFps,
    required this.isCameraInitialized,
    this.lastCapturedPath,
    this.errorMessage,
  });

  /// Factory constructor for the initial state of the camera.
  factory CameraState.initial() => const CameraState(
        flashMode: FlashMode.off,
        activeLens: CameraLens.back,
        activePresetId: 'normal',
        captureStatus: CaptureStatus.idle,
        currentFps: 0,
        isCameraInitialized: false,
      );

  final FlashMode flashMode;
  final CameraLens activeLens;
  final String activePresetId;
  final CaptureStatus captureStatus;
  final int currentFps;
  final bool isCameraInitialized;
  final String? lastCapturedPath;
  final String? errorMessage;

  /// Copies this instance, replacing specified fields.
  CameraState copyWith({
    FlashMode? flashMode,
    CameraLens? activeLens,
    String? activePresetId,
    CaptureStatus? captureStatus,
    int? currentFps,
    bool? isCameraInitialized,
    String? lastCapturedPath,
    String? errorMessage,
  }) =>
      CameraState(
        flashMode: flashMode ?? this.flashMode,
        activeLens: activeLens ?? this.activeLens,
        activePresetId: activePresetId ?? this.activePresetId,
        captureStatus: captureStatus ?? this.captureStatus,
        currentFps: currentFps ?? this.currentFps,
        isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
        lastCapturedPath: lastCapturedPath ?? this.lastCapturedPath,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraState &&
        other.flashMode == flashMode &&
        other.activeLens == activeLens &&
        other.activePresetId == activePresetId &&
        other.captureStatus == captureStatus &&
        other.currentFps == currentFps &&
        other.isCameraInitialized == isCameraInitialized &&
        other.lastCapturedPath == lastCapturedPath &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        flashMode,
        activeLens,
        activePresetId,
        captureStatus,
        currentFps,
        isCameraInitialized,
        lastCapturedPath,
        errorMessage,
      );

  @override
  String toString() =>
      'CameraState(flashMode: $flashMode, activeLens: $activeLens, '
      'activePresetId: $activePresetId, captureStatus: $captureStatus, '
      'currentFps: $currentFps, isCameraInitialized: $isCameraInitialized, '
      'lastCapturedPath: $lastCapturedPath, errorMessage: $errorMessage)';
}
