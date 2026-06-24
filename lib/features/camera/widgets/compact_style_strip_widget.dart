import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

/// Minimalist horizontal strip displaying active style parameters.
class CompactStyleStripWidget extends StatelessWidget {
  /// Main constructor.
  const CompactStyleStripWidget({
    required this.activePreset,
    super.key,
  });

  /// The currently active preset (if any).
  final PresetModel? activePreset;

  @override
  Widget build(BuildContext context) {
    if (activePreset == null) {
      return const SizedBox.shrink();
    }

    final style = activePreset!.style;
    final toneVal = style?.tone ?? 0.0;
    final colorVal = style?.color ?? 0.0;
    final textureVal = style?.texture ?? 0.0;

    String formatOffsetValue(double val) {
      final rounded = val.round();
      if (rounded > 0) {
        return '+$rounded';
      }
      return '$rounded';
    }

    String formatIntensityValue(double val) => '${val.round()}';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16161A), // Sleek secondary dark background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStripItem('TONE', formatOffsetValue(toneVal)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              height: 12,
              color: Colors.white10,
            ),
            _buildStripItem('COLOR', formatOffsetValue(colorVal)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              height: 12,
              color: Colors.white10,
            ),
            _buildStripItem('TEXTURE', formatIntensityValue(textureVal)),
          ],
        ),
      ),
    );
  }

  Widget _buildStripItem(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF39C12), // Vintage orange stamp color
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
}
