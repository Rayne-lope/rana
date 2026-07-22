import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
