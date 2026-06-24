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
import 'package:rana/features/camera/widgets/rana_styles_panel_widget.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Premium deep dark slate
      body: SafeArea(
        child: Column(
          children: [
            // ── Viewfinder Area ──────────────────────────────────────────────
            Expanded(child: _buildViewfinder(cameraState, controller)),

            // ── Bottom Control Panel ─────────────────────────────────────────
            _buildBottomPanel(cameraState, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color iconColor = Colors.white70,
    String? tooltip,
  }) {
    return Tooltip(
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
  }

  Widget _buildGlassTextButton({
    required String text,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return Tooltip(
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
  }

  Widget _buildTopOverlayControls(CameraState state, CameraController controller) {
    final isReady =
        state.isCameraInitialized && state.captureStatus == CaptureStatus.idle;
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
          onPressed: isReady ? controller.toggleFlashMode : null,
        ),

        // Ratio Button (Placeholder)
        _buildGlassTextButton(
          text: '4:3',
          tooltip: 'Aspect Ratio',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CAMERA ASPECT RATIO OPTION COMING SOON'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        // Timer Button (Placeholder)
        _buildGlassIconButton(
          icon: Icons.timer_outlined,
          tooltip: 'Self Timer',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SELF TIMER OPTION COMING SOON'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        // Camera Flip Button
        _buildGlassIconButton(
          icon: Icons.flip_camera_android_rounded,
          tooltip: 'Flip Lens',
          onPressed: isReady ? controller.toggleLens : null,
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
    int activeIndex = 0;
    for (int i = 0; i < presetsList.length; i++) {
      if (presetsList[i].id == state.activePresetId) {
        activePreset = presetsList[i];
        activeIndex = i;
        break;
      }
    }

    if (activePreset == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glassmorphic Preset Name Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
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
          border: Border.all(
            color: Colors.white24,
            width: 2,
          ),
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
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: 54,
                  height: 54,
                )
              : Container(
                  color: const Color(0xFF1E1E24),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white54,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(CameraState state, CameraController controller) =>
      AspectRatio(
        aspectRatio: 3 / 4, // Retro photo aspect ratio
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
                const _AndroidCameraPreview(),

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
        state.isCameraInitialized && state.captureStatus == CaptureStatus.idle;

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
          // Simplified horizontal scrollable preset carousel of PresetChipWidgets
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
                        onDeleted: SavedRanaStyle.isSavedStylePresetId(preset.id)
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
                child: Center(
                  child: _buildThumbnailButton(state),
                ),
              ),

              // Shutter capture button (center)
              GestureDetector(
                onTap: isReady ? controller.capture : null,
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
                width: 100, // Fit both Reset icon button and Style panel text button cleanly
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: isReady && state.activeStyle != const RanaStyle()
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
                        onPressed: () => _showRanaStylesPanel(activePreset),
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

  void _showRanaStylesPanel(PresetModel? fallbackPreset) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(cameraControllerProvider);
            final controller = ref.read(cameraControllerProvider.notifier);
            final presets = ref.read(presetsProvider).valueOrNull ?? [];
            final activePreset =
                _findPresetById(presets, state.activePresetId) ??
                fallbackPreset;

            return RanaStylesPanelWidget(
              activePresetName: activePreset?.name ?? 'Normal',
              style: state.activeStyle,
              onStyleChanged: (style) {
                unawaited(controller.updateActiveStyle(style));
              },
              onReset: () {
                unawaited(controller.resetActiveStyle());
              },
              onApply: () {
                Navigator.of(sheetContext).pop();
              },
              onSaveAsStyle: () {
                unawaited(
                  _showSaveStyleDialog(
                    sheetContext,
                    activePreset,
                    state.activeStyle,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showSaveStyleDialog(
    BuildContext sheetContext,
    PresetModel? activePreset,
    RanaStyle style,
  ) async {
    if (activePreset == null) {
      return;
    }

    final basePresetId = _basePresetIdFor(activePreset);
    final textController = TextEditingController(
      text: '${activePreset.name} Style',
    );

    final savedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17171B),
        title: const Text(
          'SAVE AS STYLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 32,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'STYLE NAME',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF39C12)),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    textController.dispose();
    final name = savedName?.trim();
    if (name == null || name.isEmpty) {
      return;
    }

    final createdAt = DateTime.now().toUtc();
    final savedStyle = SavedRanaStyle(
      id: SavedRanaStyle.createId(createdAt),
      name: name,
      basePresetId: basePresetId,
      style: style,
      createdAt: createdAt,
    );

    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }

    await ref.read(savedRanaStyleRepositoryProvider).save(savedStyle);
    ref.invalidate(presetsProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SAVED STYLE ${name.toUpperCase()}'),
        behavior: SnackBarBehavior.floating,
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

  String _basePresetIdFor(PresetModel preset) {
    final behavior = preset.behavior;
    if (behavior is Map<String, dynamic>) {
      final basePresetId = behavior['basePresetId'];
      if (basePresetId is String && basePresetId.isNotEmpty) {
        return basePresetId;
      }
    }
    return preset.id;
  }

  PresetModel? _findPresetById(List<PresetModel> presets, String id) {
    for (final preset in presets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
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
  const _AndroidCameraPreview();

  @override
  Widget build(BuildContext context) => const AndroidView(
    viewType: 'com.rana.app/camera_preview',
    layoutDirection: TextDirection.ltr,
    creationParams: <String, dynamic>{},
    creationParamsCodec: StandardMessageCodec(),
  );
}
