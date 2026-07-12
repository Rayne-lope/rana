import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Painter that renders highly detailed minimalist vector illustrations
/// inside Instax frames representing the unique style of each film preset.
class PresetIllustrationPainter extends CustomPainter {
  /// Constructor.
  PresetIllustrationPainter(this.preset);

  /// The preset model.
  final PresetModel preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final idLower = preset.id.toLowerCase();
    final categoryLower = preset.category.toLowerCase();

    // Classification logic for preset categories
    final isMonochrome = idLower.contains('bw') ||
        idLower.contains('mono') ||
        idLower.contains('ilford') ||
        idLower.contains('scala') ||
        (preset.color.saturation <= -0.8);

    final isLomo = idLower.contains('lomo') ||
        idLower.contains('toy') ||
        idLower.contains('metropolis');

    final isCinematic = categoryLower == 'cinematic' ||
        idLower.contains('cinestill') ||
        idLower.contains('cinema');

    final isDisposable = categoryLower == 'disposable' ||
        idLower.contains('quicksnap') ||
        idLower.contains('lebox') ||
        idLower.contains('disposable');

    final isInstant = categoryLower == 'instant' ||
        idLower.contains('instax') ||
        idLower.contains('polaroid');

    final isCool = idLower.contains('aurora') ||
        idLower.contains('cool') ||
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
    } else if (isCinematic) {
      _paintCinematic(canvas, size, rect);
    } else if (isDisposable) {
      _paintDisposable(canvas, size, rect);
    } else if (isInstant) {
      _paintInstant(canvas, size, rect);
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
        center: Alignment.topLeft,
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
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.15),
      0.8,
      grainPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.28),
      0.6,
      grainPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.12),
      0.8,
      grainPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.44),
      0.5,
      grainPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.35),
      0.7,
      grainPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.20),
      0.6,
      grainPaint,
    );

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

    // 4. Overlapping Sea waves (Layered paths)
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
      ).createShader(
        Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.8),
      );

    canvas.drawCircle(sunCenter, sunRadius * 1.8, sunGlow);
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()..color = const Color(0xFFFFF099),
    );

    // 3. Silhouette pine trees at the bottom
    const treeColor = Color(0xFF140D0B);
    _drawTree(
      canvas,
      size.width * 0.16,
      size.height * 0.84,
      18,
      11,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.34,
      size.height * 0.88,
      14,
      9,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.50,
      size.height * 0.90,
      24,
      14,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.68,
      size.height * 0.86,
      16,
      10,
      treeColor,
    );
    _drawTree(
      canvas,
      size.width * 0.84,
      size.height * 0.83,
      20,
      12,
      treeColor,
    );

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
        ).createShader(
          Rect.fromCircle(center: orbCenter, radius: orbRadius * 1.5),
        ),
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
            color: const Color(0xFFFF5722).withValues(
              alpha: 0.92,
            ), // Retro digital orange-red
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
    // 1. Sky Gradient (Light blue to warm peach)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5DADE2), Color(0xFFF5B041)],
        stops: [0.35, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Soft layered sun
    final sunCenter = Offset(size.width * 0.72, size.height * 0.38);
    final sunRadius = size.width * 0.14;
    canvas.drawCircle(
      sunCenter,
      sunRadius * 1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()..color = const Color(0xFFFFF6D1),
    );

    // 3. Layered minimalist valley hills
    final hillPaint1 = Paint()..color = const Color(0xFF2E4053);
    final hillPaint2 = Paint()..color = const Color(0xFF1B2631);

    final hill1 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.72,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final hill2 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.86,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(hill1, hillPaint1);
    canvas.drawPath(hill2, hillPaint2);
  }

  void _paintDisposable(Canvas canvas, Size size, Rect rect) {
    // 1. Retro plastic green/blue/yellow neon gradient background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Yellow accent wave (frequent in disposable camera packages)
    final yellowPaint = Paint()..color = const Color(0xFFF1C40F);
    final wavePath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.5,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wavePath, yellowPaint);

    // 3. Minimalist Disposable Camera lens in center
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.45;

    // Outer black lens ring
    canvas.drawCircle(
      Offset(centerX, centerY),
      size.width * 0.22,
      Paint()..color = const Color(0xFF1C2833),
    );

    // Inner lens glass (blue glow)
    canvas.drawCircle(
      Offset(centerX, centerY),
      size.width * 0.12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5DADE2),
            const Color(0xFF2E4053),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: size.width * 0.12,
        )),
    );

    // 4. Glowing flash element in top-right
    final flashX = size.width * 0.8;
    final flashY = size.height * 0.2;
    final flashRadius = size.width * 0.1;

    final flashGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFFF1C40F).withValues(alpha: 0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(flashX, flashY),
        radius: flashRadius * 2,
      ));
    canvas.drawCircle(Offset(flashX, flashY), flashRadius * 2, flashGlow);
    canvas.drawCircle(
      Offset(flashX, flashY),
      flashRadius * 0.6,
      Paint()..color = Colors.white,
    );
  }

  void _paintInstant(Canvas canvas, Size size, Rect rect) {
    // 1. Slate dark vintage background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Polaroid-style diagonal rainbow spectrum stripe
    final rainbowColors = [
      const Color(0xFFE74C3C), // Red
      const Color(0xFFE67E22), // Orange
      const Color(0xFFF1C40F), // Yellow
      const Color(0xFF2ECC71), // Green
      const Color(0xFF3498DB), // Blue
    ];

    final stripeWidth = size.width * 0.08;
    final stripePaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < rainbowColors.length; i++) {
      stripePaint.color = rainbowColors[i];
      final path = Path()
        ..moveTo(size.width * 0.2 + i * stripeWidth, 0)
        ..lineTo(size.width * 0.2 + (i + 1) * stripeWidth, 0)
        ..lineTo(0, size.height * 0.3 + (i + 1) * stripeWidth)
        ..lineTo(0, size.height * 0.3 + i * stripeWidth)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    // 3. Mini white instant frame inset representing the film format
    final frameWidth = size.width * 0.55;
    final frameHeight = size.height * 0.65;
    final frameLeft = size.width * 0.225;
    final frameTop = size.height * 0.18;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight),
      Radius.circular(size.width * 0.04),
    );

    // Draw the white paper border of the instant photo
    canvas.drawRRect(
      frameRect,
      Paint()..color = const Color(0xFFF4F6F7),
    );

    // Draw the dark inner image area inside the instant photo
    final photoWidth = frameWidth * 0.8;
    final photoHeight = frameHeight * 0.72;
    final photoLeft = frameLeft + (frameWidth - photoWidth) / 2;
    final photoTop = frameTop + (frameWidth - photoWidth) / 2;

    final photoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(photoLeft, photoTop, photoWidth, photoHeight),
      Radius.circular(size.width * 0.02),
    );

    // Draw photo background (soft blue sky/sunset inside)
    canvas.drawRRect(
      photoRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF85C1E9), Color(0xFFF5B041)],
        ).createShader(photoRect.outerRect),
    );
  }

  void _paintCinematic(Canvas canvas, Size size, Rect rect) {
    // 1. Gradient background: Deep cinematic teal/slate
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Vertical film strip sprocket pattern on the left side
    final stripWidth = size.width * 0.16;
    final stripPaint = Paint()..color = const Color(0xFF050B0D);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, stripWidth, size.height),
      stripPaint,
    );

    // Draw tiny sprocket holes (rounded rectangles)
    final holePaint = Paint()..color = const Color(0xFFD5DBDB).withValues(alpha: 0.8);
    final holeWidth = stripWidth * 0.5;
    final holeHeight = size.height * 0.08;
    final holeLeft = (stripWidth - holeWidth) / 2;

    for (var i = 0; i < 4; i++) {
      final holeTop = size.height * 0.12 + i * (size.height * 0.24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(holeLeft, holeTop, holeWidth, holeHeight),
          Radius.circular(size.width * 0.015),
        ),
        holePaint,
      );
    }

    // 3. Glowing projector beam lens light / halation ring
    final centerX = size.width * 0.62;
    final centerY = size.height * 0.46;
    final radius = size.width * 0.22;

    // Outer red/orange halation bloom ring (resembling CineStill's signature)
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF3333).withValues(alpha: 0.48),
            const Color(0xFFFF6600).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: radius * 1.6,
        )),
    );

    // Inner bright golden light source
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            const Color(0xFFFFF0B3),
            const Color(0xFFFF9933).withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: radius,
        )),
    );
  }

  @override
  bool shouldRepaint(covariant PresetIllustrationPainter oldDelegate) =>
      oldDelegate.preset.id != preset.id;
}
