import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shutter status enum.
enum ShutterStatus { ready, focusing, focusLock, captured }

/// Premium camera shutter button with realistic analog animations and mechanical blades.
class PremiumShutterButton extends StatefulWidget {
  /// Main constructor.
  const PremiumShutterButton({
    required this.onCapture,
    required this.onStatusChanged,
    this.size = 72.0,
    this.isEnabled = true,
    super.key,
  });

  /// Triggered when the photo is successfully captured.
  final VoidCallback onCapture;

  /// Triggered when the focus/capture status changes.
  final ValueChanged<ShutterStatus> onStatusChanged;

  /// The diameter of the main shutter button.
  final double size;

  /// Whether the button is interactable.
  final bool isEnabled;

  @override
  State<PremiumShutterButton> createState() => _PremiumShutterButtonState();
}

class _PremiumShutterButtonState extends State<PremiumShutterButton>
    with TickerProviderStateMixin {
  late final AnimationController _focusController;
  late final AnimationController _bladeController;
  late final AnimationController _waveController;

  bool _isPressing = false;
  math.Point<double>? _pressPointer;

  Timer? _focusTimer;
  Timer? _resetStatusTimer;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bladeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );

    _focusController.addListener(() => setState(() {}));
    _bladeController.addListener(() => setState(() {}));
    _waveController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _resetStatusTimer?.cancel();
    _focusController.dispose();
    _bladeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    if (!widget.isEnabled || _isPressing) return;
    _isPressing = true;
    widget.onStatusChanged(ShutterStatus.focusing);

    // Squeeze the blades immediately
    _bladeController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 140), () {
      if (!_isPressing) return;
      _focusController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      widget.onStatusChanged(ShutterStatus.focusLock);
      HapticFeedback.lightImpact();
    });
  }

  void _handlePressEnd() {
    if (!_isPressing) return;
    _isPressing = false;

    _focusTimer?.cancel();

    // Trigger capture wave animation
    _waveController.forward(from: 0.0);

    // Fade out focus ring
    _focusController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInCubic,
    );

    // Open blades back up
    _bladeController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );

    // Trigger Haptic & Callback
    HapticFeedback.mediumImpact();
    widget.onStatusChanged(ShutterStatus.captured);
    widget.onCapture();

    // Reset status to ready after capture animation completes
    _resetStatusTimer?.cancel();
    _resetStatusTimer = Timer(const Duration(milliseconds: 650), () {
      if (!_isPressing) {
        widget.onStatusChanged(ShutterStatus.ready);
      }
    });
  }

  void _handlePressCancel() {
    if (!_isPressing) return;
    _isPressing = false;

    _focusTimer?.cancel();
    _resetStatusTimer?.cancel();

    _focusController.animateTo(0.0);
    _bladeController.animateTo(0.0);
    widget.onStatusChanged(ShutterStatus.ready);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _isPressing ? 0.965 : 1.0;
    final translate = _isPressing ? 3.0 : 0.0;
    final wrapSize = widget.size * 1.38;

    return Listener(
      onPointerDown: (event) {
        _pressPointer = math.Point(event.position.dx, event.position.dy);
        _handlePressStart();
      },
      onPointerUp: (event) {
        _pressPointer = null;
        _handlePressEnd();
      },
      onPointerCancel: (event) {
        _pressPointer = null;
        _handlePressCancel();
      },
      onPointerMove: (event) {
        if (_pressPointer != null) {
          final diffX = event.position.dx - _pressPointer!.x;
          final diffY = event.position.dy - _pressPointer!.y;
          final dist = math.sqrt(diffX * diffX + diffY * diffY);
          // If the finger moves too far away from the button, cancel the press
          if (dist > widget.size * 1.2) {
            _pressPointer = null;
            _handlePressCancel();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translate, 0)..scale(scale),
        child: CustomPaint(
          size: Size(wrapSize, wrapSize),
          painter: ShutterPainter(
            size: widget.size,
            focusProgress: _focusController.value,
            bladeProgress: _bladeController.value,
            waveProgress: _waveController.value,
            isEnabled: widget.isEnabled,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders all elements of the premium shutter button:
/// Ambient ring, Focus ring, Capture wave, Metal shell, Knurled border, Blades, and Glass gloss.
class ShutterPainter extends CustomPainter {
  /// Constructor.
  ShutterPainter({
    required this.size,
    required this.focusProgress,
    required this.bladeProgress,
    required this.waveProgress,
    required this.isEnabled,
  });

  /// Main shutter button size.
  final double size;

  /// Focus ring animation progress.
  final double focusProgress;

  /// Blades close animation progress.
  final double bladeProgress;

  /// Capture wave animation progress.
  final double waveProgress;

  /// Interactive state.
  final bool isEnabled;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final buttonRadius = size / 2;

    // 1. Draw Ambient Ring (88% size of total wrap size)
    final ambientRadius = (canvasSize.width * 0.88) / 2;
    canvas.drawCircle(
      center,
      ambientRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.055),
    );

    // 2. Draw Focus Ring (79% size of wrap, animates scale and opacity)
    if (focusProgress > 0) {
      final focusRadius = (canvasSize.width * 0.79) / 2;
      final currentFocusRadius = focusRadius * (0.92 + (0.08 * focusProgress));
      final focusPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF4C44F).withValues(alpha: 0.65 * focusProgress);
      canvas.drawCircle(center, currentFocusRadius, focusPaint);

      // Draw focus glow
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = const Color(0xFFF4C44F).withValues(alpha: 0.28 * focusProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, currentFocusRadius, glowPaint);
    }

    // 3. Draw Capture Wave (72% size of wrap, animates scale and fades out)
    if (waveProgress > 0 && waveProgress < 1.0) {
      final baseWaveRadius = (canvasSize.width * 0.72) / 2;
      final currentWaveRadius = baseWaveRadius * (0.82 + (0.52 * waveProgress));
      final waveOpacity = (0.72 * (1.0 - waveProgress)).clamp(0.0, 1.0);
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: waveOpacity);
      canvas.drawCircle(center, currentWaveRadius, wavePaint);
    }

    // 4. Draw Metal Shell (Conic Sweep Gradient)
    final shellPaint = Paint()
      ..shader = const SweepGradient(
        transform: GradientRotation(220 * math.pi / 180),
        colors: [
          Color(0xFF17181B),
          Color(0xFF45474D),
          Color(0xFF16171A),
          Color(0xFF5B5E65),
          Color(0xFF1B1C20),
          Color(0xFF4F5157),
          Color(0xFF151619),
          Color(0xFF3D3F45),
          Color(0xFF17181B),
        ],
        stops: [0.0, 0.11, 0.21, 0.33, 0.48, 0.62, 0.77, 0.89, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: buttonRadius));

    // Outer shadow of the physical button
    canvas.drawCircle(
      center,
      buttonRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(center, buttonRadius, shellPaint);

    // Inner rim white highlight
    canvas.drawCircle(
      center,
      buttonRadius - 1.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // 5. Draw Knurling Border (repeating conic ticks)
    final knurlInner = buttonRadius - 7.0;
    final knurlOuter = buttonRadius - 4.0;
    final knurlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 0.6;

    for (var angle = 0.0; angle < 360.0; angle += 4.5) {
      final rad = angle * math.pi / 180;
      final cosVal = math.cos(rad);
      final sinVal = math.sin(rad);
      canvas.drawLine(
        Offset(center.dx + knurlInner * cosVal, center.dy + knurlInner * sinVal),
        Offset(center.dx + knurlOuter * cosVal, center.dy + knurlOuter * sinVal),
        knurlPaint,
      );
    }

    // 6. Inner Bezel Ring
    final bezelRadius = buttonRadius - 7.0;
    final bezelRect = Rect.fromCircle(center: center, radius: bezelRadius);
    final bezelPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        colors: isEnabled
            ? const [Color(0xFF383A42), Color(0xFF111216), Color(0xFF090A0C)]
            : const [Color(0xFF28282B), Color(0xFF141416), Color(0xFF0A0A0C)],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(bezelRect);

    canvas.drawCircle(center, bezelRadius, bezelPaint);

    // Bezel shadow rim
    canvas.drawCircle(
      center,
      bezelRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.black.withValues(alpha: 0.75),
    );

    // 7. Aperture Blades
    final apertureRadius = bezelRadius - 11.0;
    _drawApertureBlades(canvas, center, apertureRadius);

    // 8. Glass Cap Overlay with reflection
    final glassRadius = apertureRadius - 6.0;
    final glassPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 1.1,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glassRadius));

    canvas.drawCircle(center, glassRadius, glassPaint);

    // Gloss reflection arc
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(
        center.dx - glassRadius * 0.8,
        center.dy - glassRadius * 0.9,
        glassRadius * 1.6,
        glassRadius * 0.6,
      ));

    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - glassRadius * 0.68,
        center.dy - glassRadius * 0.85,
        glassRadius * 1.36,
        glassRadius * 0.48,
      ),
      glossPaint,
    );

    // 9. Center Mark/Pin
    canvas.drawCircle(
      center,
      3.0,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
    );
  }

  void _drawApertureBlades(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final bladePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E3138), Color(0xFF0F1012)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.08);

    // Draw 6 blades
    for (var i = 0; i < 6; i++) {
      canvas.save();
      // Pivot around the circle
      canvas.rotate(i * 60 * math.pi / 180);

      // Translate inward when squeezing the button
      final squeezeTranslation = radius * 0.12 * bladeProgress;
      canvas.translate(0, squeezeTranslation);

      // Rotate blade slightly inward when pressing
      final rotationAngle = (18.0 * bladeProgress) * math.pi / 180;
      canvas.rotate(rotationAngle);

      // Draw blade leaf path
      final path = Path()
        ..moveTo(0, -radius)
        ..quadraticBezierTo(radius * 0.7, -radius * 0.7, radius * 0.76, 0)
        ..quadraticBezierTo(radius * 0.4, radius * 0.4, 0, radius * 0.28)
        ..quadraticBezierTo(-radius * 0.4, -radius * 0.4, 0, -radius)
        ..close();

      canvas.drawPath(path, bladePaint);
      canvas.drawPath(path, strokePaint);

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShutterPainter oldDelegate) =>
      oldDelegate.focusProgress != focusProgress ||
      oldDelegate.bladeProgress != bladeProgress ||
      oldDelegate.waveProgress != waveProgress ||
      oldDelegate.isEnabled != isEnabled;
}
