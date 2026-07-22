# Typed Flutter–Kotlin platform API

The source contract is `pigeons/rana_camera_api.dart`; generated Dart and Kotlin
files are committed and must be regenerated with Pigeon 27.2.0 from
`tool/pigeon/`.

`RanaCameraHostApi` covers initialization/release, capabilities, recipe apply,
capture, flash, zoom, focus, lens, aspect ratio, capture metadata, Film Roll
records, image loading, and opening media in the gallery.

Native callbacks are separated by concern:

- preview metrics and first frame;
- capture progress, completion, and failure;
- renderer errors;
- numeric telemetry.

Initialization includes the active PlatformView ID. Android resolves it through
`CameraPreviewRegistry`; a missing or stale ID returns `CAMERA_NOT_READY`.
PlatformView creation parameters are intentionally unused.

Generated Pigeon models are transport-only. Domain callers use
`CameraPlatformService`, `RenderRecipeV1`, `CameraFailure`, and existing stream
events. Production camera traffic must not fall back to arbitrary MethodChannel
keys.
