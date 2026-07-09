import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/rana_style.dart';

const double userMinZoomRatio = 1;
const double userMaxZoomRatio = 3;

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

/// Available self-timer countdown modes.
enum SelfTimerMode {
  off(label: 'OFF', seconds: 0),
  threeSeconds(label: '3S', seconds: 3),
  fiveSeconds(label: '5S', seconds: 5),
  tenSeconds(label: '10S', seconds: 10);

  const SelfTimerMode({required this.label, required this.seconds});

  final String label;
  final int seconds;

  bool get isEnabled => this != SelfTimerMode.off;

  SelfTimerMode get next => switch (this) {
    SelfTimerMode.off => SelfTimerMode.threeSeconds,
    SelfTimerMode.threeSeconds => SelfTimerMode.fiveSeconds,
    SelfTimerMode.fiveSeconds => SelfTimerMode.tenSeconds,
    SelfTimerMode.tenSeconds => SelfTimerMode.off,
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
    required this.selfTimerMode,
    required this.selfTimerRemainingSeconds,
    required this.captureStatus,
    required this.currentFps,
    required this.isCameraInitialized,
    required this.activeStyle,
    required this.zoomRatio,
    required this.minZoomRatio,
    required this.maxZoomRatio,
    required this.zoomQualityLabel,
    required this.hasTelephotoCandidate,
    required this.isLikelyDigitalZoom,
    required this.shouldWarnDigitalZoom,
    required this.physicalCameraCount,
    this.lastCapturedPath,
    this.activeCaptureId,
    this.completedCaptureId,
    this.captureError,
    this.captureElapsedMs = 0,
    this.errorMessage,
  });

  /// Factory constructor for the initial state of the camera.
  factory CameraState.initial() => const CameraState(
    flashMode: FlashMode.off,
    activeLens: CameraLens.back,
    activePresetId: 'normal',
    aspectRatio: CameraAspectRatio.portrait34,
    selfTimerMode: SelfTimerMode.off,
    selfTimerRemainingSeconds: 0,
    captureStatus: CaptureStatus.idle,
    currentFps: 0,
    isCameraInitialized: false,
    activeStyle: RanaStyle(),
    zoomRatio: userMinZoomRatio,
    minZoomRatio: userMinZoomRatio,
    maxZoomRatio: userMaxZoomRatio,
    zoomQualityLabel: 'native',
    hasTelephotoCandidate: false,
    isLikelyDigitalZoom: false,
    shouldWarnDigitalZoom: false,
    physicalCameraCount: 0,
  );

  static const Object _unset = Object();

  final FlashMode flashMode;
  final CameraLens activeLens;
  final String activePresetId;
  final CameraAspectRatio aspectRatio;
  final SelfTimerMode selfTimerMode;
  final int selfTimerRemainingSeconds;
  final CaptureStatus captureStatus;
  final int currentFps;
  final bool isCameraInitialized;
  final RanaStyle activeStyle;
  final double zoomRatio;
  final double minZoomRatio;
  final double maxZoomRatio;
  final String zoomQualityLabel;
  final bool hasTelephotoCandidate;
  final bool isLikelyDigitalZoom;
  final bool shouldWarnDigitalZoom;
  final int physicalCameraCount;
  final String? lastCapturedPath;
  final String? activeCaptureId;
  final String? completedCaptureId;
  final String? captureError;
  final int captureElapsedMs;
  final String? errorMessage;

  bool get isSelfTimerRunning => selfTimerRemainingSeconds > 0;
  double get effectiveMaxZoomRatio {
    final cappedMaxZoomRatio = maxZoomRatio < userMaxZoomRatio
        ? maxZoomRatio
        : userMaxZoomRatio;
    return cappedMaxZoomRatio < minZoomRatio
        ? minZoomRatio
        : cappedMaxZoomRatio;
  }

  bool get isZoomLimited => maxZoomRatio < userMaxZoomRatio;

  /// Copies this instance, replacing specified fields.
  CameraState copyWith({
    FlashMode? flashMode,
    CameraLens? activeLens,
    String? activePresetId,
    CameraAspectRatio? aspectRatio,
    SelfTimerMode? selfTimerMode,
    int? selfTimerRemainingSeconds,
    CaptureStatus? captureStatus,
    int? currentFps,
    bool? isCameraInitialized,
    RanaStyle? activeStyle,
    double? zoomRatio,
    double? minZoomRatio,
    double? maxZoomRatio,
    String? zoomQualityLabel,
    bool? hasTelephotoCandidate,
    bool? isLikelyDigitalZoom,
    bool? shouldWarnDigitalZoom,
    int? physicalCameraCount,
    Object? lastCapturedPath = _unset,
    Object? activeCaptureId = _unset,
    Object? completedCaptureId = _unset,
    Object? captureError = _unset,
    int? captureElapsedMs,
    Object? errorMessage = _unset,
  }) => CameraState(
    flashMode: flashMode ?? this.flashMode,
    activeLens: activeLens ?? this.activeLens,
    activePresetId: activePresetId ?? this.activePresetId,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    selfTimerMode: selfTimerMode ?? this.selfTimerMode,
    selfTimerRemainingSeconds:
        selfTimerRemainingSeconds ?? this.selfTimerRemainingSeconds,
    captureStatus: captureStatus ?? this.captureStatus,
    currentFps: currentFps ?? this.currentFps,
    isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
    activeStyle: activeStyle ?? this.activeStyle,
    zoomRatio: zoomRatio ?? this.zoomRatio,
    minZoomRatio: minZoomRatio ?? this.minZoomRatio,
    maxZoomRatio: maxZoomRatio ?? this.maxZoomRatio,
    zoomQualityLabel: zoomQualityLabel ?? this.zoomQualityLabel,
    hasTelephotoCandidate: hasTelephotoCandidate ?? this.hasTelephotoCandidate,
    isLikelyDigitalZoom: isLikelyDigitalZoom ?? this.isLikelyDigitalZoom,
    shouldWarnDigitalZoom: shouldWarnDigitalZoom ?? this.shouldWarnDigitalZoom,
    physicalCameraCount: physicalCameraCount ?? this.physicalCameraCount,
    lastCapturedPath: identical(lastCapturedPath, _unset)
        ? this.lastCapturedPath
        : lastCapturedPath as String?,
    activeCaptureId: identical(activeCaptureId, _unset)
        ? this.activeCaptureId
        : activeCaptureId as String?,
    completedCaptureId: identical(completedCaptureId, _unset)
        ? this.completedCaptureId
        : completedCaptureId as String?,
    captureError: identical(captureError, _unset)
        ? this.captureError
        : captureError as String?,
    captureElapsedMs: captureElapsedMs ?? this.captureElapsedMs,
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
        other.selfTimerMode == selfTimerMode &&
        other.selfTimerRemainingSeconds == selfTimerRemainingSeconds &&
        other.captureStatus == captureStatus &&
        other.currentFps == currentFps &&
        other.isCameraInitialized == isCameraInitialized &&
        other.activeStyle == activeStyle &&
        other.zoomRatio == zoomRatio &&
        other.minZoomRatio == minZoomRatio &&
        other.maxZoomRatio == maxZoomRatio &&
        other.zoomQualityLabel == zoomQualityLabel &&
        other.hasTelephotoCandidate == hasTelephotoCandidate &&
        other.isLikelyDigitalZoom == isLikelyDigitalZoom &&
        other.shouldWarnDigitalZoom == shouldWarnDigitalZoom &&
        other.physicalCameraCount == physicalCameraCount &&
        other.lastCapturedPath == lastCapturedPath &&
        other.activeCaptureId == activeCaptureId &&
        other.completedCaptureId == completedCaptureId &&
        other.captureError == captureError &&
        other.captureElapsedMs == captureElapsedMs &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hashAll([
    flashMode,
    activeLens,
    activePresetId,
    aspectRatio,
    selfTimerMode,
    selfTimerRemainingSeconds,
    captureStatus,
    currentFps,
    isCameraInitialized,
    activeStyle,
    zoomRatio,
    minZoomRatio,
    maxZoomRatio,
    zoomQualityLabel,
    hasTelephotoCandidate,
    isLikelyDigitalZoom,
    shouldWarnDigitalZoom,
    physicalCameraCount,
    lastCapturedPath,
    activeCaptureId,
    completedCaptureId,
    captureError,
    captureElapsedMs,
    errorMessage,
  ]);

  @override
  String toString() =>
      'CameraState(flashMode: $flashMode, activeLens: $activeLens, '
      'activePresetId: $activePresetId, captureStatus: $captureStatus, '
      'aspectRatio: $aspectRatio, selfTimerMode: $selfTimerMode, '
      'selfTimerRemainingSeconds: $selfTimerRemainingSeconds, '
      'currentFps: $currentFps, '
      'isCameraInitialized: $isCameraInitialized, '
      'activeStyle: $activeStyle, '
      'zoomRatio: $zoomRatio, minZoomRatio: $minZoomRatio, '
      'maxZoomRatio: $maxZoomRatio, '
      'zoomQualityLabel: $zoomQualityLabel, '
      'isLikelyDigitalZoom: $isLikelyDigitalZoom, '
      'shouldWarnDigitalZoom: $shouldWarnDigitalZoom, '
      'activeCaptureId: $activeCaptureId, '
      'completedCaptureId: $completedCaptureId, '
      'captureElapsedMs: $captureElapsedMs, '
      'lastCapturedPath: $lastCapturedPath, errorMessage: $errorMessage)';
}
