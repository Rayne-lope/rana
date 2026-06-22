import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';
import 'package:rana/features/camera/state/camera_state.dart';

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

class _CameraScreenState extends ConsumerState<CameraScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize native platform channels connection on screen mount
    Future.microtask(() {
      ref.read(cameraControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Premium deep dark slate
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Control & Status Bar ─────────────────────────────────────
            _buildTopBar(cameraState, controller),

            // ── Viewfinder Area ──────────────────────────────────────────────
            Expanded(
              child: _buildViewfinder(cameraState, controller),
            ),

            // ── Bottom Control Panel ─────────────────────────────────────────
            _buildBottomPanel(cameraState, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(CameraState state, CameraController controller) {
    IconData flashIcon;
    Color flashColor;
    switch (state.flashMode) {
      case FlashMode.off:
        flashIcon = Icons.flash_off_rounded;
        flashColor = Colors.white38;
      case FlashMode.on:
        flashIcon = Icons.flash_on_rounded;
        flashColor = const Color(0xFFF1C40F); // Vivid yellow
      case FlashMode.auto:
        flashIcon = Icons.flash_auto_rounded;
        flashColor = const Color(0xFFE67E22); // Orange accent
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flash Mode Button
          IconButton(
            onPressed: state.isCameraInitialized
                ? controller.toggleFlashMode
                : null,
            icon: Icon(flashIcon, color: flashColor, size: 24),
            tooltip: 'Flash: ${state.flashMode.label}',
          ),

          // Platform FPS & Status Indicator
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isCameraInitialized
                      ? const Color(0xFF2ECC71) // Rich green
                      : const Color(0xFFE74C3C), // Crimson red
                  boxShadow: [
                    if (state.isCameraInitialized)
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.isCameraInitialized
                    ? 'LIVE — ${state.currentFps} FPS'
                    : 'OFFLINE',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          // Flip Lens Button
          IconButton(
            onPressed: state.isCameraInitialized ? controller.toggleLens : null,
            icon: const Icon(
              Icons.flip_camera_android_rounded,
              color: Colors.white70,
              size: 24,
            ),
            tooltip: 'Flip Lens',
          ),
        ],
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
                // Viewfinder Mock Background
                if (state.activeLens == CameraLens.back)
                  _buildMockBackground('Rear Camera Viewfinder')
                else
                  _buildMockBackground('Front Camera Viewfinder'),

                // 3x3 Composition Grid Lines
                const _ViewfinderGrid(),

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

              // Capture animation overlay
              if (state.captureStatus == CaptureStatus.capturing)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.70),
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

  Widget _buildMockBackground(String label) => Center(
        child: Opacity(
          opacity: 0.15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.blur_on_rounded,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBottomPanel(CameraState state, CameraController controller) {
    final presets = [
      {'id': 'placeholder', 'name': 'STUB P0'},
      {'id': 'classic_f1', 'name': 'CLASSIC F1'},
      {'id': 'retro_w2', 'name': 'RETRO W2'},
      {'id': 'cold_c3', 'name': 'COLD C3'},
      {'id': 'noir_b4', 'name': 'NOIR B&W'},
    ];

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          // Preset Carousel Selector
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isSelected = state.activePresetId == preset['id'];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(
                      preset['name']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFF39C12), // Vintage orange
                    backgroundColor: const Color(0xFF1E1E24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      if (selected && state.isCameraInitialized) {
                        controller.selectPreset(preset['id']!);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Shutter Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Extra space left for gallery icon alignment
              const SizedBox(width: 48),

              // Shutter capture button
              GestureDetector(
                onTap: state.isCameraInitialized &&
                        state.captureStatus == CaptureStatus.idle
                    ? controller.capture
                    : null,
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

              const SizedBox(width: 48),
            ],
          ),

          // Notification overlay text indicating capture result
          if (state.lastCapturedPath != null &&
              state.captureStatus == CaptureStatus.idle)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Captured: ${state.lastCapturedPath}',
                style: const TextStyle(
                  color: Color(0xFF2ECC71),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getCurrentDateStamp() {
    final now = DateTime.now();
    // Formats like: "26 06 22" (YY MM DD)
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year $month $day';
  }
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
          color: widget.success
              ? Colors.white
              : Colors.red.withValues(alpha: 0.4),
        ),
      );
}
