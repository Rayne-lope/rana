import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
import 'package:rana/features/camera/state/camera_state.dart';

/// Owns optimistic zoom state, native dispatch debounce, and stale responses.
@internal
final class CameraZoomController {
  CameraZoomController({
    required CameraPlatformService platformService,
    required CameraState Function() readState,
    required void Function(CameraState state) writeState,
  }) : _platformService = platformService,
       _readState = readState,
       _writeState = writeState;

  static const _dispatchInterval = Duration(milliseconds: 16);

  final CameraPlatformService _platformService;
  final CameraState Function() _readState;
  final void Function(CameraState state) _writeState;

  Timer? _dispatchTimer;
  double? _pendingRatio;
  int _generation = 0;

  Future<void> setZoomRatio(double zoomRatio, {bool commit = true}) async {
    if (!_canAdjustZoom) return;

    final state = _readState();
    final targetZoomRatio = clampZoomRatio(zoomRatio, state: state);
    _pendingRatio = targetZoomRatio;
    if ((state.zoomRatio - targetZoomRatio).abs() > 0.001) {
      _writeState(
        state.copyWith(
          zoomRatio: targetZoomRatio,
          // ignore: avoid_redundant_argument_values
          errorMessage: null,
        ),
      );
    }

    if (commit) {
      _dispatchTimer?.cancel();
      _dispatchTimer = null;
      await _sendZoomRatio(targetZoomRatio);
      return;
    }

    _scheduleDispatch();
  }

  Future<void> commitZoomRatio() async {
    if (!_canAdjustZoom) return;
    final targetZoomRatio = _pendingRatio ?? _readState().zoomRatio;
    _dispatchTimer?.cancel();
    _dispatchTimer = null;
    await _sendZoomRatio(targetZoomRatio);
  }

  void resetPendingRatio(double zoomRatio) {
    _generation += 1;
    _pendingRatio = zoomRatio;
    _dispatchTimer?.cancel();
    _dispatchTimer = null;
  }

  void cancelPending() {
    _generation += 1;
    _dispatchTimer?.cancel();
    _dispatchTimer = null;
  }

  CameraState mergeNativeZoomState(
    CameraState baseState,
    Map<String, dynamic> result, {
    double? fallbackZoomRatio,
  }) {
    final minZoomRatio = _readDouble(
      result,
      'minZoomRatio',
      baseState.minZoomRatio,
    );
    final maxZoomRatio = _readDouble(
      result,
      'maxZoomRatio',
      baseState.maxZoomRatio,
    );
    final zoomRatio = clampZoomRatio(
      _readDouble(
        result,
        'zoomRatio',
        fallbackZoomRatio ?? baseState.zoomRatio,
      ),
      state: baseState,
      minZoomRatio: minZoomRatio,
      maxZoomRatio: maxZoomRatio,
    );

    return baseState.copyWith(
      zoomRatio: zoomRatio,
      minZoomRatio: minZoomRatio,
      maxZoomRatio: maxZoomRatio,
      zoomQualityLabel: _readString(
        result,
        'zoomQualityLabel',
        baseState.zoomQualityLabel,
      ),
      hasTelephotoCandidate: _readBool(
        result,
        'hasTelephotoCandidate',
        baseState.hasTelephotoCandidate,
      ),
      isLikelyDigitalZoom: _readBool(
        result,
        'isLikelyDigitalZoom',
        baseState.isLikelyDigitalZoom,
      ),
      shouldWarnDigitalZoom: _readBool(
        result,
        'shouldWarnDigitalZoom',
        baseState.shouldWarnDigitalZoom,
      ),
      physicalCameraCount: _readInt(
        result,
        'physicalCameraCount',
        baseState.physicalCameraCount,
      ),
    );
  }

  double clampZoomRatio(
    double zoomRatio, {
    required CameraState state,
    double? minZoomRatio,
    double? maxZoomRatio,
  }) {
    final lowerBound = max(
      userMinZoomRatio,
      minZoomRatio ?? state.minZoomRatio,
    );
    final nativeUpperBound = maxZoomRatio ?? state.maxZoomRatio;
    final upperBound = max(lowerBound, min(userMaxZoomRatio, nativeUpperBound));
    if (!zoomRatio.isFinite) return lowerBound;
    return zoomRatio.clamp(lowerBound, upperBound);
  }

  bool get _canAdjustZoom {
    final state = _readState();
    return state.isCameraInitialized &&
        state.captureStatus == CaptureStatus.idle &&
        !state.isSelfTimerRunning;
  }

  void _scheduleDispatch() {
    if (_dispatchTimer != null) return;
    _dispatchTimer = Timer(_dispatchInterval, () {
      _dispatchTimer = null;
      final targetZoomRatio = _pendingRatio;
      if (targetZoomRatio == null || !_canAdjustZoom) return;
      unawaited(_sendZoomRatio(targetZoomRatio));
    });
  }

  Future<void> _sendZoomRatio(double zoomRatio) async {
    final generation = ++_generation;
    try {
      final result = await _platformService.setZoomRatio(zoomRatio);
      if (generation != _generation) return;
      final state = _readState();
      _writeState(
        mergeNativeZoomState(state, result, fallbackZoomRatio: zoomRatio),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      _writeState(
        _readState().copyWith(
          failure: CameraFailure.fromError(
            error,
            fallbackCode: CameraFailureCode.physicalLensUnsupported,
          ),
        ),
      );
    }
  }

  String _readString(Map<String, dynamic> result, String key, String fallback) {
    final value = result[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  bool _readBool(Map<String, dynamic> result, String key, bool fallback) {
    final value = result[key];
    return value is bool ? value : fallback;
  }

  double _readDouble(Map<String, dynamic> result, String key, double fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  int _readInt(Map<String, dynamic> result, String key, int fallback) {
    final value = result[key];
    return value is num && value.isFinite ? value.round() : fallback;
  }

  void dispose() => cancelPending();
}
