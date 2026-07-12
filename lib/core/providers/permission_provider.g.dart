// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$permissionCapabilitiesHash() =>
    r'dfc357f664725f08a07923b04d0be18f6146eb19';

/// See also [permissionCapabilities].
@ProviderFor(permissionCapabilities)
final permissionCapabilitiesProvider =
    FutureProvider<PermissionCapabilities>.internal(
      permissionCapabilities,
      name: r'permissionCapabilitiesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$permissionCapabilitiesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PermissionCapabilitiesRef = FutureProviderRef<PermissionCapabilities>;
String _$cameraPermissionControllerHash() =>
    r'64129939e054016f4f6d2eff1dc47a19f333b090';

/// Controls Camera permission only. Gallery access never changes this state.
///
/// Copied from [CameraPermissionController].
@ProviderFor(CameraPermissionController)
final cameraPermissionControllerProvider =
    NotifierProvider<
      CameraPermissionController,
      PermissionAccessState
    >.internal(
      CameraPermissionController.new,
      name: r'cameraPermissionControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cameraPermissionControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CameraPermissionController = Notifier<PermissionAccessState>;
String _$galleryPermissionControllerHash() =>
    r'dfdd4a4e61043a66beb1b2fb71d8b06a19c5810f';

/// Controls optional photo-library access only. Rana first attempts to read
/// media it owns, so this permission is not requested during camera startup.
///
/// Copied from [GalleryPermissionController].
@ProviderFor(GalleryPermissionController)
final galleryPermissionControllerProvider =
    NotifierProvider<
      GalleryPermissionController,
      PermissionAccessState
    >.internal(
      GalleryPermissionController.new,
      name: r'galleryPermissionControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$galleryPermissionControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GalleryPermissionController = Notifier<PermissionAccessState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
