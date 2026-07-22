import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/rana_camera_api.g.dart',
    dartOptions: DartOptions(),
    dartPackageName: 'rana',
    kotlinOut:
        'android/app/src/main/kotlin/com/rana/app/rana/RanaCameraApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.rana.app.rana'),
  ),
)
class InitializeCameraRequest {
  InitializeCameraRequest({
    required this.platformViewId,
    required this.aspectRatio,
    required this.lens,
    required this.flashMode,
    required this.zoomRatio,
  });

  int platformViewId;
  String aspectRatio;
  String lens;
  String flashMode;
  double zoomRatio;
}

class CameraOperationResult {
  CameraOperationResult({
    required this.status,
    this.lens,
    this.aspectRatio,
    this.label,
    this.zoomRatio,
    this.minZoomRatio,
    this.maxZoomRatio,
    this.isLikelyDigitalZoom,
    this.shouldWarnDigitalZoom,
    this.hasTelephotoCandidate,
    this.zoomQualityLabel,
  });

  String status;
  String? lens;
  String? aspectRatio;
  String? label;
  double? zoomRatio;
  double? minZoomRatio;
  double? maxZoomRatio;
  bool? isLikelyDigitalZoom;
  bool? shouldWarnDigitalZoom;
  bool? hasTelephotoCandidate;
  String? zoomQualityLabel;
}

class OutputCapabilitiesMessage {
  OutputCapabilitiesMessage({
    required this.isHeicSupported,
    this.unavailableReason,
  });

  bool isHeicSupported;
  String? unavailableReason;
}

class PermissionCapabilitiesMessage {
  PermissionCapabilitiesMessage({
    required this.requiresLegacyStorageForCapture,
    required this.galleryReadPermission,
  });

  bool requiresLegacyStorageForCapture;
  String galleryReadPermission;
}

class PerformanceBudgetMessage {
  PerformanceBudgetMessage({
    required this.targetPreviewFps,
    required this.minimumPreviewFps,
    required this.maxP95FrameMs,
    required this.maxDroppedFramePercent,
    required this.minimumFreeMemoryMb,
    required this.glCacheBudgetMb,
    required this.maxPreviewLongEdge,
  });

  int targetPreviewFps;
  int minimumPreviewFps;
  double maxP95FrameMs;
  double maxDroppedFramePercent;
  int minimumFreeMemoryMb;
  int glCacheBudgetMb;
  int maxPreviewLongEdge;
}

class DeviceCapabilityMessage {
  DeviceCapabilityMessage({
    required this.schemaVersion,
    required this.manufacturer,
    required this.model,
    required this.sdkInt,
    required this.totalMemoryMb,
    required this.appMemoryClassMb,
    required this.isLowRamDevice,
    required this.gpuRenderer,
    required this.thermalStatusSupported,
    required this.cameraHardwareLevel,
    required this.rearCameraCount,
    required this.physicalRearCameraCount,
    required this.logicalMultiCameraSupported,
    required this.heicSupported,
    required this.recentRendererFailureCount,
    required this.performanceClass,
    required this.decisionReason,
    required this.budget,
  });

  int schemaVersion;
  String manufacturer;
  String model;
  int sdkInt;
  int totalMemoryMb;
  int appMemoryClassMb;
  bool isLowRamDevice;
  String? gpuRenderer;
  bool thermalStatusSupported;
  String cameraHardwareLevel;
  int rearCameraCount;
  int physicalRearCameraCount;
  bool logicalMultiCameraSupported;
  bool heicSupported;
  int recentRendererFailureCount;
  String performanceClass;
  String decisionReason;
  PerformanceBudgetMessage budget;
}

class RenderRecipeMessage {
  RenderRecipeMessage({
    required this.recipeVersion,
    required this.temperature,
    required this.saturation,
    required this.contrast,
    required this.colorMatrix,
    required this.fade,
    required this.grain,
    required this.grainSize,
    required this.grainShadowsLimit,
    required this.grainHighlightsLimit,
    required this.vignette,
    required this.vignetteColor,
    required this.vignetteRoundness,
    required this.lutStrength,
    required this.lightLeakIntensity,
    required this.lightLeakVariant,
    required this.dustIntensity,
    required this.dustOffsetX,
    required this.dustOffsetY,
    required this.bloomThreshold,
    required this.bloomIntensity,
    required this.halationIntensity,
    required this.halationRadius,
    required this.halationColor,
    required this.lensDistortionStrength,
    required this.chromaticAberrationIntensity,
    required this.highlightRollOff,
    required this.shadowRollOff,
    required this.filmBorderStyle,
    required this.dateStampEnable,
    required this.shadowsTint,
    required this.highlightsTint,
    required this.tone,
    required this.color,
    required this.texture,
    required this.styleStrength,
    required this.undertoneX,
    required this.undertoneY,
    required this.softness,
    required this.outputQuality,
    required this.aspectRatio,
    required this.presetId,
    required this.isStyleModified,
    this.lutPath,
  });

  int recipeVersion;
  double temperature;
  double saturation;
  double contrast;
  List<double> colorMatrix;
  double fade;
  double grain;
  double grainSize;
  double grainShadowsLimit;
  double grainHighlightsLimit;
  double vignette;
  List<double> vignetteColor;
  double vignetteRoundness;
  String? lutPath;
  double lutStrength;
  double lightLeakIntensity;
  int lightLeakVariant;
  double dustIntensity;
  double dustOffsetX;
  double dustOffsetY;
  double bloomThreshold;
  double bloomIntensity;
  double halationIntensity;
  double halationRadius;
  List<double> halationColor;
  double lensDistortionStrength;
  double chromaticAberrationIntensity;
  double highlightRollOff;
  double shadowRollOff;
  int filmBorderStyle;
  bool dateStampEnable;
  List<double> shadowsTint;
  List<double> highlightsTint;
  double tone;
  double color;
  double texture;
  double styleStrength;
  double undertoneX;
  double undertoneY;
  double softness;
  String outputQuality;
  String aspectRatio;
  String presetId;
  bool isStyleModified;
}

class CaptureRequestMessage {
  CaptureRequestMessage({required this.recipe, this.filmRollId});

  RenderRecipeMessage recipe;
  String? filmRollId;
}

class CaptureAcceptedMessage {
  CaptureAcceptedMessage({required this.status, required this.captureId});

  String status;
  String captureId;
}

class CaptureResultMessage {
  CaptureResultMessage({
    required this.status,
    required this.filePath,
    required this.qualityReduced,
    required this.inSampleSize,
    required this.lutSkipped,
    required this.requestedOutputQuality,
    required this.actualOutputFormat,
    required this.outputMimeType,
    required this.outputWidth,
    required this.outputHeight,
    required this.fileSizeBytes,
    this.fallbackReason,
  });

  String status;
  String? filePath;
  bool qualityReduced;
  int inSampleSize;
  bool lutSkipped;
  String requestedOutputQuality;
  String actualOutputFormat;
  String outputMimeType;
  int outputWidth;
  int outputHeight;
  int fileSizeBytes;
  String? fallbackReason;
}

class FilmRollCaptureMessage {
  FilmRollCaptureMessage({
    required this.mediaUri,
    required this.capturedAtEpochMs,
  });

  String mediaUri;
  int capturedAtEpochMs;
}

class CaptureStyleMetadataMessage {
  CaptureStyleMetadataMessage({
    required this.mediaUri,
    required this.mediaIsRendered,
    required this.recipe,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.sourceImagePath,
    this.filmRollId,
  });

  String mediaUri;
  String? sourceImagePath;
  bool mediaIsRendered;
  RenderRecipeMessage recipe;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  String? filmRollId;
}

class PreviewMetricsMessage {
  PreviewMetricsMessage({
    required this.fps,
    required this.active,
    required this.timestampEpochMs,
    required this.firstFrame,
  });

  int fps;
  bool active;
  int timestampEpochMs;
  bool firstFrame;
}

class CaptureProgressMessage {
  CaptureProgressMessage({
    required this.captureId,
    required this.phase,
    required this.elapsedMs,
  });

  String captureId;
  String phase;
  int elapsedMs;
}

class CaptureCompletedMessage {
  CaptureCompletedMessage({
    required this.captureId,
    required this.uri,
    required this.output,
    required this.elapsedMs,
  });

  String captureId;
  String uri;
  CaptureResultMessage output;
  int elapsedMs;
}

class CaptureFailureMessage {
  CaptureFailureMessage({
    required this.captureId,
    required this.code,
    required this.message,
    required this.elapsedMs,
  });

  String captureId;
  String code;
  String message;
  int elapsedMs;
}

class RendererErrorMessage {
  RendererErrorMessage({required this.code, required this.message});

  String code;
  String message;
}

class TelemetryMessage {
  TelemetryMessage({
    required this.name,
    required this.monotonicTimestampUs,
    required this.value,
  });

  String name;
  int monotonicTimestampUs;
  double value;
}

@HostApi()
abstract class RanaCameraHostApi {
  @async
  CameraOperationResult initializeCamera(InitializeCameraRequest request);
  CameraOperationResult releaseCamera();
  OutputCapabilitiesMessage getOutputCapabilities();
  PermissionCapabilitiesMessage getPermissionCapabilities();
  DeviceCapabilityMessage getDeviceCapabilityProfile();
  CameraOperationResult applyRecipe(RenderRecipeMessage recipe);

  @async
  CaptureAcceptedMessage beginCapture(CaptureRequestMessage request);

  @async
  CaptureResultMessage executeCapture(CaptureRequestMessage request);

  CameraOperationResult setFlashMode(String flashMode);
  @async
  CameraOperationResult setZoomRatio(double zoomRatio);
  void setFocusAndMetering(double x, double y);
  void cancelFocusAndMetering();
  CameraOperationResult toggleLens(String currentLens);
  CameraOperationResult setAspectRatio(String aspectRatio);

  @async
  Uint8List loadCapturedImageBytes(String uri, int? targetSize);

  @async
  List<FilmRollCaptureMessage> listFilmRollCaptures(String filmRollId);

  @async
  CaptureStyleMetadataMessage? getCaptureStyleMetadata(String uri);

  @async
  List<CaptureStyleMetadataMessage> getCaptureStyleMetadataBatch(
    List<String> uris,
  );
  void openMediaInGallery(String uri);
}

@FlutterApi()
abstract class RanaCameraFlutterApi {
  void onPreviewMetrics(PreviewMetricsMessage event);
  void onCaptureProgress(CaptureProgressMessage event);
  void onCaptureCompleted(CaptureCompletedMessage event);
  void onCaptureFailure(CaptureFailureMessage event);
  void onRendererError(RendererErrorMessage event);
  void onTelemetry(TelemetryMessage event);
}
