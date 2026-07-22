# lib/features/camera/controller

`CameraController` is the Riverpod/UI facade. Its stateful implementation is
split into package-internal composed helpers under
`lib/src/features/camera/controller/`:

- `CameraLifecycleController` owns native initialization, release, and status
  stream lifetime.
- `CameraTimerController` owns self-timer countdown and cancellation.
- `CameraZoomController` owns optimistic zoom, debounce, and stale responses.
- `CameraRecipeQueue` serializes recipe changes and owns Film Roll capture
  reservations/reconciliation.
- `CameraRecipeBuilder` builds immutable preview and capture parameter maps.

Widgets must continue to use `cameraControllerProvider`; internal helpers are
not UI-facing APIs.
