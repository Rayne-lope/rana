import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/providers/permission_provider.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/camera/view/permission_screen.dart';
import 'package:rana/features/camera/widgets/latest_capture_thumbnail.dart';
import 'package:rana/features/camera/widgets/premium_shutter_button.dart';
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';
import 'package:rana/features/camera/widgets/style_mood_chips.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/film_roll/state/film_roll_state.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';
import 'package:rana/features/film_roll/widgets/roll_complete_sheet.dart';
import 'package:rana/features/film_roll/widgets/roll_hud_pill.dart';
import 'package:rana/features/film_roll/widgets/roll_info_sheet.dart';
import 'package:rana/features/film_roll/widgets/start_roll_sheet.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/repository/saved_rana_style_repository.dart';
import 'package:rana/features/preset/widgets/preset_selector_panel.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';

/// Interactive Camera Screen — Phase 0.4 & 0.5 Implementation.
///
/// Features a retro analog camera layout with top status controls (Flash, Flip,
/// live FPS counter), a grid viewfinder with a yellow date stamp, a preset
/// selector carousel, and a capture shutter.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

enum _ViewfinderLayoutMode { capture, styleEditor }

/// A CameraScreen-local coordinator that prevents overlapping Film Roll routes.
enum _FilmRollRoute { none, start, info, completion }

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isEditingStyle = false;
  bool _isEditingUndertone = false;
  int _activeStyleTab = 0; // 0: Tone, 1: Color, 2: Palette
  RanaStyle? _originalStyle;
  bool _isSelectingPreset = false;
  String? _originalPresetId;

  ShutterStatus _shutterStatus = ShutterStatus.ready;
  bool _showFlash = false;
  bool _showToast = false;

  Size? _stableWindowSize;
  Size? _candidateWindowSize;
  int _candidateWindowFrames = 0;
  int _metricsCheckGeneration = 0;
  int _previewGeneration = 0;
  int? _readyPreviewGeneration;
  bool _previewMetricsStable = false;
  bool _isPreviewReady = false;
  final String _startupSessionId = DateTime.now().microsecondsSinceEpoch
      .toString();

  ProviderSubscription<CameraState>? _captureFeedbackSubscription;
  ProviderSubscription<FilmRollState>? _filmRollSubscription;
  Timer? _flashTimer;
  Timer? _toastTimer;
  _FilmRollRoute _filmRollRoute = _FilmRollRoute.none;
  FilmRollCompletionEvent? _pendingRollCompletionEvent;
  String? _presentedRollCompletionEventId;

  void _handleCaptureFeedback(CameraState? previous, CameraState next) {
    final imageWasCaptured =
        previous?.captureStatus == CaptureStatus.capturing &&
        next.captureStatus == CaptureStatus.idle &&
        next.captureError == null &&
        next.isCameraInitialized;
    if (imageWasCaptured) {
      _triggerScreenFlash();
    }

    final captureWasCompleted =
        next.completedCaptureId != null &&
        next.completedCaptureId != previous?.completedCaptureId &&
        next.captureError == null;
    if (captureWasCompleted) {
      _triggerCaptureToast();
    }
  }

  void _handleFilmRollState(FilmRollState? previous, FilmRollState next) {
    final completionEvent = next.completionEvent;
    if (completionEvent == null ||
        completionEvent == previous?.completionEvent) {
      return;
    }
    if (!completionEvent.shouldPresentCompletionSheet) {
      ref
          .read(filmRollControllerProvider.notifier)
          .acknowledgeCompletionEvent(completionEvent.id);
      return;
    }
    _pendingRollCompletionEvent = completionEvent;
    _tryPresentPendingRollCompletion();
  }

  void _tryPresentPendingRollCompletion() {
    final event = _pendingRollCompletionEvent;
    if (!mounted ||
        event == null ||
        _filmRollRoute != _FilmRollRoute.none ||
        _presentedRollCompletionEventId == event.id) {
      return;
    }
    _pendingRollCompletionEvent = null;
    _presentedRollCompletionEventId = event.id;
    unawaited(_showRollCompleteSheet(event));
  }

  void _triggerScreenFlash() {
    _flashTimer?.cancel();

    setState(() {
      _showFlash = true;
    });

    _flashTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _showFlash = false;
        });
      }
    });
  }

  void _triggerCaptureToast() {
    _toastTimer?.cancel();

    setState(() {
      _showToast = true;
    });

    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  String _shutterStatusName(ShutterStatus status) {
    switch (status) {
      case ShutterStatus.ready:
        return 'READY';
      case ShutterStatus.focusing:
        return 'FOCUSING';
      case ShutterStatus.focusLock:
        return 'FOCUS LOCK';
      case ShutterStatus.captured:
        return 'CAPTURED';
    }
  }

  Offset? _tapFocusPoint;
  bool _isFocusLocked = false;
  late final AnimationController _focusAnimationController;
  Timer? _focusResetTimer;
  double _pinchStartZoomRatio = userMinZoomRatio;
  double _pinchTargetZoomRatio = userMinZoomRatio;
  bool _isZoomGestureActive = false;

  @override
  void initState() {
    super.initState();
    _captureFeedbackSubscription = ref.listenManual<CameraState>(
      cameraControllerProvider,
      _handleCaptureFeedback,
    );
    _filmRollSubscription = ref.listenManual<FilmRollState>(
      filmRollControllerProvider,
      _handleFilmRollState,
    );
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addObserver(this);

    // listenManual does not guarantee an initial delivery. A live completion
    // event remains unconsumed until presentation begins, so inspect it once
    // the camera route is active as a durable UI handoff.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleFilmRollState(null, ref.read(filmRollControllerProvider));
      _scheduleWindowMetricsCheck();
    });

    // The native preview is mounted only after permission and window metrics
    // are ready. Its creation callback owns camera initialization.
    Future.microtask(() async {
      await ref.read(cameraPermissionControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _metricsCheckGeneration += 1;
    _isPreviewReady = false;
    _captureFeedbackSubscription?.close();
    _filmRollSubscription?.close();
    _flashTimer?.cancel();
    _toastTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focusResetTimer?.cancel();
    _focusAnimationController.dispose();
    super.dispose();
  }

  Size _currentLogicalWindowSize() => MediaQuery.sizeOf(context);

  void _scheduleWindowMetricsCheck() {
    final checkGeneration = ++_metricsCheckGeneration;
    _candidateWindowSize = null;
    _candidateWindowFrames = 0;
    _queueWindowMetricsSample(checkGeneration);
  }

  void _queueWindowMetricsSample(int checkGeneration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || checkGeneration != _metricsCheckGeneration) return;

      final logicalSize = _currentLogicalWindowSize();
      if (logicalSize.isEmpty) {
        _queueWindowMetricsSample(checkGeneration);
        return;
      }

      if (_stableWindowSize == logicalSize && _previewMetricsStable) {
        return;
      }

      if (_candidateWindowSize == logicalSize) {
        _candidateWindowFrames += 1;
      } else {
        _candidateWindowSize = logicalSize;
        _candidateWindowFrames = 1;
      }

      if (_stableWindowSize != null &&
          _stableWindowSize != logicalSize &&
          _previewMetricsStable) {
        final previousGeneration = _previewGeneration;
        setState(() {
          _previewMetricsStable = false;
          _isPreviewReady = false;
          _readyPreviewGeneration = null;
        });
        AppLogger.d(
          'CameraStartup',
          'session=$_startupSessionId Window metrics changed: '
              'old=$_stableWindowSize new=$logicalSize '
              'previewGeneration=$previousGeneration',
        );
        unawaited(ref.read(cameraControllerProvider.notifier).releaseCamera());
      }

      if (_candidateWindowFrames >= 2) {
        setState(() {
          _stableWindowSize = logicalSize;
          _previewMetricsStable = true;
          _previewGeneration += 1;
          _isPreviewReady = false;
          _readyPreviewGeneration = null;
        });
        AppLogger.d(
          'CameraStartup',
          'session=$_startupSessionId Window metrics stable: '
              'size=$logicalSize '
              'previewGeneration=$_previewGeneration',
        );
        return;
      }

      _queueWindowMetricsSample(checkGeneration);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _initializePreview(
    int platformViewId,
    int previewGeneration,
  ) async {
    if (!mounted ||
        !_previewMetricsStable ||
        previewGeneration != _previewGeneration) {
      return;
    }

    if (_readyPreviewGeneration != previewGeneration) {
      _readyPreviewGeneration = previewGeneration;
      _isPreviewReady = true;
      AppLogger.d(
        'CameraStartup',
        'session=$_startupSessionId PlatformView ready: id=$platformViewId '
            'previewGeneration=$previewGeneration size=$_stableWindowSize',
      );
    }

    final controller = ref.read(cameraControllerProvider.notifier);
    controller.registerPlatformView(platformViewId);
    await controller.initialize();
    if (!mounted ||
        !_isPreviewReady ||
        previewGeneration != _previewGeneration) {
      return;
    }
    await controller.reapplyActivePreviewParams();
  }

  void _logPointerDown(PointerDownEvent event) {
    if (!kDebugMode) return;
    AppLogger.d(
      'CameraInput',
      'session=$_startupSessionId PointerDown position=${event.position} '
          'local=${event.localPosition} '
          'size=$_stableWindowSize previewGeneration=$_previewGeneration '
          'previewReady=$_isPreviewReady',
    );
  }

  void _handleViewfinderTap(TapUpDetails details, BoxConstraints constraints) {
    if (_isZoomGestureActive) return;

    final cameraState = ref.read(cameraControllerProvider);
    if (!cameraState.isCameraInitialized ||
        cameraState.captureStatus != CaptureStatus.idle) {
      return;
    }

    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    final normX = x / constraints.maxWidth;
    final normY = y / constraints.maxHeight;

    setState(() {
      _tapFocusPoint = Offset(x, y);
      _isFocusLocked = true;
    });

    _focusAnimationController.forward(from: 0);

    unawaited(
      ref
          .read(cameraControllerProvider.notifier)
          .setFocusAndMetering(normX, normY),
    );

    _focusResetTimer?.cancel();
    _focusResetTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isFocusLocked) {
        _resetFocus();
      }
    });
  }

  void _handleViewfinderScaleStart(ScaleStartDetails details) {
    _pinchStartZoomRatio = ref.read(cameraControllerProvider).zoomRatio;
    _pinchTargetZoomRatio = _pinchStartZoomRatio;
  }

  void _handleViewfinderScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    _isZoomGestureActive = true;
    final safeScale = details.scale > 0 ? details.scale : 1.0;
    final easedScale = math.pow(safeScale, 0.86).toDouble();
    final targetZoomRatio = _pinchStartZoomRatio * easedScale;
    _pinchTargetZoomRatio = targetZoomRatio;
    unawaited(
      ref
          .read(cameraControllerProvider.notifier)
          .setZoomRatio(targetZoomRatio, commit: false),
    );
  }

  void _handleViewfinderScaleEnd(ScaleEndDetails details) {
    if (!_isZoomGestureActive) return;
    _isZoomGestureActive = false;
    unawaited(
      ref
          .read(cameraControllerProvider.notifier)
          .setZoomRatio(_pinchTargetZoomRatio),
    );
  }

  void _resetFocus() {
    _focusResetTimer?.cancel();
    setState(() {
      _tapFocusPoint = null;
      _isFocusLocked = false;
    });
    unawaited(
      ref.read(cameraControllerProvider.notifier).cancelFocusAndMetering(),
    );
  }

  Future<void> _handleCapture(CameraController controller) async {
    final capabilities = await ref.read(permissionCapabilitiesProvider.future);
    if (capabilities.requiresLegacyStorageForCapture) {
      final galleryPermissions = ref.read(
        galleryPermissionControllerProvider.notifier,
      );
      await galleryPermissions.refresh();
      final galleryAccess = ref.read(galleryPermissionControllerProvider);
      if (!galleryAccess.canRead) {
        if (!mounted) return;
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1C20),
            title: const Text(
              'SAVE PHOTOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'Android 9 and older need photo storage access to save each '
              'Rana capture.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('NOT NOW'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('CONTINUE'),
              ),
            ],
          ),
        );
        if (shouldRequest != true || !mounted) return;
        await galleryPermissions.requestGalleryAccess();
        if (!ref.read(galleryPermissionControllerProvider).canRead) return;
      }
    }

    if (!mounted) return;
    await controller.handleShutterPressed();
  }

  Future<void> _showFilmRollSheet(CameraState cameraState) async {
    if (_filmRollRoute != _FilmRollRoute.none) return;
    final rollState = ref.read(filmRollControllerProvider);
    if (rollState.restorationStatus != FilmRollRestorationStatus.ready) {
      return;
    }
    final activeRoll = rollState.activeRoll;
    if (activeRoll != null && activeRoll.isActive) {
      await _showRollInfoSheet(activeRoll, rollState.pendingExposureCount);
      return;
    }

    final presets = ref.read(presetsProvider).valueOrNull ?? [];
    final activePreset = _findActivePreset(cameraState, presets);
    final presetName = activePreset?.name ?? cameraState.activePresetId;

    _filmRollRoute = _FilmRollRoute.start;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StartRollSheet(
          presetName: presetName,
          aspectRatioLabel: cameraState.aspectRatio.label,
          onLoad: (size) =>
              ref.read(cameraControllerProvider.notifier).startFilmRoll(size),
        ),
      );
    } finally {
      if (mounted && _filmRollRoute == _FilmRollRoute.start) {
        _filmRollRoute = _FilmRollRoute.none;
        _tryPresentPendingRollCompletion();
      }
    }
  }

  Future<void> _showRollInfoSheet(FilmRoll roll, int pendingExposures) async {
    if (_filmRollRoute != _FilmRollRoute.none) return;
    _filmRollRoute = _FilmRollRoute.info;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Consumer(
          builder: (context, ref, child) {
            final currentRollState = ref.watch(filmRollControllerProvider);
            final currentRoll = currentRollState.activeRoll ?? roll;
            final isSameActiveRoll = currentRollState.activeRoll?.id == roll.id;
            return RollInfoSheet(
              roll: currentRoll,
              presetName: _presetNameForRoll(currentRoll),
              aspectRatioLabel: _aspectRatioLabel(
                currentRoll.aspectRatioPlatformValue,
              ),
              pendingExposures: isSameActiveRoll
                  ? currentRollState.pendingExposureCount
                  : pendingExposures,
              pendingSaveState: currentRollState.pendingSaveState,
              recipeStatus: currentRollState.recipeStatus,
              reconciliationRequired: currentRollState.reconciliationRequired,
              actionError: currentRollState.lastActionError,
              onEnd: () => ref
                  .read(cameraControllerProvider.notifier)
                  .endFilmRoll(roll.id),
              onAbandon: () => ref
                  .read(cameraControllerProvider.notifier)
                  .abandonFilmRoll(roll.id),
              onExportContactSheet: () => ref.read(
                contactSheetExportRunnerProvider,
              )(roll: currentRoll, presetName: _presetNameForRoll(currentRoll)),
              onRetryRecipe: () => ref
                  .read(cameraControllerProvider.notifier)
                  .retryActiveFilmRollRecipe(),
              onRetryPendingSave: () => ref
                  .read(cameraControllerProvider.notifier)
                  .retryActiveFilmRollSave(),
            );
          },
        ),
      );
    } finally {
      if (mounted && _filmRollRoute == _FilmRollRoute.info) {
        _filmRollRoute = _FilmRollRoute.none;
        _tryPresentPendingRollCompletion();
      }
    }
  }

  Future<void> _showRollCompleteSheet(FilmRollCompletionEvent event) async {
    if (!mounted || _filmRollRoute != _FilmRollRoute.none) return;
    _filmRollRoute = _FilmRollRoute.completion;
    var acknowledged = false;
    try {
      final route = showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => RollCompleteSheet(
          roll: event.roll,
          presetName: _presetNameForRoll(event.roll),
        ),
      );
      // showModalBottomSheet installs its route synchronously. Acknowledge
      // only after that point so a failed presentation leaves the event alive.
      ref
          .read(filmRollControllerProvider.notifier)
          .acknowledgeCompletionEvent(event.id);
      acknowledged = true;
      await route;
    } finally {
      if (!acknowledged) {
        _presentedRollCompletionEventId = null;
        _pendingRollCompletionEvent = event;
      }
      if (mounted && _filmRollRoute == _FilmRollRoute.completion) {
        _filmRollRoute = _FilmRollRoute.none;
        _tryPresentPendingRollCompletion();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.i(
      'CameraScreen',
      'session=$_startupSessionId App lifecycle changed to: $state',
    );
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(cameraControllerProvider.notifier).releaseCamera());
    } else if (state == AppLifecycleState.resumed) {
      ref.read(cameraPermissionControllerProvider.notifier).refresh().then((_) {
        if (!mounted) return;
        if (!ref.read(cameraPermissionControllerProvider).isGranted) {
          _isPreviewReady = false;
          _readyPreviewGeneration = null;
          return;
        }
        if (!_isPreviewReady) {
          return;
        }
        unawaited(_initializePreview(-1, _previewGeneration));
      });
    }
  }

  @override
  void didChangeMetrics() {
    AppLogger.d(
      'CameraStartup',
      'session=$_startupSessionId Window metrics notification received',
    );
    _scheduleWindowMetricsCheck();
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(cameraPermissionControllerProvider);
    final cameraState = ref.watch(cameraControllerProvider);
    final rollState = ref.watch(filmRollControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    if (permissionState.isChecking && !permissionState.isGranted) {
      return const Scaffold(
        backgroundColor: Color(0xFF242424),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
          ),
        ),
      );
    }

    if (!permissionState.isGranted) {
      return const CameraPermissionScreen();
    }

    final isEditing = _isEditingStyle || _isEditingUndertone;
    final editingTitle = _isEditingUndertone ? 'Undertone' : 'Rana Styles';
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _logPointerDown,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2D3037), // Top sheet titanium
                  Color(0xFF1E2025), // Mid sheet gunmetal
                  Color(0xFF121316), // Bottom sheet deep charcoal metal
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    if (isEditing)
                      _buildStylesEditingHeader(
                        editingTitle,
                        cameraState,
                        controller,
                      )
                    else if (_isSelectingPreset)
                      _buildPresetSelectionHeader(cameraState, controller)
                    else
                      const SizedBox.shrink(),

                    Expanded(
                      child: _buildViewfinder(
                        cameraState,
                        controller,
                        rollState: rollState,
                        layoutMode: (isEditing || _isSelectingPreset)
                            ? _ViewfinderLayoutMode.styleEditor
                            : _ViewfinderLayoutMode.capture,
                      ),
                    ),

                    if (isEditing)
                      _buildStylesEditingContent(cameraState, controller)
                    else if (_isSelectingPreset)
                      _buildPresetSelectionContent(cameraState, controller)
                    else
                      _buildBottomPanel(
                        cameraState,
                        controller,
                        rollState: rollState,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showFlash)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey<String>('capture-screen-flash'),
                  color: Colors.white,
                ),
              ),
            ),
          if (_showToast)
            Positioned(
              key: const ValueKey<String>('capture-completed-toast'),
              bottom: 120,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC141416),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Text(
                        'PHOTO CAPTURED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStylesEditingContent(
    CameraState state,
    CameraController controller,
  ) {
    final presetsList = ref.watch(presetsProvider).valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isEditingUndertone)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
              child: _buildActiveStyleControl(state, controller),
            )
          else ...[
            if (activePreset != null) ...[
              StyleMoodChips(
                activePreset: activePreset,
                activeStyle: state.activeStyle,
                onSelected: (mood) {
                  unawaited(controller.applyStyleMood(mood));
                },
              ),
              const SizedBox(height: 2),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: _buildActiveStyleControl(state, controller),
            ),
          ],

          if (!_isEditingUndertone) _buildStylesSelectorTabBar(),
        ],
      ),
    );
  }

  Widget _buildPresetSelectionHeader(
    CameraState state,
    CameraController controller,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildHeaderKnob(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () {
            final presetsList = ref.read(presetsProvider).valueOrNull ?? [];
            if (_originalPresetId != null) {
              final originalPreset = presetsList.firstWhere(
                (p) => p.id == _originalPresetId,
                orElse: () => presetsList.first,
              );
              controller.selectPreset(originalPreset);
            }
            setState(() {
              _isSelectingPreset = false;
            });
          },
        ),
        const Text(
          'SELECT PRESET',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        _buildHeaderKnob(
          icon: Icons.check_rounded,
          tooltip: 'Done',
          onPressed: () {
            setState(() {
              _isSelectingPreset = false;
            });
          },
        ),
      ],
    ),
  );

  Widget _buildPresetSelectionContent(
    CameraState state,
    CameraController controller,
  ) => SizedBox(
    height: 190,
    child: ref
        .watch(presetsProvider)
        .when(
          data: (presetsList) {
            if (presetsList.isEmpty) {
              return const Center(
                child: Text(
                  'NO PRESETS FOUND',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return PresetSelectorPanel(
              presets: presetsList,
              activePresetId: state.activePresetId,
              onPresetSelected: controller.selectPreset,
              onDeletePreset: _confirmDeleteStyle,
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
            ),
          ),
          error: (err, stack) => Center(
            child: Text(
              'FAILED TO LOAD PRESETS',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
  );

  PresetModel? _findActivePreset(
    CameraState state,
    List<PresetModel> presetsList,
  ) {
    for (final preset in presetsList) {
      if (preset.id == state.activePresetId) {
        return preset;
      }
    }
    return null;
  }

  String _presetNameForRoll(FilmRoll roll) {
    final presets = ref.read(presetsProvider).valueOrNull ?? [];
    for (final preset in presets) {
      if (preset.id == roll.presetId) return preset.name;
    }
    return roll.presetId;
  }

  String _aspectRatioLabel(String platformValue) => CameraAspectRatio.values
      .firstWhere(
        (ratio) => ratio.platformValue == platformValue,
        orElse: () => CameraAspectRatio.portrait34,
      )
      .label;

  Widget _buildStylesEditingHeader(
    String title,
    CameraState state,
    CameraController controller,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Cancel / Back Button (<-)
        _buildHeaderKnob(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () {
            if (_isEditingUndertone) {
              setState(() {
                _isEditingUndertone = false;
                _isEditingStyle = false;
              });
            } else {
              // Revert all style changes
              if (_originalStyle != null) {
                controller.updateActiveStyle(_originalStyle!);
              }
              setState(() {
                _isEditingStyle = false;
              });
            }
          },
        ),

        // Title text
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),

        // Done Button
        _buildHeaderKnob(
          icon: Icons.check_rounded,
          tooltip: 'Done',
          onPressed: () {
            if (_isEditingUndertone) {
              setState(() {
                _isEditingUndertone = false;
                _isEditingStyle = false;
              });
            } else {
              // Commit all changes
              setState(() {
                _isEditingStyle = false;
              });
            }
          },
        ),
      ],
    ),
  );

  Widget _buildActiveStyleControl(
    CameraState state,
    CameraController controller,
  ) {
    if (_isEditingUndertone) {
      return RanaInteractiveUndertonePad(
        undertoneX: state.activeStyle.undertoneX,
        undertoneY: state.activeStyle.undertoneY,
        styleStrength: state.activeStyle.styleStrength,
        maxPadSize: 188,
        contentPadding: EdgeInsets.zero,
        onChanged: (x, y) {
          controller.updateActiveStyle(
            state.activeStyle.copyWith(undertoneX: x, undertoneY: y),
          );
        },
      );
    }

    switch (_activeStyleTab) {
      case 0:
        return RanaInteractiveSlider(
          key: const Key('slider-tone'),
          label: 'Tone',
          valueLabel: _formatSliderValue(state.activeStyle.tone),
          value: state.activeStyle.tone,
          min: -100,
          max: 100,
          bottomPadding: 4,
          labelGap: 4,
          toneReadout: _formatSliderValue(state.activeStyle.tone),
          colorReadout: _formatSliderValue(state.activeStyle.color),
          warmthReadout: _formatSliderValue(state.activeStyle.undertoneX * 100),
          onChanged: (val) {
            controller.updateActiveStyle(state.activeStyle.copyWith(tone: val));
          },
        );
      case 1:
        return RanaInteractiveSlider(
          key: const Key('slider-color'),
          label: 'Color',
          valueLabel: _formatSliderValue(state.activeStyle.color),
          value: state.activeStyle.color,
          min: -100,
          max: 100,
          bottomPadding: 4,
          labelGap: 4,
          toneReadout: _formatSliderValue(state.activeStyle.tone),
          colorReadout: _formatSliderValue(state.activeStyle.color),
          warmthReadout: _formatSliderValue(state.activeStyle.undertoneX * 100),
          onChanged: (val) {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(color: val),
            );
          },
        );
      case 2:
        return RanaInteractiveSlider(
          key: const Key('slider-palette'),
          label: 'Palette',
          valueLabel: _formatPaletteValue(state.activeStyle.styleStrength),
          value: state.activeStyle.styleStrength,
          min: 0,
          max: 100,
          bottomPadding: 4,
          labelGap: 4,
          toneReadout: _formatSliderValue(state.activeStyle.tone),
          colorReadout: _formatSliderValue(state.activeStyle.color),
          warmthReadout: _formatSliderValue(state.activeStyle.undertoneX * 100),
          onChanged: (val) {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(styleStrength: val),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatSliderValue(double value) {
    final rounded = value.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  String _formatPaletteValue(double value) => '${value.round()}';

  Widget _buildStylesSelectorTabBar() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('Tone', 0),
        _buildTabButton('Color', 1),
        _buildTabButton('Palette', 2),
        _buildTabButton('Undertone', 3),
      ],
    ),
  );

  Widget _buildTabButton(String label, int index) {
    final isSelected = index == 3
        ? _isEditingUndertone
        : (_activeStyleTab == index && !_isEditingUndertone);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (index == 3) {
            _isEditingUndertone = true;
            _isEditingStyle = false;
          } else {
            _isEditingUndertone = false;
            _isEditingStyle = true;
            _activeStyleTab = index;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFF4C44F), Color(0xFFF39C12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.black.withValues(alpha: 0.36),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF4C44F).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color iconColor = Colors.white70,
    String? tooltip,
  }) => Tooltip(
    message: tooltip ?? '',
    child: ClipOval(
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    ),
  );

  Widget _buildHeaderKnob({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.15, -0.2),
                colors: isEnabled
                    ? const [
                        Color(0xFF3E424B),
                        Color(0xFF202227),
                        Color(0xFF131416),
                      ]
                    : const [
                        Color(0xFF24262A),
                        Color(0xFF181A1C),
                        Color(0xFF0F1011),
                      ],
                stops: const [0.0, 0.7, 1.0],
              ),
              border: Border.all(
                color: isEnabled
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                width: 0.8,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isEnabled ? const Color(0xFFF39C12) : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextButton({
    required String text,
    required VoidCallback? onPressed,
    Key? actionKey,
    String? tooltip,
    bool isLocked = false,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: isLocked ? 'Film Roll recipe locked' : (tooltip ?? ''),
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: isLocked ? 'Aspect ratio locked by active Film Roll' : text,
        hint: isLocked
            ? 'End or abandon the Film Roll to change the aspect ratio'
            : null,
        child: ClipOval(
          child: Material(
            color: Colors.black.withValues(alpha: 0.4),
            child: InkWell(
              key: actionKey,
              onTap: onPressed,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.white24,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLocked)
                      const Positioned(
                        right: 7,
                        bottom: 7,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFF4C44F),
                          size: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelfTimerButton(CameraState state, CameraController controller) {
    final isRunning = state.isSelfTimerRunning;
    final hasSelection = state.selfTimerMode.isEnabled;
    final label = isRunning
        ? state.selfTimerRemainingSeconds.toString()
        : state.selfTimerMode.label;
    final tooltip = isRunning
        ? 'Self Timer: ${state.selfTimerRemainingSeconds}s remaining'
        : 'Self Timer: ${state.selfTimerMode.label}';

    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: Material(
          color: Colors.black.withValues(alpha: 0.4),
          child: InkWell(
            onTap:
                state.isCameraInitialized &&
                    state.captureStatus == CaptureStatus.idle
                ? controller.cycleSelfTimer
                : null,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    );
                    return FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: hasSelection
                      ? Text(
                          label,
                          key: ValueKey<String>(label),
                          style: TextStyle(
                            color: isRunning
                                ? const Color(0xFFF39C12)
                                : Colors.white,
                            fontSize: isRunning ? 12 : 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isRunning ? 0.3 : 0.8,
                          ),
                        )
                      : Icon(
                          Icons.timer_outlined,
                          key: const ValueKey<String>('timer_icon'),
                          color: state.isCameraInitialized
                              ? Colors.white70
                              : Colors.white24,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlayControls(
    CameraState state,
    CameraController controller, {
    required bool isRollActive,
  }) {
    final canInteract =
        state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;
    IconData flashIcon;
    Color flashColor;
    switch (state.flashMode) {
      case FlashMode.off:
        flashIcon = Icons.flash_off_rounded;
        flashColor = Colors.white70;
      case FlashMode.on:
        flashIcon = Icons.flash_on_rounded;
        flashColor = const Color(0xFFF1C40F); // Vivid yellow
      case FlashMode.auto:
        flashIcon = Icons.flash_auto_rounded;
        flashColor = const Color(0xFFE67E22); // Orange accent
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Flash Mode Button
        _buildGlassIconButton(
          icon: flashIcon,
          iconColor: flashColor,
          tooltip: 'Flash: ${state.flashMode.label}',
          onPressed: canInteract ? controller.toggleFlashMode : null,
        ),

        // Aspect Ratio Button
        _buildGlassTextButton(
          text: state.aspectRatio.label,
          actionKey: const ValueKey<String>('camera-aspect-ratio-control'),
          tooltip: isRollActive
              ? 'Film Roll recipe locked'
              : 'Aspect Ratio: ${state.aspectRatio.label}',
          onPressed: canInteract && !isRollActive
              ? controller.cycleAspectRatio
              : null,
          isLocked: isRollActive,
        ),

        // Timer Button
        _buildSelfTimerButton(state, controller),

        // Camera Flip Button
        _buildGlassIconButton(
          icon: Icons.flip_camera_android_rounded,
          tooltip: 'Flip Lens',
          onPressed: canInteract ? controller.toggleLens : null,
        ),

        // Settings Button
        _buildGlassIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ],
    );
  }

  Widget _buildThumbnailButton(CameraState state) => SizedBox(
    width: 44,
    height: 60,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey<String>('camera-gallery-action'),
            onTap: () => context.go(AppRoutes.gallery),
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.15, -0.2),
                      colors: [
                        Color(0xFF3E424B),
                        Color(0xFF202227),
                        Color(0xFF131416),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child:
                        state.lastCapturedPath != null &&
                            state.lastCapturedPath!.isNotEmpty
                        ? LatestCaptureThumbnail(
                            imageUri: state.lastCapturedPath,
                          )
                        : const Center(
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'GALLERY',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
  Widget _buildViewfinder(
    CameraState state,
    CameraController controller, {
    required FilmRollState rollState,
    required _ViewfinderLayoutMode layoutMode,
  }) {
    final presetsList = ref.watch(presetsProvider).valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);
    final isReady =
        state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;
    final activeRoll = rollState.activeRoll;
    final isRollActive = rollState.hasActiveRoll;
    final presetLeadingIcon = isRollActive
        ? Icons.lock_outline_rounded
        : Icons.photo_camera_back_rounded;
    final presetTrailingIcon = isRollActive
        ? Icons.lock_rounded
        : Icons.keyboard_arrow_up_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = _previewGateSize(
                constraints,
                state.aspectRatio.viewfinderRatio,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: SizedBox(
                      width: previewSize.width,
                      height: previewSize.height,
                      child: _buildPreviewGate(state, controller),
                    ),
                  ),

                  // Top controls stay anchored to the fixed camera stage.
                  if (layoutMode == _ViewfinderLayoutMode.capture)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildTopOverlayControls(
                        state,
                        controller,
                        isRollActive: isRollActive,
                      ),
                    ),

                  if (layoutMode == _ViewfinderLayoutMode.capture &&
                      activeRoll != null &&
                      activeRoll.isActive)
                    Positioned(
                      top: _isFocusLocked ? 96 : 68,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: RollHudPill(
                          roll: activeRoll,
                          pendingExposures: rollState.pendingExposureCount,
                          onTap: () => unawaited(
                            _showRollInfoSheet(
                              activeRoll,
                              rollState.pendingExposureCount,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating preset selector at the viewfinder bottom center.
                  if (layoutMode == _ViewfinderLayoutMode.capture)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Semantics(
                          button: true,
                          enabled: isReady && !isRollActive,
                          label: isRollActive
                              ? 'Preset locked by Film Roll'
                              : 'Select preset',
                          hint: isRollActive
                              ? 'End or abandon the Film Roll to change '
                                    'the preset'
                              : null,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const ValueKey<String>(
                                'camera-preset-selector',
                              ),
                              onTap: isReady && !isRollActive
                                  ? () {
                                      setState(() {
                                        _originalPresetId =
                                            state.activePresetId;
                                        _isSelectingPreset = true;
                                      });
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(22),
                              child: SizedBox(
                                height: 44,
                                child: Center(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: isRollActive ? 0.45 : 1,
                                    child: AnimatedContainer(
                                      key: const ValueKey<String>(
                                        'camera-preset-selector-surface',
                                      ),
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      height: 34,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(17),
                                        gradient: const RadialGradient(
                                          center: Alignment(-0.15, -0.2),
                                          colors: [
                                            Color(0xFF3E424B),
                                            Color(0xFF202227),
                                            Color(0xFF131416),
                                          ],
                                          stops: [0, 0.7, 1],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.09,
                                          ),
                                          width: 0.8,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            presetLeadingIcon,
                                            size: 12,
                                            color: const Color(0xFFF39C12),
                                          ),
                                          const SizedBox(width: 6),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 124,
                                            ),
                                            child: Text(
                                              (activePreset?.name ?? 'NORMAL')
                                                  .toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFF39C12),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.5,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            presetTrailingIcon,
                                            size: 13,
                                            color: Colors.white60,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Self timer countdown overlay
                  if (state.isSelfTimerRunning)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.18),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                final fade = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                );
                                return FadeTransition(
                                  opacity: fade,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.92, end: 1)
                                        .animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                key: ValueKey<int>(
                                  state.selfTimerRemainingSeconds,
                                ),
                                width: 132,
                                height: 132,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.56),
                                  border: Border.all(
                                    color: const Color(0xFFF39C12),
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${state.selfTimerRemainingSeconds}',
                                      style: const TextStyle(
                                        color: Color(0xFFF39C12),
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'SELF TIMER',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Size _previewGateSize(BoxConstraints constraints, double aspectRatio) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;
    if (!maxWidth.isFinite ||
        !maxHeight.isFinite ||
        maxWidth <= 0 ||
        maxHeight <= 0 ||
        aspectRatio <= 0) {
      return Size.zero;
    }

    final fittedWidth = math.min(maxWidth, maxHeight * aspectRatio);
    return Size(fittedWidth, fittedWidth / aspectRatio);
  }

  Widget _buildPreviewGate(CameraState state, CameraController controller) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleViewfinderTap(details, constraints),
            onScaleStart: _handleViewfinderScaleStart,
            onScaleUpdate: _handleViewfinderScaleUpdate,
            onScaleEnd: _handleViewfinderScaleEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live Camera Viewfinder Preview
                if (_previewMetricsStable)
                  _AndroidCameraPreview(
                    key: ValueKey<String>(
                      'camera-preview-${state.aspectRatio.platformValue}-'
                      '$_previewGeneration',
                    ),
                    onPlatformViewCreated: (platformViewId) {
                      unawaited(
                        _initializePreview(platformViewId, _previewGeneration),
                      );
                    },
                  )
                else
                  const ColoredBox(
                    key: ValueKey<String>('camera-preview-metrics-gate'),
                    color: Colors.black,
                  ),

                // 3x3 Composition Grid Lines
                if (ref.watch(gridLinesProvider)) const _ViewfinderGrid(),

                // Focus lock point indicator (Focus Ring)
                if (_tapFocusPoint != null)
                  Positioned(
                    left: _tapFocusPoint!.dx - 30,
                    top: _tapFocusPoint!.dy - 30,
                    child: _FocusRing(controller: _focusAnimationController),
                  ),

                // AE/AF Lock indicator
                if (_isFocusLocked)
                  Positioned(
                    top: 46,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _resetFocus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF39C12)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFF39C12),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'AE/AF LOCK',
                                style: TextStyle(
                                  color: Color(0xFFF39C12),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Native zoom indicator and reset affordance (placed cleanly
                // above the floating preset selector overlay).
                if (state.isCameraInitialized)
                  Positioned(
                    bottom: 64,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _ZoomIndicator(
                        zoomRatio: state.zoomRatio,
                        isEnabled:
                            state.captureStatus == CaptureStatus.idle &&
                            !state.isSelfTimerRunning,
                        isLimited:
                            state.isZoomLimited &&
                            state.zoomRatio >=
                                state.effectiveMaxZoomRatio - 0.01,
                        shouldWarnDigitalZoom: state.shouldWarnDigitalZoom,
                        onReset: () {
                          unawaited(controller.setZoomRatio(userMinZoomRatio));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildBottomPanel(
    CameraState state,
    CameraController controller, {
    required FilmRollState rollState,
  }) {
    final presetsAsync = ref.watch(presetsProvider);
    final isReady =
        state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;

    final presetsList = presetsAsync.valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);
    final isRollActive = rollState.hasActiveRoll;
    final shutterBlockReason = _shutterBlockReason(state, rollState);
    final canUseShutter = isReady && shutterBlockReason == null;
    final canOpenFilmRoll =
        isRollActive ||
        (state.isCameraInitialized &&
            rollState.restorationStatus == FilmRollRestorationStatus.ready &&
            state.captureStatus == CaptureStatus.idle &&
            !state.isSelfTimerRunning);

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shutter status label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _shutterStatus == ShutterStatus.ready
                      ? Colors.white24
                      : const Color(0xFFF4C44F),
                  boxShadow: _shutterStatus == ShutterStatus.ready
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFFF4C44F,
                            ).withValues(alpha: 0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _shutterStatusName(_shutterStatus),
                style: TextStyle(
                  color: _shutterStatus == ShutterStatus.ready
                      ? Colors.white38
                      : const Color(0xFFF4C44F),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            key: const ValueKey<String>('camera-bottom-controls'),
            width: double.infinity,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 8,
                  width: 96,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThumbnailButton(state),
                      const SizedBox(width: 8),
                      _BottomPanelActionButton(
                        actionKey: const ValueKey<String>('camera-film-action'),
                        label: 'FILM',
                        icon: Icons.local_movies_outlined,
                        isEnabled: canOpenFilmRoll,
                        onPressed: () => unawaited(_showFilmRollSheet(state)),
                        tooltip: isRollActive
                            ? 'Film Roll: ${rollState.activeRoll!.exposuresTaken}/'
                                  '${rollState.activeRoll!.size.count}'
                            : 'Load Film Roll',
                      ),
                    ],
                  ),
                ),
                PremiumShutterButton(
                  key: const ValueKey<String>('camera-shutter-button'),
                  isEnabled: canUseShutter,
                  disabledReason: shutterBlockReason,
                  onStatusChanged: (status) {
                    setState(() {
                      _shutterStatus = status;
                    });
                  },
                  onCapture: () => _handleCapture(controller),
                ),
                Positioned(
                  right: 8,
                  width: 96,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BottomPanelActionButton(
                        actionKey: const ValueKey<String>(
                          'camera-reset-action',
                        ),
                        label: 'RESET',
                        icon: Icons.replay_rounded,
                        isEnabled:
                            isReady &&
                            !isRollActive &&
                            activePreset != null &&
                            state.activeStyle !=
                                (activePreset.style ?? const RanaStyle()),
                        onPressed: controller.resetActiveStyle,
                        tooltip: isRollActive
                            ? 'Film Roll recipe locked'
                            : 'Reset Style',
                        isLocked: isRollActive,
                      ),
                      const SizedBox(width: 8),
                      _BottomPanelActionButton(
                        actionKey: const ValueKey<String>(
                          'camera-style-action',
                        ),
                        label: 'STYLE',
                        icon: Icons.tune_rounded,
                        isEnabled:
                            isReady && !isRollActive && activePreset != null,
                        onPressed: () {
                          setState(() {
                            _originalStyle = state.activeStyle;
                            _isEditingStyle = true;
                            _isEditingUndertone = false;
                            _activeStyleTab = 0;
                          });
                        },
                        tooltip: isRollActive
                            ? 'Film Roll recipe locked'
                            : 'Rana Style',
                        isLocked: isRollActive,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _shutterBlockReason(CameraState state, FilmRollState rollState) {
    if (!state.isCameraInitialized) return 'Camera is still initializing.';
    if (state.captureStatus != CaptureStatus.idle) {
      return 'A photo is currently being captured.';
    }
    if (state.isSelfTimerRunning) return 'The self timer is running.';
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
      return 'The locked Film Roll recipe is unavailable. '
          'Retry Recipe, End Roll, or Abandon Roll.';
    }
    if (rollState.recipeStatus == FilmRollRecipeStatus.applying ||
        state.activeFilmRollRecipeStatus ==
            ActiveFilmRollRecipeStatus.restoring) {
      return 'The locked Film Roll recipe is restoring.';
    }
    if (rollState.hasPendingSaveRecovery) {
      return 'A saved Film Roll frame needs recovery before you can '
          'shoot again.';
    }
    if (rollState.cannotReserveExposure) {
      return 'Film Roll capacity is full, including frames still processing.';
    }
    return null;
  }

  Future<void> _confirmDeleteStyle(PresetModel preset) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17171B),
        title: const Text(
          'DELETE STYLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        content: Text(
          preset.name,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await ref.read(savedRanaStyleRepositoryProvider).delete(preset.id);
    ref.invalidate(presetsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DELETED STYLE ${preset.name.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _BottomPanelActionButton extends StatelessWidget {
  const _BottomPanelActionButton({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
    this.tooltip,
    this.isLocked = false,
  });

  final Key actionKey;
  final String label;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isLocked;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: isLocked ? 'Film Roll recipe locked' : (tooltip ?? label),
    child: Semantics(
      button: true,
      enabled: isEnabled,
      label: isLocked ? '$label locked by active Film Roll' : label,
      hint: isLocked
          ? 'End or abandon the Film Roll to change this setting'
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: actionKey,
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.15, -0.2),
                      colors: isEnabled
                          ? const [
                              Color(0xFF3E424B),
                              Color(0xFF202227),
                              Color(0xFF131416),
                            ]
                          : const [
                              Color(0xFF24262A),
                              Color(0xFF181A1C),
                              Color(0xFF0F1011),
                            ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: isEnabled
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.03),
                      width: 0.8,
                    ),
                    boxShadow: isEnabled
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_outline_rounded : icon,
                    size: 17,
                    color: isEnabled
                        ? const Color(0xFFF39C12)
                        : (isLocked ? const Color(0xFFF4C44F) : Colors.white24),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isEnabled ? Colors.white70 : Colors.white24,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ViewfinderGrid extends StatelessWidget {
  const _ViewfinderGrid();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Row(
        children: [
          const Spacer(),
          Container(width: 1, color: Colors.white12),
          const Spacer(),
          Container(width: 1, color: Colors.white12),
          const Spacer(),
        ],
      ),
      Column(
        children: [
          const Spacer(),
          Container(height: 1, color: Colors.white12),
          const Spacer(),
          Container(height: 1, color: Colors.white12),
          const Spacer(),
        ],
      ),
    ],
  );
}

class _AndroidCameraPreview extends StatelessWidget {
  const _AndroidCameraPreview({super.key, this.onPlatformViewCreated});

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'com.rana.app/camera_preview',
    layoutDirection: TextDirection.ltr,
    hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    onPlatformViewCreated: onPlatformViewCreated,
  );
}

class _ZoomIndicator extends StatelessWidget {
  const _ZoomIndicator({
    required this.zoomRatio,
    required this.isEnabled,
    required this.isLimited,
    required this.shouldWarnDigitalZoom,
    required this.onReset,
  });

  final double zoomRatio;
  final bool isEnabled;
  final bool isLimited;
  final bool shouldWarnDigitalZoom;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isZoomed = zoomRatio > userMinZoomRatio + 0.01;
    final foreground = shouldWarnDigitalZoom
        ? const Color(0xFFFFC857)
        : isZoomed
        ? const Color(0xFFF39C12)
        : Colors.white70;
    final label = '${zoomRatio.toStringAsFixed(1)}x';
    final displayLabel = isLimited
        ? '$label MAX'
        : shouldWarnDigitalZoom
        ? '$label DIGI'
        : label;
    final tooltip = shouldWarnDigitalZoom
        ? 'Likely Digital Zoom'
        : isZoomed
        ? 'Reset Zoom'
        : 'Zoom';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: shouldWarnDigitalZoom
            ? 'Zoom $label likely digital'
            : 'Zoom $label',
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: isEnabled && isZoomed ? onReset : null,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 10,
                      offset: Offset(0, 1),
                    ),
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(displayLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final scale = Tween<double>(begin: 1.6, end: 1)
          .animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
          )
          .value;
      final opacity =
          TweenSequence<double>([
                TweenSequenceItem(
                  tween: Tween<double>(begin: 1, end: 1),
                  weight: 40,
                ),
                TweenSequenceItem(
                  tween: Tween<double>(begin: 1, end: 0.4),
                  weight: 60,
                ),
              ])
              .animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              )
              .value;

      return Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF39C12), width: 1.5),
            ),
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF39C12),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
