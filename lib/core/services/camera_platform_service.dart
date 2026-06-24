import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';

/// Service that interfaces with native Android camera code via platform
/// channels.
class CameraPlatformService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.rana.app/camera_control',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.rana.app/camera_status',
  );

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
  Future<Map<String, dynamic>> selectPreset(
    String presetId,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'selectPreset',
        {'presetId': presetId, 'params': params},
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
  Future<Map<String, dynamic>> executeCapture(
    Map<String, dynamic> params,
  ) async {
    try {
      AppLogger.glParams('EXPORT', params);
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCapture',
        params,
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

  /// Loads raw bytes for a previously captured `content://` image URI.
  Future<Uint8List> loadCapturedImageBytes(String uri) async {
    try {
      final result = await _methodChannel.invokeMethod<Uint8List>(
        'loadCapturedImageBytes',
        {'uri': uri},
      );
      return result ?? Uint8List(0);
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to load captured image bytes: $uri',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Opens a previously captured image in the Android system gallery.
  Future<void> openMediaInGallery(String uri) async {
    try {
      await _methodChannel.invokeMethod<void>('openMediaInGallery', {
        'uri': uri,
      });
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to open media in gallery: $uri',
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

  /// Sets the active camera aspect ratio natively.
  Future<Map<String, dynamic>> setAspectRatio(String aspectRatio) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'setAspectRatio',
        {'aspectRatio': aspectRatio},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to set camera aspect ratio: $aspectRatio',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Releases native camera resources when backgrounded.
  Future<Map<String, dynamic>> releaseCamera() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'releaseCamera',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e, stack) {
      AppLogger.e(
        'CameraPlatformService',
        'Failed to release camera resources',
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
        (event) => Map<String, dynamic>.from(event as Map<dynamic, dynamic>),
      );
}
