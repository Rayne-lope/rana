import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/src/features/camera/performance/device_capability_profile.dart';
import 'package:rana/src/platform/rana_camera_api.g.dart' as pigeon;
import 'package:rana/src/platform/rana_camera_pigeon_mapper.dart';

final class _CapabilityHostApi extends pigeon.RanaCameraHostApi {
  _CapabilityHostApi(this.profile);

  final pigeon.DeviceCapabilityMessage profile;

  @override
  Future<pigeon.DeviceCapabilityMessage> getDeviceCapabilityProfile() async =>
      profile;
}

void main() {
  test(
    'typed platform service returns an internal capability profile',
    () async {
      final service = CameraPlatformService(
        hostApi: _CapabilityHostApi(_message()),
      );

      final profile = await service.getDeviceCapabilityProfile();

      expect(profile.schemaVersion, 1);
      expect(profile.performanceClass, DevicePerformanceClass.high);
      expect(profile.budget.targetPreviewFps, 30);
      expect(profile.budget.isValid, isTrue);
      expect(profile.gpuRenderer, 'Adreno 740');
    },
  );

  test('unknown native performance class falls back conservatively', () {
    final profile = deviceCapabilityFromPigeon(
      _message(performanceClass: 'future_tier'),
    );

    expect(profile.performanceClass, DevicePerformanceClass.compatibility);
  });

  test('diagnostic capability map cannot contain media identifiers', () {
    final profile = deviceCapabilityFromPigeon(_message());
    final encoded = jsonEncode(profile.toSafeMap()).toLowerCase();

    expect(encoded, isNot(contains('content://')));
    expect(encoded, isNot(contains('captureid')));
    expect(encoded, isNot(contains('filmrollid')));
    expect(encoded, isNot(contains('imagedata')));
    expect(encoded, isNot(contains('filepath')));
    expect(profile.toSafeMap().keys, isNot(contains('uri')));
  });
}

pigeon.DeviceCapabilityMessage _message({String performanceClass = 'high'}) =>
    pigeon.DeviceCapabilityMessage(
      schemaVersion: 1,
      manufacturer: 'Google',
      model: 'Pixel',
      sdkInt: 35,
      totalMemoryMb: 8192,
      appMemoryClassMb: 512,
      isLowRamDevice: false,
      gpuRenderer: 'Adreno 740',
      thermalStatusSupported: true,
      cameraHardwareLevel: 'full',
      rearCameraCount: 2,
      physicalRearCameraCount: 2,
      logicalMultiCameraSupported: true,
      heicSupported: true,
      recentRendererFailureCount: 0,
      performanceClass: performanceClass,
      decisionReason: 'high_capability_device',
      budget: pigeon.PerformanceBudgetMessage(
        targetPreviewFps: 30,
        minimumPreviewFps: 28,
        maxP95FrameMs: 40,
        maxDroppedFramePercent: 3,
        minimumFreeMemoryMb: 512,
        glCacheBudgetMb: 96,
        maxPreviewLongEdge: 1920,
      ),
    );
