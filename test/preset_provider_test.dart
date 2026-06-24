import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:rana/features/preset/repository/saved_rana_style_repository.dart';

void main() {
  group('Presets provider Tests', () {
    test('appends saved styles as cloned preset entries', () async {
      final createdAt = DateTime.utc(2026, 6, 24, 12);
      final savedStyle = SavedRanaStyle(
        id: SavedRanaStyle.createId(createdAt),
        name: 'Warm Rose',
        basePresetId: 'rana_warm',
        style: const RanaStyle(tone: 28, undertoneX: -0.4, undertoneY: 0.6),
        createdAt: createdAt,
      );

      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([_warmPreset]),
          ),
          savedRanaStyleRepositoryProvider.overrideWithValue(
            _FakeSavedRanaStyleRepository([savedStyle]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final presets = await container.read(presetsProvider.future);

      expect(presets, hasLength(2));
      expect(presets[0], equals(_warmPreset));
      expect(presets[1].id, equals(savedStyle.id));
      expect(presets[1].name, equals('Warm Rose'));
      expect(presets[1].category, equals(SavedRanaStyle.category));
      expect(presets[1].lut, equals(_warmPreset.lut));
      expect(presets[1].effects, equals(_warmPreset.effects));
      expect(presets[1].style, equals(savedStyle.style));
      expect(presets[1].behavior, equals({'basePresetId': 'rana_warm'}));
    });

    test('skips saved styles whose base preset is unavailable', () async {
      final savedStyle = SavedRanaStyle(
        id: SavedRanaStyle.createId(DateTime.utc(2026, 6, 24, 13)),
        name: 'Missing Base',
        basePresetId: 'missing',
        style: const RanaStyle(tone: 28),
        createdAt: DateTime.utc(2026, 6, 24, 13),
      );

      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([_warmPreset]),
          ),
          savedRanaStyleRepositoryProvider.overrideWithValue(
            _FakeSavedRanaStyleRepository([savedStyle]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final presets = await container.read(presetsProvider.future);

      expect(presets, equals([_warmPreset]));
    });
  });
}

const _warmPreset = PresetModel(
  id: 'rana_warm',
  name: 'Rana Warm',
  category: 'Classic',
  color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
  grain: PresetGrain(intensity: 0.1),
  vignette: PresetVignette(intensity: 0.05),
  lut: 'assets/luts/rana_warm_v1.png',
  effects: PresetEffects(
    lightLeak: LightLeakEffect(intensity: 0.22, variant: -1),
    dust: DustEffect(intensity: 0.06),
    bloom: PresetBloom(threshold: 0.65, intensity: 0.10),
    halation: PresetHalation(intensity: 0.08),
    lensDistortion: PresetLensDistortion(strength: 0.06),
  ),
);

class _FakePresetRepository implements PresetRepository {
  const _FakePresetRepository(this.presets);

  final List<PresetModel> presets;

  @override
  Future<List<PresetModel>> loadAll() async => presets;
}

class _FakeSavedRanaStyleRepository implements SavedRanaStyleRepository {
  const _FakeSavedRanaStyleRepository(this.styles);

  final List<SavedRanaStyle> styles;

  @override
  Future<List<SavedRanaStyle>> loadAll() async => styles;

  @override
  Future<void> save(SavedRanaStyle style) async {}

  @override
  Future<void> delete(String id) async {}
}
