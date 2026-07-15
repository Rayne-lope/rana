// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'film_roll_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filmRollControllerHash() =>
    r'fa354d7f3a83c1ac5152130c4ec4f996cbe6f684';

/// Controller for the Film Roll feature.
///
/// Key rules enforced here:
///  - Only one active roll at a time ([startRoll] is a no-op if one exists).
///  - [recordExposure] must only be called from the camera controller's
///    `_handleCaptureCompleted` — never on shutter press.
///  - [abandonRoll] removes the roll record; already-saved photos stay in Gallery.
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
