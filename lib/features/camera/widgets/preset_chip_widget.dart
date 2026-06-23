import 'package:flutter/material.dart';
import 'package:rana/features/preset/model/preset_model.dart';

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

  Color _getThumbnailColor() {
    switch (preset.id) {
      case 'rana_warm':
        return const Color(0xFFE67E22);
      case 'rana_cool':
        return const Color(0xFF3498DB);
      case 'rana_mono':
        return const Color(0xFF7F8C8D);
      default:
        return const Color(0xFFBDC3C7);
    }
  }

  @override
  Widget build(BuildContext context) => ChoiceChip(
        avatar: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getThumbnailColor(),
          ),
        ),
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
