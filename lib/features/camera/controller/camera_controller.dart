import 'dart:async';

import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_controller.g.dart';

@riverpod
class CameraController extends _$CameraController {
  late final CameraPlatformService _platformService;
  StreamSubscription<Map<String, dynamic>>? _statusSubscription;

  @override
  CameraState build() {
    _platformService = CameraPlatformService();

    ref.onDispose(() {
      unawaited(_statusSubscription?.cancel());
    });

    return CameraState.initial();
  }

  /// Triggers asynchronous native initialization and listens to status updates
  /// (FPS).
  Future<void> initialize() async {
    if (state.isCameraInitialized) return;
    try {
      final result = await _platformService.initializeCamera();
      final initialLensValue = result['lens'] as String? ?? 'back';
      final initialLens = CameraLens.values.firstWhere(
        (l) => l.value == initialLensValue,
        orElse: () => CameraLens.back,
      );

      state = state.copyWith(
        isCameraInitialized: true,
        activeLens: initialLens,
        // ignore: avoid_redundant_argument_values
        errorMessage: null,
      );

      unawaited(_statusSubscription?.cancel());
      _statusSubscription = _platformService.statusStream.listen(
        (event) {
          if (event['type'] == 'status_update') {
            final fps = event['fps'] as int? ?? 0;
            state = state.copyWith(currentFps: fps);
          }
        },
        onError: (Object err) {
          state = state.copyWith(errorMessage: err.toString());
        },
      );
    } on Object catch (e) {
      state = state.copyWith(
        isCameraInitialized: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cycles to the next flash mode (off -> on -> auto).
  Future<void> toggleFlashMode() async {
    final nextFlash = _getNextFlashMode(state.flashMode);
    try {
      await _platformService.setFlashMode(nextFlash.name);
      state = state.copyWith(flashMode: nextFlash);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Toggles front and back camera lenses.
  Future<void> toggleLens() async {
    try {
      final currentLensValue = state.activeLens.value;
      final result = await _platformService.toggleLens(currentLensValue);
      final nextLensValue = result['lens'] as String? ?? 'back';
      final nextLens = CameraLens.values.firstWhere(
        (l) => l.value == nextLensValue,
        orElse: () => CameraLens.back,
      );
      state = state.copyWith(activeLens: nextLens);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Selects active film preset on native rendering pipeline.
  Future<void> selectPreset(PresetModel preset) async {
    try {
      final paramsMap = <String, dynamic>{
        'temperature': preset.color.temperature,
        'contrast': preset.color.contrast,
        'saturation': preset.color.saturation,
        'grain': preset.grain.intensity,
        'vignette': preset.vignette.intensity,
        'lutPath': preset.lut,
        'lutStrength': preset.lut != null ? 1.0 : 0.0,
      };
      AppLogger.glParams('PREVIEW', paramsMap);
      ref.read(consistencyDebugProvider.notifier).update(
            (state) => state.copyWith(lastPreviewParams: paramsMap),
          );
      await _platformService.selectPreset(preset.id, paramsMap);
      state = state.copyWith(activePresetId: preset.id);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Triggers film capture flow.
  Future<void> capture() async {
    if (state.captureStatus != CaptureStatus.idle) return;

    final captureParams = _buildCaptureParams();
    ref.read(consistencyDebugProvider.notifier).update(
          (state) => state.copyWith(lastExportParams: captureParams),
        );

    state = state.copyWith(
      captureStatus: CaptureStatus.capturing,
      errorMessage: null,
      lastCapturedPath: null,
    );

    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      state = state.copyWith(captureStatus: CaptureStatus.processing);

      final result = await _platformService.executeCapture(captureParams);
      final filePath = result['filePath'] as String?;

      state = state.copyWith(
        captureStatus: CaptureStatus.success,
        lastCapturedPath: filePath,
      );
    } on Object catch (e) {
      state = state.copyWith(
        captureStatus: CaptureStatus.error,
        errorMessage: e.toString(),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2)).then((_) {
          if (state.captureStatus == CaptureStatus.error) {
            state = state.copyWith(captureStatus: CaptureStatus.idle);
          }
        }),
      );
    }
  }

  Map<String, dynamic> _buildCaptureParams() {
    PresetModel? activePreset;
    final presets = ref.read(presetsProvider).valueOrNull;
    if (presets != null) {
      for (final preset in presets) {
        if (preset.id == state.activePresetId) {
          activePreset = preset;
          break;
        }
      }
    }

    final lut = activePreset?.lut;
    final lutPath = lut is String && lut.isNotEmpty ? lut : null;

    return <String, dynamic>{
      'temperature': activePreset?.color.temperature ?? 0.0,
      'saturation': activePreset?.color.saturation ?? 0.0,
      'contrast': activePreset?.color.contrast ?? 0.0,
      'grain': activePreset?.grain.intensity ?? 0.0,
      'vignette': activePreset?.vignette.intensity ?? 0.0,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
    };
  }

  /// Clears the transient success state once the result screen is dismissed.
  void acknowledgeResultDismissed() {
    if (state.captureStatus != CaptureStatus.success) {
      return;
    }
    state = state.copyWith(captureStatus: CaptureStatus.idle);
  }

  /// Releases native camera resources and resets initialization state.
  Future<void> releaseCamera() async {
    if (!state.isCameraInitialized) return;
    try {
      unawaited(_statusSubscription?.cancel());
      _statusSubscription = null;
      await _platformService.releaseCamera();
      state = state.copyWith(isCameraInitialized: false, currentFps: 0);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  FlashMode _getNextFlashMode(FlashMode current) {
    switch (current) {
      case FlashMode.off:
        return FlashMode.on;
      case FlashMode.on:
        return FlashMode.auto;
      case FlashMode.auto:
        return FlashMode.off;
    }
  }
}
