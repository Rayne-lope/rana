import 'package:flutter/foundation.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
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

/// Readiness of the recipe locked by an active Film Roll.
///
/// A camera may be initialized while a persisted roll's recipe is still being
/// restored. Keeping that distinction in immutable state prevents the UI from
/// advertising a usable shutter before the native pipeline is configured.
enum ActiveFilmRollRecipeStatus {
  /// There is no active roll to restore.
  notRequired,

  /// The persisted recipe is being applied to the native preview.
  restoring,

  /// The native preview and capture pipeline match the locked recipe.
  ready,

  /// The persisted recipe could not be found or applied. Recovery is needed.
  unavailable,
}

/// The actual encoded result of a completed capture.
@immutable
class CaptureOutputMetadata {
  const CaptureOutputMetadata({
    required this.requestedOutputQuality,
    required this.actualOutputFormat,
    required this.outputMimeType,
    required this.outputWidth,
    required this.outputHeight,
    required this.fileSizeBytes,
    required this.qualityReduced,
    required this.lutSkipped,
    this.fallbackReason,
  });

  factory CaptureOutputMetadata.fromEvent(Map<String, dynamic> event) =>
      CaptureOutputMetadata(
        requestedOutputQuality:
            event['requestedOutputQuality'] as String? ?? 'high_jpeg',
        actualOutputFormat: event['actualOutputFormat'] as String? ?? 'jpeg',
        outputMimeType: event['outputMimeType'] as String? ?? 'image/jpeg',
        outputWidth: (event['outputWidth'] as num?)?.toInt() ?? 0,
        outputHeight: (event['outputHeight'] as num?)?.toInt() ?? 0,
        fileSizeBytes: (event['fileSizeBytes'] as num?)?.toInt() ?? 0,
        qualityReduced: event['qualityReduced'] == true,
        lutSkipped: event['lutSkipped'] == true,
        fallbackReason: event['fallbackReason'] as String?,
      );

  final String requestedOutputQuality;
  final String actualOutputFormat;
  final String outputMimeType;
  final int outputWidth;
  final int outputHeight;
  final int fileSizeBytes;
  final bool qualityReduced;
  final bool lutSkipped;
  final String? fallbackReason;

  String get formatLabel => actualOutputFormat.toUpperCase();

  String get fileSizeLabel {
    if (fileSizeBytes <= 0) return 'UNKNOWN SIZE';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      other is CaptureOutputMetadata &&
      other.requestedOutputQuality == requestedOutputQuality &&
      other.actualOutputFormat == actualOutputFormat &&
      other.outputMimeType == outputMimeType &&
      other.outputWidth == outputWidth &&
      other.outputHeight == outputHeight &&
      other.fileSizeBytes == fileSizeBytes &&
      other.qualityReduced == qualityReduced &&
      other.lutSkipped == lutSkipped &&
      other.fallbackReason == fallbackReason;

  @override
  int get hashCode => Object.hashAll([
    requestedOutputQuality,
    actualOutputFormat,
    outputMimeType,
    outputWidth,
    outputHeight,
    fileSizeBytes,
    qualityReduced,
    lutSkipped,
    fallbackReason,
  ]);
}

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
    required this.activeFilmRollRecipeStatus,
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
    this.lastCaptureOutput,
    this.failure,
    String? errorMessage,
  }) : _compatibilityErrorMessage = errorMessage;

  /// Factory constructor for the initial state of the camera.
  factory CameraState.initial() => const CameraState(
    flashMode: FlashMode.off,
    activeLens: CameraLens.back,
    activePresetId: 'normal',
    aspectRatio: CameraAspectRatio.portrait34,
    selfTimerMode: SelfTimerMode.off,
    selfTimerRemainingSeconds: 0,
    captureStatus: CaptureStatus.idle,
    activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.notRequired,
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
  final ActiveFilmRollRecipeStatus activeFilmRollRecipeStatus;
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
  final CaptureOutputMetadata? lastCaptureOutput;
  final CameraFailure? failure;
  final String? _compatibilityErrorMessage;

  /// Compatibility view for UI/tests written before structured failures.
  String? get errorMessage =>
      failure?.userMessage ?? _compatibilityErrorMessage;

  bool get isSelfTimerRunning => selfTimerRemainingSeconds > 0;

  /// Whether an active Film Roll currently permits capture and self-timer use.
  bool get isActiveFilmRollRecipeReady =>
      activeFilmRollRecipeStatus != ActiveFilmRollRecipeStatus.unavailable &&
      activeFilmRollRecipeStatus != ActiveFilmRollRecipeStatus.restoring;
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
    ActiveFilmRollRecipeStatus? activeFilmRollRecipeStatus,
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
    Object? lastCaptureOutput = _unset,
    Object? failure = _unset,
    Object? errorMessage = _unset,
  }) {
    final resolvedFailure = identical(failure, _unset)
        ? identical(errorMessage, _unset)
              ? this.failure
              : switch (errorMessage) {
                  final String message => CameraFailure.fromLegacyMessage(
                    message,
                  ),
                  _ => null,
                }
        : failure as CameraFailure?;
    final resolvedCompatibilityMessage = identical(errorMessage, _unset)
        ? identical(failure, _unset)
              ? _compatibilityErrorMessage
              : null
        : null;
    return CameraState(
      flashMode: flashMode ?? this.flashMode,
      activeLens: activeLens ?? this.activeLens,
      activePresetId: activePresetId ?? this.activePresetId,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      selfTimerMode: selfTimerMode ?? this.selfTimerMode,
      selfTimerRemainingSeconds:
          selfTimerRemainingSeconds ?? this.selfTimerRemainingSeconds,
      captureStatus: captureStatus ?? this.captureStatus,
      activeFilmRollRecipeStatus:
          activeFilmRollRecipeStatus ?? this.activeFilmRollRecipeStatus,
      currentFps: currentFps ?? this.currentFps,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      activeStyle: activeStyle ?? this.activeStyle,
      zoomRatio: zoomRatio ?? this.zoomRatio,
      minZoomRatio: minZoomRatio ?? this.minZoomRatio,
      maxZoomRatio: maxZoomRatio ?? this.maxZoomRatio,
      zoomQualityLabel: zoomQualityLabel ?? this.zoomQualityLabel,
      hasTelephotoCandidate:
          hasTelephotoCandidate ?? this.hasTelephotoCandidate,
      isLikelyDigitalZoom: isLikelyDigitalZoom ?? this.isLikelyDigitalZoom,
      shouldWarnDigitalZoom:
          shouldWarnDigitalZoom ?? this.shouldWarnDigitalZoom,
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
      lastCaptureOutput: identical(lastCaptureOutput, _unset)
          ? this.lastCaptureOutput
          : lastCaptureOutput as CaptureOutputMetadata?,
      failure: resolvedFailure,
      errorMessage: resolvedCompatibilityMessage,
    );
  }

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
        other.activeFilmRollRecipeStatus == activeFilmRollRecipeStatus &&
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
        other.lastCaptureOutput == lastCaptureOutput &&
        other.failure == failure &&
        other._compatibilityErrorMessage == _compatibilityErrorMessage;
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
    activeFilmRollRecipeStatus,
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
    lastCaptureOutput,
    failure,
    _compatibilityErrorMessage,
  ]);

  @override
  String toString() =>
      'CameraState(flashMode: $flashMode, activeLens: $activeLens, '
      'activePresetId: $activePresetId, captureStatus: $captureStatus, '
      'activeFilmRollRecipeStatus: $activeFilmRollRecipeStatus, '
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
      'lastCaptureOutput: $lastCaptureOutput, '
      'lastCapturedPath: $lastCapturedPath, failure: $failure, '
      'errorMessage: $errorMessage)';
}
