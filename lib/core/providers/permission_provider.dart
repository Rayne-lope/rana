import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permission_provider.g.dart';

/// Immutable model representing the runtime permissions status of the app.
@immutable
class PermissionState {
  const PermissionState({
    required this.hasCamera,
    required this.hasStorage,
    required this.isChecking,
    required this.isPermanentlyDenied,
  });

  final bool hasCamera;
  final bool hasStorage;
  final bool isChecking;
  final bool isPermanentlyDenied;


  /// Check if both necessary permissions are fully granted.
  bool get isAllGranted => hasCamera && hasStorage;

  /// Copies this instance, replacing specified fields.
  PermissionState copyWith({
    bool? hasCamera,
    bool? hasStorage,
    bool? isChecking,
    bool? isPermanentlyDenied,
  }) =>
      PermissionState(
        hasCamera: hasCamera ?? this.hasCamera,
        hasStorage: hasStorage ?? this.hasStorage,
        isChecking: isChecking ?? this.isChecking,
        isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionState &&
        other.hasCamera == hasCamera &&
        other.hasStorage == hasStorage &&
        other.isChecking == isChecking &&
        other.isPermanentlyDenied == isPermanentlyDenied;
  }

  @override
  int get hashCode => Object.hash(
        hasCamera,
        hasStorage,
        isChecking,
        isPermanentlyDenied,
      );

  @override
  String toString() =>
      'PermissionState(hasCamera: $hasCamera, hasStorage: $hasStorage, '
      'isChecking: $isChecking, isPermanentlyDenied: $isPermanentlyDenied)';
}

@riverpod
class PermissionController extends _$PermissionController {
  @override
  PermissionState build() => const PermissionState(
        hasCamera: false,
        hasStorage: false,
        isChecking: true,
        isPermanentlyDenied: false,
      );

  /// Synchronizes current permission status from OS.
  Future<void> checkPermissions() async {
    state = state.copyWith(isChecking: true);

    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;
    final photosStatus = await Permission.photos.status;

    final hasCamera = cameraStatus.isGranted;
    final hasStorage = storageStatus.isGranted || photosStatus.isGranted;

    final isPermDenied = cameraStatus.isPermanentlyDenied ||
        storageStatus.isPermanentlyDenied ||
        photosStatus.isPermanentlyDenied;

    state = PermissionState(
      hasCamera: hasCamera,
      hasStorage: hasStorage,
      isChecking: false,
      isPermanentlyDenied: isPermDenied,
    );
  }

  /// Prompts OS native dialogs to request permissions.
  Future<void> requestPermissions() async {
    state = state.copyWith(isChecking: true);

    final cameraResult = await Permission.camera.request();
    final storageResult = await Permission.storage.request();
    final photosResult = await Permission.photos.request();

    final hasCamera = cameraResult.isGranted;
    final hasStorage = storageResult.isGranted || photosResult.isGranted;

    final isPermDenied = cameraResult.isPermanentlyDenied ||
        storageResult.isPermanentlyDenied ||
        photosResult.isPermanentlyDenied;

    state = PermissionState(
      hasCamera: hasCamera,
      hasStorage: hasStorage,
      isChecking: false,
      isPermanentlyDenied: isPermDenied,
    );
  }
}
