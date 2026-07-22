import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preset_repository.g.dart';

/// Repository interface for loading camera presets.
// ignore: one_member_abstracts
abstract interface class PresetRepository {
  /// Loads all presets from the data source.
  Future<List<PresetModel>> loadAll();
}

/// Implementation of [PresetRepository] that loads recipes from assets.
class AssetPresetRepository implements PresetRepository {
  /// Creates an [AssetPresetRepository] with the given [AssetBundle].
  const AssetPresetRepository({required AssetBundle assetBundle})
    : _assetBundle = assetBundle;

  final AssetBundle _assetBundle;

  @override
  Future<List<PresetModel>> loadAll() async {
    final presets = <PresetModel>[];
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_assetBundle);
      final assetKeys = manifest.listAssets();

      final presetKeys = assetKeys
          .where(
            (key) => key.startsWith('assets/presets/') && key.endsWith('.json'),
          )
          .toList();

      for (final key in presetKeys) {
        try {
          final jsonStr = await _assetBundle.loadString(key);
          final dynamic decoded = json.decode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            presets.add(PresetModel.fromJson(decoded));
          } else {
            AppLogger.e('AssetPresetRepository', 'JSON at $key is not a map');
          }
        } on Object catch (e, stackTrace) {
          AppLogger.e(
            'AssetPresetRepository',
            'Failed to load/parse preset: $key',
            e,
            stackTrace,
          );
        }
      }
    } on Object catch (e, stackTrace) {
      AppLogger.e(
        'AssetPresetRepository',
        'Failed to load AssetManifest',
        e,
        stackTrace,
      );
    }
    return presets;
  }
}

/// Provider exposing the [PresetRepository] implementation.
@riverpod
PresetRepository presetRepository(PresetRepositoryRef ref) =>
    AssetPresetRepository(assetBundle: rootBundle);
