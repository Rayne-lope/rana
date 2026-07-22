// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'film_roll_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filmRollControllerHash() =>
    r'e2678e5905338d62980d4ceaddf0e0e414f5efc3';

/// Controller for the Film Roll feature.
///
/// All durable lifecycle actions use one queue. A native capture reservation is
/// added synchronously to make capacity atomic on the Flutter isolate, then it
/// remains capacity-consuming until its saved exposure is durably persisted.
///
/// Copied from [FilmRollController].
@ProviderFor(FilmRollController)
final filmRollControllerProvider =
    NotifierProvider<FilmRollController, FilmRollState>.internal(
      FilmRollController.new,
      name: r'filmRollControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$filmRollControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FilmRollController = Notifier<FilmRollState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
