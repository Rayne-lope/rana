# Rana

Rana is an Android-first Flutter camera that applies a versioned analog-film
recipe consistently to live preview, offline capture, and gallery re-rendering.

## Platform baseline

- Android application ID: `com.rana.app.rana`
- Minimum SDK: 24
- Target/compile SDK: 36
- Flutter UI with CameraX, OpenGL ES, MediaStore, and a generated Pigeon bridge
- Portrait activity; window-metric stabilization protects cold starts and
  PlatformView recreation

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Native gates require Android Studio's JBR when no system JDK is configured:

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:testDebugUnitTest :app:lintDebug
```

Pigeon generation is isolated from Riverpod's analyzer dependency:

```bash
dart --packages=tool/pigeon/.dart_tool/package_config.json \
  tool/pigeon/bin/generate.dart --input pigeons/rana_camera_api.dart
```

## Architecture and operations

- [Architecture](docs/architecture.md)
- [Camera, render, and capture pipeline](docs/camera-pipeline.md)
- [Preview transform](docs/preview-transform.md)
- [Typed platform API](docs/platform-api.md)
- [Parity and lifecycle testing](docs/parity-lifecycle-testing.md)
- [Device matrix](docs/device-matrix.md)
- [Permission audit](docs/permission-audit.md)
- [Release checklist and signing](docs/release-checklist.md)
- [Improvement roadmap PRD](docs/rana_improvement_roadmap_prd.md)

The P0 automated baseline is zero analyzer findings. Physical-device claims are
recorded only after the exact matrix has been run; see the device matrix for
currently pending Xiaomi 14T Pro validation.
