import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Painter that renders highly detailed minimalist vector illustrations inside Instax frames
/// representing the unique style of each film preset.
class PresetIllustrationPainter extends CustomPainter {
  /// Constructor.
  PresetIllustrationPainter(this.preset);

  /// The preset model.
  final PresetModel preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final idLower = preset.id.toLowerCase();

    // Classification logic for preset categories
    final isMonochrome = idLower.contains('bw') ||
        idLower.contains('mono') ||
        idLower.contains('ilford') ||
        idLower.contains('scala') ||
        (preset.color.saturation <= -0.8);

    final isLomo = idLower.contains('lomo') ||
        idLower.contains('toy') ||
        idLower.contains('metropolis');

    final isCool = idLower.contains('aurora') ||
        idLower.contains('cool') ||
        idLower.contains('cinestill') ||
        (preset.color.temperature < -0.05);

    final isForest = idLower.contains('dusk') ||
        idLower.contains('rust') ||
        idLower.contains('nocturne') ||
        idLower.contains('purple') ||
        idLower.contains('lomochrome');

    final isWarm = idLower.contains('gold') ||
        idLower.contains('portra') ||
        idLower.contains('warm') ||
        idLower.contains('ektar') ||
        (preset.color.temperature > 0.05);

    // Render corresponding detailed illustration
    if (isLomo) {
      _paintLomo(canvas, size, rect);
    } else if (isMonochrome) {
      _paintMonochrome(canvas, size, rect);
    } else if (isForest) {
      _paintForest(canvas, size, rect);
    } else if (isCool) {
      _paintCool(canvas, size, rect);
    } else if (isWarm) {
      _paintWarm(canvas, size, rect);
    } else {
      _paintDefault(canvas, size, rect);
    }
  }

  void _paintLomo(Canvas canvas, Size size, Rect rect) {
    // 1. Dark vignette background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF07060A), Color(0xFF14121B)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Glowing Pink/Orange Light Leak in top-left
    final leakPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-1.0, -1.0),
        radius: 1.4,
        colors: [
          const Color(0xFFFF3366).withValues(alpha: 0.45),
          const Color(0xFFFF9900).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, leakPaint);

    // 3. Concentric Chromatic Aberration circles (Lomo toy look)
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    final radius = size.width * 0.28;

    // Cyan channel shift
    canvas.drawCircle(
      Offset(centerX - 2, centerY - 1.5),
      radius,
      Paint()
        ..color = const Color(0x9900FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Magenta channel shift
    canvas.drawCircle(
      Offset(centerX + 2, centerY + 1.5),
      radius,
      Paint()
        ..color = const Color(0x99FF00FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Yellow channel shift
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius - 3.0,
      Paint()
        ..color = const Color(0x99FFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner glowing sphere
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: radius,
      ));
    canvas.drawCircle(Offset(centerX, centerY), radius, glowPaint);
  }

  void _paintMonochrome(Canvas canvas, Size size, Rect rect) {
    // 1. Monochrome night gradient background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF141416), Color(0xFF28282E)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Grain particles (Tiny random starry dots in B&W)
    final grainPaint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.15), 0.8, grainPaint);
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.28), 0.6, grainPaint);
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.12), 0.8, grainPaint);
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.44), 0.5, grainPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.35), 0.7, grainPaint);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.20), 0.6, grainPaint);

    // 3. Detailed Crescent Moon
    final moonPath = Path()
      ..moveTo(size.width * 0.52, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.16,
        size.width * 0.74,
        size.height * 0.40,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.64,
        size.width * 0.52,
        size.height * 0.64,
      )
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * 0.52,
        size.width * 0.64,
        size.height * 0.40,
      )
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * 0.28,
        size.width * 0.52,
        size.height * 0.16,
      )
      ..close();
    canvas.drawPath(
      moonPath,
      Paint()..color = const Color(0xFFF0F0F3).withValues(alpha: 0.9),
    );

    // 4. Overlapping Sea waves (Layered paths with slight contrast difference)
    final wavePaint1 = Paint()..color = const Color(0xFF1D1D22);
    final wavePaint2 = Paint()..color = const Color(0xFF121216);
    final wavePaint3 = Paint()..color = const Color(0xFF08080A);

    final wavePath1 = Path()
      ..moveTo(0, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.65,
        size.width * 0.5,
        size.height * 0.73,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.81,
        size.width,
        size.height * 0.70,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final wavePath2 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.84,
        size.width * 0.6,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.80,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final wavePath3 = Path()
      ..moveTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.84,
        size.width * 0.55,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.90,
        size.width,
        size.height * 0.87,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(wavePath1, wavePaint1);
    canvas.drawPath(wavePath2, wavePaint2);
    canvas.drawPath(wavePath3, wavePaint3);
  }

  void _paintForest(Canvas canvas, Size size, Rect rect) {
    // 1. Deep Sunset Dusk Purple-to-Orange Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF282F44), Color(0xFFD35400), Color(0xFFE74C3C)],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Soft glowing setting sun
    final sunCenter = Offset(size.width * 0.5, size.height * 0.58);
    final sunRadius = size.width * 0.16;

    final sunGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE066).withValues(alpha: 0.95),
          const Color(0xFFE74C3C).withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.8));

    canvas.drawCircle(sunCenter, sunRadius * 1.8, sunGlow);
    canvas.drawCircle(sunCenter, sunRadius, Paint()..color = const Color(0xFFFFF099));

    // 3. Silhouette pine trees at the bottom
    final treeColor = const Color(0xFF140D0B);
    _drawTree(canvas, size.width * 0.16, size.height * 0.84, 18, 11, treeColor);
    _drawTree(canvas, size.width * 0.34, size.height * 0.88, 14, 9, treeColor);
    _drawTree(canvas, size.width * 0.50, size.height * 0.90, 24, 14, treeColor);
    _drawTree(canvas, size.width * 0.68, size.height * 0.86, 16, 10, treeColor);
    _drawTree(canvas, size.width * 0.84, size.height * 0.83, 20, 12, treeColor);

    // Ground block
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.88, size.width, size.height),
      Paint()..color = treeColor,
    );
  }

  void _drawTree(
    Canvas canvas,
    double x,
    double y,
    double height,
    double width,
    Color color,
  ) {
    final path = Path()
      ..moveTo(x, y - height)
      ..lineTo(x - width / 2, y)
      ..lineTo(x + width / 2, y)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintCool(Canvas canvas, Size size, Rect rect) {
    // 1. High contrast Cinematic Teal Sky Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF003F5C), Color(0xFF2C7A7B)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Glowing Moon/Sun with Halation halo (Soft Red-Orange bloom)
    final orbCenter = Offset(size.width * 0.5, size.height * 0.42);
    final orbRadius = size.width * 0.18;

    // Halation/Bloom ring
    canvas.drawCircle(
      orbCenter,
      orbRadius * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF5722).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius * 1.5)),
    );

    // Clean white center
    canvas.drawCircle(
      orbCenter,
      orbRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // 3. Overlapping Mountain peaks at the bottom
    final mountainPaint1 = Paint()..color = const Color(0xFF0A2540);
    final mountainPaint2 = Paint()..color = const Color(0xFF04101A);

    final m1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.32, size.height * 0.52)
      ..lineTo(size.width * 0.60, size.height * 0.76)
      ..lineTo(size.width * 0.80, size.height * 0.46)
      ..lineTo(size.width, size.height)
      ..close();

    final m2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.14, size.height * 0.72)
      ..lineTo(size.width * 0.50, size.height * 0.60)
      ..lineTo(size.width * 0.88, size.height * 0.82)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(m1, mountainPaint1);
    canvas.drawPath(m2, mountainPaint2);
  }

  void _paintWarm(Canvas canvas, Size size, Rect rect) {
    // 1. Warm Golden Hour Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE67E22), Color(0xFFF1C40F)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Large Sun
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // 3. Layered desert sand dunes
    final dunePaint1 = Paint()..color = const Color(0xFFD35400);
    final dunePaint2 = Paint()..color = const Color(0xFFBA4A00);

    final dune1 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.64,
        size.width,
        size.height * 0.74,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final dune2 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.88,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(dune1, dunePaint1);
    canvas.drawPath(dune2, dunePaint2);

    // 4. Render Orange Retro Date Stamp if date stamp is enabled in preset
    final hasDate = preset.effects.dateStamp?.enable ?? false;
    if (hasDate) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: "'98 07 12",
          style: TextStyle(
            color: const Color(0xFFFF5722).withValues(alpha: 0.92), // Retro digital orange-red
            fontSize: size.width * 0.11,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 0.2,
            shadows: [
              Shadow(
                color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                blurRadius: 1,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          size.width - textPainter.width - size.width * 0.08,
          size.height - textPainter.height - size.width * 0.05,
        ),
      );
    }
  }

  void _paintDefault(Canvas canvas, Size size, Rect rect) {
    // 1. Sky Blue background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5DADE2), Color(0xFF3498DB)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Sun in top right corner
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.32),
      size.width * 0.16,
      Paint()..color = const Color(0xFFF1C40F),
    );

    // 3. Simple ground hill
    final groundPaint = Paint()..color = const Color(0xFF2E4053);
    final ground = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.75,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, groundPaint);
  }

  @override
  bool shouldRepaint(covariant PresetIllustrationPainter oldDelegate) =>
      oldDelegate.preset.id != preset.id;
}
