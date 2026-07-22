import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rana/features/camera/state/camera_state.dart';

@internal
final class CameraBottomPanelActionButton extends StatelessWidget {
  const CameraBottomPanelActionButton({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
    this.tooltip,
    this.isLocked = false,
    super.key,
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

@internal
final class CameraViewfinderGrid extends StatelessWidget {
  const CameraViewfinderGrid({super.key});

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

@internal
final class AndroidCameraPreview extends StatelessWidget {
  const AndroidCameraPreview({super.key, this.onPlatformViewCreated});

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'com.rana.app/camera_preview',
    layoutDirection: TextDirection.ltr,
    hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    onPlatformViewCreated: onPlatformViewCreated,
  );
}

@internal
final class CameraZoomIndicator extends StatelessWidget {
  const CameraZoomIndicator({
    required this.zoomRatio,
    required this.isEnabled,
    required this.isLimited,
    required this.shouldWarnDigitalZoom,
    required this.onReset,
    super.key,
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

@internal
final class CameraFocusRing extends StatelessWidget {
  const CameraFocusRing({required this.controller, super.key});

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
