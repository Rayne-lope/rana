// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$presetsHash() => r'f63bab2cd8961aae4da4e92e112d4bb9814aff74';

/// Provider exposing the list of parsed presets loaded dynamically from assets.
///
/// Copied from [Presets].
@ProviderFor(Presets)
final presetsProvider =
    AutoDisposeAsyncNotifierProvider<Presets, List<PresetModel>>.internal(
      Presets.new,
      name: r'presetsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$presetsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Presets = AutoDisposeAsyncNotifier<List<PresetModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
