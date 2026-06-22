import 'package:flutter/material.dart';

/// Retro-themed CRT Terminal styled error screen displayed on critical crash.
class GlobalErrorScreen extends StatelessWidget {
  const GlobalErrorScreen({
    required this.error,
    required this.stackTrace,
    required this.onReset,
    super.key,
  });

  final Object error;
  final StackTrace stackTrace;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF08080A), // Extra dark slate black
        body: Stack(
          fit: StackFit.expand,
          children: [
            // CRT scanline overlay effect
            const _CrtScanlines(),

            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Terminal Title Bar
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Scrollable Exception details in terminal block
                    Expanded(
                      child: _buildTerminalConsole(),
                    ),
                    const SizedBox(height: 24),

                    // Reset Reboot Button
                    ElevatedButton(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB020), // Amber neon
                        foregroundColor: Colors.black,
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: Color(0xFFFFC040),
                            width: 2,
                          ),
                        ),
                        shadowColor: const Color(0xFFFFB020)
                            .withValues(alpha: 0.4),
                      ),
                      child: const Text(
                        'SYSTEM REBOOT / RELOAD',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFB020),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'CRITICAL SYSTEM FAULT',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFB020),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFFFB020).withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1.5, color: const Color(0xFFFFB020)),
        ],
      );

  Widget _buildTerminalConsole() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1014),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB020).withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB020).withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRect(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                '>> EXCEPTION DETECTED:\n$error',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  color: Color(0xFFFFB020),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '>> STACK TRACE LOG:',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: Color(0xFFFFB020),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stackTrace.toString(),
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: const Color(0xFFFFB020).withValues(alpha: 0.75),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CrtScanlines extends StatelessWidget {
  const _CrtScanlines();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(
          children: List.generate(
            150,
            (index) => Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withValues(
                        alpha: index.isEven ? 0.07 : 0.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
