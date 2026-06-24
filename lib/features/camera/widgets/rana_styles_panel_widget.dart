import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/rana_style.dart';

/// Expanded Rana Styles editor shown from the camera action plate.
class RanaStylesPanelWidget extends StatelessWidget {
  /// Main constructor.
  const RanaStylesPanelWidget({
    required this.activePresetName,
    required this.style,
    required this.onStyleChanged,
    required this.onReset,
    required this.onApply,
    required this.onSaveAsStyle,
    super.key,
  });

  /// Name of the currently active base preset.
  final String activePresetName;

  /// Effective, editable style values.
  final RanaStyle style;

  /// Called whenever a style slider changes.
  final ValueChanged<RanaStyle> onStyleChanged;

  /// Resets the effective style.
  final VoidCallback onReset;

  /// Applies the current style.
  final VoidCallback onApply;

  /// Placeholder action for the future style persistence flow.
  final VoidCallback onSaveAsStyle;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF111114),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFF39C12),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RANA STYLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activePresetName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StyleSlider(
                  label: 'Tone',
                  valueLabel: _formatOffset(style.tone),
                  value: style.tone.clamp(-100.0, 100.0),
                  min: -100,
                  max: 100,
                  divisions: 200,
                  onChanged: (value) =>
                      onStyleChanged(style.copyWith(tone: value)),
                ),
                _StyleSlider(
                  label: 'Color',
                  valueLabel: _formatOffset(style.color),
                  value: style.color.clamp(-100.0, 100.0),
                  min: -100,
                  max: 100,
                  divisions: 200,
                  onChanged: (value) =>
                      onStyleChanged(style.copyWith(color: value)),
                ),
                _StyleSlider(
                  label: 'Texture',
                  valueLabel: _formatIntensity(style.texture),
                  value: style.texture.clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) =>
                      onStyleChanged(style.copyWith(texture: value)),
                ),
                _StyleSlider(
                  label: 'Style Strength',
                  valueLabel: '${_formatIntensity(style.styleStrength)}%',
                  value: style.styleStrength.clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) =>
                      onStyleChanged(style.copyWith(styleStrength: value)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StyleActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'RESET',
                        onPressed: onReset,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StyleActionButton(
                        icon: Icons.check_rounded,
                        label: 'APPLY',
                        isPrimary: true,
                        onPressed: onApply,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StyleActionButton(
                        icon: Icons.bookmark_add_outlined,
                        label: 'SAVE STYLE',
                        onPressed: onSaveAsStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatOffset(double value) {
    final rounded = value.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  static String _formatIntensity(double value) => '${value.round()}';
}

class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
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
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFF39C12),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
            overlayColor: const Color(0x33F39C12),
            thumbColor: Colors.white,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _StyleActionButton extends StatelessWidget {
  const _StyleActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? Colors.black : Colors.white70;
    final background = isPrimary
        ? const Color(0xFFF39C12)
        : Colors.white.withValues(alpha: 0.06);

    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
