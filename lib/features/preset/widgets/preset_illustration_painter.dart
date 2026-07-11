import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Painter that renders minimalist vector illustrations inside Instax frames
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
    // 1. Dark background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F0F12), Color(0xFF1C1A22)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Concentric chromatic circles (Lomo toy look)
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    final radius = size.width * 0.28;

    // Cyan channel shift
    canvas.drawCircle(
      Offset(centerX - 1.5, centerY - 1.0),
      radius,
      Paint()
        ..color = const Color(0x7F00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Magenta channel shift
    canvas.drawCircle(
      Offset(centerX + 1.5, centerY + 1.0),
      radius,
      Paint()
        ..color = const Color(0x7FFF00FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Yellow channel shift
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius - 2.0,
      Paint()
        ..color = const Color(0x7FFFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner glowing sphere
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.3),
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
        colors: [Color(0xFF16161A), Color(0xFF32323A)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Crescent Moon
    final moonPath = Path()
      ..moveTo(size.width * 0.55, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.2,
        size.width * 0.75,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.64,
        size.width * 0.55,
        size.height * 0.64,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.53,
        size.width * 0.66,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.31,
        size.width * 0.55,
        size.height * 0.2,
      )
      ..close();
    canvas.drawPath(
      moonPath,
      Paint()..color = const Color(0xFFEAEAED).withValues(alpha: 0.85),
    );

    // 3. Wavy Sea waves (Layered paths)
    final wavePaint1 = Paint()..color = const Color(0xFF1C1C22);
    final wavePaint2 = Paint()..color = const Color(0xFF0C0C0E);

    final wavePath1 = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.77,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.84,
        size.width,
        size.height * 0.75,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final wavePath2 = Path()
      ..moveTo(0, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.88,
        size.width * 0.6,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.84,
        size.width,
        size.height * 0.86,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(wavePath1, wavePaint1);
    canvas.drawPath(wavePath2, wavePaint2);
  }

  void _paintForest(Canvas canvas, Size size, Rect rect) {
    // 1. Deep Sunset Dusk Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2C3E50), Color(0xFFD35400)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Setting sun
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.62),
      size.width * 0.12,
      Paint()..color = const Color(0xFFFFCC33).withValues(alpha: 0.9),
    );

    // 3. Silhouette pine trees at the bottom
    const treeColor = Color(0xFF1E1610);
    _drawTree(
      canvas,
      size.width * 0.22,
      size.height * 0.88,
      16,
      10,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.48,
      size.height * 0.92,
      22,
      14,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.78,
      size.height * 0.86,
      18,
      11,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.34,
      size.height * 0.94,
      12,
      8,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.64,
      size.height * 0.95,
      14,
      9,
      treeColor,
    );

    // Ground block
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.92, size.width, size.height),
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
    // 1. Cool Night Sky Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F1E36), Color(0xFF173A5C)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.25),
      1,
      starPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.18),
      1.2,
      starPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.4),
      0.8,
      starPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.32),
      1,
      starPaint,
    );

    // 3. Overlapping Mountain peaks
    final mountainPaint1 = Paint()..color = const Color(0xFF102842);
    final mountainPaint2 = Paint()..color = const Color(0xFF081422);

    final m1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.3, size.height * 0.45)
      ..lineTo(size.width * 0.62, size.height * 0.75)
      ..lineTo(size.width * 0.82, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..close();

    final m2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.12, size.height * 0.68)
      ..lineTo(size.width * 0.52, size.height * 0.54)
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
      Offset(size.width * 0.5, size.height * 0.45),
      size.width * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // 3. Desert Sand dunes
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
