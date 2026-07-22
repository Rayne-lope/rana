# Architecture

Rana keeps Flutter domain APIs separate from generated transport and Android
implementation details.

## Flutter

- `CameraController` remains the Riverpod façade used by screens.
- Lifecycle, timer, zoom, and serialized recipe/Film Roll work live in focused
  composed controllers under `lib/src/features/camera/controller/`.
- `RenderRecipeV1` is the immutable visual source of truth. Capture identity,
  Film Roll reservation, URI, and actual encoder output are separate context.
- `CameraScreenCoordinator` owns primary UI mode, lifecycle, metrics, and modal
  route serialization. Presentation widgets do not call Riverpod directly.
- `CameraFailure` carries a wire code, user-safe and developer messages,
  recoverability, and a recovery action. `CameraState.errorMessage` remains a
  compatibility getter.
- Local telemetry stores at most 256 numeric samples with monotonic timestamps.

## Bridge

`CameraPlatformService` adapts the generated Pigeon API to existing domain maps
and streams. Generated types stay under `lib/src/platform/` and are not public
domain models. The legacy camera MethodChannel is debug-only; gallery/media
operations not yet in the camera contract may remain on the media channel.

## Android

- `MainActivity` registers the PlatformView and Pigeon host, forwards activity
  results, and temporarily retains non-camera gallery/media compatibility
  operations that are outside the P0 camera contract.
- `CameraPreviewView` is a thin PlatformView shell around `RanaCameraEngine`.
- Registry, surface, binder, lens, zoom, focus, capture, processing, metadata,
  MediaStore writing, and HEIC encoding have explicit owners.
- Initialization is generation-aware and requires both CameraX provider and GL
  input surface. A first-frame callback is distinct from initialization.

## Storage versions

- Render recipe: v1
- Capture metadata database: v5 (legacy v0 recipes migrate on read)
- Film Roll storage: v2 with `lockedRecipe`

Unsupported recipe versions produce structured errors and never delete media.
