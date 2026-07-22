import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/state/camera_failure.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/camera/telemetry/camera_telemetry.dart';

void main() {
  test('native error maps to a user-safe typed recovery action', () {
    final failure = CameraFailure.fromError(
      PlatformException(
        code: 'CAMERA_NOT_READY',
        message: 'activePreviewView was null for platform view 42',
      ),
    );

    expect(failure.code, CameraFailureCode.cameraNotReady);
    expect(failure.recoveryAction, CameraRecoveryAction.reinitialize);
    expect(failure.userMessage, isNot(contains('activePreviewView')));
    expect(failure.developerMessage, contains('platform view 42'));
  });

  test('legacy errorMessage remains compatible while populating failure', () {
    final state = CameraState.initial().copyWith(
      errorMessage: 'Film Roll recipe locked while restoring.',
    );

    expect(state.errorMessage, 'Film Roll recipe locked while restoring.');
    expect(state.failure, isNotNull);
    expect(state.failure!.code, CameraFailureCode.filmRollRecoveryFailed);
    expect(state.copyWith(errorMessage: null).failure, isNull);
  });

  test('telemetry evicts to 256 numeric samples without media identifiers', () {
    final telemetry = CameraTelemetry();
    for (var index = 0; index < 300; index += 1) {
      telemetry.record(
        'capture_process_ms',
        index,
        monotonicTimestampUs: index,
      );
    }
    telemetry.record('content://rana/private/photo', 1);

    final snapshot = telemetry.snapshot();
    final encoded = jsonEncode(snapshot.toSafeMap());
    expect(snapshot.samples, hasLength(256));
    expect(snapshot.samples.first.value, 44);
    expect(encoded, isNot(contains('content://')));
    expect(encoded, isNot(contains('photo')));
  });

  test('all required failures define recovery metadata', () {
    for (final code in CameraFailureCode.values) {
      final failure = CameraFailure.fromCode(code);
      expect(failure.userMessage, isNotEmpty, reason: code.wireValue);
      expect(failure.developerMessage, isNotEmpty, reason: code.wireValue);
    }
  });
}
