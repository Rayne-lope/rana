import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';
import 'package:rana/src/features/camera/controller/camera_lifecycle_controller.dart';
import 'package:rana/src/features/camera/controller/camera_recipe_queue.dart';
import 'package:rana/src/features/camera/controller/camera_timer_controller.dart';
import 'package:rana/src/features/camera/controller/camera_zoom_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_controller.g.dart';

/// UI-facing camera facade. Stateful workflows live in composed helpers.
@Riverpod(keepAlive: true)
class CameraController extends _$CameraController {
  late final CameraPlatformService _platformService;
  late final CameraLifecycleController _lifecycleController;
  late final CameraTimerController _timerController;
  late final CameraZoomController _zoomController;
  late final CameraRecipeQueue _recipeQueue;

  @override
  CameraState build() {
    _platformService = CameraPlatformService();
    _zoomController = CameraZoomController(
      platformService: _platformService,
      readState: () => state,
      writeState: (nextState) => state = nextState,
    );
    _recipeQueue = CameraRecipeQueue(
      ref: ref,
      platformService: _platformService,
      readState: () => state,
      writeState: (nextState) => state = nextState,
      readLifecycleGeneration: () => _lifecycleController.generation,
      cancelSelfTimer: ({clearMode = false}) {
        _timerController.cancel(clearMode: clearMode);
      },
      mergeNativeZoomState: _zoomController.mergeNativeZoomState,
    );
    _timerController = CameraTimerController(
      readState: () => state,
      writeState: (nextState) => state = nextState,
      captureBlockReason: _recipeQueue.captureBlockReason,
      capture: capture,
    );
    _lifecycleController = CameraLifecycleController(
      platformService: _platformService,
      readState: () => state,
      writeState: (nextState) => state = nextState,
      applyInitializeResult: _applyInitializeResult,
      configureInitializedCamera: _recipeQueue.configureInitializedCamera,
      handleStatusEvent: _recipeQueue.handleStatusEvent,
      prepareRelease: _prepareRelease,
      hasCaptureWork: () => _recipeQueue.hasCaptureWork,
    );

    ref.onDispose(() {
      _lifecycleController.dispose();
      _timerController.dispose();
      _zoomController.dispose();
    });

    return CameraState.initial();
  }

  /// Triggers asynchronous native initialization and status listening.
  Future<void> initialize() => _lifecycleController.initialize();

  /// Registers the active Android PlatformView before native initialization.
  void registerPlatformView(int platformViewId) {
    _platformService.registerPlatformView(
      CameraPreviewRegistration(
        platformViewId: platformViewId,
        aspectRatio: state.aspectRatio.platformValue,
        lens: state.activeLens.value,
        flashMode: state.flashMode.name,
        zoomRatio: state.zoomRatio,
      ),
    );
  }

  /// Cycles to the next flash mode (off -> on -> auto).
  Future<void> toggleFlashMode() async {
    if (state.isSelfTimerRunning) return;
    final nextFlash = _getNextFlashMode(state.flashMode);
    try {
      await _platformService.setFlashMode(nextFlash.name);
      state = state.copyWith(flashMode: nextFlash);
    } on Object catch (error) {
      state = state.copyWith(failure: CameraFailure.fromError(error));
    }
  }

  /// Toggles front and back camera lenses.
  Future<void> toggleLens() async {
    if (state.isSelfTimerRunning) return;
    try {
      final result = await _platformService.toggleLens(state.activeLens.value);
      final nextLensValue = result['lens'] as String? ?? 'back';
      final nextLens = CameraLens.values.firstWhere(
        (lens) => lens.value == nextLensValue,
        orElse: () => CameraLens.back,
      );
      _zoomController.resetPendingRatio(userMinZoomRatio);
      state = _zoomController.mergeNativeZoomState(
        state.copyWith(activeLens: nextLens, zoomRatio: userMinZoomRatio),
        result,
        fallbackZoomRatio: userMinZoomRatio,
      );
    } on Object catch (error) {
      state = state.copyWith(
        failure: CameraFailure.fromError(
          error,
          fallbackCode: CameraFailureCode.lensSwitchTimeout,
        ),
      );
    }
  }

  Future<void> cycleAspectRatio() => _recipeQueue.cycleAspectRatio();

  Future<void> setAspectRatio(CameraAspectRatio aspectRatio) =>
      _recipeQueue.setAspectRatio(aspectRatio);

  Future<void> selectPreset(PresetModel preset) =>
      _recipeQueue.selectPreset(preset);

  Future<void> updateActiveStyle(RanaStyle style) =>
      _recipeQueue.updateActiveStyle(style);

  Future<void> applyStyleMood(RanaStyleMood mood) =>
      _recipeQueue.applyStyleMood(mood);

  Future<void> reapplyActivePreviewParams() =>
      _recipeQueue.reapplyActivePreviewParams();

  Future<void> resetActiveStyle() => _recipeQueue.resetActiveStyle();

  Future<FilmRollActionResult> startFilmRoll(FilmRollSize size) =>
      _recipeQueue.startFilmRoll(size);

  Future<FilmRollActionResult> retryActiveFilmRollRecipe() =>
      _recipeQueue.retryActiveFilmRollRecipe();

  Future<FilmRollActionResult> retryActiveFilmRollSave() =>
      _recipeQueue.retryActiveFilmRollSave();

  Future<FilmRollActionResult> endFilmRoll(String expectedRollId) =>
      _recipeQueue.endFilmRoll(expectedRollId);

  Future<FilmRollActionResult> abandonFilmRoll(String expectedRollId) =>
      _recipeQueue.abandonFilmRoll(expectedRollId);

  /// Handles the shutter button, starting the timer when enabled.
  Future<void> handleShutterPressed() async {
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) return;

    final blockReason = _recipeQueue.captureBlockReason();
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
      return;
    }

    if (!state.selfTimerMode.isEnabled) {
      await capture();
      return;
    }
    startSelfTimer(state.selfTimerMode);
  }

  Future<void> capture() => _recipeQueue.capture();

  void cycleSelfTimer() => _timerController.cycle();

  void cancelSelfTimer({bool clearMode = false}) {
    _timerController.cancel(clearMode: clearMode);
  }

  void startSelfTimer(SelfTimerMode mode) => _timerController.start(mode);

  /// Clears legacy result metadata after a direct ResultScreen visit.
  void acknowledgeResultDismissed() {
    if (state.completedCaptureId == null) return;
    state = state.copyWith(
      completedCaptureId: null,
      captureError: null,
      captureElapsedMs: 0,
    );
  }

  /// Releases native camera resources and resets initialization state.
  Future<void> releaseCamera() => _lifecycleController.releaseCamera();

  Future<void> setZoomRatio(double zoomRatio, {bool commit = true}) =>
      _zoomController.setZoomRatio(zoomRatio, commit: commit);

  Future<void> commitZoomRatio() => _zoomController.commitZoomRatio();

  /// Sets focus and metering coordinates normalized from 0.0 to 1.0.
  Future<void> setFocusAndMetering(double x, double y) async {
    if (!state.isCameraInitialized) return;
    try {
      await _platformService.setFocusAndMetering(x, y);
    } on Object catch (error) {
      state = state.copyWith(failure: CameraFailure.fromError(error));
    }
  }

  /// Cancels focus and metering lock and restores continuous auto focus.
  Future<void> cancelFocusAndMetering() async {
    if (!state.isCameraInitialized) return;
    try {
      await _platformService.cancelFocusAndMetering();
    } on Object catch (error) {
      state = state.copyWith(failure: CameraFailure.fromError(error));
    }
  }

  /// Clears a presented structured failure without changing camera state.
  void clearFailure() {
    state = state.copyWith(failure: null);
  }

  /// Executes recovery actions that can be completed inside the camera route.
  Future<void> recoverFromFailure() async {
    final failure = state.failure;
    if (failure == null || !failure.isRecoverable) return;
    state = state.copyWith(failure: null);
    switch (failure.recoveryAction) {
      case CameraRecoveryAction.retry:
        if (state.isCameraInitialized) {
          await reapplyActivePreviewParams();
        } else {
          await initialize();
        }
      case CameraRecoveryAction.reinitialize:
      case CameraRecoveryAction.fallbackLens:
        _zoomController.resetPendingRatio(userMinZoomRatio);
        await releaseCamera();
        await initialize();
      case CameraRecoveryAction.none:
      case CameraRecoveryAction.openSettings:
      case CameraRecoveryAction.freeStorage:
        return;
    }
  }

  void _applyInitializeResult(Map<String, dynamic> result) {
    final initialLensValue = result['lens'] as String? ?? 'back';
    final initialLens = CameraLens.values.firstWhere(
      (lens) => lens.value == initialLensValue,
      orElse: () => CameraLens.back,
    );
    state = _zoomController.mergeNativeZoomState(
      state.copyWith(
        isCameraInitialized: true,
        activeLens: initialLens,
        // ignore: avoid_redundant_argument_values
        errorMessage: null,
      ),
      result,
      fallbackZoomRatio: state.zoomRatio,
    );
  }

  void _prepareRelease() {
    _recipeQueue.prepareRelease();
    _timerController.cancel();
    _zoomController.cancelPending();
  }

  FlashMode _getNextFlashMode(FlashMode current) => switch (current) {
    FlashMode.off => FlashMode.on,
    FlashMode.on => FlashMode.auto,
    FlashMode.auto => FlashMode.off,
  };
}
