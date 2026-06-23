import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/utils/color_preview_calculator.dart';

/// Preset thumbnail widget showing a circular gradient preview.
class PresetThumbnailWidget extends StatelessWidget {
  /// Main constructor.
  const PresetThumbnailWidget({
    required this.preset,
    this.size = 12.0,
    super.key,
  });

  /// The preset model recipe.
  final PresetModel preset;

  /// The size of the circular thumbnail.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ColorPreviewCalculator.calculate(preset);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GradientCirclePainter(
          shadowColor: colors.shadow,
          highlightColor: colors.highlight,
        ),
      ),
    );
  }
}

class _GradientCirclePainter extends CustomPainter {
  const _GradientCirclePainter({
    required this.shadowColor,
    required this.highlightColor,
  });

  final Color shadowColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [shadowColor, highlightColor],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientCirclePainter oldDelegate) =>
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.highlightColor != highlightColor;
}
