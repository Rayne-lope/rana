import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';

class StyleMoodChips extends StatelessWidget {
  const StyleMoodChips({
    required this.activePreset,
    required this.activeStyle,
    required this.onSelected,
    super.key,
  });

  final PresetModel activePreset;
  final RanaStyle activeStyle;
  final ValueChanged<RanaStyleMood> onSelected;

  @override
  Widget build(BuildContext context) {
    final moods = RanaStyleMood.availableForPreset(activePreset);
    final selectedMood = RanaStyleMood.matchForStyle(activePreset, activeStyle);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final mood = moods[index];
          return _StyleMoodChip(
            key: Key('style-mood-chip-${mood.id}'),
            mood: mood,
            isSelected: selectedMood?.id == mood.id,
            onTap: () => onSelected(mood),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: moods.length,
      ),
    );
  }
}

class _StyleMoodChip extends StatelessWidget {
  const _StyleMoodChip({
    required this.mood,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final RanaStyleMood mood;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? const Color(0xFF0F0F11)
        : Colors.white.withValues(alpha: 0.78);
    final background = isSelected
        ? const Color(0xFFF39C12)
        : const Color(0xFF17171B);
    final borderColor = isSelected
        ? const Color(0xFFF39C12)
        : Colors.white.withValues(alpha: 0.10);

    return Tooltip(
      message: mood.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: 32,
            constraints: const BoxConstraints(minWidth: 68),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(mood.swatchColor),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  mood.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
