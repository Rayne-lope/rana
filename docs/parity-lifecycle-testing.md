# Parity and lifecycle testing

## Automated parity

`test/render_parity_test.dart` uses deterministic color patches and crop markers.
Preview, offline capture, and gallery adapters receive the same recipe snapshot.
The gate requires:

- SSIM at least 0.98;
- mean absolute RGB error at most 2/255;
- crop alignment error at most one pixel.

This deterministic reference gate catches recipe/wire divergence. Physical GL
parity remains an instrumentation/device gate and is not claimed by the host
test.

## Automated lifecycle

Tests cover stale PlatformView IDs and generations, initialization/release
races, rapid resume, metric recreation, inactive versus paused release, timer
cancellation, zoom debounce, and Film Roll reservation reconciliation.

Standard gates:

```bash
flutter analyze
flutter test
cd android && ./gradlew :app:testDebugUnitTest :app:lintDebug
flutter build apk --debug
```

Pigeon generation must be run twice with identical generated-file hashes.

## Physical P0 gate

On Xiaomi 14T Pro / HyperOS 3, run 50 landscape and 20 portrait cold launches
with auto-rotate both enabled and disabled. Every launch must accept taps on
Settings and Gallery. Also run background/resume, renderer/activity recreation,
rapid capture, lens/aspect changes, permission revocation, low storage, and an
interrupted Film Roll. Record evidence in the device matrix.
