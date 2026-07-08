import 'dart:async';
import 'dart:math';

import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/utils/rana_texture_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_controller.g.dart';

@Riverpod(keepAlive: true)
class CameraController extends _$CameraController {
  late final CameraPlatformService _platformService;
  StreamSubscription<Map<String, dynamic>>? _statusSubscription;
  Timer? _selfTimerCountdown;
  int _selfTimerGeneration = 0;
  int? _currentPreviewVariant;
  PresetModel? _selectedPreset;
  Timer? _zoomDispatchTimer;
  double? _pendingZoomRatio;
  int _zoomGeneration = 0;
  static const _zoomDispatchInterval = Duration(milliseconds: 16);

  int _randomizeVariant() => Random().nextInt(4); // 0 to 3

  @override
  CameraState build() {
    _platformService = CameraPlatformService();

    ref.onDispose(() {
      unawaited(_statusSubscription?.cancel());
      _statusSubscription = null;
      _selfTimerGeneration += 1;
      _selfTimerCountdown?.cancel();
      _selfTimerCountdown = null;
      _zoomGeneration += 1;
      _zoomDispatchTimer?.cancel();
      _zoomDispatchTimer = null;
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

      state = _withZoomState(
        state.copyWith(
          isCameraInitialized: true,
          activeLens: initialLens,
          // ignore: avoid_redundant_argument_values
          errorMessage: null,
        ),
        result,
        fallbackZoomRatio: state.zoomRatio,
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

      try {
        final aspectRatioResult = await _platformService.setAspectRatio(
          state.aspectRatio.platformValue,
        );
        state = _withZoomState(
          state,
          aspectRatioResult,
          fallbackZoomRatio: state.zoomRatio,
        );
      } on Object catch (e) {
        state = state.copyWith(errorMessage: e.toString());
      }
      await reapplyActivePreviewParams();
    } on Object catch (e) {
      state = state.copyWith(
        isCameraInitialized: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cycles to the next flash mode (off -> on -> auto).
  Future<void> toggleFlashMode() async {
    if (state.isSelfTimerRunning) return;
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
    if (state.isSelfTimerRunning) return;
    try {
      final currentLensValue = state.activeLens.value;
      final result = await _platformService.toggleLens(currentLensValue);
      final nextLensValue = result['lens'] as String? ?? 'back';
      final nextLens = CameraLens.values.firstWhere(
        (l) => l.value == nextLensValue,
        orElse: () => CameraLens.back,
      );
      _pendingZoomRatio = userMinZoomRatio;
      _zoomDispatchTimer?.cancel();
      _zoomDispatchTimer = null;
      state = _withZoomState(
        state.copyWith(activeLens: nextLens, zoomRatio: userMinZoomRatio),
        result,
        fallbackZoomRatio: userMinZoomRatio,
      );
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Cycles to the next supported aspect ratio and syncs it to native.
  Future<void> cycleAspectRatio() async {
    await setAspectRatio(state.aspectRatio.next);
  }

  /// Updates the active aspect ratio for both Flutter and native preview.
  Future<void> setAspectRatio(CameraAspectRatio aspectRatio) async {
    if (state.isSelfTimerRunning) return;
    if (!state.isCameraInitialized) {
      state = state.copyWith(aspectRatio: aspectRatio);
      return;
    }

    try {
      final result = await _platformService.setAspectRatio(
        aspectRatio.platformValue,
      );
      state = _withZoomState(
        state.copyWith(aspectRatio: aspectRatio),
        result,
        fallbackZoomRatio: state.zoomRatio,
      );
      await reapplyActivePreviewParams();
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Selects active film preset on native rendering pipeline.
  Future<void> selectPreset(PresetModel preset) async {
    if (state.isSelfTimerRunning) return;
    try {
      final isNewPreset = state.activePresetId != preset.id;
      final effectiveStyle = _clampStyle(preset.style ?? const RanaStyle());
      final targetVariant = preset.effects.lightLeak.variant;
      if (targetVariant == -1) {
        if (isNewPreset || _currentPreviewVariant == null) {
          _currentPreviewVariant = _randomizeVariant();
        }
      } else {
        _currentPreviewVariant = targetVariant;
      }

      final paramsMap = _buildPreviewParams(preset, style: effectiveStyle);
      AppLogger.glParams('PREVIEW', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => GlParamsState(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(preset.id, paramsMap);
      _selectedPreset = preset;
      state = state.copyWith(
        activePresetId: preset.id,
        activeStyle: effectiveStyle,
      );
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Updates the active Rana Style and pushes it to the preview renderer.
  Future<void> updateActiveStyle(RanaStyle style) async {
    if (state.isSelfTimerRunning) return;
    final clampedStyle = _clampStyle(style);
    state = state.copyWith(activeStyle: clampedStyle);

    final activePreset = _activePreset();
    if (activePreset == null || !state.isCameraInitialized) {
      return;
    }

    try {
      final paramsMap = _buildPreviewParams(activePreset, style: clampedStyle);
      AppLogger.glParams('PREVIEW_STYLE_UPDATE', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(activePreset.id, paramsMap);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Re-sends the current active preset/style to the native preview renderer.
  Future<void> reapplyActivePreviewParams() async {
    if (state.isSelfTimerRunning) return;
    if (!state.isCameraInitialized) {
      return;
    }

    final activePreset = _activePreset();
    if (activePreset == null) {
      return;
    }

    try {
      final paramsMap = _buildPreviewParams(
        activePreset,
        style: state.activeStyle,
      );
      AppLogger.glParams('PREVIEW_REAPPLY', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(activePreset.id, paramsMap);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Resets the active Rana Style to the preset default, or neutral.
  Future<void> resetActiveStyle() async {
    if (state.isSelfTimerRunning) return;
    final activePreset = _activePreset();
    await updateActiveStyle(activePreset?.style ?? const RanaStyle());
  }

  /// Handles the shutter button, starting the timer when enabled.
  Future<void> handleShutterPressed() async {
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) return;

    if (!state.selfTimerMode.isEnabled) {
      await capture();
      return;
    }

    startSelfTimer(state.selfTimerMode);
  }

  /// Triggers film capture flow.
  Future<void> capture() async {
    if (state.captureStatus != CaptureStatus.idle || state.isSelfTimerRunning) {
      return;
    }

    cancelSelfTimer();

    final captureParams = _buildCaptureParams();
    final activePreviewParams = ref
        .read(consistencyDebugProvider)
        .lastPreviewParams;
    ref
        .read(consistencyDebugProvider.notifier)
        .update(
          (state) => GlParamsState(
            lastPreviewParams: state.lastPreviewParams,
            lastExportParams: captureParams,
            lastCapturedPreviewParams: activePreviewParams ?? captureParams,
          ),
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
      _randomizeNextVariantForPreview();
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

  /// Cycles the self-timer preset or cancels an active countdown.
  void cycleSelfTimer() {
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) {
      cancelSelfTimer();
      return;
    }

    final nextMode = state.selfTimerMode.next;
    state = state.copyWith(
      selfTimerMode: nextMode,
      selfTimerRemainingSeconds: 0,
    );
  }

  /// Cancels any active countdown without changing the selected mode.
  void cancelSelfTimer({bool clearMode = false}) {
    _selfTimerGeneration += 1;
    _selfTimerCountdown?.cancel();
    _selfTimerCountdown = null;

    state = state.copyWith(
      selfTimerMode: clearMode ? SelfTimerMode.off : state.selfTimerMode,
      selfTimerRemainingSeconds: 0,
    );
  }

  void startSelfTimer(SelfTimerMode mode) {
    if (!mode.isEnabled || state.captureStatus != CaptureStatus.idle) return;

    cancelSelfTimer();

    final totalSeconds = mode.seconds;
    final session = ++_selfTimerGeneration;
    state = state.copyWith(
      selfTimerMode: mode,
      selfTimerRemainingSeconds: totalSeconds,
    );

    _selfTimerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (session != _selfTimerGeneration) {
        timer.cancel();
        return;
      }

      if (!state.isCameraInitialized ||
          state.captureStatus != CaptureStatus.idle) {
        timer.cancel();
        _selfTimerCountdown = null;
        if (session == _selfTimerGeneration) {
          state = state.copyWith(selfTimerRemainingSeconds: 0);
        }
        return;
      }

      final nextRemaining = state.selfTimerRemainingSeconds - 1;
      if (nextRemaining > 0) {
        state = state.copyWith(selfTimerRemainingSeconds: nextRemaining);
        return;
      }

      timer.cancel();
      _selfTimerCountdown = null;
      if (session != _selfTimerGeneration) {
        return;
      }

      state = state.copyWith(selfTimerRemainingSeconds: 0);
      unawaited(capture());
    });
  }

  Map<String, dynamic> _buildCaptureParams() {
    final activePreset = _activePreset();
    final style = activePreset != null ? state.activeStyle : const RanaStyle();

    final lut = activePreset?.lut;
    final lutPath = lut is String && lut.isNotEmpty ? lut : null;

    final presetGrain = activePreset?.grain.intensity ?? 0.0;
    final presetDust = activePreset?.effects.dust.intensity ?? 0.0;
    final textureVal = style.texture;
    final styleStrength = style.styleStrength;

    final mapped = RanaTextureMapper.mapTexture(
      textureVal,
      presetGrain: presetGrain,
      presetDust: presetDust,
    );

    final blend = styleStrength / 100.0;
    final finalGrain =
        presetGrain * (1.0 - blend) + (mapped['grain'] ?? 0.0) * blend;
    final finalDust =
        presetDust * (1.0 - blend) + (mapped['dust'] ?? 0.0) * blend;
    final finalGrainSize =
        1.0 * (1.0 - blend) + (mapped['grainSize'] ?? 1.0) * blend;
    final finalSoftness =
        0.0 * (1.0 - blend) + (mapped['softness'] ?? 0.0) * blend;

    return <String, dynamic>{
      'temperature': activePreset?.color.temperature ?? 0.0,
      'saturation': activePreset?.color.saturation ?? 0.0,
      'contrast': activePreset?.color.contrast ?? 0.0,
      'grain': finalGrain,
      'vignette': activePreset?.vignette.intensity ?? 0.0,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': activePreset?.effects.lightLeak.intensity ?? 0.0,
      'lightLeakVariant': _currentPreviewVariant ?? -1,
      'dustIntensity': finalDust,
      'bloomThreshold': activePreset?.effects.bloom.threshold ?? 0.8,
      'bloomIntensity': activePreset?.effects.bloom.intensity ?? 0.0,
      'halationIntensity': activePreset?.effects.halation.intensity ?? 0.0,
      'lensDistortionStrength':
          activePreset?.effects.lensDistortion.strength ?? 0.0,
      'tone': style.tone,
      'color': style.color,
      'textureVal': textureVal,
      'styleStrength': styleStrength,
      'undertoneX': style.undertoneX,
      'undertoneY': style.undertoneY,
      'grainSize': finalGrainSize,
      'softness': finalSoftness,
    };
  }

  void _randomizeNextVariantForPreview() {
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
    if (activePreset == null) return;

    if (activePreset.effects.lightLeak.variant == -1) {
      _currentPreviewVariant = _randomizeVariant();
      final paramsMap = _buildPreviewParams(activePreset);

      AppLogger.glParams('PREVIEW_UPDATE_RANDOM', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      unawaited(_platformService.selectPreset(activePreset.id, paramsMap));
    }
  }

  Map<String, dynamic> _buildPreviewParams(
    PresetModel preset, {
    RanaStyle? style,
  }) {
    final effectiveStyle = style ?? state.activeStyle;
    final lutPath = preset.lut is String && (preset.lut as String).isNotEmpty
        ? preset.lut as String
        : null;

    final presetGrain = preset.grain.intensity;
    final presetDust = preset.effects.dust.intensity;
    final textureVal = effectiveStyle.texture;
    final styleStrength = effectiveStyle.styleStrength;

    final mapped = RanaTextureMapper.mapTexture(
      textureVal,
      presetGrain: presetGrain,
      presetDust: presetDust,
    );

    final blend = styleStrength / 100.0;
    final finalGrain =
        presetGrain * (1.0 - blend) + (mapped['grain'] ?? 0.0) * blend;
    final finalDust =
        presetDust * (1.0 - blend) + (mapped['dust'] ?? 0.0) * blend;
    final finalGrainSize =
        1.0 * (1.0 - blend) + (mapped['grainSize'] ?? 1.0) * blend;
    final finalSoftness =
        0.0 * (1.0 - blend) + (mapped['softness'] ?? 0.0) * blend;

    return <String, dynamic>{
      'temperature': preset.color.temperature,
      'contrast': preset.color.contrast,
      'saturation': preset.color.saturation,
      'grain': finalGrain,
      'vignette': preset.vignette.intensity,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': preset.effects.lightLeak.intensity,
      'lightLeakVariant': _currentPreviewVariant ?? -1,
      'dustIntensity': finalDust,
      'bloomThreshold': preset.effects.bloom.threshold,
      'bloomIntensity': preset.effects.bloom.intensity,
      'halationIntensity': preset.effects.halation.intensity,
      'lensDistortionStrength': preset.effects.lensDistortion.strength,
      'tone': effectiveStyle.tone,
      'color': effectiveStyle.color,
      'textureVal': textureVal,
      'styleStrength': styleStrength,
      'undertoneX': effectiveStyle.undertoneX,
      'undertoneY': effectiveStyle.undertoneY,
      'grainSize': finalGrainSize,
      'softness': finalSoftness,
    };
  }

  PresetModel? _activePreset() {
    final selectedPreset = _selectedPreset;
    if (selectedPreset != null && selectedPreset.id == state.activePresetId) {
      return selectedPreset;
    }

    final presets = ref.read(presetsProvider).valueOrNull;
    if (presets == null) {
      return null;
    }

    for (final preset in presets) {
      if (preset.id == state.activePresetId) {
        _selectedPreset = preset;
        return preset;
      }
    }
    return null;
  }

  RanaStyle _clampStyle(RanaStyle style) => RanaStyle(
    tone: style.tone.clamp(-100.0, 100.0),
    color: style.color.clamp(-100.0, 100.0),
    texture: style.texture.clamp(0.0, 100.0),
    styleStrength: style.styleStrength.clamp(0.0, 100.0),
    undertoneX: style.undertoneX.clamp(-1.0, 1.0),
    undertoneY: style.undertoneY.clamp(-1.0, 1.0),
  );

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
      cancelSelfTimer();
      _zoomGeneration += 1;
      _zoomDispatchTimer?.cancel();
      _zoomDispatchTimer = null;
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

  /// Sets native camera zoom, clamped to Rana's 1x-3x user-facing range.
  Future<void> setZoomRatio(double zoomRatio, {bool commit = true}) async {
    if (!_canAdjustZoom) return;

    final targetZoomRatio = _clampZoomRatio(zoomRatio);
    _pendingZoomRatio = targetZoomRatio;
    if ((state.zoomRatio - targetZoomRatio).abs() > 0.001) {
      state = state.copyWith(
        zoomRatio: targetZoomRatio,
        // ignore: avoid_redundant_argument_values
        errorMessage: null,
      );
    }

    if (commit) {
      _zoomDispatchTimer?.cancel();
      _zoomDispatchTimer = null;
      await _sendZoomRatio(targetZoomRatio);
      return;
    }

    _scheduleZoomDispatch();
  }

  /// Flushes a pending pinch zoom update immediately.
  Future<void> commitZoomRatio() async {
    if (!_canAdjustZoom) return;
    final targetZoomRatio = _pendingZoomRatio ?? state.zoomRatio;
    _zoomDispatchTimer?.cancel();
    _zoomDispatchTimer = null;
    await _sendZoomRatio(targetZoomRatio);
  }

  bool get _canAdjustZoom =>
      state.isCameraInitialized &&
      state.captureStatus == CaptureStatus.idle &&
      !state.isSelfTimerRunning;

  void _scheduleZoomDispatch() {
    if (_zoomDispatchTimer != null) return;
    _zoomDispatchTimer = Timer(_zoomDispatchInterval, () {
      _zoomDispatchTimer = null;
      final targetZoomRatio = _pendingZoomRatio;
      if (targetZoomRatio == null || !_canAdjustZoom) {
        return;
      }
      unawaited(_sendZoomRatio(targetZoomRatio));
    });
  }

  Future<void> _sendZoomRatio(double zoomRatio) async {
    final generation = ++_zoomGeneration;
    try {
      final result = await _platformService.setZoomRatio(zoomRatio);
      if (generation != _zoomGeneration) return;
      state = _withZoomState(state, result, fallbackZoomRatio: zoomRatio);
    } on Object catch (e) {
      if (generation != _zoomGeneration) return;
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  CameraState _withZoomState(
    CameraState baseState,
    Map<String, dynamic> result, {
    double? fallbackZoomRatio,
  }) {
    final minZoomRatio = _readDouble(
      result,
      'minZoomRatio',
      baseState.minZoomRatio,
    );
    final maxZoomRatio = _readDouble(
      result,
      'maxZoomRatio',
      baseState.maxZoomRatio,
    );
    final zoomRatio = _clampZoomRatio(
      _readDouble(
        result,
        'zoomRatio',
        fallbackZoomRatio ?? baseState.zoomRatio,
      ),
      minZoomRatio: minZoomRatio,
      maxZoomRatio: maxZoomRatio,
    );

    return baseState.copyWith(
      zoomRatio: zoomRatio,
      minZoomRatio: minZoomRatio,
      maxZoomRatio: maxZoomRatio,
    );
  }

  double _readDouble(Map<String, dynamic> result, String key, double fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  double _clampZoomRatio(
    double zoomRatio, {
    double? minZoomRatio,
    double? maxZoomRatio,
  }) {
    final lowerBound = max(
      userMinZoomRatio,
      minZoomRatio ?? state.minZoomRatio,
    );
    final nativeUpperBound = maxZoomRatio ?? state.maxZoomRatio;
    final upperBound = max(lowerBound, min(userMaxZoomRatio, nativeUpperBound));
    if (!zoomRatio.isFinite) return lowerBound;
    return zoomRatio.clamp(lowerBound, upperBound);
  }

  /// Sets focus and metering point coordinates (normalized 0.0 to 1.0)
  Future<void> setFocusAndMetering(double x, double y) async {
    if (!state.isCameraInitialized) return;
    try {
      await _platformService.setFocusAndMetering(x, y);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Cancels focus and metering lock, returning to continuous auto focus
  Future<void> cancelFocusAndMetering() async {
    if (!state.isCameraInitialized) return;
    try {
      await _platformService.cancelFocusAndMetering();
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
