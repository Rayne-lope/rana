import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/rana_style.dart';

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

/// Supported camera aspect ratios for the viewfinder and capture pipeline.
enum CameraAspectRatio {
  portrait34(
    label: '3:4',
    viewfinderRatio: 3 / 4,
    platformValue: 'portrait_3_4',
  ),
  square11(label: '1:1', viewfinderRatio: 1, platformValue: 'square_1_1'),
  portrait916(
    label: '9:16',
    viewfinderRatio: 9 / 16,
    platformValue: 'portrait_9_16',
  );

  const CameraAspectRatio({
    required this.label,
    required this.viewfinderRatio,
    required this.platformValue,
  });

  final String label;
  final double viewfinderRatio;
  final String platformValue;

  CameraAspectRatio get next => switch (this) {
    CameraAspectRatio.portrait34 => CameraAspectRatio.square11,
    CameraAspectRatio.square11 => CameraAspectRatio.portrait916,
    CameraAspectRatio.portrait916 => CameraAspectRatio.portrait34,
  };
}

/// States representing the capturing flow animation.
enum CaptureStatus { idle, capturing, processing, success, error }

/// Immutable state model containing the current camera interface configuration.
@immutable
class CameraState {
  /// Main constructor.
  const CameraState({
    required this.flashMode,
    required this.activeLens,
    required this.activePresetId,
    required this.aspectRatio,
    required this.captureStatus,
    required this.currentFps,
    required this.isCameraInitialized,
    required this.activeStyle,
    this.lastCapturedPath,
    this.errorMessage,
  });

  /// Factory constructor for the initial state of the camera.
  factory CameraState.initial() => const CameraState(
    flashMode: FlashMode.off,
    activeLens: CameraLens.back,
    activePresetId: 'normal',
    aspectRatio: CameraAspectRatio.portrait34,
    captureStatus: CaptureStatus.idle,
    currentFps: 0,
    isCameraInitialized: false,
    activeStyle: RanaStyle(),
  );

  static const Object _unset = Object();

  final FlashMode flashMode;
  final CameraLens activeLens;
  final String activePresetId;
  final CameraAspectRatio aspectRatio;
  final CaptureStatus captureStatus;
  final int currentFps;
  final bool isCameraInitialized;
  final RanaStyle activeStyle;
  final String? lastCapturedPath;
  final String? errorMessage;

  /// Copies this instance, replacing specified fields.
  CameraState copyWith({
    FlashMode? flashMode,
    CameraLens? activeLens,
    String? activePresetId,
    CameraAspectRatio? aspectRatio,
    CaptureStatus? captureStatus,
    int? currentFps,
    bool? isCameraInitialized,
    RanaStyle? activeStyle,
    Object? lastCapturedPath = _unset,
    Object? errorMessage = _unset,
  }) => CameraState(
    flashMode: flashMode ?? this.flashMode,
    activeLens: activeLens ?? this.activeLens,
    activePresetId: activePresetId ?? this.activePresetId,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    captureStatus: captureStatus ?? this.captureStatus,
    currentFps: currentFps ?? this.currentFps,
    isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
    activeStyle: activeStyle ?? this.activeStyle,
    lastCapturedPath: identical(lastCapturedPath, _unset)
        ? this.lastCapturedPath
        : lastCapturedPath as String?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraState &&
        other.flashMode == flashMode &&
        other.activeLens == activeLens &&
        other.activePresetId == activePresetId &&
        other.aspectRatio == aspectRatio &&
        other.captureStatus == captureStatus &&
        other.currentFps == currentFps &&
        other.isCameraInitialized == isCameraInitialized &&
        other.activeStyle == activeStyle &&
        other.lastCapturedPath == lastCapturedPath &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    flashMode,
    activeLens,
    activePresetId,
    aspectRatio,
    captureStatus,
    currentFps,
    isCameraInitialized,
    activeStyle,
    lastCapturedPath,
    errorMessage,
  );

  @override
  String toString() =>
      'CameraState(flashMode: $flashMode, activeLens: $activeLens, '
      'activePresetId: $activePresetId, captureStatus: $captureStatus, '
      'aspectRatio: $aspectRatio, currentFps: $currentFps, '
      'isCameraInitialized: $isCameraInitialized, '
      'activeStyle: $activeStyle, '
      'lastCapturedPath: $lastCapturedPath, errorMessage: $errorMessage)';
}
