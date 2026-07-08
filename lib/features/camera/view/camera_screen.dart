import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';
import 'package:rana/features/camera/widgets/style_mood_chips.dart';
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

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ProviderSubscription<CameraState> _cameraStateSubscription;

  bool _isEditingStyle = false;
  bool _isEditingUndertone = false;
  int _activeStyleTab = 0; // 0: Tone, 1: Color, 2: Palette
  RanaStyle? _originalStyle;
  double _originalUndertoneX = 0;
  double _originalUndertoneY = 0;
  bool _isSelectingPreset = false;
  String? _originalPresetId;

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
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addObserver(this);
    _cameraStateSubscription = ref.listenManual<CameraState>(
      cameraControllerProvider,
      (previous, next) {
        final enteredSuccess =
            previous?.captureStatus != CaptureStatus.success &&
            next.captureStatus == CaptureStatus.success;
        final imageUri = next.lastCapturedPath;
        if (!enteredSuccess || imageUri == null) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(context.push(AppRoutes.result, extra: imageUri));
        });
      },
    );

    // Verify permissions first, then initialize platform connection if granted
    Future.microtask(() async {
      await ref.read(permissionControllerProvider.notifier).checkPermissions();
      if (ref.read(permissionControllerProvider).isAllGranted) {
        await ref.read(cameraControllerProvider.notifier).initialize();
      }
    });
  }

  @override
  void dispose() {
    _cameraStateSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    _focusResetTimer?.cancel();
    _focusAnimationController.dispose();
    super.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.i('CameraScreen', 'App lifecycle changed to: $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(cameraControllerProvider.notifier).releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(permissionControllerProvider.notifier).checkPermissions().then((
        _,
      ) {
        if (ref.read(permissionControllerProvider).isAllGranted) {
          ref.read(cameraControllerProvider.notifier).initialize();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionControllerProvider);
    final cameraState = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    if (permissionState.isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F11),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF39C12)),
          ),
        ),
      );
    }

    if (!permissionState.isAllGranted) {
      return const PermissionScreen();
    }

    final isEditing = _isEditingStyle || _isEditingUndertone;
    final editingTitle = _isEditingUndertone ? 'Undertone' : 'Rana Styles';
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Premium deep dark slate
      body: SafeArea(
        child: Column(
          children: [
            if (isEditing)
              _buildStylesEditingHeader(editingTitle, cameraState, controller)
            else if (_isSelectingPreset)
              _buildPresetSelectionHeader(cameraState, controller)
            else
              const SizedBox.shrink(),

            Expanded(
              child: _buildViewfinder(
                cameraState,
                controller,
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
              _buildBottomPanel(cameraState, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildStylesEditingContent(
    CameraState state,
    CameraController controller,
  ) {
    final presetsList = ref.watch(presetsProvider).valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);

    return Column(
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
          _buildCompactValuesRow(state.activeStyle),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _buildActiveStyleControl(state, controller),
          ),
        ],

        if (_isEditingUndertone)
          _buildUndertoneActionsRow(state, controller)
        else
          _buildStylesSelectorTabBar(),
      ],
    );
  }

  Widget _buildPresetSelectionHeader(
    CameraState state,
    CameraController controller,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
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
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const Text(
              'SELECT PRESET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectingPreset = false;
                });
              },
              child: const Text(
                'DONE',
                style: TextStyle(
                  color: Color(0xFFF39C12),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildPresetSelectionContent(
    CameraState state,
    CameraController controller,
  ) =>
      SizedBox(
        height: 280,
        child: ref.watch(presetsProvider).when(
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
        IconButton(
          onPressed: () {
            if (_isEditingUndertone) {
              // Revert only undertone changes from this session
              controller.updateActiveStyle(
                state.activeStyle.copyWith(
                  undertoneX: _originalUndertoneX,
                  undertoneY: _originalUndertoneY,
                ),
              );
              setState(() {
                _isEditingUndertone = false;
                _isEditingStyle = true;
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),

        // Title text
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),

        // Done Button
        TextButton(
          onPressed: () {
            if (_isEditingUndertone) {
              // Save undertone coordinate (by returning to sliders view)
              setState(() {
                _isEditingUndertone = false;
                _isEditingStyle = true;
              });
            } else {
              // Commit all changes
              setState(() {
                _isEditingStyle = false;
              });
            }
          },
          child: Text(
            _isEditingUndertone ? 'APPLY' : 'DONE',
            style: const TextStyle(
              color: Color(0xFFF39C12),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCompactValuesRow(RanaStyle style) {
    final toneVal = style.tone.round();
    final colorVal = style.color.round();
    final paletteVal = style.styleStrength.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCompactValueLabel('TONE', toneVal),
          const SizedBox(width: 18),
          _buildCompactValueLabel('COLOR', colorVal),
          const SizedBox(width: 18),
          _buildCompactValueLabel('PALETTE', paletteVal),
        ],
      ),
    );
  }

  Widget _buildCompactValueLabel(String label, int value) => RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 10,
        fontFamily: 'monospace',
        letterSpacing: 0.5,
      ),
      children: [
        TextSpan(
          text: '$label ',
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '$value',
          style: const TextStyle(
            color: Color(0xFFF39C12),
            fontWeight: FontWeight.w900,
          ),
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

  Widget _buildStylesSelectorTabBar() => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
      color: Colors.black26,
    ),
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
    final color = isSelected ? const Color(0xFFF39C12) : Colors.white54;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (index == 3) {
            final activeStyle = ref.read(cameraControllerProvider).activeStyle;
            _originalUndertoneX = activeStyle.undertoneX;
            _originalUndertoneY = activeStyle.undertoneY;
            _isEditingUndertone = true;
            _isEditingStyle = false;
          } else {
            _isEditingUndertone = false;
            _isEditingStyle = true;
            _activeStyleTab = index;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildUndertoneActionsRow(
    CameraState state,
    CameraController controller,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 5),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
      color: Colors.black26,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCompactActionButton(
          label: 'RESET',
          color: Colors.white54,
          onPressed: () {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(undertoneX: 0, undertoneY: 0),
            );
          },
        ),
        _buildCompactActionButton(
          label: 'APPLY',
          color: const Color(0xFFF39C12),
          onPressed: () {
            setState(() {
              _isEditingUndertone = false;
              _isEditingStyle = true;
            });
          },
        ),
      ],
    ),
  );

  Widget _buildCompactActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );

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

  Widget _buildGlassTextButton({
    required String text,
    required VoidCallback? onPressed,
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
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

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
    CameraController controller,
  ) {
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
          tooltip: 'Aspect Ratio: ${state.aspectRatio.label}',
          onPressed: canInteract ? controller.cycleAspectRatio : null,
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

  Widget _buildThumbnailButton(CameraState state) {
    final path = state.lastCapturedPath;
    final fileExists = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => context.go(AppRoutes.gallery),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: fileExists
              ? Image.file(File(path), fit: BoxFit.cover, width: 54, height: 54)
              : const ColoredBox(
                  color: Color(0xFF1E1E24),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white54,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(
    CameraState state,
    CameraController controller, {
    required _ViewfinderLayoutMode layoutMode,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: _buildTopOverlayControls(state, controller),
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

                // Capture animation overlay
                if (state.captureStatus == CaptureStatus.capturing)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.70),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFFF39C12),
                            size: 32,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'CAPTURING...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (state.captureStatus == CaptureStatus.processing)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.76),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFF39C12),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'DEVELOPING FILM...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Camera shutter flash screen effect
                if (state.captureStatus == CaptureStatus.success ||
                    state.captureStatus == CaptureStatus.error)
                  _FlashScreenEffect(
                    success: state.captureStatus == CaptureStatus.success,
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

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

  Widget _buildPreviewGate(CameraState state, CameraController controller) {
    final presetsAsync = ref.watch(presetsProvider);
    final presetsList = presetsAsync.valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);

    return ClipRRect(
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
              _AndroidCameraPreview(
                key: ValueKey<String>(
                  'camera-preview-${state.aspectRatio.platformValue}',
                ),
                aspectRatio: state.aspectRatio,
                lens: state.activeLens,
                flashMode: state.flashMode,
                zoomRatio: state.zoomRatio,
                onPlatformViewCreated: (_) {
                  unawaited(controller.reapplyActivePreviewParams());
                },
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

              // Native zoom indicator and reset affordance.
              if (state.isCameraInitialized)
                Positioned(
                  top: 12,
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
                          state.zoomRatio >= state.effectiveMaxZoomRatio - 0.01,
                      onReset: () {
                        unawaited(controller.setZoomRatio(userMinZoomRatio));
                      },
                    ),
                  ),
                ),

              // Minimalist active preset stamp (bottom-right)
              if (activePreset != null)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Opacity(
                    opacity: 0.9,
                    child: Text(
                      activePreset.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        // Vintage orange stamp color
                        color: Color(0xFFF39C12),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 2,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(CameraState state, CameraController controller) {
    final presetsAsync = ref.watch(presetsProvider);
    final isReady =
        state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;

    final presetsList = presetsAsync.valueOrNull ?? [];
    final activePreset = _findActivePreset(state, presetsList);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          // Single clean active preset selector pill button
          Center(
            child: GestureDetector(
              onTap: isReady
                  ? () {
                      setState(() {
                        _originalPresetId = state.activePresetId;
                        _isSelectingPreset = true;
                      });
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A), // Match visual layout
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_back_outlined,
                      size: 14,
                      color: Color(0xFFF39C12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (activePreset?.name ?? 'NORMAL').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFF39C12),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 14,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Shutter Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Circular thumbnail (left) - tapping opens gallery
              SizedBox(
                width: 120,
                child: Center(child: _buildThumbnailButton(state)),
              ),

              // Shutter capture button (center)
              GestureDetector(
                onTap: isReady ? controller.handleShutterPressed : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.transparent,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isCameraInitialized
                          ? Colors.white
                          : Colors.white12,
                    ),
                  ),
                ),
              ),

              // Style and Reset Button (right)
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _BottomPanelActionButton(
                        label: 'RESET',
                        icon: Icons.replay_rounded,
                        isEnabled:
                            isReady &&
                            activePreset != null &&
                            state.activeStyle !=
                                (activePreset.style ?? const RanaStyle()),
                        onPressed: controller.resetActiveStyle,
                        tooltip: 'Reset Style',
                      ),
                    ),
                    Expanded(
                      child: _BottomPanelActionButton(
                        label: 'STYLE',
                        icon: Icons.tune_rounded,
                        isEnabled: isReady && activePreset != null,
                        onPressed: () {
                          setState(() {
                            _originalStyle = state.activeStyle;
                            _originalUndertoneX = state.activeStyle.undertoneX;
                            _originalUndertoneY = state.activeStyle.undertoneY;
                            _isEditingStyle = true;
                            _isEditingUndertone = false;
                            _activeStyleTab = 0;
                          });
                        },
                        tooltip: 'Rana Style',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? label,
    child: TextButton(
      onPressed: isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: isEnabled ? const Color(0xFFF39C12) : Colors.white24,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
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

class _FlashScreenEffect extends StatefulWidget {
  const _FlashScreenEffect({required this.success});

  final bool success;

  @override
  State<_FlashScreenEffect> createState() => _FlashScreenEffectState();
}

class _FlashScreenEffectState extends State<_FlashScreenEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 85),
    ]).animate(_animController);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacityAnim,
    child: Container(
      color: widget.success ? Colors.white : Colors.red.withValues(alpha: 0.4),
    ),
  );
}

class _AndroidCameraPreview extends StatelessWidget {
  const _AndroidCameraPreview({
    required this.aspectRatio,
    required this.lens,
    required this.flashMode,
    required this.zoomRatio,
    super.key,
    this.onPlatformViewCreated,
  });

  final CameraAspectRatio aspectRatio;
  final CameraLens lens;
  final FlashMode flashMode;
  final double zoomRatio;
  final PlatformViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'com.rana.app/camera_preview',
    layoutDirection: TextDirection.ltr,
    creationParams: <String, dynamic>{
      'aspectRatio': aspectRatio.platformValue,
      'lens': lens.value,
      'flashMode': flashMode.name,
      'zoomRatio': zoomRatio,
    },
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: onPlatformViewCreated,
  );
}

class _ZoomIndicator extends StatelessWidget {
  const _ZoomIndicator({
    required this.zoomRatio,
    required this.isEnabled,
    required this.isLimited,
    required this.onReset,
  });

  final double zoomRatio;
  final bool isEnabled;
  final bool isLimited;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isZoomed = zoomRatio > userMinZoomRatio + 0.01;
    final foreground = isZoomed ? const Color(0xFFF39C12) : Colors.white70;
    final label = '${zoomRatio.toStringAsFixed(1)}x';
    final tooltip = isZoomed ? 'Reset Zoom' : 'Zoom';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: 'Zoom $label',
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
                child: Text(isLimited ? '$label  MAX' : label),
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
