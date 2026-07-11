import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/widgets/preset_illustration_painter.dart';

/// Preset thumbnail widget showing a beautiful, vector-drawn Polaroid/Instax film card.
class PresetThumbnailWidget extends StatelessWidget {
  /// Main constructor.
  const PresetThumbnailWidget({
    required this.preset,
    this.size = 28.0,
    super.key,
  });

  /// The preset model recipe.
  final PresetModel preset;

  /// The width of the Instax paper card.
  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size;
    final height = size * 1.25;
    final paddingVal = width * 0.08;
    final bottomPaddingVal = width * 0.24;

    return Center(
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.fromLTRB(
          paddingVal,
          paddingVal,
          paddingVal,
          bottomPaddingVal,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB), // Clean off-white paper color
          borderRadius: BorderRadius.circular(width * 0.08),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF16161A), // Dark photo backing
            borderRadius: BorderRadius.circular(width * 0.03),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.03),
            child: CustomPaint(
              painter: PresetIllustrationPainter(preset),
            ),
          ),
        ),
      ),
    );
  }
}
