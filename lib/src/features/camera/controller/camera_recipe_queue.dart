import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/debug/provider/consistency_debug_provider.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/film_roll/model/roll_capture_entry.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';
import 'package:rana/features/render/model/render_recipe.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';
import 'package:rana/src/features/camera/controller/camera_recipe_builder.dart';

/// Serializes camera recipe mutations and owns Film Roll capture reservations.
@internal
final class CameraRecipeQueue {
  CameraRecipeQueue({
    required this.ref,
    required CameraPlatformService platformService,
    required CameraState Function() readState,
    required void Function(CameraState state) writeState,
    required int Function() readLifecycleGeneration,
    required void Function({bool clearMode}) cancelSelfTimer,
    required CameraState Function(
      CameraState baseState,
      Map<String, dynamic> result, {
      double? fallbackZoomRatio,
    })
    mergeNativeZoomState,
    CameraRecipeBuilder recipeBuilder = const CameraRecipeBuilder(),
  }) : _platformService = platformService,
       _readState = readState,
       _writeState = writeState,
       _readLifecycleGeneration = readLifecycleGeneration,
       _cancelSelfTimer = cancelSelfTimer,
       _mergeNativeZoomState = mergeNativeZoomState,
       _recipeBuilder = recipeBuilder;

  final Ref<CameraState> ref;
  final CameraPlatformService _platformService;
  final CameraState Function() _readState;
  final void Function(CameraState state) _writeState;
  final int Function() _readLifecycleGeneration;
  final void Function({bool clearMode}) _cancelSelfTimer;
  final CameraState Function(
    CameraState baseState,
    Map<String, dynamic> result, {
    double? fallbackZoomRatio,
  })
  _mergeNativeZoomState;
  final CameraRecipeBuilder _recipeBuilder;

  Future<void> _recipeQueue = Future<void>.value();
  int? _currentPreviewVariant;
  PresetModel? _selectedPreset;
  RenderRecipeV1? _activeRecipe;
  final Set<String> _pendingCaptureIds = <String>{};
  final Map<String, FilmRollExposureReservation> _rollReservations =
      <String, FilmRollExposureReservation>{};
  final Set<String> _earlyTerminalCaptureIds = <String>{};
  FilmRollExposureReservation? _acquiringRollReservation;
  String? _acquiringCaptureId;
  bool _awaitingNativeCaptureAcceptance = false;
  bool _filmRollReconciliationRequired = false;

  CameraState get state => _readState();

  set state(CameraState value) => _writeState(value);

  int get _cameraLifecycleGeneration => _readLifecycleGeneration();

  int _randomizeVariant() => Random().nextInt(4);

  void cancelSelfTimer({bool clearMode = false}) {
    _cancelSelfTimer(clearMode: clearMode);
  }

  CameraState _withZoomState(
    CameraState baseState,
    Map<String, dynamic> result, {
    double? fallbackZoomRatio,
  }) => _mergeNativeZoomState(
    baseState,
    result,
    fallbackZoomRatio: fallbackZoomRatio,
  );

  Future<void> configureInitializedCamera(bool Function() isCurrent) async {
    final restoredRollApplied = await restoreActiveRollConfiguration();
    if (!isCurrent()) return;
    if (restoredRollApplied) return;

    await _queueRecipe(() async {
      if (!isCurrent()) return;
      final aspectRatioResult = await _platformService.setAspectRatio(
        state.aspectRatio.platformValue,
      );
      if (!isCurrent()) return;
      state = _withZoomState(
        state,
        aspectRatioResult,
        fallbackZoomRatio: state.zoomRatio,
      );
      await _reapplyActivePreviewParamsInternal();
    });
  }

  void prepareRelease() {
    final activeRoll = ref.read(filmRollControllerProvider).activeRoll;
    if (activeRoll == null || !activeRoll.isActive) return;

    _filmRollReconciliationRequired = true;
    ref
        .read(filmRollControllerProvider.notifier)
        .requireReconciliation(
          expectedRollId: activeRoll.id,
          message:
              'Film Roll captures will be recovered when the camera resumes.',
        );
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

      final recipe = _buildRecipe(preset, style: effectiveStyle);
      final paramsMap = _recipeBuilder.previewParamsFor(recipe);
      AppLogger.glParams('PREVIEW', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => GlParamsState(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(preset.id, paramsMap);
      _selectedPreset = preset;
      _activeRecipe = recipe;
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
      final recipe = _buildRecipe(activePreset, style: clampedStyle);
      final paramsMap = _recipeBuilder.previewParamsFor(recipe);
      AppLogger.glParams('PREVIEW_STYLE_UPDATE', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(activePreset.id, paramsMap);
      _activeRecipe = recipe;
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
      final recipe = _buildRecipe(activePreset, style: state.activeStyle);
      final paramsMap = _recipeBuilder.previewParamsFor(recipe);
      AppLogger.glParams('PREVIEW_REAPPLY', paramsMap);
      ref
          .read(consistencyDebugProvider.notifier)
          .update((state) => state.copyWith(lastPreviewParams: paramsMap));
      await _platformService.selectPreset(activePreset.id, paramsMap);
      _activeRecipe = recipe;
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
      final lockedRecipe =
          _activeRecipe ?? _buildRecipe(preset, style: lockedStyle);
      final filmRollController = ref.read(filmRollControllerProvider.notifier);
      final result = await filmRollController.startRoll(
        presetId: preset.id,
        lockedStyle: lockedStyle,
        lockedRecipe: lockedRecipe,
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
      if (hasCaptureWork) {
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
    if (hasCaptureWork || state.isSelfTimerRunning) {
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

  bool get hasCaptureWork =>
      _awaitingNativeCaptureAcceptance ||
      _acquiringRollReservation != null ||
      _pendingCaptureIds.isNotEmpty ||
      _rollReservations.isNotEmpty;

  bool get _hasCameraLifecycleWork =>
      hasCaptureWork || state.isSelfTimerRunning;

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

  /// Triggers film capture flow.
  Future<void> capture() async {
    if (state.captureStatus != CaptureStatus.idle || state.isSelfTimerRunning) {
      return;
    }

    final filmRollController = ref.read(filmRollControllerProvider.notifier);
    final rollState = ref.read(filmRollControllerProvider);
    final blockReason = captureBlockReason();
    if (blockReason != null) {
      state = state.copyWith(errorMessage: blockReason);
      return;
    }

    RenderRecipeV1? lockedRecipe;
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

    final captureRecipe =
        lockedRecipe ??
        _activeRecipe ??
        _buildRecipe(_activePreset(), style: state.activeStyle);
    final captureParams = _recipeBuilder.captureParamsFor(
      captureRecipe,
      filmRollId: reservation?.filmRollId,
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
        if (!hasCaptureWork) {
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
        failure: CameraFailure.fromError(
          e,
          fallbackCode: CameraFailureCode.captureFailed,
        ),
      );
    }
  }

  String? captureBlockReason() {
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

  RenderRecipeV1? _verifiedLockedCaptureRecipe(FilmRoll roll) {
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
        state.aspectRatio != expectedAspect ||
        _activeRecipe != roll.lockedRecipe) {
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
    return roll.lockedRecipe;
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
          final recipe = _buildRecipe(activePreset, style: state.activeStyle);
          final paramsMap = _recipeBuilder.previewParamsFor(recipe);

          AppLogger.glParams('PREVIEW_UPDATE_RANDOM', paramsMap);
          ref
              .read(consistencyDebugProvider.notifier)
              .update((state) => state.copyWith(lastPreviewParams: paramsMap));
          await _platformService.selectPreset(activePreset.id, paramsMap);
          _activeRecipe = recipe;
        }
      }),
    );
  }

  void handleStatusEvent(Map<String, dynamic> event) {
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
      case 'renderer_error':
        final code = CameraFailureCode.fromWireValue(
          event['errorCode'] as String? ?? '',
        );
        state = state.copyWith(
          failure: CameraFailure.fromCode(
            code == CameraFailureCode.unknown
                ? CameraFailureCode.glRenderFailed
                : code,
            developerMessage: event['message'] as String?,
          ),
        );
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
    final failureCode = CameraFailureCode.fromWireValue(
      event['errorCode'] as String? ?? '',
    );
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
      failure: CameraFailure.fromCode(
        failureCode == CameraFailureCode.unknown
            ? CameraFailureCode.captureFailed
            : failureCode,
        developerMessage: message,
      ),
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
    if (hasCaptureWork) return;
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

  Future<bool> restoreActiveRollConfiguration() =>
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
      var lockedRecipe = roll.lockedRecipe;
      if (roll.needsRecipeMigration) {
        lockedRecipe = _buildRecipe(preset, style: roll.lockedStyle);
        final upgraded = await ref
            .read(filmRollControllerProvider.notifier)
            .upgradeActiveLockedRecipe(
              expectedRollId: roll.id,
              recipe: lockedRecipe,
            );
        if (upgraded == null) return false;
      }
      final paramsMap = _recipeBuilder.previewParamsFor(lockedRecipe);
      AppLogger.glParams('PREVIEW_FILM_ROLL_RESTORE', paramsMap);
      await _platformService.selectPreset(preset.id, paramsMap);
      _selectedPreset = preset;
      _activeRecipe = lockedRecipe;
      state = state.copyWith(
        activePresetId: preset.id,
        activeStyle: roll.lockedStyle,
      );
      return true;
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
    if (hasCaptureWork) {
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

  RenderRecipeV1 _buildRecipe(PresetModel? preset, {required RanaStyle style}) {
    final outputQuality =
        ref.read(outputQualityProvider).valueOrNull ?? OutputQuality.highJpeg;
    return _recipeBuilder.buildRecipe(
      preset: preset,
      style: style,
      previewVariant: _currentPreviewVariant,
      outputQuality: outputQuality,
      aspectRatio: state.aspectRatio.platformValue,
    );
  }

  RanaStyle _clampStyle(RanaStyle style) => _recipeBuilder.clampStyle(style);

  int _readInt(Map<String, dynamic> result, String key, int fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.round() : fallback;
  }
}
