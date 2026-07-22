import 'package:flutter/foundation.dart';

/// Mutually exclusive primary presentation mode for the camera route.
@immutable
sealed class CameraUiMode {
  const CameraUiMode();

  bool get usesEditorLayout => this is! CameraCaptureMode;
}

final class CameraCaptureMode extends CameraUiMode {
  const CameraCaptureMode();
}

final class CameraFilmSelectionMode extends CameraUiMode {
  const CameraFilmSelectionMode();
}

final class CameraStyleEditingMode extends CameraUiMode {
  const CameraStyleEditingMode();
}

final class CameraUndertoneEditingMode extends CameraUiMode {
  const CameraUndertoneEditingMode();
}

final class CameraFilmRollManagementMode extends CameraUiMode {
  const CameraFilmRollManagementMode();
}
