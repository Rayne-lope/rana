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

@immutable
class _MatrixSelection {
  const _MatrixSelection({required this.column, required this.row});

  factory _MatrixSelection.fromUndertone(
    double undertoneX,
    double undertoneY,
  ) => _MatrixSelection(
    column: _snapIndex((undertoneX.clamp(-1.0, 1.0) + 1) / 2),
    row: _snapIndex((1 - undertoneY.clamp(-1.0, 1.0)) / 2),
  );

  factory _MatrixSelection.fromLocalPosition(
    Offset localPosition,
    Size size,
    double paddingFraction,
  ) {
    final horizontalInset = size.width * paddingFraction;
    final verticalInset = size.height * paddingFraction;
    final clampedX = localPosition.dx.clamp(
      horizontalInset,
      size.width - horizontalInset,
    );
    final clampedY = localPosition.dy.clamp(
      verticalInset,
      size.height - verticalInset,
    );
    final normalizedX =
        (clampedX - horizontalInset) / (size.width - horizontalInset * 2);
    final normalizedY =
        (clampedY - verticalInset) / (size.height - verticalInset * 2);
    return _MatrixSelection(
      column: _snapIndex(normalizedX),
      row: _snapIndex(normalizedY),
    );
  }

  static const int axisCount = 11;

  static int _snapIndex(num normalized) =>
      (normalized * (axisCount - 1)).round().clamp(0, axisCount - 1);

  final int column;
  final int row;

  double get undertoneX => -1 + (column / (axisCount - 1)) * 2;
  double get undertoneY => 1 - (row / (axisCount - 1)) * 2;

  @override
  bool operator ==(Object other) =>
      other is _MatrixSelection && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);
}

class _RanaInteractiveUndertonePadState
    extends State<RanaInteractiveUndertonePad>
    with SingleTickerProviderStateMixin {
  static const int _matrixCount = _MatrixSelection.axisCount;
  static const double _gridPaddingFraction = 0.085;
  static const double _headerReserve = 24;
  static const double _outerAxisReserve = 33;
  static const double _sideAxisWidth = 32;

  late final AnimationController _pulseController;
  late final ValueNotifier<_MatrixSelection> _selection;
  late final ValueNotifier<bool> _isDragging;

  @override
  void initState() {
    super.initState();
    _selection = ValueNotifier<_MatrixSelection>(
      _MatrixSelection.fromUndertone(widget.undertoneX, widget.undertoneY),
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
      _selection.value = _MatrixSelection.fromUndertone(
        widget.undertoneX,
        widget.undertoneY,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _selection.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  void _updateFromLocalPosition(Offset localPosition, Size size) {
    if (size.isEmpty) return;
    final selection = _MatrixSelection.fromLocalPosition(
      localPosition,
      size,
      _gridPaddingFraction,
    );
    if (selection == _selection.value) return;

    _selection.value = selection;
    widget.onChanged(selection.undertoneX, selection.undertoneY);
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
  Widget build(BuildContext context) => Padding(
    padding: widget.contentPadding,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? math.max<double>(
                0,
                constraints.maxHeight - _headerReserve - _outerAxisReserve,
              )
            : widget.maxPadSize;
        final availableWidth = constraints.maxWidth.isFinite
            ? math.max<double>(0, constraints.maxWidth - _sideAxisWidth * 2)
            : widget.maxPadSize;
        final matrixSize = math.min<double>(
          widget.maxPadSize,
          math.min<double>(availableWidth, availableHeight),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ValueListenableBuilder<_MatrixSelection>(
                  valueListenable: _selection,
                  builder: (context, selection, child) => Text(
                    '${_formatAxis(selection.undertoneX)} / '
                    '${_formatAxis(selection.undertoneY)}',
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
            const SizedBox(height: 6),
            const _PadAxisLabel(label: 'MAGENTA', alignment: TextAlign.center),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: _sideAxisWidth,
                  child: _PadAxisLabel(
                    label: 'WARM',
                    alignment: TextAlign.center,
                  ),
                ),
                SizedBox.square(
                  dimension: matrixSize,
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
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _UndertoneMatrixPainter(
                              selection: _selection,
                              isDragging: _isDragging,
                              pulse: _pulseController,
                              columns: _matrixCount,
                              rows: _matrixCount,
                              paddingFraction: _gridPaddingFraction,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(
                  width: _sideAxisWidth,
                  child: _PadAxisLabel(
                    label: 'COOL',
                    alignment: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _PadAxisLabel(label: 'GREEN', alignment: TextAlign.center),
          ],
        );
      },
    ),
  );
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
    required this.selection,
    required this.isDragging,
    required this.pulse,
    required this.columns,
    required this.rows,
    required this.paddingFraction,
  }) : super(repaint: Listenable.merge([selection, isDragging, pulse]));

  final ValueListenable<_MatrixSelection> selection;
  final ValueListenable<bool> isDragging;
  final Animation<double> pulse;
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
    final selected = selection.value;
    final puck = _pointFor(size, selected.column, selected.row);
    final dragging = isDragging.value;
    final pulseValue = pulse.value;

    canvas.save();
    canvas.clipRRect(roundedRect);
    _drawBackground(canvas, rect);
    _drawMatrix(canvas, size, selected, dragging, pulseValue);
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

  void _drawBackground(Canvas canvas, Rect rect) {
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
  }

  void _drawMatrix(
    Canvas canvas,
    Size size,
    _MatrixSelection selected,
    bool dragging,
    double pulseValue,
  ) {
    final baseRadius = math.max(1.15, size.shortestSide * 0.0083);

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final point = _pointFor(size, column, row);
        final onAxis = column == selected.column || row == selected.row;
        final gridDistance = math.sqrt(
          math.pow(column - selected.column, 2) +
              math.pow(row - selected.row, 2),
        );
        final isNear = dragging && gridDistance <= 1.25;
        final isMedium =
            dragging && gridDistance > 1.25 && gridDistance <= 2.25;
        final radius = isNear
            ? baseRadius * (1.75 + pulseValue * 0.15)
            : isMedium
            ? baseRadius * (1.30 + pulseValue * 0.08)
            : baseRadius;
        final alpha = isNear
            ? 1.0
            : isMedium
            ? 0.82
            : onAxis
            ? 0.98
            : 0.56;

        if (isNear || isMedium) {
          canvas.drawCircle(
            point,
            radius * (isNear ? 2.8 : 2.2),
            Paint()
              ..color = const Color(
                0xFFFFD3C1,
              ).withValues(alpha: isNear ? 0.42 + pulseValue * 0.12 : 0.20)
              ..maskFilter = ui.MaskFilter.blur(
                ui.BlurStyle.normal,
                size.shortestSide * (isNear ? 0.032 : 0.020),
              ),
          );
        }

        canvas.drawCircle(
          point,
          radius,
          Paint()..color = Colors.white.withValues(alpha: alpha),
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
    canvas.drawArc(
      puckRect.deflate(size.shortestSide * 0.004),
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.shortestSide * 0.002)
        ..color = const Color(0xFF797775).withValues(alpha: 0.46),
    );
    canvas.drawArc(
      puckRect.deflate(size.shortestSide * 0.007),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, size.shortestSide * 0.0018)
        ..color = Colors.white.withValues(alpha: 0.58),
    );

    final glossRect = Rect.fromCenter(
      center: puck.translate(-puckRadius * 0.10, -puckRadius * 0.40),
      width: puckRadius * 1.16,
      height: puckRadius * 0.38,
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
          ..color = const Color(0xFFF4C44F)
              .withValues(alpha: 0.18 + pulseValue * 0.08)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            6 + pulseValue * 3,
          ),
      );
    }

    final knobRect = Rect.fromCircle(center: knob, radius: thumbRadius);

    // Convex metallic radial dial
    canvas.drawCircle(
      knob,
      thumbRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.18, -0.22),
          colors: [
            Color(0xFF4C4F56),
            Color(0xFF282A2F),
            Color(0xFF121316),
          ],
          stops: [0, 0.68, 1],
        ).createShader(knobRect),
    );

    // Fine inner highlight rim on the edge to simulate metal reflection
    canvas.drawCircle(
      knob,
      thumbRadius - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    // Outer border of the knob
    canvas.drawCircle(
      knob,
      thumbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF0F1012),
    );

    // Gold center indicator pin
    canvas.drawCircle(
      knob,
      2.8,
      Paint()
        ..color = const Color(0xFFF4C44F)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.3),
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
      color: const Color(0xFF0A0B0E),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 5,
          offset: const Offset(0, 2),
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
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF39C12),
            fontSize: 12,
            fontWeight: FontWeight.w900,
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
