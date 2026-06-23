import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preset_provider.g.dart';

/// Provider exposing the list of parsed presets loaded dynamically from assets.
@riverpod
class Presets extends _$Presets {
  @override
  Future<List<PresetModel>> build() async {
    final repository = ref.watch(presetRepositoryProvider);
    return repository.loadAll();
  }
}
