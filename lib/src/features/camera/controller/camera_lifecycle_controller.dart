import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
import 'package:rana/features/camera/state/camera_state.dart';

/// Coordinates native camera initialization, release, and status streaming.
@internal
final class CameraLifecycleController {
  CameraLifecycleController({
    required CameraPlatformService platformService,
    required CameraState Function() readState,
    required void Function(CameraState state) writeState,
    required void Function(Map<String, dynamic> result) applyInitializeResult,
    required Future<void> Function(bool Function() isCurrent)
    configureInitializedCamera,
    required void Function(Map<String, dynamic> event) handleStatusEvent,
    required void Function() prepareRelease,
    required bool Function() hasCaptureWork,
  }) : _platformService = platformService,
       _readState = readState,
       _writeState = writeState,
       _applyInitializeResult = applyInitializeResult,
       _configureInitializedCamera = configureInitializedCamera,
       _handleStatusEvent = handleStatusEvent,
       _prepareRelease = prepareRelease,
       _hasCaptureWork = hasCaptureWork;

  final CameraPlatformService _platformService;
  final CameraState Function() _readState;
  final void Function(CameraState state) _writeState;
  final void Function(Map<String, dynamic> result) _applyInitializeResult;
  final Future<void> Function(bool Function() isCurrent)
  _configureInitializedCamera;
  final void Function(Map<String, dynamic> event) _handleStatusEvent;
  final void Function() _prepareRelease;
  final bool Function() _hasCaptureWork;

  StreamSubscription<Map<String, dynamic>>? _statusSubscription;
  int _generation = 0;
  Future<void>? _initializationFuture;
  Future<void>? _releaseFuture;

  int get generation => _generation;

  Future<void> initialize() {
    final releaseInFlight = _releaseFuture;
    if (releaseInFlight != null) {
      final initializationInFlight = _initializationFuture;
      if (initializationInFlight != null) return initializationInFlight;
      return _trackInitialization(_initializeAfterRelease(releaseInFlight));
    }
    if (_readState().isCameraInitialized) return Future<void>.value();
    final initializationInFlight = _initializationFuture;
    if (initializationInFlight != null) return initializationInFlight;

    return _trackInitialization(_initializeCamera());
  }

  Future<void> releaseCamera() {
    final releaseInFlight = _releaseFuture;
    if (releaseInFlight != null) return releaseInFlight;

    final pendingInitialization = _initializationFuture;
    _initializationFuture = null;
    late final Future<void> release;
    release = _releaseCameraInternal(pendingInitialization).whenComplete(() {
      if (identical(_releaseFuture, release)) {
        _releaseFuture = null;
      }
    });
    _releaseFuture = release;
    return release;
  }

  Future<void> _trackInitialization(Future<void> initialization) {
    _initializationFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeAfterRelease(Future<void> release) async {
    await release;
    if (_readState().isCameraInitialized) return;
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final lifecycleGeneration = ++_generation;
    bool isCurrent() => lifecycleGeneration == _generation;

    try {
      final result = await _platformService.initializeCamera();
      if (!isCurrent()) {
        unawaited(_platformService.releaseCamera());
        return;
      }

      _applyInitializeResult(result);
      _statusSubscription ??= _platformService.statusStream.listen(
        _handleStatusEvent,
        onError: (Object error) {
          _writeState(
            _readState().copyWith(failure: CameraFailure.fromError(error)),
          );
        },
      );

      await _configureInitializedCamera(isCurrent);
    } on Object catch (error) {
      if (!isCurrent()) return;
      _writeState(
        _readState().copyWith(
          isCameraInitialized: false,
          failure: CameraFailure.fromError(
            error,
            fallbackCode: CameraFailureCode.cameraInitializationFailed,
          ),
        ),
      );
    }
  }

  Future<void> _releaseCameraInternal(
    Future<void>? pendingInitialization,
  ) async {
    final lifecycleGeneration = ++_generation;
    _prepareRelease();

    if (pendingInitialization != null) {
      try {
        await pendingInitialization;
      } on Object {
        // Initialization already recorded its error. Continue native release.
      }
    }
    if (lifecycleGeneration != _generation) return;
    if (!_readState().isCameraInitialized) return;

    try {
      await _platformService.releaseCamera();
      if (lifecycleGeneration != _generation) return;
      final state = _readState();
      _writeState(
        state.copyWith(
          isCameraInitialized: false,
          currentFps: 0,
          captureStatus: _hasCaptureWork()
              ? CaptureStatus.capturing
              : CaptureStatus.idle,
        ),
      );
    } on Object catch (error) {
      if (lifecycleGeneration != _generation) return;
      _writeState(
        _readState().copyWith(
          failure: CameraFailure.fromError(
            error,
            fallbackCode: CameraFailureCode.cameraInitializationFailed,
          ),
        ),
      );
    }
  }

  void dispose() {
    unawaited(_statusSubscription?.cancel());
    _statusSubscription = null;
    _generation += 1;
  }
}
