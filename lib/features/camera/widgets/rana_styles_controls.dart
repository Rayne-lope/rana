import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class RanaInteractiveUndertonePad extends StatefulWidget {
  const RanaInteractiveUndertonePad({
    required this.undertoneX,
    required this.undertoneY,
    required this.styleStrength,
    required this.onChanged,
    super.key,
  });

  final double undertoneX; // [-1.0, 1.0]
  final double undertoneY; // [-1.0, 1.0]
  final double styleStrength; // [0.0, 100.0]
  final void Function(double x, double y) onChanged;

  @override
  State<RanaInteractiveUndertonePad> createState() =>
      _RanaInteractiveUndertonePadState();
}

class _RanaInteractiveUndertonePadState
    extends State<RanaInteractiveUndertonePad>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  // Normalized coordinates in [0.0, 1.0] range
  double _x = 0.5;
  double _y = 0.5;
  double _targetX = 0.5;
  double _targetY = 0.5;

  double _motion = 0;
  double _motionTarget = 0;
  int _motionUntil = 0;
  double _time = 0;
  bool _dragging = false;

  final List<_TrailPoint> _trail = [];

  @override
  void initState() {
    super.initState();
    _targetX = _mapXToNormalized(widget.undertoneX);
    _targetY = _mapYToNormalized(widget.undertoneY);
    _x = _targetX;
    _y = _targetY;

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);

    _wakeMotion(900);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  static const double _padLayoutSize = 220;
  static const double _padEdgeRatio = 28 / _padLayoutSize;

  double _mapXToNormalized(double ux) {
    final ratio = ((ux + 1) / 2).clamp(0, 1);
    return _padEdgeRatio + ratio * (1 - _padEdgeRatio * 2);
  }

  double _mapYToNormalized(double uy) {
    final ratio = ((1 - uy) / 2).clamp(0, 1);
    return _padEdgeRatio + ratio * (1 - _padEdgeRatio * 2);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _startLoop() {
    if (!_ticker.isAnimating) {
      _ticker.repeat();
    }
  }

  void _wakeMotion([int durationMs = 1300]) {
    _motionUntil = DateTime.now().millisecondsSinceEpoch + durationMs;
    _motionTarget = 1;
    _startLoop();
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ease = _dragging ? 0.28 : 0.13;

    _time += 1 / 60;

    _x = _lerp(_x, _targetX, ease);
    _y = _lerp(_y, _targetY, ease);

    if (now > _motionUntil) {
      _motionTarget = 0;
    }

    _motion = _lerp(_motion, _motionTarget, _dragging ? 0.18 : 0.075);

    for (final point in _trail) {
      point.life -= 0.035;
    }
    _trail.removeWhere((point) => point.life <= 0);

    final stillMoving =
        _dragging ||
        _motion > 0.008 ||
        _trail.isNotEmpty ||
        (_x - _targetX).abs() > 0.002 ||
        (_y - _targetY).abs() > 0.002;

    setState(() {});

    if (!stillMoving) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(covariant RanaInteractiveUndertonePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.undertoneX != widget.undertoneX ||
        oldWidget.undertoneY != widget.undertoneY) {
      if (!_dragging) {
        _targetX = _mapXToNormalized(widget.undertoneX);
        _targetY = _mapYToNormalized(widget.undertoneY);
        _startLoop();
      }
    }
  }

  void _setPadFromLocal(Offset localPosition, double size) {
    final edge = size * _padEdgeRatio;
    final dx = localPosition.dx.clamp(edge, size - edge);
    final dy = localPosition.dy.clamp(edge, size - edge);

    _targetX = dx / size;
    _targetY = dy / size;

    _trail.add(_TrailPoint(_targetX, _targetY));
    if (_trail.length > 12) {
      _trail.removeAt(0);
    }

    final denom = size - edge * 2;
    final logicalX = denom > 0 ? ((dx - edge) / denom) * 2.0 - 1.0 : 0.0;
    final logicalY = denom > 0 ? 1.0 - ((dy - edge) / denom) * 2.0 : 0.0;

    widget.onChanged(logicalX, logicalY);
    _wakeMotion(1500);
  }

  static String _formatAxis(double value) {
    final rounded = (value * 100).round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final normStyleStrength = widget.styleStrength / 100.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'UNDERTONE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatAxis(widget.undertoneX)} / ${_formatAxis(widget.undertoneY)}',
                style: const TextStyle(
                  color: Color(0xFFF39C12),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(
                    _padLayoutSize,
                    constraints.biggest.shortestSide,
                  );

                  return SizedBox.square(
                    dimension: size,
                    child: GestureDetector(
                      key: const Key('undertone-pad'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _setPadFromLocal(details.localPosition, size);
                      },
                      onPanStart: (details) {
                        _dragging = true;
                        _setPadFromLocal(details.localPosition, size);
                      },
                      onPanUpdate: (details) {
                        _setPadFromLocal(details.localPosition, size);
                      },
                      onPanEnd: (_) {
                        _dragging = false;
                        _wakeMotion(1200);
                      },
                      onPanCancel: () {
                        _dragging = false;
                        _wakeMotion(1200);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _ToneFieldPainter(
                                  x: _x,
                                  y: _y,
                                  slider: normStyleStrength,
                                  motion: _motion,
                                  time: _time,
                                  trail: List<_TrailPoint>.from(_trail),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: _PadAxisLabel(
                              label: 'MAGENTA',
                              alignment: TextAlign.center,
                            ),
                          ),
                          const Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: _PadAxisLabel(
                              label: 'GREEN',
                              alignment: TextAlign.center,
                            ),
                          ),
                          const Positioned(
                            left: 12,
                            top: 0,
                            bottom: 0,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _PadAxisLabel(label: 'WARM'),
                            ),
                          ),
                          const Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _PadAxisLabel(
                                label: 'COOL',
                                alignment: TextAlign.right,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailPoint {
  _TrailPoint(this.x, this.y);

  final double x;
  final double y;
  double life = 1;
}

class _PadAxisLabel extends StatelessWidget {
  const _PadAxisLabel({required this.label, this.alignment = TextAlign.left});

  final String label;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) => Text(
    label,
    textAlign: alignment,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.50),
      fontSize: 9,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}

class _ToneFieldPainter extends CustomPainter {
  const _ToneFieldPainter({
    required this.x,
    required this.y,
    required this.slider,
    required this.motion,
    required this.time,
    required this.trail,
  });

  final double x;
  final double y;
  final double slider;
  final double motion;
  final double time;
  final List<_TrailPoint> trail;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(42));

    final orb = Offset(size.width * x, size.height * y);

    canvas.save();
    canvas.clipRRect(rrect);

    _drawBase(canvas, size, rect, orb);
    _drawTrail(canvas, size);
    _drawDiamondGrid(canvas, size, orb);
    _drawConstellationLines(canvas, size, orb);
    _drawOrb(canvas, size, orb);

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.075),
    );
  }

  void _drawBase(Canvas canvas, Size size, Rect rect, Offset orb) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(42)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            const Color(0xFFB2C4B8).withValues(alpha: 0.88),
            const Color(0xFF68484E).withValues(alpha: 0.92),
            const Color(0xFF1F0720).withValues(alpha: 0.99),
          ],
          [0.0, 0.40, 1.0],
        ),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.72, size.height * 0.12),
          size.width * 0.70,
          [
            const Color(0xFFC0E0C7).withValues(alpha: 0.38),
            const Color(0xFF4FAA84).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          [0.0, 0.48, 1.0],
        ),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            ui.Gradient.radial(orb + const Offset(-18, 10), size.width * 0.55, [
              const Color(
                0xFFFF8BAE,
              ).withValues(alpha: 0.10 + motion * 0.14 + slider * 0.10),
              Colors.transparent,
            ]),
    );
  }

  void _drawTrail(Canvas canvas, Size size) {
    for (final point in trail) {
      final center = Offset(point.x * size.width, point.y * size.height);

      canvas.drawCircle(
        center,
        28 + (1 - point.life) * 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(
            0xFFFFD2E2,
          ).withValues(alpha: 0.12 * point.life),
      );
    }
  }

  void _drawDiamondGrid(Canvas canvas, Size size, Offset orb) {
    const cols = 10;
    const rows = 10;

    const left = 32;
    const top = 33;
    const right = 32;
    const bottom = 34;

    final gridW = size.width - left - right;
    final gridH = size.height - top - bottom;

    final activeRadius = 52 + slider * 18;
    final ringRadius = 44 + math.sin(time * 2.2) * 8 + motion * 6;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final offset = row.isEven ? 0.0 : 0.5;
        final nx = (col + offset) / (cols - 0.25);

        if (nx > 1) continue;

        final ny = row / (rows - 1);

        final dot = Offset(left + nx * gridW, top + ny * gridH);

        final distance = (dot - orb).distance;

        final near = (1 - distance / activeRadius).clamp(0.0, 1.0);
        final ring =
            (1 - (distance - ringRadius).abs() / 19).clamp(0.0, 1.0) * motion;

        final shimmer =
            (math.sin(time * 2.4 + row * 0.8 + col * 0.35) * 0.5 + 0.5) *
            0.12 *
            motion;

        final energy = near + ring * 0.72 + shimmer;

        const baseSize = 2.0;
        final dotSize = baseSize + near * 3.1 + ring * 1.6;

        final opacity = (0.28 + near * 0.55 + ring * 0.26 + shimmer).clamp(
          0.22,
          1.0,
        );

        if (energy > 0.05) {
          canvas.save();
          canvas.translate(dot.dx, dot.dy);
          canvas.rotate(math.pi / 4);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: dotSize * 5.4,
              height: dotSize * 5.4,
            ),
            Paint()
              ..color = const Color(
                0xFFFFC0DA,
              ).withValues(alpha: 0.10 * energy),
          );
          canvas.restore();
        }

        canvas.save();
        canvas.translate(dot.dx, dot.dy);
        canvas.rotate(math.pi / 4);

        final stretch = 1 + near * 0.55 + ring * 0.25;

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: dotSize,
            height: dotSize * stretch,
          ),
          Paint()..color = Colors.white.withValues(alpha: opacity),
        );

        canvas.restore();
      }
    }
  }

  void _drawConstellationLines(Canvas canvas, Size size, Offset orb) {
    const cols = 10;
    const rows = 10;

    const left = 32;
    const top = 33;
    const right = 32;
    const bottom = 34;

    final gridW = size.width - left - right;
    final gridH = size.height - top - bottom;

    final activeRadius = 47 + slider * 14;
    final closeNodes = <_LineNode>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final offset = row.isEven ? 0.0 : 0.5;
        final nx = (col + offset) / (cols - 0.25);

        if (nx > 1) continue;

        final ny = row / (rows - 1);

        final dot = Offset(left + nx * gridW, top + ny * gridH);

        final distance = (dot - orb).distance;

        if (distance < activeRadius) {
          closeNodes.add(_LineNode(dot, distance));
        }
      }
    }

    closeNodes.sort((a, b) => a.distance.compareTo(b.distance));

    final selectedNodes = closeNodes.take(9).toList();

    for (var i = 0; i < selectedNodes.length; i++) {
      final node = selectedNodes[i];
      final alpha = (1 - node.distance / activeRadius) * (0.13 + motion * 0.18);

      final control = Offset(
        (orb.dx + node.offset.dx) / 2 + math.sin(time * 2 + i) * 5,
        (orb.dy + node.offset.dy) / 2 + math.cos(time * 2 + i) * 5,
      );

      final path = Path()
        ..moveTo(orb.dx, orb.dy)
        ..quadraticBezierTo(
          control.dx,
          control.dy,
          node.offset.dx,
          node.offset.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFE2EE).withValues(alpha: alpha),
      );
    }
  }

  void _drawOrb(Canvas canvas, Size size, Offset orb) {
    canvas.drawCircle(
      orb,
      66,
      Paint()
        ..shader = ui.Gradient.radial(
          orb,
          66,
          [
            Colors.white.withValues(alpha: 0.06 + motion * 0.10),
            const Color(0xFFFFB4D4).withValues(alpha: 0.08 + motion * 0.12),
            Colors.transparent,
          ],
          [0.0, 0.32, 1.0],
        ),
    );

    canvas.drawCircle(
      orb,
      42 + motion * 12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.05 + motion * 0.13),
    );

    canvas.drawCircle(
      orb,
      25 + slider * 6,
      Paint()
        ..color = Colors.white
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.2),
    );

    canvas.drawCircle(
      orb,
      25 + slider * 6,
      Paint()
        ..shader = ui.Gradient.radial(
          orb - const Offset(7, 9),
          34,
          [
            Colors.white,
            Colors.white.withValues(alpha: 0.82),
            const Color(0xFFEEEEEE).withValues(alpha: 0.96),
          ],
          [0.0, 0.52, 1.0],
        ),
    );

    canvas.drawCircle(
      orb + const Offset(-10, 17),
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.78 + motion * 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _ToneFieldPainter oldDelegate) => true;
}

class _LineNode {
  const _LineNode(this.offset, this.distance);

  final Offset offset;
  final double distance;
}

class RanaInteractiveSlider extends StatefulWidget {
  const RanaInteractiveSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<RanaInteractiveSlider> createState() => _RanaInteractiveSliderState();
}

class _RanaInteractiveSliderState extends State<RanaInteractiveSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  double _x = 0;
  double _targetX = 0;
  double _motion = 0;
  double _motionTarget = 0;
  int _motionUntil = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _targetX = _normalize(widget.value);
    _x = _targetX;

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);

    _wakeMotion(900);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _normalize(double val) =>
      ((val - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _denormalize(double norm) =>
      widget.min + norm * (widget.max - widget.min);

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _startLoop() {
    if (!_ticker.isAnimating) {
      _ticker.repeat();
    }
  }

  void _wakeMotion([int durationMs = 1300]) {
    _motionUntil = DateTime.now().millisecondsSinceEpoch + durationMs;
    _motionTarget = 1;
    _startLoop();
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ease = _dragging ? 0.28 : 0.13;

    _x = _lerp(_x, _targetX, ease);

    if (now > _motionUntil) {
      _motionTarget = 0;
    }

    _motion = _lerp(_motion, _motionTarget, _dragging ? 0.18 : 0.075);

    final stillMoving =
        _dragging || _motion > 0.008 || (_x - _targetX).abs() > 0.002;

    setState(() {});

    if (!stillMoving) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(covariant RanaInteractiveSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final normalized = _normalize(widget.value);
      if (!_dragging) {
        _targetX = normalized;
        _startLoop();
      }
    }
  }

  void _setSliderFromLocal(Offset localPosition, double width) {
    const edge = 20.0;
    final dx = localPosition.dx.clamp(edge, width - edge);
    final denom = width - edge * 2;
    _targetX = denom > 0 ? (dx - edge) / denom : 0.0;

    widget.onChanged(_denormalize(_targetX));
    _wakeMotion(1200);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              widget.valueLabel,
              style: const TextStyle(
                color: Color(0xFFF39C12),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 40.0;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _setSliderFromLocal(details.localPosition, width);
              },
              onPanStart: (details) {
                _dragging = true;
                _setSliderFromLocal(details.localPosition, width);
              },
              onPanUpdate: (details) {
                _setSliderFromLocal(details.localPosition, width);
              },
              onPanEnd: (_) {
                _dragging = false;
                _wakeMotion(1200);
              },
              onPanCancel: () {
                _dragging = false;
                _wakeMotion(1200);
              },
              child: SizedBox(
                width: width,
                height: height,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ToneSliderPainter(value: _x, motion: _motion),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _ToneSliderPainter extends CustomPainter {
  const _ToneSliderPainter({required this.value, required this.motion});

  final double value;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [
            const Color(0xFF527F91).withValues(alpha: 0.90),
            const Color(0xFF66676C).withValues(alpha: 0.94),
            const Color(0xFF9D4D4F).withValues(alpha: 0.91),
            const Color(0xFF702B4E).withValues(alpha: 0.90),
          ],
          [0.0, 0.35, 0.72, 1.0],
        ),
    );

    final knobX = 20 + value * (size.width - 40);

    final fillRect = Rect.fromLTWH(
      5,
      5,
      (knobX - 4).clamp(0.0, size.width - 10),
      size.height - 10,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(999)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(knobX, 0),
          [
            const Color(0xFFBCE2EE).withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.08),
            const Color(0xFFFFC2D0).withValues(alpha: 0.28),
          ],
          [0.0, 0.58, 1.0],
        ),
    );

    final knobCenter = Offset(knobX, size.height / 2);

    canvas.drawCircle(
      knobCenter,
      25,
      Paint()
        ..color = const Color(
          0xFFFFD2E2,
        ).withValues(alpha: 0.15 + motion * 0.16)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          10 + motion * 10,
        ),
    );

    canvas.drawCircle(knobCenter, 16, Paint()..color = Colors.white);

    canvas.drawCircle(
      knobCenter,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.88),
    );

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(covariant _ToneSliderPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.motion != motion;
}

class StylesPanelBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    canvas.save();
    canvas.clipRRect(rrect);

    // Base background gradient
    final base = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        const Color(0xFF111C18),
        const Color(0xFF0C0E0D),
      ]);
    canvas.drawRect(rect, base);

    // Green glow top-center
    canvas.drawCircle(
      Offset(size.width * 0.50, -8),
      size.width * 0.44,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.50, -8),
          size.width * 0.44,
          [const Color(0xFF43FFB2).withValues(alpha: 0.12), Colors.transparent],
        ),
    );

    // Plum glow bottom-left
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.48),
      size.width * 0.48,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.16, size.height * 0.48),
          size.width * 0.48,
          [const Color(0xFF7F244C).withValues(alpha: 0.16), Colors.transparent],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StylesPanelBackgroundPainter oldDelegate) =>
      false;
}
