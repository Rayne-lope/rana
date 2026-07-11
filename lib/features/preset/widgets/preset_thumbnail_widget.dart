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

  String _shortenName(String name) {
    var clean = name.toUpperCase();
    if (clean.startsWith('RANA ')) {
      clean = clean.replaceFirst('RANA ', '');
    } else if (clean.startsWith('KODAK ')) {
      clean = clean.replaceFirst('KODAK ', '');
    } else if (clean.startsWith('FUJIFILM ')) {
      clean = clean.replaceFirst('FUJIFILM ', '');
    } else if (clean.startsWith('ILFORD ')) {
      clean = clean.replaceFirst('ILFORD ', '');
    } else if (clean.startsWith('AGFA ')) {
      clean = clean.replaceFirst('AGFA ', '');
    }

    if (clean.length > 6) {
      return '${clean.substring(0, 5)}.';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final width = size;
    final height = size * 1.35;
    final paddingVal = width * 0.08;

    return Center(
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.fromLTRB(
          paddingVal,
          paddingVal,
          paddingVal,
          paddingVal * 0.8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFC), // Premium off-white paper color
          borderRadius: BorderRadius.circular(width * 0.08),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 3.5,
              offset: const Offset(0, 1.2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A), // Dark photo backing
                  borderRadius: BorderRadius.circular(width * 0.04),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(width * 0.04),
                        child: CustomPaint(
                          painter: PresetIllustrationPainter(preset),
                        ),
                      ),
                    ),
                    // Glossy shine diagonal overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(width * 0.04),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0.05),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.22, 0.32, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: width * 0.08),
            // Typed preset label in signature area
            Text(
              _shortenName(preset.name),
              style: TextStyle(
                color: const Color(0xFF7E7E84).withValues(alpha: 0.85),
                fontSize: width * 0.105,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 0.3,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ],
        ),
      ),
    );
  }
}
