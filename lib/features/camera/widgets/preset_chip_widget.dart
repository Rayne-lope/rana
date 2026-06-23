import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/widgets/preset_thumbnail_widget.dart';

/// Reusable preset chip widget.
class PresetChipWidget extends StatelessWidget {
  /// Main constructor.
  const PresetChipWidget({
    required this.preset,
    required this.isSelected,
    required this.isEnabled,
    required this.onSelected,
    super.key,
  });

  /// The preset model recipe.
  final PresetModel preset;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Whether the chip is enabled (e.g. camera is initialized).
  final bool isEnabled;

  /// Callback when selected.
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        avatar: PresetThumbnailWidget(preset: preset),
        label: Text(
          preset.name.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFF39C12), // Vintage orange
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onSelected: isEnabled ? onSelected : null,
      );
}
