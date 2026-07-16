import 'dart:async';
import 'dart:math';

import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';
import 'package:rana/features/preset/utils/rana_texture_mapper.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_controller.g.dart';

/// The verified recipe used for a single Film Roll capture.
///
/// Capture parameters are built from this immutable pair rather than from
/// mutable camera state, so a delayed UI/native mutation can never make a
/// saved Film Roll frame use a different preset or style.
class _LockedCaptureRecipe {
  const _LockedCaptureRecipe({required this.preset, required this.style});

  final PresetModel preset;
  final RanaStyle style;
}

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
  int _cameraLifecycleGeneration = 0;
  Future<void>? _initializationFuture;
  Future<void>? _releaseFuture;
  Future<void> _recipeQueue = Future<void>.value();
  final Set<String> _pendingCaptureIds = <String>{};
  final Map<String, FilmRollExposureReservation> _rollReservations =
      <String, FilmRollExposureReservation>{};
  final Set<String> _earlyTerminalCaptureIds = <String>{};
  FilmRollExposureReservation? _acquiringRollReservation;
  String? _acquiringCaptureId;
  bool _awaitingNativeCaptureAcceptance = false;
  bool _filmRollReconciliationRequired = false;
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
      // Accepted captures may still publish a terminal native event while the
      // app is backgrounded. Keep their association until reconciliation or a
      // terminal event clears it; dropping it here can strand a Film Roll
      // reservation forever.
      _cameraLifecycleGeneration += 1;
    });

    return CameraState.initial();
  }

  /// Triggers asynchronous native initialization and listens to status updates
  /// (FPS).
  Future<void> initialize() {
    // A fast resume can arrive while Android is still releasing the preview.
    // Chain a fresh initialization behind that release instead of returning
    // early from the stale `isCameraInitialized` value.
    final releaseInFlight = _releaseFuture;
    if (releaseInFlight != null) {
      final initializationInFlight = _initializationFuture;
      if (initializationInFlight != null) return initializationInFlight;
      return _trackInitialization(_initializeAfterRelease(releaseInFlight));
    }
    if (state.isCameraInitialized) return Future<void>.value();
    final initializationInFlight = _initializationFuture;
    if (initializationInFlight != null) return initializationInFlight;

    return _trackInitialization(_initializeCamera());
  }

  Future<void> _trackInitialization(Future<void> initialization) {
    _initializationFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeAfterRelease(Future<void> release) async {
    await release;
    if (state.isCameraInitialized) return;
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final lifecycleGeneration = ++_cameraLifecycleGeneration;
    try {
      final result = await _platformService.initializeCamera();
      if (lifecycleGeneration != _cameraLifecycleGeneration) {
        // Release an initialization that lost a race with backgrounding.
        unawaited(_platformService.releaseCamera());
        return;
      }
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

      // Keep this subscription across pause/release. Native encoding can
      // complete after the preview is released, and those terminal events are
      // needed to release or commit the matching Film Roll reservation.
      _statusSubscription ??= _platformService.statusStream.listen(
        _handleStatusEvent,
        onError: (Object err) {
          state = state.copyWith(errorMessage: err.toString());
        },
      );

      final restoredRollApplied = await _restoreActiveRollConfiguration();
      if (lifecycleGeneration != _cameraLifecycleGeneration) return;
      if (!restoredRollApplied) {
        await _queueRecipe(() async {
          if (lifecycleGeneration != _cameraLifecycleGeneration) return;
          final aspectRatioResult = await _platformService.setAspectRatio(
            state.aspectRatio.platformValue,
          );
          if (lifecycleGeneration != _cameraLifecycleGeneration) return;
          state = _withZoomState(
            state,
            aspectRatioResult,
            fallbackZoomRatio: state.zoomRatio,
          );
          await _reapplyActivePreviewParamsInternal();
        });
      }
    } on Object catch (e) {
      if (lifecycleGeneration != _cameraLifecycleGeneration) return;
      state = state.copyWith(
        isCameraInitialized: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Serializes mutations which can change the camera recipe.
  ///
  /// Film Roll start and restoration run through the same queue so a late
  /// native response from a preset/style/aspect control cannot overwrite the
  /// recipe snapshot that was just locked into a roll.
  Future<T> _queueRecipe<T>(Future<T> Function() operation) {
    final next = _recipeQueue.then<T>(
      (_) => operation(),
      onError: (Object error, StackTrace stackTrace) => operation(),
    );
    _recipeQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
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
  Future<void> cycleAspectRatio() => _queueRecipe(() async {
    if (state.isSelfTimerRunning || _blockWhenRollLocked('aspect ratio')) {
      return;
    }
    await _setAspectRatioInternal(state.aspectRatio.next);
  });

  /// Updates the active aspect ratio for both Flutter and native preview.
  Future<void> setAspectRatio(CameraAspectRatio aspectRatio) =>
      _queueRecipe(() async {
        if (state.isSelfTimerRunning || _blockWhenRollLocked('aspect ratio')) {
          return;
        }
        await _setAspectRatioInternal(aspectRatio);
      });

  Future<void> _setAspectRatioInternal(CameraAspectRatio aspectRatio) async {
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
      await _reapplyActivePreviewParamsInternal();
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Selects active film preset on native rendering pipeline.
  ///
  /// Blocked when a Film Roll is active — the preset is locked for the
  /// duration of the roll. The caller should surface an error to the user.
  Future<void> selectPreset(PresetModel preset) => _queueRecipe(() async {
    if (state.isSelfTimerRunning || _blockWhenRollLocked('preset')) return;
    await _applyPreset(preset, style: preset.style ?? const RanaStyle());
  });

  Future<bool> _applyPreset(
    PresetModel preset, {
    required RanaStyle style,
  }) async {
    try {
      final isNewPreset = state.activePresetId != preset.id;
      final effectiveStyle = _clampStyle(style);
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
      return true;
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Updates the active Rana Style and pushes it to the preview renderer.
  Future<void> updateActiveStyle(RanaStyle style) => _queueRecipe(() async {
    if (state.isSelfTimerRunning || _blockWhenRollLocked('style')) return;
    await _updateActiveStyleInternal(style);
  });

  Future<void> _updateActiveStyleInternal(RanaStyle style) async {
    final clampedStyle = _clampStyle(style);
    final activePreset = _activePreset();
    if (activePreset == null || !state.isCameraInitialized) {
      state = state.copyWith(activeStyle: clampedStyle);
      return;
    }

    try {
      final paramsMap = _buildPreviewParams(activePreset, style: clampedStyle);
      AppLogger.glParams('PREVIEW_STYLE_UPDATE', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(activePreset.id, paramsMap);
      state = state.copyWith(activeStyle: clampedStyle);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Applies a quick preset-aware Mood on top of the selected preset style.
  Future<void> applyStyleMood(RanaStyleMood mood) => _queueRecipe(() async {
    if (state.isSelfTimerRunning || _blockWhenRollLocked('style')) return;
    final activePreset = _activePreset();
    if (activePreset == null) {
      return;
    }
    await _updateActiveStyleInternal(mood.resolve(activePreset));
  });

  /// Re-sends the current active preset/style to the native preview renderer.
  Future<void> reapplyActivePreviewParams() =>
      _queueRecipe(_reapplyActivePreviewParamsInternal);

  Future<void> _reapplyActivePreviewParamsInternal() async {
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
  Future<void> resetActiveStyle() => _queueRecipe(() async {
    if (state.isSelfTimerRunning || _blockWhenRollLocked('style')) return;
    final activePreset = _activePreset();
    await _updateActiveStyleInternal(activePreset?.style ?? const RanaStyle());
  });

  /// Atomically locks the recipe currently visible in the camera into a new
  /// Film Roll. Recipe mutations and roll creation share [_recipeQueue], so a
  /// late preset/style/aspect update cannot become part of the wrong roll.
  Future<FilmRollActionResult> startFilmRoll(FilmRollSize size) => _queueRecipe(
    () async {
      if (!state.isCameraInitialized) {
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.lifecycleBusy,
          'Camera is still starting. Try again in a moment.',
        );
      }
      if (_hasCameraLifecycleWork) {
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.lifecycleBusy,
          'Wait for the current capture or timer before starting a roll.',
        );
      }

      var preset = _activePreset();
      if (preset == null) {
        final presets = await ref.read(presetsProvider.future);
        for (final candidate in presets) {
          if (candidate.id == state.activePresetId) {
            preset = candidate;
            break;
          }
        }
      }
      if (preset == null) {
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.recipeUnavailable,
          'The current recipe is unavailable. Choose a preset and try again.',
        );
      }

      // Snapshot only after every previously requested recipe mutation has
      // completed. `RanaStyle` is immutable, so this remains the exact
      // recipe even if UI code later creates a new style value.
      final lockedStyle = state.activeStyle;
      final lockedAspectRatio = state.aspectRatio;
      final filmRollController = ref.read(filmRollControllerProvider.notifier);
      final result = await filmRollController.startRoll(
        presetId: preset.id,
        lockedStyle: lockedStyle,
        size: size,
        aspectRatioPlatformValue: lockedAspectRatio.platformValue,
      );
      if (!result.succeeded || result.roll == null) return result;

      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.restoring,
        errorMessage: null,
      );
      filmRollController.setActiveRecipeStatus(
        FilmRollRecipeStatus.applying,
        expectedRollId: result.roll!.id,
      );

      final applied = await _applyLockedRollRecipe(result.roll!);
      if (!applied) {
        const message =
            'The locked Film Roll recipe could not be applied. Retry the '
            'recipe, end the roll, or abandon it.';
        filmRollController.setActiveRecipeStatus(
          FilmRollRecipeStatus.unavailable,
          expectedRollId: result.roll!.id,
          message: message,
        );
        state = state.copyWith(
          activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
          errorMessage: message,
        );
        return FilmRollActionResult.failed(
          FilmRollActionFailure.recipeUnavailable,
          'The roll was started, but its locked recipe could not be applied.',
          roll: result.roll,
        );
      }
      filmRollController.setActiveRecipeStatus(
        FilmRollRecipeStatus.ready,
        expectedRollId: result.roll!.id,
      );
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.ready,
        errorMessage: null,
      );
      return result;
    },
  );

  /// Re-applies an active roll's persisted recipe without falling back to a
  /// different preset, aspect ratio, or style.
  Future<FilmRollActionResult> retryActiveFilmRollRecipe() => _queueRecipe(
    () async {
      final rollState = ref.read(filmRollControllerProvider);
      final roll = rollState.activeRoll;
      if (roll == null || !roll.isActive) {
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.noActiveRoll,
          'There is no active Film Roll to recover.',
        );
      }
      if (_hasCameraCaptureWork) {
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.lifecycleBusy,
          'Wait for the current capture to finish before retrying the recipe.',
        );
      }
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.restoring,
        errorMessage: null,
      );
      final controller = ref.read(filmRollControllerProvider.notifier);
      controller.setActiveRecipeStatus(
        FilmRollRecipeStatus.applying,
        expectedRollId: roll.id,
      );
      final applied = await _applyLockedRollRecipe(roll);
      if (!applied) {
        const message =
            'The locked Film Roll recipe is still unavailable. Retry it, end '
            'the roll, or abandon it.';
        controller.setActiveRecipeStatus(
          FilmRollRecipeStatus.unavailable,
          expectedRollId: roll.id,
          message: message,
        );
        state = state.copyWith(
          activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
          errorMessage: message,
        );
        return const FilmRollActionResult.failed(
          FilmRollActionFailure.recipeUnavailable,
          message,
        );
      }
      controller.setActiveRecipeStatus(
        FilmRollRecipeStatus.ready,
        expectedRollId: roll.id,
      );
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.ready,
        errorMessage: null,
      );
      final reconciliation = await _reconcileActiveFilmRoll(roll.id);
      return reconciliation ?? FilmRollActionResult.success(roll: roll);
    },
  );

  /// Retries the durable save which is holding a Film Roll capacity slot.
  Future<FilmRollActionResult> retryActiveFilmRollSave() async {
    if (_hasCameraCaptureWork || state.isSelfTimerRunning) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.lifecycleBusy,
        'Wait for the current capture or timer before retrying the save.',
      );
    }
    final result = await ref
        .read(filmRollControllerProvider.notifier)
        .retryPendingSave();
    if (result.succeeded && !result.isDuplicate && result.roll != null) {
      await _reconcileFilmRollAfterCaptureSettles(result.roll!.id);
    }
    return result;
  }

  /// Archives an active roll after all capture and persistence work is idle.
  Future<FilmRollActionResult> endFilmRoll(String expectedRollId) =>
      _queueRecipe(() async {
        final blocked = _filmRollEndActionBlocked();
        if (blocked != null) return blocked;
        final result = await ref
            .read(filmRollControllerProvider.notifier)
            .endRoll(expectedRollId: expectedRollId);
        if (result.succeeded) {
          _filmRollReconciliationRequired = false;
          state = state.copyWith(
            activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.notRequired,
          );
        }
        return result;
      });

  /// Removes only an active roll grouping after all capture work is idle.
  Future<FilmRollActionResult> abandonFilmRoll(String expectedRollId) =>
      _queueRecipe(() async {
        final blocked = _filmRollEndActionBlocked();
        if (blocked != null) return blocked;
        final result = await ref
            .read(filmRollControllerProvider.notifier)
            .abandonRoll(expectedRollId: expectedRollId);
        if (result.succeeded) {
          _filmRollReconciliationRequired = false;
          state = state.copyWith(
            activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.notRequired,
          );
        }
        return result;
      });

  bool get _hasCameraCaptureWork =>
      _awaitingNativeCaptureAcceptance ||
      _acquiringRollReservation != null ||
      _pendingCaptureIds.isNotEmpty ||
      _rollReservations.isNotEmpty;

  bool get _hasCameraLifecycleWork =>
      _hasCameraCaptureWork || state.isSelfTimerRunning;

  FilmRollActionResult? _filmRollEndActionBlocked() {
    final rollState = ref.read(filmRollControllerProvider);
    if (_hasCameraLifecycleWork || rollState.pendingExposureCount > 0) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.lifecycleBusy,
        'Wait for the timer, capture, and saved frame processing to finish.',
      );
    }
    if (rollState.hasPendingSaveRecovery) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.recoveryRequired,
        'Recover the pending Film Roll save before changing the roll.',
      );
    }
    // A missing/failed recipe deliberately permits End and Abandon. It is a
    // safe terminal path even when reconciliation cannot be retried; capture
    // and persistence recovery states remain blocked above.
    if (rollState.recipeStatus != FilmRollRecipeStatus.unavailable &&
        (rollState.reconciliationRequired || _filmRollReconciliationRequired)) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.recoveryRequired,
        'Recover Film Roll captures before changing the roll.',
      );
    }
    return null;
  }

  /// Handles the shutter button, starting the timer when enabled.
  Future<void> handleShutterPressed() async {
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) return;

    final blockReason = _captureBlockReason();
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

  /// Triggers film capture flow.
  Future<void> capture() async {
    if (state.captureStatus != CaptureStatus.idle || state.isSelfTimerRunning) {
      return;
    }

    final filmRollController = ref.read(filmRollControllerProvider.notifier);
    final rollState = ref.read(filmRollControllerProvider);
    final blockReason = _captureBlockReason();
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
      return;
    }

    _LockedCaptureRecipe? lockedRecipe;
    if (rollState.hasActiveRoll) {
      lockedRecipe = _verifiedLockedCaptureRecipe(rollState.activeRoll!);
      if (lockedRecipe == null) return;
    }

    FilmRollExposureReservation? reservation;
    if (rollState.hasActiveRoll) {
      final reserveResult = filmRollController.tryReserveExposure();
      if (!reserveResult.succeeded) {
        state = state.copyWith(
          errorMessage:
              reserveResult.message ?? 'The Film Roll cannot accept a frame.',
        );
        return;
      }
      reservation = reserveResult.reservation;
      if (reservation == null) {
        state = state.copyWith(
          errorMessage: 'The Film Roll cannot accept a frame.',
        );
        return;
      }
    }

    cancelSelfTimer();
    final startedAt = DateTime.now();
    final captureLifecycleGeneration = _cameraLifecycleGeneration;
    _acquiringRollReservation = reservation;
    _acquiringCaptureId = null;
    _awaitingNativeCaptureAcceptance = true;
    AppLogger.i('RanaCaptureTimeline', 'event=shutter_tap elapsedMs=0');

    final captureParams = _buildCaptureParams(
      filmRollId: reservation?.filmRollId,
      presetOverride: lockedRecipe?.preset,
      styleOverride: lockedRecipe?.style,
    );
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
      captureError: null,
      completedCaptureId: null,
      captureElapsedMs: 0,
      lastCaptureOutput: null,
    );

    try {
      final result = await _platformService.beginCapture(captureParams);
      final captureId = result['captureId'] as String?;
      if (captureId == null || captureId.isEmpty) {
        throw StateError('Native capture did not return a captureId');
      }
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.i(
        'RanaCaptureTimeline',
        'captureId=$captureId event=native_accepted elapsedMs=$elapsedMs',
      );
      final completedBeforeAcceptance = _earlyTerminalCaptureIds.remove(
        captureId,
      );
      _awaitingNativeCaptureAcceptance = false;
      if (!completedBeforeAcceptance) {
        _pendingCaptureIds.add(captureId);
        if (reservation != null) {
          _rollReservations[captureId] = reservation;
        }
      }
      if (_acquiringRollReservation == reservation) {
        _acquiringRollReservation = null;
      }
      _acquiringCaptureId = completedBeforeAcceptance ? null : captureId;
      if (captureLifecycleGeneration == _cameraLifecycleGeneration) {
        state = state.copyWith(
          captureStatus: completedBeforeAcceptance
              ? CaptureStatus.idle
              : CaptureStatus.capturing,
          activeCaptureId: completedBeforeAcceptance ? null : captureId,
          captureElapsedMs: elapsedMs,
        );
      }
    } on Object catch (e) {
      _awaitingNativeCaptureAcceptance = false;
      if (_acquiringRollReservation == reservation) {
        _acquiringRollReservation = null;
        if (reservation != null) {
          unawaited(_releaseFilmRollExposure(reservation));
        }
      }
      if (captureLifecycleGeneration != _cameraLifecycleGeneration) {
        if (!_hasCameraCaptureWork) {
          state = state.copyWith(
            captureStatus: CaptureStatus.idle,
            activeCaptureId: null,
          );
        }
        return;
      }
      state = state.copyWith(
        captureStatus: CaptureStatus.idle,
        captureError: e.toString(),
        errorMessage: e.toString(),
      );
    }
  }

  String? _captureBlockReason() {
    if (!state.isCameraInitialized) {
      return 'Camera is still starting. Try again in a moment.';
    }
    final rollState = ref.read(filmRollControllerProvider);
    // A persisted roll can be discovered after the native preview starts.
    // Do not allow an unassociated "normal" frame during that window, and
    // never fall back to a different recipe if restoration itself failed.
    if (rollState.restorationStatus == FilmRollRestorationStatus.restoring) {
      return 'Film Roll restoration is still in progress.';
    }
    if (rollState.restorationStatus == FilmRollRestorationStatus.failed) {
      return 'Film Roll restoration failed. Reopen the camera before shooting.';
    }
    if (!rollState.hasActiveRoll) return null;
    if (rollState.recipeStatus == FilmRollRecipeStatus.unavailable ||
        state.activeFilmRollRecipeStatus ==
            ActiveFilmRollRecipeStatus.unavailable) {
      return 'The locked Film Roll recipe is unavailable. Retry it, end the '
          'roll, or abandon it.';
    }
    if (rollState.recipeStatus == FilmRollRecipeStatus.applying ||
        state.activeFilmRollRecipeStatus ==
            ActiveFilmRollRecipeStatus.restoring) {
      return 'The locked Film Roll recipe is still restoring.';
    }
    if (rollState.reconciliationRequired || _filmRollReconciliationRequired) {
      return 'Film Roll captures are being recovered. Try again in a moment.';
    }
    if (rollState.hasPendingSaveRecovery) {
      return 'A Film Roll frame needs to be saved. Retry that save before '
          'shooting.';
    }
    if (rollState.cannotReserveExposure) {
      final roll = rollState.activeRoll!;
      return 'Roll complete — '
          '${roll.exposuresTaken + rollState.pendingExposureCount}/'
          '${roll.size.count} frames are already reserved.';
    }
    return null;
  }

  _LockedCaptureRecipe? _verifiedLockedCaptureRecipe(FilmRoll roll) {
    final expectedAspectRatio = CameraAspectRatio.values.where(
      (ratio) => ratio.platformValue == roll.aspectRatioPlatformValue,
    );
    final expectedAspect = expectedAspectRatio.isEmpty
        ? null
        : expectedAspectRatio.first;
    final preset = _activePreset();
    if (expectedAspect == null ||
        preset == null ||
        preset.id != roll.presetId ||
        state.activePresetId != roll.presetId ||
        state.activeStyle != roll.lockedStyle ||
        state.aspectRatio != expectedAspect) {
      const message =
          'The locked Film Roll recipe no longer matches the camera. Retry '
          'the recipe before shooting.';
      ref
          .read(filmRollControllerProvider.notifier)
          .setActiveRecipeStatus(
            FilmRollRecipeStatus.unavailable,
            expectedRollId: roll.id,
            message: message,
          );
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
        errorMessage: message,
      );
      return null;
    }
    return _LockedCaptureRecipe(preset: preset, style: roll.lockedStyle);
  }

  /// Cycles the self-timer preset or cancels an active countdown.
  void cycleSelfTimer() {
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) {
      cancelSelfTimer();
      return;
    }
    final blockReason = _captureBlockReason();
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
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
    final blockReason = _captureBlockReason();
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
      return;
    }

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

  Map<String, dynamic> _buildCaptureParams({
    String? filmRollId,
    PresetModel? presetOverride,
    RanaStyle? styleOverride,
  }) {
    final activePreset = presetOverride ?? _activePreset();
    final style =
        styleOverride ??
        (activePreset != null ? state.activeStyle : const RanaStyle());

    final lut = activePreset?.lut;
    final lutPath = lut is String && lut.isNotEmpty ? lut : null;

    final presetGrain = activePreset?.grain.intensity ?? 0.0;
    final presetDust = activePreset?.effects.dust.intensity ?? 0.0;
    final presetGrainSize = activePreset?.grain.size ?? 1.0;
    final grainShadowsLimit =
        activePreset?.grain.shadowsLimit ?? PresetGrain.defaultShadowsLimit;
    final grainHighlightsLimit =
        activePreset?.grain.highlightsLimit ??
        PresetGrain.defaultHighlightsLimit;
    final presetSoftness = activePreset?.effects.softness ?? 0.0;
    final textureVal = style.textureVal ?? style.texture;
    final styleStrength = style.styleStrength;
    final shadowsTint =
        activePreset?.effects.splitToning?.shadowsTint ??
        const <double>[0, 0, 0];
    final highlightsTint =
        activePreset?.effects.splitToning?.highlightsTint ??
        const <double>[0, 0, 0];
    final outputQuality =
        ref.read(outputQualityProvider).valueOrNull ?? OutputQuality.highJpeg;
    final baseStyle = activePreset?.style ?? const RanaStyle();
    final isStyleModified = activePreset != null && style != baseStyle;

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
    final grainSizeMultiplier =
        (1.0 - blend) + (mapped['grainSize'] ?? 1.0) * blend;
    final finalGrainSize = presetGrainSize * grainSizeMultiplier;
    final finalSoftness = (presetSoftness + (mapped['softness'] ?? 0.0) * blend)
        .clamp(0.0, 1.0);

    return <String, dynamic>{
      'temperature': activePreset?.color.temperature ?? 0.0,
      'saturation': activePreset?.color.saturation ?? 0.0,
      'contrast': activePreset?.color.contrast ?? 0.0,
      'colorMatrix': activePreset?.color.matrix ?? PresetColor.identityMatrix,
      'fade': activePreset?.color.fade ?? 0.0,
      'grain': finalGrain,
      'vignette': activePreset?.vignette.intensity ?? 0.0,
      'vignetteColorR':
          activePreset?.vignette.color[0] ?? PresetVignette.defaultColor[0],
      'vignetteColorG':
          activePreset?.vignette.color[1] ?? PresetVignette.defaultColor[1],
      'vignetteColorB':
          activePreset?.vignette.color[2] ?? PresetVignette.defaultColor[2],
      'vignetteRoundness': activePreset?.vignette.roundness ?? 0.0,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': activePreset?.effects.lightLeak.intensity ?? 0.0,
      'lightLeakVariant': _currentPreviewVariant ?? -1,
      'dustIntensity': finalDust,
      'bloomThreshold': activePreset?.effects.bloom.threshold ?? 0.8,
      'bloomIntensity': activePreset?.effects.bloom.intensity ?? 0.0,
      'halationIntensity': activePreset?.effects.halation.intensity ?? 0.0,
      'halationRadius': activePreset?.effects.halation.radius ?? 1.0,
      'halationColorR':
          activePreset?.effects.halation.color[0] ??
          PresetHalation.defaultColor[0],
      'halationColorG':
          activePreset?.effects.halation.color[1] ??
          PresetHalation.defaultColor[1],
      'halationColorB':
          activePreset?.effects.halation.color[2] ??
          PresetHalation.defaultColor[2],
      'lensDistortionStrength':
          activePreset?.effects.lensDistortion.strength ?? 0.0,
      'chromaticAberrationIntensity':
          activePreset?.effects.chromaticAberration?.intensity ?? 0.0,
      'highlightRollOff': activePreset?.effects.highlightRollOff ?? 0.0,
      'shadowRollOff': activePreset?.effects.shadowRollOff ?? 0.0,
      'filmBorderStyle':
          activePreset?.effects.filmBorder.style.channelValue ?? 0,
      'dateStampEnable': activePreset?.effects.dateStamp?.enable ?? false,
      'shadowsTintR': shadowsTint[0],
      'shadowsTintG': shadowsTint[1],
      'shadowsTintB': shadowsTint[2],
      'highlightsTintR': highlightsTint[0],
      'highlightsTintG': highlightsTint[1],
      'highlightsTintB': highlightsTint[2],
      'tone': style.tone,
      'color': style.color,
      'textureVal': textureVal,
      'styleStrength': styleStrength,
      'undertoneX': style.undertoneX,
      'undertoneY': style.undertoneY,
      'grainSize': finalGrainSize,
      'grainShadowsLimit': grainShadowsLimit,
      'grainHighlightsLimit': grainHighlightsLimit,
      'softness': finalSoftness,
      'outputQuality': outputQuality.storageValue,
      'presetId': activePreset?.id ?? 'normal',
      'isStyleModified': isStyleModified,
      // Film Roll: pass the active roll ID so the Android side can store
      // it against the capture in the metadata DB.
      'filmRollId': filmRollId,
    };
  }

  void _randomizeNextVariantForPreview() {
    unawaited(
      _queueRecipe(() async {
        // A Film Roll's recipe is immutable for its lifetime. Do not let a
        // terminal event from an earlier capture asynchronously alter a newly
        // locked preview.
        if (ref.read(filmRollControllerProvider).hasActiveRoll) return;
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
          await _platformService.selectPreset(activePreset.id, paramsMap);
        }
      }),
    );
  }

  void _handleStatusEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'status_update':
        final fps = event['fps'] as int? ?? 0;
        state = state.copyWith(currentFps: fps);
      case 'capture_progress':
        _handleCaptureProgress(event);
      case 'capture_completed':
        _handleCaptureCompleted(event);
      case 'capture_failed':
        _handleCaptureFailed(event);
    }
  }

  void _handleCaptureProgress(Map<String, dynamic> event) {
    final captureId = event['captureId'] as String?;
    if (captureId == null ||
        (!_pendingCaptureIds.contains(captureId) &&
            !_awaitingNativeCaptureAcceptance)) {
      return;
    }
    final phase = event['phase'] as String? ?? 'unknown';
    final elapsedMs = _readInt(event, 'elapsedMs', state.captureElapsedMs);
    AppLogger.i(
      'RanaCaptureTimeline',
      'captureId=$captureId event=$phase elapsedMs=$elapsedMs',
    );
    if (phase == 'image_captured' && _acquiringCaptureId == captureId) {
      _acquiringCaptureId = null;
      state = state.copyWith(
        captureStatus: CaptureStatus.idle,
        captureElapsedMs: elapsedMs,
      );
    } else if (state.activeCaptureId == captureId) {
      state = state.copyWith(captureElapsedMs: elapsedMs);
    }
  }

  void _handleCaptureCompleted(Map<String, dynamic> event) {
    final captureId = event['captureId'] as String?;
    if (captureId == null) {
      return;
    }
    final wasPending = _pendingCaptureIds.remove(captureId);
    final wasEarlyTerminal = !wasPending && _awaitingNativeCaptureAcceptance;
    if (!wasPending && !wasEarlyTerminal) {
      return;
    }
    if (wasEarlyTerminal) {
      _earlyTerminalCaptureIds.add(captureId);
      _awaitingNativeCaptureAcceptance = false;
    }
    if (_acquiringCaptureId == captureId) {
      _acquiringCaptureId = null;
    }
    final imageUri = event['uri'] as String?;
    final reservation =
        _rollReservations.remove(captureId) ??
        (wasEarlyTerminal ? _takeAcquiringReservation() : null);
    final elapsedMs = _readInt(event, 'elapsedMs', state.captureElapsedMs);
    AppLogger.i(
      'RanaCaptureTimeline',
      'captureId=$captureId event=capture_completed '
          'uri=$imageUri elapsedMs=$elapsedMs',
    );
    state = state.copyWith(
      captureStatus: _acquiringCaptureId == null
          ? CaptureStatus.idle
          : CaptureStatus.capturing,
      activeCaptureId: state.activeCaptureId == captureId
          ? _acquiringCaptureId
          : state.activeCaptureId,
      completedCaptureId: captureId,
      captureElapsedMs: elapsedMs,
      captureError: null,
      errorMessage: null,
      lastCapturedPath: imageUri ?? state.lastCapturedPath,
      lastCaptureOutput: CaptureOutputMetadata.fromEvent(event),
    );
    _randomizeNextVariantForPreview();

    // Commit only the reservation made for this native capture. Starting a
    // later roll must never retroactively claim an earlier photo.
    if (imageUri != null && reservation != null) {
      unawaited(
        _commitFilmRollExposure(
          captureId: captureId,
          reservation: reservation,
          mediaUri: imageUri,
        ),
      );
    } else if (reservation != null) {
      unawaited(_releaseFilmRollExposure(reservation));
    }
  }

  void _handleCaptureFailed(Map<String, dynamic> event) {
    final captureId = event['captureId'] as String?;
    if (captureId == null) {
      return;
    }
    final wasPending = _pendingCaptureIds.remove(captureId);
    final wasEarlyTerminal = !wasPending && _awaitingNativeCaptureAcceptance;
    if (!wasPending && !wasEarlyTerminal) {
      return;
    }
    if (wasEarlyTerminal) {
      _earlyTerminalCaptureIds.add(captureId);
      _awaitingNativeCaptureAcceptance = false;
    }
    if (_acquiringCaptureId == captureId) {
      _acquiringCaptureId = null;
    }
    final reservation =
        _rollReservations.remove(captureId) ??
        (wasEarlyTerminal ? _takeAcquiringReservation() : null);
    if (reservation != null) {
      unawaited(_releaseFilmRollExposure(reservation));
    }
    final elapsedMs = _readInt(event, 'elapsedMs', state.captureElapsedMs);
    final message =
        event['message'] as String? ??
        event['errorCode'] as String? ??
        'Capture failed';
    AppLogger.w(
      'RanaCaptureTimeline',
      'captureId=$captureId event=capture_failed '
          'message=$message elapsedMs=$elapsedMs',
    );
    state = state.copyWith(
      captureStatus: _acquiringCaptureId == null
          ? CaptureStatus.idle
          : CaptureStatus.capturing,
      activeCaptureId: state.activeCaptureId == captureId
          ? _acquiringCaptureId
          : state.activeCaptureId,
      captureElapsedMs: elapsedMs,
      captureError: message,
      errorMessage: message,
    );
  }

  FilmRollExposureReservation? _takeAcquiringReservation() {
    final reservation = _acquiringRollReservation;
    _acquiringRollReservation = null;
    return reservation;
  }

  Future<void> _commitFilmRollExposure({
    required String captureId,
    required FilmRollExposureReservation reservation,
    required String mediaUri,
  }) async {
    final result = await ref
        .read(filmRollControllerProvider.notifier)
        .recordExposure(
          captureId: captureId,
          reservation: reservation,
          mediaUri: mediaUri,
        );
    if (!result.succeeded && !result.isDuplicate) {
      state = state.copyWith(
        errorMessage:
            result.message ?? 'The Film Roll frame could not be saved.',
      );
    }
    if (result.succeeded && !result.isDuplicate) {
      await _reconcileFilmRollAfterCaptureSettles(reservation.filmRollId);
    }
  }

  Future<void> _releaseFilmRollExposure(
    FilmRollExposureReservation reservation,
  ) async {
    final result = await ref
        .read(filmRollControllerProvider.notifier)
        .releaseExposure(reservation);
    if (!result.succeeded && !result.isDuplicate) {
      state = state.copyWith(
        errorMessage:
            result.message ?? 'The Film Roll capture could not be released.',
      );
    }
    if (result.succeeded && !result.isDuplicate) {
      await _reconcileFilmRollAfterCaptureSettles(reservation.filmRollId);
    }
  }

  Future<void> _reconcileFilmRollAfterCaptureSettles(String rollId) async {
    if (_hasCameraCaptureWork) return;
    final rollState = ref.read(filmRollControllerProvider);
    final activeRoll = rollState.activeRoll;
    if (activeRoll == null || activeRoll.id != rollId) {
      _filmRollReconciliationRequired = false;
      return;
    }
    if (rollState.reconciliationRequired || _filmRollReconciliationRequired) {
      await _reconcileActiveFilmRoll(rollId);
    }
  }

  bool _blockWhenRollLocked(String setting) {
    final rollState = ref.read(filmRollControllerProvider);
    final roll = rollState.activeRoll;
    if (roll == null || !roll.isActive) return false;

    state = state.copyWith(
      errorMessage:
          'Film Roll recipe locked — end or abandon the current roll '
          'before changing $setting.',
    );
    AppLogger.w(
      'CameraController',
      'Film Roll setting blocked: roll=${roll.id} setting=$setting',
    );
    return true;
  }

  Future<bool> _restoreActiveRollConfiguration() =>
      _queueRecipe(_restoreActiveRollConfigurationInternal);

  Future<bool> _restoreActiveRollConfigurationInternal() async {
    final rollController = ref.read(filmRollControllerProvider.notifier);
    await rollController.waitUntilRestored();
    final rollState = ref.read(filmRollControllerProvider);
    final roll = rollState.activeRoll;
    if (rollState.restorationStatus != FilmRollRestorationStatus.ready) {
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
        errorMessage:
            'Film Roll restoration could not be completed. Retry after '
            'reopening the camera.',
      );
      // Treat a failed restore as handled configuration. Returning false
      // would let initialize reapply the ordinary preview recipe, creating a
      // silent fall-back path while capture must remain blocked.
      return true;
    }
    if (roll == null || !roll.isActive) {
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.notRequired,
      );
      return false;
    }
    state = state.copyWith(
      activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.restoring,
      errorMessage: null,
    );
    rollController.setActiveRecipeStatus(
      FilmRollRecipeStatus.applying,
      expectedRollId: roll.id,
    );
    final applied = await _applyLockedRollRecipe(roll);
    if (!applied) {
      const message =
          'The locked Film Roll recipe is unavailable. Retry it, end the '
          'roll, or abandon it.';
      rollController.setActiveRecipeStatus(
        FilmRollRecipeStatus.unavailable,
        expectedRollId: roll.id,
        message: message,
      );
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
        errorMessage: message,
      );
      return true;
    }

    rollController.setActiveRecipeStatus(
      FilmRollRecipeStatus.ready,
      expectedRollId: roll.id,
    );
    state = state.copyWith(
      activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.ready,
      errorMessage: null,
    );
    await _reconcileActiveFilmRoll(roll.id);
    return true;
  }

  Future<bool> _applyLockedRollRecipe(FilmRoll roll) async {
    if (!state.isCameraInitialized) return false;
    CameraAspectRatio? aspectRatio;
    for (final candidate in CameraAspectRatio.values) {
      if (candidate.platformValue == roll.aspectRatioPlatformValue) {
        aspectRatio = candidate;
        break;
      }
    }
    if (aspectRatio == null) {
      state = state.copyWith(
        errorMessage: 'The locked Film Roll aspect ratio is unavailable.',
      );
      return false;
    }

    try {
      final aspectResult = await _platformService.setAspectRatio(
        aspectRatio.platformValue,
      );
      state = _withZoomState(
        state.copyWith(aspectRatio: aspectRatio),
        aspectResult,
        fallbackZoomRatio: state.zoomRatio,
      );

      final presets = await ref.read(presetsProvider.future);
      PresetModel? preset;
      for (final candidate in presets) {
        if (candidate.id == roll.presetId) {
          preset = candidate;
          break;
        }
      }
      if (preset == null) {
        state = state.copyWith(
          errorMessage: 'The locked Film Roll preset is unavailable.',
        );
        return false;
      }
      return _applyPreset(preset, style: roll.lockedStyle);
    } on Object catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Reconciles native metadata after restore or resume. Android's persisted
  /// URI/timestamp records are authoritative when a process died while image
  /// encoding was still finishing.
  Future<FilmRollActionResult?> _reconcileActiveFilmRoll(String rollId) async {
    final active = ref.read(filmRollControllerProvider).activeRoll;
    if (active == null || active.id != rollId || !active.isActive) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.staleRoll,
        'The Film Roll is no longer active.',
      );
    }
    // When this controller survived a pause, native processing may still
    // publish a terminal event. Keep its reservation capacity intact until it
    // settles; a metadata query that runs too early could otherwise clear the
    // reservation before Android has persisted the record.
    if (_hasCameraCaptureWork) {
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.lifecycleBusy,
        'Waiting for the accepted Film Roll capture to finish processing.',
      );
    }
    try {
      final records = await _platformService.listFilmRollCaptures(rollId);
      final captures = <RollCaptureEntry>[
        for (var index = 0; index < records.length; index += 1)
          RollCaptureEntry(
            filmRollId: rollId,
            mediaUri: records[index].mediaUri,
            capturedAt: records[index].capturedAt,
            exposureIndex: index + 1,
          ),
      ];
      final result = await ref
          .read(filmRollControllerProvider.notifier)
          .reconcileCapturedMedia(rollId: rollId, captures: captures);
      if (!result.succeeded) {
        _filmRollReconciliationRequired = true;
        state = state.copyWith(
          errorMessage:
              result.message ?? 'Film Roll captures could not be recovered.',
        );
        return result;
      }
      final current = ref.read(filmRollControllerProvider).activeRoll;
      _filmRollReconciliationRequired = false;
      if (current == null || current.id != rollId) {
        state = state.copyWith(
          activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.notRequired,
        );
      }
      return result;
    } on Object catch (e, stack) {
      AppLogger.e(
        'CameraController',
        'Failed to reconcile Film Roll captures: $rollId',
        e,
        stack,
      );
      const message =
          'Film Roll capture recovery is unavailable. Retry the recipe or '
          'reopen the camera.';
      _filmRollReconciliationRequired = true;
      final controller = ref.read(filmRollControllerProvider.notifier);
      controller.requireReconciliation(
        expectedRollId: rollId,
        message: message,
      );
      controller.setActiveRecipeStatus(
        FilmRollRecipeStatus.unavailable,
        expectedRollId: rollId,
        message: message,
      );
      state = state.copyWith(
        activeFilmRollRecipeStatus: ActiveFilmRollRecipeStatus.unavailable,
        errorMessage: message,
      );
      return const FilmRollActionResult.failed(
        FilmRollActionFailure.recoveryRequired,
        message,
      );
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
    final presetGrainSize = preset.grain.size ?? 1.0;
    final grainShadowsLimit = preset.grain.shadowsLimit;
    final grainHighlightsLimit = preset.grain.highlightsLimit;
    final presetSoftness = preset.effects.softness ?? 0.0;
    final textureVal = effectiveStyle.textureVal ?? effectiveStyle.texture;
    final styleStrength = effectiveStyle.styleStrength;
    final shadowsTint =
        preset.effects.splitToning?.shadowsTint ?? const <double>[0, 0, 0];
    final highlightsTint =
        preset.effects.splitToning?.highlightsTint ?? const <double>[0, 0, 0];

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
    final grainSizeMultiplier =
        (1.0 - blend) + (mapped['grainSize'] ?? 1.0) * blend;
    final finalGrainSize = presetGrainSize * grainSizeMultiplier;
    final finalSoftness = (presetSoftness + (mapped['softness'] ?? 0.0) * blend)
        .clamp(0.0, 1.0);

    return <String, dynamic>{
      'temperature': preset.color.temperature,
      'contrast': preset.color.contrast,
      'saturation': preset.color.saturation,
      'colorMatrix': preset.color.matrix,
      'fade': preset.color.fade ?? 0.0,
      'grain': finalGrain,
      'vignette': preset.vignette.intensity,
      'vignetteColorR': preset.vignette.color[0],
      'vignetteColorG': preset.vignette.color[1],
      'vignetteColorB': preset.vignette.color[2],
      'vignetteRoundness': preset.vignette.roundness,
      'lutPath': lutPath,
      'lutStrength': lutPath != null ? 1.0 : 0.0,
      'lightLeakIntensity': preset.effects.lightLeak.intensity,
      'lightLeakVariant': _currentPreviewVariant ?? -1,
      'dustIntensity': finalDust,
      'bloomThreshold': preset.effects.bloom.threshold,
      'bloomIntensity': preset.effects.bloom.intensity,
      'halationIntensity': preset.effects.halation.intensity,
      'halationRadius': preset.effects.halation.radius,
      'halationColorR': preset.effects.halation.color[0],
      'halationColorG': preset.effects.halation.color[1],
      'halationColorB': preset.effects.halation.color[2],
      'lensDistortionStrength': preset.effects.lensDistortion.strength,
      'chromaticAberrationIntensity':
          preset.effects.chromaticAberration?.intensity ?? 0.0,
      'highlightRollOff': preset.effects.highlightRollOff,
      'shadowRollOff': preset.effects.shadowRollOff,
      'filmBorderStyle': preset.effects.filmBorder.style.channelValue,
      'dateStampEnable': preset.effects.dateStamp?.enable ?? false,
      'shadowsTintR': shadowsTint[0],
      'shadowsTintG': shadowsTint[1],
      'shadowsTintB': shadowsTint[2],
      'highlightsTintR': highlightsTint[0],
      'highlightsTintG': highlightsTint[1],
      'highlightsTintB': highlightsTint[2],
      'tone': effectiveStyle.tone,
      'color': effectiveStyle.color,
      'textureVal': textureVal,
      'styleStrength': styleStrength,
      'undertoneX': effectiveStyle.undertoneX,
      'undertoneY': effectiveStyle.undertoneY,
      'grainSize': finalGrainSize,
      'grainShadowsLimit': grainShadowsLimit,
      'grainHighlightsLimit': grainHighlightsLimit,
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

  /// Clears legacy result metadata after a direct ResultScreen visit.
  void acknowledgeResultDismissed() {
    if (state.completedCaptureId == null) {
      return;
    }
    state = state.copyWith(
      completedCaptureId: null,
      captureError: null,
      captureElapsedMs: 0,
    );
  }

  /// Releases native camera resources and resets initialization state.
  Future<void> releaseCamera() {
    final releaseInFlight = _releaseFuture;
    if (releaseInFlight != null) return releaseInFlight;

    // A resume during release must not attach to an old initialization future.
    // The release still awaits it below, so its stale native result is settled
    // before a queued resume initializes the preview again.
    final pendingInitialization = _initializationFuture;
    _initializationFuture = null;
    late final Future<void> release;
    release = _releaseCameraInternal(pendingInitialization).whenComplete(() {
      if (identical(_releaseFuture, release)) {
        _releaseFuture = null;
      }
    });
    _releaseFuture = release;
    return release;
  }

  Future<void> _releaseCameraInternal(
    Future<void>? pendingInitialization,
  ) async {
    final lifecycleGeneration = ++_cameraLifecycleGeneration;
    final activeRoll = ref.read(filmRollControllerProvider).activeRoll;
    if (activeRoll != null && activeRoll.isActive) {
      // A release can race Android's processing executor. Preserve all
      // accepted IDs and reservations, then query its durable metadata on
      // resume before accepting another shutter press.
      _filmRollReconciliationRequired = true;
      ref
          .read(filmRollControllerProvider.notifier)
          .requireReconciliation(
            expectedRollId: activeRoll.id,
            message:
                'Film Roll captures will be recovered when the camera resumes.',
          );
    }
    cancelSelfTimer();
    _zoomGeneration += 1;
    _zoomDispatchTimer?.cancel();
    _zoomDispatchTimer = null;
    if (pendingInitialization != null) {
      try {
        await pendingInitialization;
      } on Object {
        // The initialization already recorded its safe error state. Continue
        // releasing so a future resume can obtain a fresh native camera.
      }
    }
    if (lifecycleGeneration != _cameraLifecycleGeneration) return;
    if (!state.isCameraInitialized) return;
    try {
      await _platformService.releaseCamera();
      if (lifecycleGeneration != _cameraLifecycleGeneration) return;
      state = state.copyWith(
        isCameraInitialized: false,
        currentFps: 0,
        captureStatus: _hasCameraCaptureWork
            ? CaptureStatus.capturing
            : CaptureStatus.idle,
      );
    } on Object catch (e) {
      if (lifecycleGeneration != _cameraLifecycleGeneration) return;
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
      zoomQualityLabel: _readString(
        result,
        'zoomQualityLabel',
        baseState.zoomQualityLabel,
      ),
      hasTelephotoCandidate: _readBool(
        result,
        'hasTelephotoCandidate',
        baseState.hasTelephotoCandidate,
      ),
      isLikelyDigitalZoom: _readBool(
        result,
        'isLikelyDigitalZoom',
        baseState.isLikelyDigitalZoom,
      ),
      shouldWarnDigitalZoom: _readBool(
        result,
        'shouldWarnDigitalZoom',
        baseState.shouldWarnDigitalZoom,
      ),
      physicalCameraCount: _readInt(
        result,
        'physicalCameraCount',
        baseState.physicalCameraCount,
      ),
    );
  }

  String _readString(Map<String, dynamic> result, String key, String fallback) {
    final value = result[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  bool _readBool(Map<String, dynamic> result, String key, bool fallback) {
    final value = result[key];
    return value is bool ? value : fallback;
  }

  double _readDouble(Map<String, dynamic> result, String key, double fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  int _readInt(Map<String, dynamic> result, String key, int fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.round() : fallback;
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
