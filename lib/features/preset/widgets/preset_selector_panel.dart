import 'package:flutter/material.dart';
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';

/// A premium, brand-grouped preset selector panel.
class PresetSelectorPanel extends StatelessWidget {
  /// Main constructor.
  const PresetSelectorPanel({
    required this.presets,
    required this.activePresetId,
    required this.onPresetSelected,
    this.onDeletePreset,
    super.key,
  });

  /// All loaded presets.
  final List<PresetModel> presets;

  /// Currently active preset ID.
  final String? activePresetId;

  /// Callback when a preset is selected.
  final ValueChanged<PresetModel> onPresetSelected;

  /// Optional callback to delete a user style preset.
  final ValueChanged<PresetModel>? onDeletePreset;

  @override
  Widget build(BuildContext context) {
    // 1. Group the presets by brand using type inference
    final myStyles = <PresetModel>[];
    final rana = <PresetModel>[];
    final kodak = <PresetModel>[];
    final fuji = <PresetModel>[];
    final agfa = <PresetModel>[];
    final lomography = <PresetModel>[];
    final cinestill = <PresetModel>[];
    final ilford = <PresetModel>[];
    final defaults = <PresetModel>[];
    final others = <PresetModel>[];

    // Filter out placeholders and group
    for (final preset in presets) {
      if (preset.id == 'placeholder') continue;

      final nameLower = preset.name.toLowerCase();
      final idLower = preset.id.toLowerCase();
      final isSavedStyle = SavedRanaStyle.isSavedStylePresetId(preset.id);

      if (isSavedStyle) {
        myStyles.add(preset);
      } else if (idLower == 'normal') {
        defaults.add(preset);
      } else if (nameLower.contains('rana') || idLower.startsWith('rana')) {
        rana.add(preset);
      } else if (nameLower.contains('kodak') ||
          idLower.startsWith('kodak') ||
          idLower.contains('ektar') ||
          idLower.contains('gold') ||
          idLower.contains('portra') ||
          idLower.contains('tri_x') ||
          idLower.contains('vision3')) {
        kodak.add(preset);
      } else if (nameLower.contains('fujifilm') ||
          nameLower.contains('fuji') ||
          idLower.startsWith('fuji') ||
          idLower.contains('pro_400h') ||
          idLower.contains('velvia') ||
          idLower.contains('superia') ||
          idLower.contains('natura') ||
          idLower.contains('quicksnap')) {
        fuji.add(preset);
      } else if (nameLower.contains('agfa') || idLower.startsWith('agfa')) {
        agfa.add(preset);
      } else if (nameLower.contains('lomo') || idLower.startsWith('lomo')) {
        lomography.add(preset);
      } else if (nameLower.contains('cinestill') ||
          idLower.startsWith('cinestill')) {
        cinestill.add(preset);
      } else if (nameLower.contains('ilford') ||
          idLower.startsWith('ilford') ||
          idLower.contains('hp5')) {
        ilford.add(preset);
      } else {
        others.add(preset);
      }
    }

    return CustomPaint(
      painter: StylesPanelBackgroundPainter(),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Build rows for each brand if not empty
              if (defaults.isNotEmpty)
                _buildBrandRow('DEFAULT', defaults),
              if (rana.isNotEmpty)
                _buildBrandRow('RANA', rana),
              if (kodak.isNotEmpty)
                _buildBrandRow('KODAK', kodak),
              if (fuji.isNotEmpty)
                _buildBrandRow('FUJIFILM', fuji),
              if (agfa.isNotEmpty)
                _buildBrandRow('AGFA', agfa),
              if (lomography.isNotEmpty)
                _buildBrandRow('LOMOGRAPHY', lomography),
              if (cinestill.isNotEmpty)
                _buildBrandRow('CINESTILL', cinestill),
              if (ilford.isNotEmpty)
                _buildBrandRow('ILFORD', ilford),
              if (myStyles.isNotEmpty)
                _buildBrandRow('MY STYLES', myStyles),
              if (others.isNotEmpty)
                _buildBrandRow('OTHERS', others),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandRow(String brandName, List<PresetModel> brandPresets) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              brandName,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: brandPresets.length,
              itemBuilder: (context, index) {
                final preset = brandPresets[index];
                final isSelected = activePresetId == preset.id;

                // Extract short name for display
                var displayName = preset.name.toUpperCase();
                if (displayName.startsWith('KODAK ')) {
                  displayName = displayName.replaceFirst('KODAK ', '');
                } else if (displayName.startsWith('FUJIFILM ')) {
                  displayName = displayName.replaceFirst('FUJIFILM ', '');
                } else if (displayName.startsWith('RANA ')) {
                  displayName = displayName.replaceFirst('RANA ', '');
                } else if (displayName.startsWith('ILFORD ')) {
                  displayName = displayName.replaceFirst('ILFORD ', '');
                } else if (displayName.startsWith('AGFA ')) {
                  displayName = displayName.replaceFirst('AGFA ', '');
                } else if (displayName.startsWith('LOMOGRAPHY ')) {
                  displayName = displayName.replaceFirst('LOMOGRAPHY ', '');
                }

                final isSavedStyle =
                    SavedRanaStyle.isSavedStylePresetId(preset.id);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => onPresetSelected(preset),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon Container
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF39C12)
                                          .withValues(alpha: 0.12)
                                      : const Color(0xFF16161A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFF39C12)
                                        : Colors.white.withValues(alpha: 0.05),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF39C12)
                                                .withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.photo_camera_back_outlined,
                                  size: 24,
                                  color: isSelected
                                      ? const Color(0xFFF39C12)
                                      : Colors.white54,
                                ),
                              ),
                              if (isSavedStyle && onDeletePreset != null)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => onDeletePreset!(preset),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Text Label
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFFF39C12)
                                  : Colors.white70,
                              fontSize: 8.5,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
}
