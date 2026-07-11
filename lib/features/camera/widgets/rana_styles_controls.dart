import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RanaInteractiveUndertonePad extends StatefulWidget {
  const RanaInteractiveUndertonePad({
    required this.undertoneX,
    required this.undertoneY,
    required this.styleStrength,
    required this.onChanged,
    this.maxPadSize = 220,
    this.contentPadding = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  final double undertoneX;
  final double undertoneY;
  final double styleStrength;
  final void Function(double x, double y) onChanged;
  final double maxPadSize;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<RanaInteractiveUndertonePad> createState() =>
      _RanaInteractiveUndertonePadState();
}

class _RanaInteractiveUndertonePadState
    extends State<RanaInteractiveUndertonePad>
    with SingleTickerProviderStateMixin {
  static const int _matrixCount = 11;
  static const double _gridPaddingFraction = 0.085;
  static const double _headerReserve = 32;

  late final AnimationController _pulseController;
  late final ValueNotifier<Offset> _puckPosition;
  late final ValueNotifier<bool> _isDragging;

  @override
  void initState() {
    super.initState();
    _puckPosition = ValueNotifier<Offset>(
      _toPuckPosition(widget.undertoneX, widget.undertoneY),
    );
    _isDragging = ValueNotifier<bool>(false);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant RanaInteractiveUndertonePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging.value &&
        (oldWidget.undertoneX != widget.undertoneX ||
            oldWidget.undertoneY != widget.undertoneY)) {
      _puckPosition.value = _toPuckPosition(
        widget.undertoneX,
        widget.undertoneY,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _puckPosition.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  Offset _toPuckPosition(double undertoneX, double undertoneY) {
    const usableSpan = 1 - (_gridPaddingFraction * 2);
    return Offset(
      _gridPaddingFraction +
          (((undertoneX.clamp(-1.0, 1.0) + 1) / 2) * usableSpan),
      _gridPaddingFraction +
          (((1 - undertoneY.clamp(-1.0, 1.0)) / 2) * usableSpan),
    );
  }

  double _toUndertoneValue(double normalized) {
    const usableSpan = 1 - (_gridPaddingFraction * 2);
    return (((normalized - _gridPaddingFraction) / usableSpan) * 2 - 1).clamp(
      -1.0,
      1.0,
    );
  }

  void _updateFromLocalPosition(Offset localPosition, Size size) {
    if (size.isEmpty) return;

    final minX = size.width * _gridPaddingFraction;
    final maxX = size.width - minX;
    final minY = size.height * _gridPaddingFraction;
    final maxY = size.height - minY;
    final clamped = Offset(
      localPosition.dx.clamp(minX, maxX),
      localPosition.dy.clamp(minY, maxY),
    );
    final normalized = Offset(
      clamped.dx / size.width,
      clamped.dy / size.height,
    );

    _puckPosition.value = normalized;
    widget.onChanged(
      _toUndertoneValue(normalized.dx),
      -_toUndertoneValue(normalized.dy),
    );
  }

  void _startDrag(Offset localPosition, Size size) {
    _isDragging.value = true;
    _pulseController.repeat(reverse: true);
    _updateFromLocalPosition(localPosition, size);
  }

  void _endDrag() {
    _isDragging.value = false;
    _pulseController
      ..stop()
      ..value = 0;
  }

  static String _formatAxis(double value) {
    final rounded = (value * 100).round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStrength = (widget.styleStrength / 100).clamp(0.0, 1.0);

    return Padding(
      padding: widget.contentPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight.isFinite
              ? math.max<double>(0, constraints.maxHeight - _headerReserve)
              : widget.maxPadSize;
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.maxPadSize;
          final size = math.min<double>(
            widget.maxPadSize,
            math.min<double>(maxWidth, maxHeight),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
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
                  ValueListenableBuilder<Offset>(
                    valueListenable: _puckPosition,
                    builder: (context, position, child) => Text(
                      '${_formatAxis(_toUndertoneValue(position.dx))} / '
                      '${_formatAxis(-_toUndertoneValue(position.dy))}',
                      style: const TextStyle(
                        color: Color(0xFFF39C12),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: SizedBox.square(
                  dimension: size,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final paintSize = constraints.biggest;
                      return GestureDetector(
                        key: const Key('undertone-pad'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _updateFromLocalPosition(
                          details.localPosition,
                          paintSize,
                        ),
                        onPanStart: (details) =>
                            _startDrag(details.localPosition, paintSize),
                        onPanUpdate: (details) => _updateFromLocalPosition(
                          details.localPosition,
                          paintSize,
                        ),
                        onPanEnd: (_) => _endDrag(),
                        onPanCancel: _endDrag,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _UndertoneMatrixPainter(
                                    puckPosition: _puckPosition,
                                    isDragging: _isDragging,
                                    pulse: _pulseController,
                                    styleStrength: normalizedStrength,
                                    columns: _matrixCount,
                                    rows: _matrixCount,
                                    paddingFraction: _gridPaddingFraction,
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
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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

class _UndertoneMatrixPainter extends CustomPainter {
  _UndertoneMatrixPainter({
    required this.puckPosition,
    required this.isDragging,
    required this.pulse,
    required this.styleStrength,
    required this.columns,
    required this.rows,
    required this.paddingFraction,
  }) : super(repaint: Listenable.merge([puckPosition, isDragging, pulse]));

  final ValueListenable<Offset> puckPosition;
  final ValueListenable<bool> isDragging;
  final Animation<double> pulse;
  final double styleStrength;
  final int columns;
  final int rows;
  final double paddingFraction;

  Offset _pointFor(Size size, int column, int row) => Offset(
    size.width *
        (paddingFraction +
            (column / (columns - 1)) * (1 - paddingFraction * 2)),
    size.height *
        (paddingFraction + (row / (rows - 1)) * (1 - paddingFraction * 2)),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cornerRadius = Radius.circular(size.shortestSide * 0.12);
    final roundedRect = RRect.fromRectAndRadius(rect, cornerRadius);
    final puck = Offset(
      puckPosition.value.dx * size.width,
      puckPosition.value.dy * size.height,
    );
    final dragging = isDragging.value;
    final pulseValue = pulse.value;

    canvas.save();
    canvas.clipRRect(roundedRect);
    _drawBackground(canvas, rect, puck, styleStrength);
    _drawMatrix(canvas, size, puck, dragging, pulseValue);
    _drawPuck(canvas, size, puck, dragging, pulseValue);
    canvas.restore();

    canvas.drawRRect(
      roundedRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.17),
    );
  }

  void _drawBackground(Canvas canvas, Rect rect, Offset puck, double strength) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD4886D), Color(0xFF776E7A), Color(0xFF6687B6)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.92),
          radius: 0.95,
          colors: [
            const Color(0xFFE88AB7).withValues(alpha: 0.40),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.90),
          radius: 0.95,
          colors: [
            const Color(0xFF68B994).withValues(alpha: 0.40),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      puck,
      rect.width * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(puck, rect.width * 0.42, [
          Colors.white.withValues(alpha: 0.05 + strength * 0.10),
          Colors.transparent,
        ]),
    );
  }

  void _drawMatrix(
    Canvas canvas,
    Size size,
    Offset puck,
    bool dragging,
    double pulseValue,
  ) {
    final baseRadius = math.max(1.15, size.shortestSide * 0.0083);
    final influenceRadius = size.shortestSide * (dragging ? 0.32 : 0.22);

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final point = _pointFor(size, column, row);
        final distance = (point - puck).distance;
        final proximity = (1 - distance / influenceRadius).clamp(0.0, 1.0);
        final onAxis =
            (point.dx - puck.dx).abs() < baseRadius * 1.5 ||
            (point.dy - puck.dy).abs() < baseRadius * 1.5;
        final glow = dragging ? proximity : (onAxis ? proximity * 0.65 : 0.0);
        final radius =
            baseRadius + glow * baseRadius * (1.4 + pulseValue * 0.35);

        if (glow > 0) {
          canvas.drawCircle(
            point,
            radius * 2.4,
            Paint()
              ..color = const Color(
                0xFFFFD3C1,
              ).withValues(alpha: (0.08 + glow * 0.34).clamp(0.0, 0.42))
              ..maskFilter = ui.MaskFilter.blur(
                ui.BlurStyle.normal,
                size.shortestSide * 0.025,
              ),
          );
        }

        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..color = Colors.white.withValues(
              alpha: (0.56 + proximity * 0.38).clamp(0.0, 0.98),
            ),
        );
      }
    }
  }

  void _drawPuck(
    Canvas canvas,
    Size size,
    Offset puck,
    bool dragging,
    double pulseValue,
  ) {
    final puckRadius = size.shortestSide * (dragging ? 0.064 : 0.053);
    if (dragging) {
      canvas.drawCircle(
        puck,
        puckRadius * (1.85 + pulseValue * 0.35),
        Paint()
          ..color = const Color(
            0xFFFFC8AD,
          ).withValues(alpha: 0.34 + pulseValue * 0.20)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            puckRadius * (1.25 + pulseValue * 0.25),
          ),
      );
    }

    final puckRect = Rect.fromCircle(center: puck, radius: puckRadius);
    canvas.drawCircle(
      puck,
      puckRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.34, -0.38),
          radius: 1.1,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F5F3), Color(0xFFD1CFCE)],
          stops: [0, 0.48, 1],
        ).createShader(puckRect),
    );
    canvas.drawCircle(
      puck,
      puckRadius + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * 0.003)
        ..color = const Color(0xFF242327).withValues(alpha: 0.82),
    );
    canvas.drawCircle(
      puck,
      puckRadius - size.shortestSide * 0.006,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.shortestSide * 0.002)
        ..color = Colors.white.withValues(alpha: 0.58),
    );

    final glossRect = Rect.fromCenter(
      center: puck.translate(-puckRadius * 0.12, -puckRadius * 0.42),
      width: puckRadius * 1.12,
      height: puckRadius * 0.42,
    );
    canvas.drawOval(
      glossRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(glossRect),
    );
  }

  @override
  bool shouldRepaint(covariant _UndertoneMatrixPainter oldDelegate) =>
      oldDelegate.styleStrength != styleStrength ||
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows ||
      oldDelegate.paddingFraction != paddingFraction;
}

class RanaInteractiveSlider extends StatefulWidget {
  const RanaInteractiveSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.bottomPadding = 14,
    this.labelGap = 6,
    this.trackHeight = 40,
    this.toneReadout,
    this.colorReadout,
    this.warmthReadout,
    super.key,
  }) : assert(
         (toneReadout == null &&
                 colorReadout == null &&
                 warmthReadout == null) ||
             (toneReadout != null &&
                 colorReadout != null &&
                 warmthReadout != null),
         'Readouts must either all be set or all be omitted.',
       );

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double bottomPadding;
  final double labelGap;
  final double trackHeight;
  final String? toneReadout;
  final String? colorReadout;
  final String? warmthReadout;

  bool get hasReadout =>
      toneReadout != null && colorReadout != null && warmthReadout != null;

  @override
  State<RanaInteractiveSlider> createState() => _RanaInteractiveSliderState();
}

class _RanaInteractiveSliderState extends State<RanaInteractiveSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final ValueNotifier<double> _position;
  late final ValueNotifier<bool> _isDragging;

  @override
  void initState() {
    super.initState();
    _position = ValueNotifier<double>(_normalize(widget.value));
    _isDragging = ValueNotifier<bool>(false);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant RanaInteractiveSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging.value && oldWidget.value != widget.value) {
      _position.value = _normalize(widget.value);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _position.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  double _normalize(double value) {
    final range = widget.max - widget.min;
    if (range == 0) return 0;
    return ((value - widget.min) / range).clamp(0.0, 1.0);
  }

  double _denormalize(double normalized) =>
      widget.min + normalized * (widget.max - widget.min);

  void _updateFromLocalPosition(Offset localPosition, Size size) {
    const thumbRadius = 20.0;
    final minX = math.min(thumbRadius, size.width / 2);
    final maxX = math.max(minX, size.width - thumbRadius);
    final span = maxX - minX;
    final normalized = span == 0
        ? 0.0
        : ((localPosition.dx.clamp(minX, maxX) - minX) / span);

    _position.value = normalized;
    widget.onChanged(_denormalize(normalized));
  }

  void _startDrag(Offset localPosition, Size size) {
    _isDragging.value = true;
    _pulseController.repeat(reverse: true);
    _updateFromLocalPosition(localPosition, size);
  }

  void _endDrag() {
    _isDragging.value = false;
    _pulseController
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: widget.bottomPadding),
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
        SizedBox(height: widget.labelGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.maxWidth,
              math.max<double>(40, widget.trackHeight),
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _updateFromLocalPosition(details.localPosition, size),
              onPanStart: (details) => _startDrag(details.localPosition, size),
              onPanUpdate: (details) =>
                  _updateFromLocalPosition(details.localPosition, size),
              onPanEnd: (_) => _endDrag(),
              onPanCancel: _endDrag,
              child: SizedBox.fromSize(
                size: size,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PremiumSliderPainter(
                      position: _position,
                      isDragging: _isDragging,
                      pulse: _pulseController,
                      palette: _SliderPalette.forLabel(widget.label),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.hasReadout) ...[
          const SizedBox(height: 10),
          _StyleReadout(
            tone: widget.toneReadout!,
            color: widget.colorReadout!,
            warmth: widget.warmthReadout!,
          ),
        ],
      ],
    ),
  );
}

class _SliderPalette {
  const _SliderPalette(this.colors, this.stops);

  factory _SliderPalette.forLabel(String label) {
    switch (label.toLowerCase()) {
      case 'color':
        return const _SliderPalette(
          [
            Color(0xFF7892B8),
            Color(0xFFABA6B0),
            Color(0xFFD9A49C),
            Color(0xFFF07A58),
          ],
          [0, 0.36, 0.67, 1],
        );
      case 'palette':
        return const _SliderPalette(
          [
            Color(0xFF565B66),
            Color(0xFF8C8589),
            Color(0xFFCF9B7B),
            Color(0xFFFFB357),
          ],
          [0, 0.34, 0.70, 1],
        );
      default:
        return const _SliderPalette(
          [
            Color(0xFF7C9DFF),
            Color(0xFFB5A9CB),
            Color(0xFFCFAAA1),
            Color(0xFFFF7D4D),
          ],
          [0, 0.30, 0.62, 1],
        );
    }
  }

  final List<Color> colors;
  final List<double> stops;
}

class _PremiumSliderPainter extends CustomPainter {
  _PremiumSliderPainter({
    required this.position,
    required this.isDragging,
    required this.pulse,
    required this.palette,
  }) : super(repaint: Listenable.merge([position, isDragging, pulse]));

  final ValueListenable<double> position;
  final ValueListenable<bool> isDragging;
  final Animation<double> pulse;
  final _SliderPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const thumbRadius = 20.0;
    final trackHeight = math.min<double>(34, size.height - 4);
    final trackRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: trackHeight,
    );
    final track = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackHeight / 2),
    );
    final knobX = thumbRadius + position.value * (size.width - thumbRadius * 2);
    final knob = Offset(knobX, size.height / 2);
    final dragging = isDragging.value;
    final pulseValue = pulse.value;

    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          colors: palette.colors,
          stops: palette.stops,
        ).createShader(trackRect)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.35),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(trackRect),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    if (dragging) {
      canvas.drawCircle(
        knob,
        thumbRadius * (1.35 + pulseValue * 0.22),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20 + pulseValue * 0.12)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            9 + pulseValue * 5,
          ),
      );
    }
    canvas.drawCircle(
      knob,
      thumbRadius,
      Paint()
        ..color = const Color(0xFFFDFCFB)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2),
    );
    canvas.drawCircle(
      knob,
      thumbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      knob.translate(-thumbRadius * 0.22, -thumbRadius * 0.28),
      thumbRadius * 0.26,
      Paint()..color = Colors.white.withValues(alpha: 0.68),
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumSliderPainter oldDelegate) =>
      oldDelegate.palette.colors != palette.colors ||
      oldDelegate.palette.stops != palette.stops;
}

class _StyleReadout extends StatelessWidget {
  const _StyleReadout({
    required this.tone,
    required this.color,
    required this.warmth,
  });

  final String tone;
  final String color;
  final String warmth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ReadoutItem(label: 'TONE', value: tone),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ReadoutItem(label: 'COLOR', value: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ReadoutItem(label: 'WARMTH', value: warmth),
      ),
    ],
  );
}

class _ReadoutItem extends StatelessWidget {
  const _ReadoutItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      color: Colors.white.withValues(alpha: 0.035),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A898F),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

class StylesPanelBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    canvas.save();
    canvas.clipRRect(rrect);

    final base = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        const Color(0xFF111C18),
        const Color(0xFF0C0E0D),
      ]);
    canvas.drawRect(rect, base);

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
