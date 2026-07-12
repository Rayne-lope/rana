import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permission_provider.g.dart';

enum GalleryReadPermission { storage, photos }

@immutable
class PermissionCapabilities {
  const PermissionCapabilities({
    required this.requiresLegacyStorageForCapture,
    required this.galleryReadPermission,
  });

  factory PermissionCapabilities.fromMap(Map<String, dynamic> map) =>
      PermissionCapabilities(
        requiresLegacyStorageForCapture:
            map['requiresLegacyStorageForCapture'] == true,
        galleryReadPermission:
            map['galleryReadPermission'] == GalleryReadPermission.storage.name
            ? GalleryReadPermission.storage
            : GalleryReadPermission.photos,
      );

  final bool requiresLegacyStorageForCapture;
  final GalleryReadPermission galleryReadPermission;
}

@immutable
class PermissionAccessState {
  const PermissionAccessState({
    required this.isGranted,
    required this.isLimited,
    required this.isPermanentlyDenied,
    required this.isChecking,
  });

  const PermissionAccessState.initial()
    : isGranted = false,
      isLimited = false,
      isPermanentlyDenied = false,
      isChecking = true;

  final bool isGranted;
  final bool isLimited;
  final bool isPermanentlyDenied;
  final bool isChecking;

  bool get canRead => isGranted || isLimited;

  PermissionAccessState copyWith({
    bool? isGranted,
    bool? isLimited,
    bool? isPermanentlyDenied,
    bool? isChecking,
  }) => PermissionAccessState(
    isGranted: isGranted ?? this.isGranted,
    isLimited: isLimited ?? this.isLimited,
    isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
    isChecking: isChecking ?? this.isChecking,
  );

  @override
  bool operator ==(Object other) =>
      other is PermissionAccessState &&
      other.isGranted == isGranted &&
      other.isLimited == isLimited &&
      other.isPermanentlyDenied == isPermanentlyDenied &&
      other.isChecking == isChecking;

  @override
  int get hashCode => Object.hash(
    isGranted,
    isLimited,
    isPermanentlyDenied,
    isChecking,
  );
}

PermissionAccessState _stateFromStatus(PermissionStatus status) =>
    PermissionAccessState(
      isGranted: status.isGranted,
      isLimited: status.isLimited,
      isPermanentlyDenied: status.isPermanentlyDenied,
      isChecking: false,
    );

@Riverpod(keepAlive: true)
Future<PermissionCapabilities> permissionCapabilities(
  PermissionCapabilitiesRef ref,
) async {
  final result = await CameraPlatformService().getPermissionCapabilities();
  return PermissionCapabilities.fromMap(result);
}

/// Controls Camera permission only. Gallery access never changes this state.
@Riverpod(keepAlive: true)
class CameraPermissionController extends _$CameraPermissionController {
  @override
  PermissionAccessState build() => const PermissionAccessState.initial();

  Future<void> refresh() async {
    state = state.copyWith(isChecking: true);
    state = _stateFromStatus(await Permission.camera.status);
  }

  Future<void> requestCamera() async {
    state = state.copyWith(isChecking: true);
    state = _stateFromStatus(await Permission.camera.request());
  }
}

/// Optional access used only for previous-install media and legacy Android.
@Riverpod(keepAlive: true)
class GalleryPermissionController extends _$GalleryPermissionController {
  @override
  PermissionAccessState build() => const PermissionAccessState.initial();

  Future<void> refresh() async {
    state = state.copyWith(isChecking: true);
    final permission = await _readPermission();
    state = _stateFromStatus(await permission.status);
  }

  Future<void> requestGalleryAccess() async {
    state = state.copyWith(isChecking: true);
    final permission = await _readPermission();
    state = _stateFromStatus(await permission.request());
  }

  Future<Permission> _readPermission() async {
    final capabilities = await ref.read(permissionCapabilitiesProvider.future);
    return capabilities.galleryReadPermission == GalleryReadPermission.storage
        ? Permission.storage
        : Permission.photos;
  }
}
