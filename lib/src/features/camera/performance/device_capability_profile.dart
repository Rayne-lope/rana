import 'package:flutter/foundation.dart';

@internal
enum DevicePerformanceClass {
  high('high'),
  balanced('balanced'),
  compatibility('compatibility'),
  safe('safe');

  const DevicePerformanceClass(this.wireValue);

  final String wireValue;

  static DevicePerformanceClass fromWire(String value) => values.firstWhere(
    (candidate) => candidate.wireValue == value,
    orElse: () => DevicePerformanceClass.compatibility,
  );
}

@immutable
@internal
final class PerformanceBudget {
  const PerformanceBudget({
    required this.targetPreviewFps,
    required this.minimumPreviewFps,
    required this.maxP95FrameMs,
    required this.maxDroppedFramePercent,
    required this.minimumFreeMemoryMb,
    required this.glCacheBudgetMb,
    required this.maxPreviewLongEdge,
  });

  final int targetPreviewFps;
  final int minimumPreviewFps;
  final double maxP95FrameMs;
  final double maxDroppedFramePercent;
  final int minimumFreeMemoryMb;
  final int glCacheBudgetMb;
  final int maxPreviewLongEdge;

  bool get isValid =>
      targetPreviewFps > 0 &&
      minimumPreviewFps > 0 &&
      minimumPreviewFps <= targetPreviewFps &&
      maxP95FrameMs.isFinite &&
      maxP95FrameMs > 0 &&
      maxDroppedFramePercent.isFinite &&
      maxDroppedFramePercent >= 0 &&
      minimumFreeMemoryMb > 0 &&
      glCacheBudgetMb > 0 &&
      maxPreviewLongEdge > 0;

  Map<String, Object> toSafeMap() => <String, Object>{
    'targetPreviewFps': targetPreviewFps,
    'minimumPreviewFps': minimumPreviewFps,
    'maxP95FrameMs': maxP95FrameMs,
    'maxDroppedFramePercent': maxDroppedFramePercent,
    'minimumFreeMemoryMb': minimumFreeMemoryMb,
    'glCacheBudgetMb': glCacheBudgetMb,
    'maxPreviewLongEdge': maxPreviewLongEdge,
  };
}

@immutable
@internal
final class DeviceCapabilityProfile {
  const DeviceCapabilityProfile({
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

  final int schemaVersion;
  final String manufacturer;
  final String model;
  final int sdkInt;
  final int totalMemoryMb;
  final int appMemoryClassMb;
  final bool isLowRamDevice;
  final String? gpuRenderer;
  final bool thermalStatusSupported;
  final String cameraHardwareLevel;
  final int rearCameraCount;
  final int physicalRearCameraCount;
  final bool logicalMultiCameraSupported;
  final bool heicSupported;
  final int recentRendererFailureCount;
  final DevicePerformanceClass performanceClass;
  final String decisionReason;
  final PerformanceBudget budget;

  Map<String, Object?> toSafeMap() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'manufacturer': manufacturer,
    'model': model,
    'sdkInt': sdkInt,
    'totalMemoryMb': totalMemoryMb,
    'appMemoryClassMb': appMemoryClassMb,
    'isLowRamDevice': isLowRamDevice,
    'gpuRenderer': gpuRenderer,
    'thermalStatusSupported': thermalStatusSupported,
    'cameraHardwareLevel': cameraHardwareLevel,
    'rearCameraCount': rearCameraCount,
    'physicalRearCameraCount': physicalRearCameraCount,
    'logicalMultiCameraSupported': logicalMultiCameraSupported,
    'heicSupported': heicSupported,
    'recentRendererFailureCount': recentRendererFailureCount,
    'performanceClass': performanceClass.wireValue,
    'decisionReason': decisionReason,
    'budget': budget.toSafeMap(),
  };
}
