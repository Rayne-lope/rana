import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';

/// Service that interfaces with native Android camera code via platform
/// channels.
class CameraPlatformService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.rana.app/camera_control');
  static const EventChannel _eventChannel =
      EventChannel('com.rana.app/camera_status');

  /// Requests native initialization of the camera engine.
  Future<Map<String, dynamic>> initializeCamera() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'initializeCamera',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to initialize camera on platform side',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Sets the active film/analog preset on the native rendering pipeline.
  Future<Map<String, dynamic>> selectPreset(String presetId) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'selectPreset',
        {'presetId': presetId},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to select preset: $presetId',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Commands the native engine to capture a high-resolution frame.
  Future<Map<String, dynamic>> executeCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCapture',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to execute capture on native side',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Sets the flash mode for active capturing.
  Future<Map<String, dynamic>> setFlashMode(String flashMode) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'setFlashMode',
        {'flashMode': flashMode},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to set flash mode: $flashMode',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Toggles between front and back lenses natively.
  Future<Map<String, dynamic>> toggleLens(String currentLens) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'toggleLens',
        {'lens': currentLens},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to toggle camera lens from: $currentLens',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Stream of status updates emitted from the native camera engine
  /// (e.g. FPS metrics).
  Stream<Map<String, dynamic>> get statusStream =>
      _eventChannel.receiveBroadcastStream().map(
            (event) => Map<String, dynamic>.from(
              event as Map<dynamic, dynamic>,
            ),
          );
}
