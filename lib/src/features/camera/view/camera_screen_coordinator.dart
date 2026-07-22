import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/src/features/camera/view/camera_ui_mode.dart';

enum CameraFilmRollRoute { start, info, completion }

/// Coordinates route-wide mode, lifecycle, metrics, and modal ownership.
@internal
final class CameraScreenCoordinator {
  CameraScreenCoordinator({
    required this.sessionId,
    required FutureOr<void> Function() releaseCamera,
    required FutureOr<void> Function() resumeCamera,
    required VoidCallback scheduleMetricsCheck,
  }) : _releaseCamera = releaseCamera,
       _resumeCamera = resumeCamera,
       _scheduleMetricsCheck = scheduleMetricsCheck;

  final String sessionId;
  final FutureOr<void> Function() _releaseCamera;
  final FutureOr<void> Function() _resumeCamera;
  final VoidCallback _scheduleMetricsCheck;

  CameraUiMode _mode = const CameraCaptureMode();
  CameraUiMode? _modeBeforeFilmRoll;
  CameraFilmRollRoute? _filmRollRoute;

  CameraUiMode get mode => _mode;
  CameraFilmRollRoute? get filmRollRoute => _filmRollRoute;
  bool get hasFilmRollRoute => _filmRollRoute != null;

  void transitionTo(CameraUiMode mode) {
    if (_filmRollRoute != null && mode is! CameraFilmRollManagementMode) {
      throw StateError('Cannot leave Film Roll mode while its route is open.');
    }
    _mode = mode;
  }

  bool beginFilmRollRoute(CameraFilmRollRoute route) {
    if (_filmRollRoute != null) return false;
    _modeBeforeFilmRoll = _mode;
    _filmRollRoute = route;
    _mode = const CameraFilmRollManagementMode();
    return true;
  }

  bool finishFilmRollRoute(CameraFilmRollRoute route) {
    if (_filmRollRoute != route) return false;
    _filmRollRoute = null;
    _mode = _modeBeforeFilmRoll ?? const CameraCaptureMode();
    _modeBeforeFilmRoll = null;
    return true;
  }

  void handleLifecycle(AppLifecycleState state) {
    AppLogger.i(
      'CameraScreen',
      'session=$sessionId App lifecycle changed to: $state',
    );
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(Future<void>.sync(_releaseCamera));
      case AppLifecycleState.resumed:
        unawaited(Future<void>.sync(_resumeCamera));
      case AppLifecycleState.inactive:
        break;
    }
  }

  void handleMetricsChanged() {
    AppLogger.d(
      'CameraStartup',
      'session=$sessionId Window metrics notification received',
    );
    _scheduleMetricsCheck();
  }
}
