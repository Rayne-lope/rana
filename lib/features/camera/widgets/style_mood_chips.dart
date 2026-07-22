import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rana/core/services/camera_feedback_service.dart';
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
            onTap: () {
              unawaited(CameraFeedbackService.instance.playDialTick());
              onSelected(mood);
            },
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

    return Tooltip(
      message: mood.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 32,
            constraints: const BoxConstraints(minWidth: 68),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFF4C44F), Color(0xFFF39C12)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.black.withValues(alpha: 0.36),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF4C44F).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF39C12).withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      )
                    ]
                  : null,
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
                      color: isSelected
                          ? Colors.black.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(mood.swatchColor).withValues(alpha: 0.4),
                        blurRadius: 2,
                        spreadRadius: 0.5,
                      )
                    ],
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
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
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
