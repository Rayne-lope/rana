import 'dart:async';
import 'dart:io';

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
import 'package:rana/features/camera/widgets/preset_chip_widget.dart';
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';
import 'package:rana/features/preset/repository/saved_rana_style_repository.dart';
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

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  late final ProviderSubscription<CameraState> _cameraStateSubscription;
  final GlobalKey _previewKey = GlobalKey(debugLabel: 'camera-preview');

  bool _isEditingStyle = false;
  bool _isEditingUndertone = false;
  int _activeStyleTab = 0; // 0: Tone, 1: Color, 2: Texture
  RanaStyle? _originalStyle;
  double _originalUndertoneX = 0;
  double _originalUndertoneY = 0;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
            else
              const SizedBox.shrink(),

            Flexible(
              fit: isEditing ? FlexFit.loose : FlexFit.tight,
              child: SizedBox(
                height: isEditing ? _editingPreviewHeight(context) : null,
                child: _buildViewfinder(cameraState, controller),
              ),
            ),

            if (isEditing)
              Expanded(
                child: _buildStylesEditingContent(cameraState, controller),
              )
            else
              _buildBottomPanel(cameraState, controller),
          ],
        ),
      ),
    );
  }

  double _editingPreviewHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final factor = _isEditingUndertone ? 0.50 : 0.58;
    return screenHeight * factor;
  }

  Widget _buildStylesEditingContent(
    CameraState state,
    CameraController controller,
  ) => Column(
    children: [
      _buildCompactValuesRow(state.activeStyle),

      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildActiveStyleControl(state, controller),
          ),
        ),
      ),

      if (_isEditingUndertone)
        _buildUndertoneActionsRow(state, controller)
      else
        _buildStylesSelectorTabBar(),
    ],
  );

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
    final textureVal = style.texture.round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCompactValueLabel('TONE', toneVal),
          const SizedBox(width: 24),
          _buildCompactValueLabel('COLOR', colorVal),
          const SizedBox(width: 24),
          _buildCompactValueLabel('TEXTURE', textureVal),
        ],
      ),
    );
  }

  Widget _buildCompactValueLabel(String label, int value) => RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 11,
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
          onChanged: (val) {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(color: val),
            );
          },
        );
      case 2:
        return RanaInteractiveSlider(
          key: const Key('slider-texture'),
          label: 'Texture',
          valueLabel: _formatSliderValue(state.activeStyle.texture),
          value: state.activeStyle.texture,
          min: 0,
          max: 100,
          onChanged: (val) {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(texture: val),
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

  Widget _buildStylesSelectorTabBar() => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
      color: Colors.black26,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('Tone', 0),
        _buildTabButton('Color', 1),
        _buildTabButton('Texture', 2),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
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
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
      color: Colors.black26,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () {
            controller.updateActiveStyle(
              state.activeStyle.copyWith(undertoneX: 0, undertoneY: 0),
            );
          },
          child: const Text(
            'RESET',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isEditingUndertone = false;
              _isEditingStyle = true;
            });
          },
          child: const Text(
            'APPLY',
            style: TextStyle(
              color: Color(0xFFF39C12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
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

  Widget _buildPresetOverlay(CameraState state) {
    final presetsAsync = ref.watch(presetsProvider);
    final presetsList = presetsAsync.valueOrNull ?? [];
    if (presetsList.isEmpty) return const SizedBox.shrink();

    PresetModel? activePreset;
    var activeIndex = 0;
    for (var i = 0; i < presetsList.length; i++) {
      if (presetsList[i].id == state.activePresetId) {
        activePreset = presetsList[i];
        activeIndex = i;
        break;
      }
    }

    if (activePreset == null) return const SizedBox.shrink();

    final showDots = !_isEditingStyle && !_isEditingUndertone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glassmorphic Preset Name Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            activePreset.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        if (showDots) ...[
          const SizedBox(height: 8),
          // Page dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(presetsList.length, (index) {
              final isSelected = index == activeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 6 : 4,
                height: isSelected ? 6 : 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFFF39C12)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ],
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
    CameraController controller,
  ) => AspectRatio(
    aspectRatio: state.aspectRatio.viewfinderRatio,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Live Camera Viewfinder Preview
            _AndroidCameraPreview(
              key: _previewKey,
              onPlatformViewCreated: (_) {
                unawaited(controller.reapplyActivePreviewParams());
              },
            ),

            // 3x3 Composition Grid Lines
            if (ref.watch(gridLinesProvider)) const _ViewfinderGrid(),

            // Date/Time Stamp (Classic Huji/Dazz cam orange stamp)
            Positioned(
              bottom: 16,
              right: 16,
              child: Opacity(
                opacity: 0.85,
                child: Text(
                  _getCurrentDateStamp(),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Color(0xFFF39C12), // Vintage orange stamp color
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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

            // Top controls overlay
            if (!_isEditingStyle && !_isEditingUndertone)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildTopOverlayControls(state, controller),
              ),

            // Bottom active preset & indicator overlay
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildPresetOverlay(state),
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
                              scale: Tween<double>(begin: 0.92, end: 1).animate(
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
                          key: ValueKey<int>(state.selfTimerRemainingSeconds),
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
        ),
      ),
    ),
  );

  Widget _buildBottomPanel(CameraState state, CameraController controller) {
    final presetsAsync = ref.watch(presetsProvider);
    final isReady =
        state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;

    final presetsList = presetsAsync.valueOrNull ?? [];
    PresetModel? activePreset;
    for (final p in presetsList) {
      if (p.id == state.activePresetId) {
        activePreset = p;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          // Simplified horizontal scrollable preset carousel of chips
          presetsAsync.when(
            data: (presetsList) {
              if (presetsList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
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

              return SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: presetsList.length,
                  itemBuilder: (context, index) {
                    final preset = presetsList[index];
                    final isSelected = state.activePresetId == preset.id;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: PresetChipWidget(
                        preset: preset,
                        isSelected: isSelected,
                        isEnabled: isReady,
                        onDeleted:
                            SavedRanaStyle.isSavedStylePresetId(preset.id)
                            ? () => _confirmDeleteStyle(preset)
                            : null,
                        onSelected: (selected) {
                          if (selected) {
                            controller.selectPreset(preset);
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            },
            loading: _buildShimmerLoading,
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(height: 24),

          // Shutter Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Circular thumbnail (left) - tapping opens gallery
              SizedBox(
                width: 72,
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
                // Fit both Reset and Style panel text buttons cleanly
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed:
                          isReady && state.activeStyle != const RanaStyle()
                          ? controller.resetActiveStyle
                          : null,
                      icon: Icon(
                        Icons.replay_rounded,
                        color: state.activeStyle != const RanaStyle()
                            ? const Color(0xFFF39C12)
                            : Colors.white24,
                        size: 22,
                      ),
                      tooltip: 'Reset Style',
                    ),
                    Expanded(
                      child: _StylePanelButton(
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

  String _getCurrentDateStamp() {
    final now = DateTime.now();
    // Formats like: "26 06 22" (YY MM DD)
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year $month $day';
  }

  Widget _buildShimmerLoading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: SizedBox(
          width: 60,
          height: 10,
          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white10)),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Chip(
              backgroundColor: const Color(0xFF1E1E24),
              label: const SizedBox(width: 50, height: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _StylePanelButton extends StatelessWidget {
  const _StylePanelButton({required this.isEnabled, required this.onPressed});

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Rana Style',
    child: TextButton(
      onPressed: isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: isEnabled ? const Color(0xFFF39C12) : Colors.white24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_rounded, size: 22),
          SizedBox(height: 4),
          Text(
            'STYLE',
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
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
  const _AndroidCameraPreview({super.key, this.onPlatformViewCreated});

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'com.rana.app/camera_preview',
    layoutDirection: TextDirection.ltr,
    creationParams: const <String, dynamic>{},
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: onPlatformViewCreated,
  );
}
