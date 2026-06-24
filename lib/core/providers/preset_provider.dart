import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:rana/features/preset/repository/saved_rana_style_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preset_provider.g.dart';

/// Provider exposing the list of parsed presets loaded dynamically from assets.
@riverpod
class Presets extends _$Presets {
  @override
  Future<List<PresetModel>> build() async {
    final repository = ref.watch(presetRepositoryProvider);
    final savedStyleRepository = ref.watch(savedRanaStyleRepositoryProvider);
    final assetPresets = await repository.loadAll();
    final savedStyles = await savedStyleRepository.loadAll();
    return [...assetPresets, ..._mapSavedStyles(assetPresets, savedStyles)];
  }

  List<PresetModel> _mapSavedStyles(
    List<PresetModel> assetPresets,
    List<SavedRanaStyle> savedStyles,
  ) {
    final presetsById = {for (final preset in assetPresets) preset.id: preset};

    return [
      for (final savedStyle in savedStyles)
        if (presetsById[savedStyle.basePresetId] != null)
          _toPresetModel(presetsById[savedStyle.basePresetId]!, savedStyle),
    ];
  }

  PresetModel _toPresetModel(PresetModel base, SavedRanaStyle savedStyle) =>
      PresetModel(
        id: savedStyle.id,
        name: savedStyle.name,
        category: SavedRanaStyle.category,
        color: base.color,
        grain: base.grain,
        vignette: base.vignette,
        lut: base.lut,
        overlay: base.overlay,
        behavior: <String, dynamic>{'basePresetId': savedStyle.basePresetId},
        effects: base.effects,
        style: savedStyle.style,
      );
}
