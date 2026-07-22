import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rana/features/camera/state/camera_failure.dart';

/// Stateless camera chrome; coordination and controller access stay outside.
@internal
final class CameraScreenLayout extends StatelessWidget {
  const CameraScreenLayout({
    required this.header,
    required this.viewfinder,
    required this.controls,
    super.key,
  });

  final Widget header;
  final Widget viewfinder;
  final Widget controls;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2D3037), Color(0xFF1E2025), Color(0xFF121316)],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(child: viewfinder),
            controls,
          ],
        ),
      ),
    ),
  );
}

/// Transient capture feedback is intentionally separate from primary UI mode.
@internal
final class CameraCaptureFeedbackOverlay extends StatelessWidget {
  const CameraCaptureFeedbackOverlay({
    required this.showFlash,
    required this.showToast,
    super.key,
  });

  final bool showFlash;
  final bool showToast;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (showFlash)
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              key: ValueKey<String>('capture-screen-flash'),
              color: Colors.white,
            ),
          ),
        ),
      if (showToast)
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
  );
}

@internal
final class CameraFailureBanner extends StatelessWidget {
  const CameraFailureBanner({
    required this.failure,
    required this.onRecover,
    required this.onDismiss,
    super.key,
  });

  final CameraFailure failure;
  final VoidCallback onRecover;
  final VoidCallback onDismiss;

  String get _actionLabel => switch (failure.recoveryAction) {
    CameraRecoveryAction.openSettings => 'SETTINGS',
    CameraRecoveryAction.reinitialize => 'RESTART',
    CameraRecoveryAction.fallbackLens => 'USE 1×',
    CameraRecoveryAction.freeStorage => 'OK',
    CameraRecoveryAction.retry => 'RETRY',
    CameraRecoveryAction.none => 'DISMISS',
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Material(
        key: const ValueKey<String>('camera-failure-banner'),
        color: const Color(0xF0222328),
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF4C44F),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    failure.userMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: failure.isRecoverable ? onRecover : onDismiss,
                  child: Text(_actionLabel),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 18,
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
