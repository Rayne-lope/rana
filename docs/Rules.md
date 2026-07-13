# Rana Camera Preview Rules

Project: **Rana**  
Scope: Flutter + Android native CameraX custom GL live preview  
Primary bug class: preview aspect ratio, crop, rotation, resize, SurfaceTexture, OpenGL transform  
Main Android files:

- `android/app/src/main/kotlin/com/rana/app/rana/CameraAspectRatio.kt`
- `android/app/src/main/kotlin/com/rana/app/rana/CameraPreviewView.kt`
- `android/app/src/main/kotlin/com/rana/app/rana/CameraGlRenderer.kt`
- `android/app/src/main/kotlin/com/rana/app/rana/PreviewTextureTransform.kt`
- `lib/features/camera/view/camera_screen.dart`

---

## 0. Purpose

This file is the mandatory engineering rulebook for any human, AI agent, or Codex session that wants to edit Rana camera preview code.

The Rana camera preview is not a normal Flutter layout problem. It crosses several layers:

1. Flutter layout and `AndroidView` size.
2. Android PlatformView measurement and resize.
3. CameraX `Preview`, `ViewPort`, `SurfaceRequest`, and `TransformationInfo`.
4. `SurfaceTexture` buffer negotiation and OES texture transform.
5. EGL surface size and `glViewport`.
6. Custom OpenGL renderer matrix math.
7. Device orientation, lens facing, and possible mirroring.

A preview ratio fix is accepted only if it preserves all supported preview ratios:

- `3:4`
- `1:1`
- `9:16`

The goal is **live preview aspect correctness only** unless a task explicitly says otherwise.

---

## 1. Mandatory reading before editing preview code

Before editing any file related to camera preview, read the relevant docs below. Do not start coding from assumptions.

### 1.1 CameraX transform output

Read this before changing anything related to `cropRect`, `rotationDegrees`, `ViewPort`, transform matrix, preview scaling, or custom surface rendering.

- Android Developers — CameraX Transform Output  
  https://developer.android.com/media/camera/camerax/transform-output

Why this is required:

- CameraX output is a combination of a buffer and transformation information.
- Preview display requires the buffer to be cropped and rotated correctly before being shown.
- Custom surfaces and OpenGL renderers must apply transform logic manually.

### 1.2 `SurfaceRequest.TransformationInfo`

Read this before changing `PreviewTextureTransform.kt`, `CameraPreviewView.bindPreview()`, or any code that consumes `cropRect`, `rotationDegrees`, `sensorToBufferTransformMatrix`, `hasCameraTransform`, or `isMirroring`.

- AndroidX API Reference — `SurfaceRequest.TransformationInfo`  
  https://developer.android.com/reference/androidx/camera/core/SurfaceRequest.TransformationInfo

Required understanding:

- `cropRect` is in preview buffer coordinates.
- The coordinate system ranges from `(0, 0)` to `SurfaceRequest.getResolution()`.
- `cropRect` is not Flutter view-space.
- `cropRect` is not raw sensor active-array space.
- If `ViewPort` is configured, CameraX computes the crop rectangle based on that `ViewPort`.
- `rotationDegrees` must not be blindly applied if the camera transform is already included by the surface path.
- On CameraX versions that expose `hasCameraTransform()`, use it to avoid double rotation.

### 1.3 Official CameraX OpenGL renderer sample

Read this before changing `CameraGlRenderer.kt`, EGL setup, `SurfaceTexture`, `setDefaultBufferSize`, OES shader sampling, or render loop behavior.

- AndroidX Camera core test app — `OpenGLRenderer.java`  
  https://android.googlesource.com/platform/frameworks/support/+/refs/heads/androidx-main/camera/integration-tests/coretestapp/src/main/java/androidx/camera/integration/core/OpenGLRenderer.java

Required understanding:

- The official sample uses `SurfaceRequest.getResolution()` as the `SurfaceTexture` default buffer size.
- The sample uses `SurfaceTexture.getTransformMatrix()` during rendering.
- The sample separates texture transform, crop/output transform, and view/model transform logic.
- The sample recalculates transforms based on preview size, crop rect, output surface size, rotation, and mirroring.

### 1.4 CameraX `PreviewTransformation` source

Read this before trying to recreate `PreviewView` behavior manually.

- AndroidX source — `PreviewTransformation.java`  
  https://android.googlesource.com/platform/frameworks/support/+/f2e05c341382db64d127118a13451dcaa554b702/camera/camera-view/src/main/java/androidx/camera/view/PreviewTransformation.java

Required understanding:

- `PreviewView` does not solve aspect ratio by simple raw ratio comparison.
- It maps a transformed surface rectangle to the preview view rectangle.
- It accounts for crop rect, surface size, preview view size, rotation, and layout direction.
- This source is the best reference when building custom `PreviewView`-like behavior.

### 1.5 Android `SurfaceTexture`

Read this before changing `SurfaceTexture`, OES texture ID usage, `updateTexImage()`, `getTransformMatrix()`, render thread, or shader sampling.

- Android API Reference — `SurfaceTexture`  
  https://developer.android.com/reference/android/graphics/SurfaceTexture

Required understanding:

- Camera frames arrive through `SurfaceTexture` as an external OES texture.
- `updateTexImage()` must be called with the owning OpenGL context current.
- After `updateTexImage()`, the renderer must call `getTransformMatrix()` and use that matrix when sampling the texture.
- The matrix can change between frames.
- OES textures must be sampled as `GL_TEXTURE_EXTERNAL_OES`, not normal `GL_TEXTURE_2D`.

### 1.6 Flutter Android Platform Views

Read this before changing `AndroidView`, Flutter preview gate layout, PlatformView creation, native view sizing, resize handling, or composition mode assumptions.

- Flutter Docs — Hosting native Android views in Flutter  
  https://docs.flutter.dev/platform-integration/android/platform-views

Required understanding:

- `AndroidView` embeds a native Android view inside Flutter.
- Flutter layout size and native Android measured size must be verified separately.
- A correct Flutter `SizedBox` aspect ratio does not guarantee the native renderer has already recalculated its output transform.
- Resize after ratio change must be observed on the Android side.

### 1.7 CameraX release notes

Read this before using or assuming CameraX APIs such as `hasCameraTransform()`, `sensorToBufferTransformMatrix`, `isMirroring`, `ResolutionSelector`, or newer transform behavior.

- AndroidX Camera release notes  
  https://developer.android.com/jetpack/androidx/releases/camera

Required understanding:

- CameraX transform APIs and behavior vary by library version.
- Before using a newer API, confirm the exact CameraX version in Rana.
- If the method is unavailable in Rana's current CameraX version, do not write code that assumes it exists.

### 1.8 Android camera samples repository

Use this for general CameraX reference only. Do not copy unrelated app architecture directly into Rana.

- Android Camera Samples  
  https://github.com/android/camera-samples

---

## 2. Non-negotiable preview rules

### Rule 1 — Flutter gate controls UI size only

Flutter `_previewGateSize(...)` determines the visible UI container size for the preview.

It does not decide CameraX buffer resolution.
It does not replace CameraX `ViewPort`.
It does not replace OpenGL transform logic.

### Rule 2 — `SurfaceRequest.resolution` controls the CameraX preview buffer

When CameraX provides a `SurfaceRequest`, the renderer must treat `request.resolution` as the requested preview buffer size.

Do not replace it with the Flutter gate size.
Do not force it to square for `1:1`.
Do not force it to `9:16` or `3:4` based on UI ratio.

Allowed:

```kotlin
cameraSurfaceTexture.setDefaultBufferSize(
    request.resolution.width,
    request.resolution.height
)
```

Not allowed:

```kotlin
cameraSurfaceTexture.setDefaultBufferSize(
    androidView.width,
    androidView.height
)
```

Not allowed:

```kotlin
cameraSurfaceTexture.setDefaultBufferSize(squareSize, squareSize)
```

### Rule 3 — `cropRect` is buffer-space

`TransformationInfo.cropRect` must be interpreted in the coordinate space of `SurfaceRequest.resolution`.

Example:

```text
request.resolution = 1440 x 1080
cropRect = Rect(180, 0, 1260, 1080)
```

This means CameraX selected a square 1080 x 1080 valid region inside a 1440 x 1080 preview buffer.

It does not mean the Flutter view is 1080 x 1080.
It does not mean the sensor output is 1080 x 1080.
It does not mean the buffer should be resized to 1080 x 1080.

### Rule 4 — Do not compare raw `cropRect` ratio to desired UI ratio as a fix

This is forbidden because it already regressed Rana ratios.

Not allowed:

```kotlin
val cropRatio = cropRect.width().toFloat() / cropRect.height()
if (abs(cropRatio - desiredRatio) > tolerance) {
    cropRect = manualCenterCrop(...)
}
```

Reason:

- `cropRect` must be interpreted with buffer size, rotation, output size, lens facing, and transform order.
- Width and height may need rotation-aware interpretation.
- Replacing CameraX crop with a manual crop can break `3:4`, `1:1`, and `9:16` together.

### Rule 5 — Always use `SurfaceTexture.getTransformMatrix()` for OES sampling

The renderer must call `SurfaceTexture.updateTexImage()` and then `SurfaceTexture.getTransformMatrix(...)` on the GL thread with the correct OpenGL context current.

Do not remove the SurfaceTexture matrix.
Do not assume it is identity.
Do not apply stale matrix values after surface recreation.

### Rule 6 — Separate texture transform from output geometry transform

Do not collapse all logic into one unclear crop matrix unless the matrix spaces are documented and tested.

Recommended mental model:

```text
CameraX buffer
→ SurfaceTexture OES texture sampling transform
→ crop rect valid region
→ output view mapping
→ EGL surface size
→ glViewport
→ Flutter AndroidView visible gate
```

Texture sampling matrix and output MVP matrix should be separated or clearly documented.

### Rule 7 — Do not blindly apply `rotationDegrees`

`rotationDegrees` can cause double rotation if the SurfaceTexture path already contains the camera transform.

If the CameraX version exposes `hasCameraTransform()`:

```text
hasCameraTransform = true
→ Camera transform is already included in the SurfaceTexture transform path.
→ Do not blindly apply rotationDegrees again.

hasCameraTransform = false
→ App may need to apply rotationDegrees in the renderer.
```

If `hasCameraTransform()` is not available, verify behavior with logs and visual tests before applying rotation manually.

### Rule 8 — Recompute transform after every size or transform event

The renderer must recompute preview transform when any of these change:

- ratio mode changes: `3:4`, `1:1`, `9:16`
- Flutter `AndroidView` size changes
- native `CameraPreviewView.onSizeChanged()` fires
- CameraX `SurfaceRequest.resolution` changes
- CameraX `TransformationInfo` changes
- `cropRect` changes
- `rotationDegrees` changes
- display rotation changes
- lens facing changes
- EGL surface is recreated
- `glViewport` changes

### Rule 9 — Do not change image capture unless the task explicitly asks for it

This rule file is about live preview correctness.

Do not change:

- capture output size
- JPEG/EXIF behavior
- save pipeline
- gallery pipeline
- shader style/preset
- filter preset
- capture ratio behavior

unless the task explicitly requires those changes.

### Rule 10 — A fix is not accepted until all supported ratios pass

A preview fix must pass:

- `3:4`
- `1:1`
- `9:16`
- rotate device or simulate orientation where applicable
- switch ratio multiple times in one session
- close/reopen camera screen
- front/back camera if both are supported

---

## 3. Rana ratio model

Current expected ratio mapping:

```text
3:4
- Flutter viewfinder ratio: 3 / 4
- CameraX target aspect: RATIO_4_3
- ViewPort: 3 / 4

1:1
- Flutter viewfinder ratio: 1 / 1
- CameraX target aspect: RATIO_4_3
- ViewPort: 1 / 1

9:16
- Flutter viewfinder ratio: 9 / 16
- CameraX target aspect: RATIO_16_9
- ViewPort: 9 / 16
```

Important:

`1:1` using CameraX `RATIO_4_3` is allowed. The buffer can remain 4:3 while `ViewPort(1,1)` produces a square crop region.

Expected example for `1:1`:

```text
request.resolution = 1440 x 1080
cropRect = Rect(180, 0, 1260, 1080)
visible region = 1080 x 1080 square
output AndroidView = square
preview result = not stretched
```

If `request.resolution` is 4:3 in `1:1`, that is not automatically a bug.

---

## 4. Required diagnosis before coding

Before editing matrix/crop code, collect logs first.

### 4.1 Flutter logs

Add or verify logs in `camera_screen.dart` around preview gate calculation.

Required fields:

```text
[RanaFlutterPreviewGate]
ratioMode=1:1|3:4|9:16
screenSizeLogical=WIDTHxHEIGHT
devicePixelRatio=...
gateLogical=WIDTHxHEIGHT
gatePhysicalApprox=WIDTHxHEIGHT
androidViewKey=...
```

Expected:

- `1:1` gate width/height should be equal or nearly equal after rounding.
- `3:4` gate width/height should match `0.75` ratio.
- `9:16` gate width/height should match `0.5625` ratio.

### 4.2 Native Android view logs

Add logs in `CameraPreviewView`:

```text
[RanaNativePreviewView]
event=onMeasure|onSizeChanged|onLayout
ratioMode=...
measured=WIDTHxHEIGHT
layout=left,top,right,bottom
actualSize=WIDTHxHEIGHT
oldSize=WIDTHxHEIGHT
displayRotation=...
```

Expected:

- In `1:1`, native view size should be square or very close after pixel rounding.
- If Flutter gate is square but native view is not square, the bug is PlatformView sizing or layout propagation.

### 4.3 CameraX bind logs

Add logs in `CameraPreviewView.bindPreview()`:

```text
[RanaCameraXBind]
ratioMode=...
viewfinderRatio=...
previewTargetAspect=RATIO_4_3|RATIO_16_9
viewPort=Rational(width,height)
targetRotation=...
lensFacing=...
useCaseGroupCreated=true|false
previewBound=true|false
imageCaptureBound=true|false
```

Expected:

- `1:1` must use `ViewPort(1, 1)`.
- `3:4` must use `ViewPort(3, 4)`.
- `9:16` must use `ViewPort(9, 16)`.

### 4.4 `SurfaceRequest` logs

Log every new `SurfaceRequest`:

```text
[RanaSurfaceRequest]
ratioMode=...
requestResolution=WIDTHxHEIGHT
setDefaultBufferSize=WIDTHxHEIGHT
surfaceTextureId=...
surfaceProvided=true|false
```

Expected:

- `setDefaultBufferSize` must match `requestResolution`.
- Do not expect `1:1` to produce square `requestResolution`.

### 4.5 `TransformationInfo` logs

Log every `TransformationInfo` callback:

```text
[RanaTransformationInfo]
ratioMode=...
requestResolution=WIDTHxHEIGHT
cropRect=left,top,right,bottom
cropSize=WIDTHxHEIGHT
rotationDegrees=0|90|180|270
hasCameraTransform=true|false|unavailable
isMirroring=true|false|unavailable
sensorToBufferTransformMatrix=[...16 or 9 values if available...]
```

Expected for `1:1`:

- If request buffer is 4:3, crop rect should usually be square or near-square.
- If crop rect is full 4:3 in `1:1`, suspect `ViewPort` is not active or not rebound.
- If crop rect is square but preview is stretched, suspect renderer transform or output sizing.

### 4.6 SurfaceTexture logs

Log the first few frames after bind and after every ratio change:

```text
[RanaSurfaceTexture]
frameIndex=...
timestamp=...
textureMatrix=[16 floats]
```

Required:

- Call `updateTexImage()` on the GL thread.
- Call `getTransformMatrix()` after `updateTexImage()`.
- Do not reuse a stale matrix after a new SurfaceTexture or SurfaceRequest.

### 4.7 OpenGL renderer logs

Log renderer state after transform recompute:

```text
[RanaGlRenderer]
ratioMode=...
previewBufferSize=WIDTHxHEIGHT
cropRect=left,top,right,bottom
outputViewSize=WIDTHxHEIGHT
eglSurfaceSize=WIDTHxHEIGHT
glViewport=0,0,WIDTH,HEIGHT
rotationDegrees=...
hasCameraTransform=...
textureMatrix=[16 floats]
mvpMatrix=[16 floats]
transformDirtyReason=ratioChanged|viewSizeChanged|surfaceRequestChanged|transformationInfoChanged|eglSurfaceChanged|displayRotationChanged
```

Expected:

- `glViewport` must match EGL surface/output size.
- Transform must be recomputed after ratio changes.
- Transform must be recomputed after native view size changes.

---

## 5. Diagnosis map

Use this before writing a fix.

### Case A — `1:1` cropRect is full 4:3

Example:

```text
ratioMode=1:1
requestResolution=1440x1080
cropRect=0,0,1440,1080
```

Likely cause:

- `ViewPort(1,1)` is not active.
- `UseCaseGroup` was not rebuilt after ratio change.
- Ratio state is stale when binding CameraX.
- TransformationInfo callback belongs to an old SurfaceRequest.

Fix area:

- `CameraAspectRatio.kt`
- `CameraPreviewView.bindPreview()`
- UseCaseGroup / ViewPort creation
- ratio change rebind sequence

Do not fix this in GL crop matrix first.

### Case B — `1:1` cropRect is square but preview is stretched

Example:

```text
ratioMode=1:1
requestResolution=1440x1080
cropRect=180,0,1260,1080
nativeView=1080x1080
preview still looks horizontally/vertically stretched
```

Likely cause:

- Renderer draws full buffer into square output.
- Crop is applied in the wrong coordinate space.
- Texture matrix and crop matrix are multiplied in the wrong order.
- `glViewport` is stale.
- Output MVP matrix is stale.

Fix area:

- `CameraGlRenderer.kt`
- `PreviewTextureTransform.kt`
- EGL surface resize handling
- matrix recompute lifecycle

### Case C — Flutter gate is square but native AndroidView is not square

Example:

```text
Flutter gate = 360x360
CameraPreviewView.onSizeChanged = 360x480
```

Likely cause:

- PlatformView sizing issue.
- Native view layout params are overriding Flutter size.
- AndroidView is not recreated or resized after ratio change.
- Parent layout clips visually but native renderer still uses old output size.

Fix area:

- `camera_screen.dart`
- PlatformView keying strategy
- `CameraPreviewView.onMeasure()` / `onSizeChanged()`
- renderer output size update

### Case D — Preview becomes correct after reopen/rotate only

Likely cause:

- stale transform state
- missing transform dirty flag
- surface resize not triggering renderer recompute
- old `TransformationInfo` reused
- EGL surface recreated but renderer uses old viewport/matrix

Fix area:

- lifecycle ordering
- transform dirty reasons
- SurfaceTexture recreation path
- renderer state reset

### Case E — Only front camera is wrong

Likely cause:

- mirroring not handled
- `isMirroring` unavailable or ignored
- custom mirror transform conflicts with CameraX transform

Fix area:

- lens-facing-specific transform
- `TransformationInfo.isMirroring` if available
- output MVP matrix

---

## 6. Forbidden fixes

The following fixes are not allowed unless a separate research note proves they are correct for Rana.

### 6.1 Raw crop ratio override

Forbidden:

```kotlin
if (cropRect.width().toFloat() / cropRect.height() != desiredRatio) {
    useManualCenterCrop()
}
```

Reason:

- Already regressed all ratios in Rana.
- Ignores rotation and coordinate space.
- Confuses buffer-space with view-space.

### 6.2 Setting SurfaceTexture buffer size to Flutter gate

Forbidden:

```kotlin
surfaceTexture.setDefaultBufferSize(view.width, view.height)
```

Reason:

- CameraX asked for `SurfaceRequest.resolution`.
- Official CameraX OpenGL sample uses request resolution.
- Flutter gate is output size, not producer buffer size.

### 6.3 Removing `SurfaceTexture.getTransformMatrix()`

Forbidden:

```kotlin
// assume identity texture transform
```

Reason:

- OES texture sampling requires the transform matrix.
- The matrix can vary by frame/device/producer.

### 6.4 Applying rotation blindly

Forbidden:

```kotlin
matrix.postRotate(rotationDegrees.toFloat())
```

without checking current transform behavior.

Reason:

- Can cause double rotation.
- CameraX may already include camera transform in the SurfaceTexture path.

### 6.5 Fixing preview by changing capture pipeline

Forbidden unless explicitly requested:

- changing `ImageCapture` target ratio
- changing JPEG crop
- changing EXIF rotation
- changing saved image dimensions
- changing capture filter/shader style

Reason:

- Current task scope is live preview aspect correctness.

---

## 7. Recommended implementation path

### Step 1 — Add instrumentation first

Before changing matrix math, add all required logs from section 4.

No preview transform fix is allowed without logs.

### Step 2 — Verify ratio propagation

For each ratio, confirm:

```text
Flutter selected ratio
→ native ratioMode
→ CameraAspectRatio config
→ CameraX ViewPort
→ SurfaceRequest
→ TransformationInfo
→ renderer output transform
```

### Step 3 — Preserve `SurfaceRequest.resolution`

Keep:

```kotlin
cameraSurfaceTexture.setDefaultBufferSize(
    request.resolution.width,
    request.resolution.height
)
```

### Step 4 — Treat CameraX crop as authoritative

If `ViewPort` is active and CameraX returns a valid `cropRect`, use it as the valid preview region.

Do not replace it based on raw ratio checks.

### Step 5 — Separate transforms

Preferred renderer model:

```text
textureMatrix = SurfaceTexture.getTransformMatrix()
previewCrop = TransformationInfo.cropRect in request-resolution buffer space
outputMatrix = map previewCrop into actual AndroidView/EGL output size
final shader sampling = textureMatrix
final geometry placement = outputMatrix / MVP
```

If current code combines them, document the coordinate space and multiplication order clearly.

### Step 6 — Recompute on every relevant event

Implement or verify a dirty flag system:

```kotlin
markTransformDirty("ratioChanged")
markTransformDirty("viewSizeChanged")
markTransformDirty("surfaceRequestChanged")
markTransformDirty("transformationInfoChanged")
markTransformDirty("eglSurfaceChanged")
markTransformDirty("displayRotationChanged")
```

Renderer must recompute before drawing the next frame.

### Step 7 — Add visual calibration overlay

Temporary debug overlay allowed:

- center circle
- 3x3 grid
- crop border
- text with ratio, request resolution, crop rect, output size

Acceptance:

- A circle must remain a circle in `3:4`, `1:1`, and `9:16`.
- Grid cells must not stretch.

Remove or hide overlay behind debug flag before final release.

---

## 8. Test matrix

A preview fix must be tested with this matrix.

### 8.1 Ratio switching

Test sequence:

```text
Open camera
3:4 → 1:1 → 9:16 → 1:1 → 3:4
Close camera
Open camera again
1:1 → 9:16 → 3:4
```

Expected:

- no stretch
- no stale crop
- no delayed correction only after reopen
- no black frame beyond normal transient camera startup

### 8.2 Orientation

Test if the app supports or reacts to rotation:

```text
Portrait
Rotate device if allowed
Return portrait
Switch ratio again
```

Expected:

- no double rotation
- no swapped ratio bug
- crop remains centered/expected

### 8.3 Camera lens

If both lenses are supported:

```text
Back camera: 3:4, 1:1, 9:16
Front camera: 3:4, 1:1, 9:16
```

Expected:

- no stretch
- front camera mirror behavior consistent with intended UX

### 8.4 Lifecycle

Test:

```text
Open camera
Switch ratio
Background app
Return app
Switch ratio again
Take photo
Return to preview
```

Expected:

- transform state not stale
- SurfaceTexture not using old matrix
- EGL viewport not stale

---

## 9. Acceptance criteria

A preview-ratio fix is accepted only if all are true:

1. `3:4`, `1:1`, and `9:16` preview are visually correct.
2. The calibration circle remains circular in all ratios.
3. Flutter gate size and native Android view size match expected ratio.
4. `SurfaceRequest.resolution` is logged and used for default buffer size.
5. `TransformationInfo.cropRect` is logged.
6. `SurfaceTexture.getTransformMatrix()` is used after `updateTexImage()`.
7. `glViewport` matches current EGL/output size.
8. Transform recomputes after ratio change.
9. No capture pipeline behavior changed unless explicitly requested.
10. No shader style/preset changed.
11. No raw crop-ratio override introduced.
12. The fix does not depend on reopening the camera screen to become correct.

---

## 10. Rollback criteria

Immediately revert or isolate the change if any of these happen:

- `3:4` becomes stretched after fixing `1:1`.
- `9:16` becomes stretched after fixing `1:1`.
- Preview is correct only after reopening the camera.
- Front camera becomes mirrored incorrectly.
- Captured image output changes unexpectedly.
- Shader style/preset changes unexpectedly.
- Preview flickers repeatedly after ratio switch.
- Device rotation causes double rotation.
- Logs show stale `SurfaceRequest` or stale transform info being used.

---

## 11. Codex / AI agent instruction block

Paste this into any AI coding session before asking it to edit Rana preview code:

```text
You are editing the Rana Flutter + Android CameraX custom GL camera preview.

Before coding, follow these mandatory rules:

1. Read Android CameraX Transform Output docs:
   https://developer.android.com/media/camera/camerax/transform-output

2. Read SurfaceRequest.TransformationInfo docs:
   https://developer.android.com/reference/androidx/camera/core/SurfaceRequest.TransformationInfo

3. Read the official CameraX OpenGLRenderer sample:
   https://android.googlesource.com/platform/frameworks/support/+/refs/heads/androidx-main/camera/integration-tests/coretestapp/src/main/java/androidx/camera/integration/core/OpenGLRenderer.java

4. Read Android SurfaceTexture docs:
   https://developer.android.com/reference/android/graphics/SurfaceTexture

5. Treat cropRect as buffer-space relative to SurfaceRequest.resolution.

6. Do not compare raw cropRect aspect ratio to the desired UI ratio as a fix.

7. Do not replace CameraX cropRect with manual center crop unless logs prove CameraX ViewPort is not active and the new behavior is documented.

8. Do not set SurfaceTexture default buffer size to Flutter gate size. Use SurfaceRequest.resolution.

9. Do not remove SurfaceTexture.getTransformMatrix().

10. Do not blindly apply rotationDegrees because it may double-rotate depending on hasCameraTransform / SurfaceTexture behavior.

11. Preserve ImageCapture pipeline unless the task explicitly asks to change capture output.

12. Preserve shader style and filter/preset behavior.

13. Add logs before changing transform math.

14. A valid fix must preserve 3:4, 1:1, and 9:16.

15. If 1:1 cropRect is full 4:3, debug CameraX ViewPort/rebind first.

16. If 1:1 cropRect is square but preview is stretched, debug GL transform/output size first.

17. If Flutter gate is square but native AndroidView is not square, debug PlatformView/native resize first.
```

---

## 12. Minimal safe task plan for preview-ratio bug

When fixing Rana preview ratio, follow this order:

```text
1. Add logs.
2. Reproduce 1:1 stretch.
3. Capture logs for 3:4, 1:1, 9:16.
4. Classify bug using diagnosis map.
5. Patch only the classified layer.
6. Re-test all ratios.
7. Verify capture output unchanged.
8. Remove noisy logs or keep behind debug flag.
```

Do not start at step 5.

---

## 13. Quick reference links

CameraX Transform Output  
https://developer.android.com/media/camera/camerax/transform-output

SurfaceRequest.TransformationInfo  
https://developer.android.com/reference/androidx/camera/core/SurfaceRequest.TransformationInfo

Official CameraX OpenGLRenderer sample  
https://android.googlesource.com/platform/frameworks/support/+/refs/heads/androidx-main/camera/integration-tests/coretestapp/src/main/java/androidx/camera/integration/core/OpenGLRenderer.java

CameraX PreviewTransformation source  
https://android.googlesource.com/platform/frameworks/support/+/f2e05c341382db64d127118a13451dcaa554b702/camera/camera-view/src/main/java/androidx/camera/view/PreviewTransformation.java

Android SurfaceTexture API  
https://developer.android.com/reference/android/graphics/SurfaceTexture

Flutter Android Platform Views  
https://docs.flutter.dev/platform-integration/android/platform-views

AndroidX Camera release notes  
https://developer.android.com/jetpack/androidx/releases/camera

Android Camera Samples  
https://github.com/android/camera-samples
