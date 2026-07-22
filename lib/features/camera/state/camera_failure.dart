import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CameraFailureCode {
  cameraPermissionDenied('CAMERA_PERMISSION_DENIED'),
  cameraNotReady('CAMERA_NOT_READY'),
  cameraInitializationFailed('CAMERA_INITIALIZATION_FAILED'),
  cameraBindFailed('CAMERA_BIND_FAILED'),
  glInitializationFailed('GL_INITIALIZATION_FAILED'),
  glRenderFailed('GL_RENDER_FAILED'),
  capturePipelineBusy('CAPTURE_PIPELINE_BUSY'),
  captureFailed('CAPTURE_FAILED'),
  captureProcessingFailed('CAPTURE_PROCESSING_FAILED'),
  mediaStoreWriteFailed('MEDIASTORE_WRITE_FAILED'),
  outputEncodingFailed('OUTPUT_ENCODING_FAILED'),
  lensSwitchTimeout('LENS_SWITCH_TIMEOUT'),
  physicalLensUnsupported('PHYSICAL_LENS_UNSUPPORTED'),
  filmRollRecoveryFailed('FILM_ROLL_RECOVERY_FAILED'),
  metadataReadFailed('METADATA_READ_FAILED'),
  metadataWriteFailed('METADATA_WRITE_FAILED'),
  unknownRecipeVersion('UNKNOWN_RECIPE_VERSION'),
  unknown('UNKNOWN_CAMERA_FAILURE');

  const CameraFailureCode(this.wireValue);

  final String wireValue;

  static CameraFailureCode fromWireValue(String value) {
    for (final code in values) {
      if (code.wireValue == value) return code;
    }
    return unknown;
  }
}

enum CameraRecoveryAction {
  none,
  retry,
  reinitialize,
  openSettings,
  fallbackLens,
  freeStorage,
}

@immutable
final class CameraFailure {
  const CameraFailure({
    required this.code,
    required this.userMessage,
    required this.developerMessage,
    required this.isRecoverable,
    required this.recoveryAction,
  });

  factory CameraFailure.fromError(
    Object error, {
    CameraFailureCode fallbackCode = CameraFailureCode.unknown,
  }) {
    if (error is CameraFailureException) return error.failure;
    if (error is PlatformException) {
      return CameraFailure.fromCode(
        CameraFailureCode.fromWireValue(error.code),
        developerMessage: error.message ?? error.toString(),
      );
    }
    return CameraFailure.fromCode(
      fallbackCode,
      developerMessage: error.toString(),
    );
  }

  factory CameraFailure.fromLegacyMessage(String message) {
    final normalized = message.toUpperCase();
    for (final code in CameraFailureCode.values) {
      if (normalized.contains(code.wireValue)) {
        return CameraFailure.fromCode(code, developerMessage: message);
      }
    }
    final inferred = switch (normalized) {
      final value when value.contains('FILM ROLL') =>
        CameraFailureCode.filmRollRecoveryFailed,
      final value when value.contains('ZOOM') || value.contains('LENS') =>
        CameraFailureCode.physicalLensUnsupported,
      final value when value.contains('CAPTURE') =>
        CameraFailureCode.captureFailed,
      final value when value.contains('INITIAL') || value.contains('PREVIEW') =>
        CameraFailureCode.cameraInitializationFailed,
      _ => CameraFailureCode.unknown,
    };
    final mapped = CameraFailure.fromCode(inferred, developerMessage: message);
    return CameraFailure(
      code: mapped.code,
      userMessage: message,
      developerMessage: message,
      isRecoverable: mapped.isRecoverable,
      recoveryAction: mapped.recoveryAction,
    );
  }

  factory CameraFailure.fromCode(
    CameraFailureCode code, {
    String? developerMessage,
  }) {
    final definition =
        _definitions[code] ?? _definitions[CameraFailureCode.unknown]!;
    return CameraFailure(
      code: code,
      userMessage: definition.userMessage,
      developerMessage: developerMessage ?? definition.userMessage,
      isRecoverable: definition.isRecoverable,
      recoveryAction: definition.recoveryAction,
    );
  }

  final CameraFailureCode code;
  final String userMessage;
  final String developerMessage;
  final bool isRecoverable;
  final CameraRecoveryAction recoveryAction;

  String get wireCode => code.wireValue;

  @override
  bool operator ==(Object other) =>
      other is CameraFailure &&
      other.code == code &&
      other.userMessage == userMessage &&
      other.developerMessage == developerMessage &&
      other.isRecoverable == isRecoverable &&
      other.recoveryAction == recoveryAction;

  @override
  int get hashCode => Object.hash(
    code,
    userMessage,
    developerMessage,
    isRecoverable,
    recoveryAction,
  );
}

final class CameraFailureException implements Exception {
  const CameraFailureException(this.failure);

  final CameraFailure failure;

  @override
  String toString() => '${failure.wireCode}: ${failure.developerMessage}';
}

typedef _FailureDefinition = ({
  String userMessage,
  bool isRecoverable,
  CameraRecoveryAction recoveryAction,
});

const _definitions = <CameraFailureCode, _FailureDefinition>{
  CameraFailureCode.cameraPermissionDenied: (
    userMessage: 'Camera access is required to take photos.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.openSettings,
  ),
  CameraFailureCode.cameraNotReady: (
    userMessage: 'The camera preview is not ready yet.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.reinitialize,
  ),
  CameraFailureCode.cameraInitializationFailed: (
    userMessage: 'The camera could not start. Try again.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.reinitialize,
  ),
  CameraFailureCode.cameraBindFailed: (
    userMessage: 'The camera could not connect to the preview.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.reinitialize,
  ),
  CameraFailureCode.glInitializationFailed: (
    userMessage: 'The camera renderer could not start.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.reinitialize,
  ),
  CameraFailureCode.glRenderFailed: (
    userMessage: 'The preview renderer encountered a problem.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.capturePipelineBusy: (
    userMessage: 'The previous photo is still processing.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.captureFailed: (
    userMessage: 'The photo could not be captured. Try again.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.captureProcessingFailed: (
    userMessage: 'The photo could not be processed. Try again.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.mediaStoreWriteFailed: (
    userMessage: 'The photo could not be saved.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.freeStorage,
  ),
  CameraFailureCode.outputEncodingFailed: (
    userMessage: 'The selected image format could not be encoded.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.lensSwitchTimeout: (
    userMessage: 'The selected lens did not respond.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.fallbackLens,
  ),
  CameraFailureCode.physicalLensUnsupported: (
    userMessage:
        'This lens is unavailable. Using the standard lens is recommended.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.fallbackLens,
  ),
  CameraFailureCode.filmRollRecoveryFailed: (
    userMessage: 'The Film Roll could not be restored.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.metadataReadFailed: (
    userMessage: 'Photo settings could not be read.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.metadataWriteFailed: (
    userMessage: 'Photo settings could not be saved.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
  CameraFailureCode.unknownRecipeVersion: (
    userMessage: 'This photo recipe was created by an unsupported version.',
    isRecoverable: false,
    recoveryAction: CameraRecoveryAction.none,
  ),
  CameraFailureCode.unknown: (
    userMessage: 'The camera encountered an unexpected problem.',
    isRecoverable: true,
    recoveryAction: CameraRecoveryAction.retry,
  ),
};
