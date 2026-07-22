import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rana/features/camera/state/camera_state.dart';

/// Owns the camera self-timer countdown and cancellation generation.
@internal
final class CameraTimerController {
  CameraTimerController({
    required CameraState Function() readState,
    required void Function(CameraState state) writeState,
    required String? Function() captureBlockReason,
    required Future<void> Function() capture,
  }) : _readState = readState,
       _writeState = writeState,
       _captureBlockReason = captureBlockReason,
       _capture = capture;

  final CameraState Function() _readState;
  final void Function(CameraState state) _writeState;
  final String? Function() _captureBlockReason;
  final Future<void> Function() _capture;

  Timer? _countdown;
  int _generation = 0;

  void cycle() {
    final state = _readState();
    if (state.captureStatus != CaptureStatus.idle) return;
    if (state.isSelfTimerRunning) {
      cancel();
      return;
    }
    final blockReason = _captureBlockReason();
    if (blockReason != null) {
      _writeState(state.copyWith(errorMessage: blockReason));
      return;
    }

    _writeState(
      state.copyWith(
        selfTimerMode: state.selfTimerMode.next,
        selfTimerRemainingSeconds: 0,
      ),
    );
  }

  void cancel({bool clearMode = false}) {
    _generation += 1;
    _countdown?.cancel();
    _countdown = null;

    final state = _readState();
    _writeState(
      state.copyWith(
        selfTimerMode: clearMode ? SelfTimerMode.off : state.selfTimerMode,
        selfTimerRemainingSeconds: 0,
      ),
    );
  }

  void start(SelfTimerMode mode) {
    final state = _readState();
    if (!mode.isEnabled || state.captureStatus != CaptureStatus.idle) return;
    final blockReason = _captureBlockReason();
    if (blockReason != null) {
      _writeState(state.copyWith(errorMessage: blockReason));
      return;
    }

    cancel();

    final session = ++_generation;
    _writeState(
      _readState().copyWith(
        selfTimerMode: mode,
        selfTimerRemainingSeconds: mode.seconds,
      ),
    );

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (session != _generation) {
        timer.cancel();
        return;
      }

      final current = _readState();
      if (!current.isCameraInitialized ||
          current.captureStatus != CaptureStatus.idle) {
        timer.cancel();
        _countdown = null;
        if (session == _generation) {
          _writeState(current.copyWith(selfTimerRemainingSeconds: 0));
        }
        return;
      }

      final nextRemaining = current.selfTimerRemainingSeconds - 1;
      if (nextRemaining > 0) {
        _writeState(current.copyWith(selfTimerRemainingSeconds: nextRemaining));
        return;
      }

      timer.cancel();
      _countdown = null;
      if (session != _generation) return;

      _writeState(current.copyWith(selfTimerRemainingSeconds: 0));
      unawaited(_capture());
    });
  }

  void dispose() {
    _generation += 1;
    _countdown?.cancel();
    _countdown = null;
  }
}
