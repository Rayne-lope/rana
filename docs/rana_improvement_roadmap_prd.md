# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Rana Camera App — Architecture, Stability, Performance, and Product Improvement Roadmap

**Document Version:** 1.0  
**Product:** Rana  
**Platform:** Android  
**Primary Stack:** Flutter, Riverpod, Kotlin, CameraX, OpenGL ES  
**Document Status:** Draft for execution  
**Prepared for:** Rana development roadmap  

---

# 1. Executive Summary

Rana is an Android camera application focused on producing premium analog-inspired images through a real-time camera pipeline.

The current application already includes:

- Flutter-based user interface
- Native Android CameraX integration
- OpenGL-based real-time rendering
- Analog film presets
- LUT processing
- Grain
- Vignette
- Bloom
- Halation
- Light leak
- Dust
- Chromatic aberration
- Tone and color adjustments
- Undertone controls
- Focus and metering
- Zoom
- Front and rear camera switching
- Aspect-ratio controls
- HEIC output capability
- Film Roll workflow
- Film Roll archive
- Contact sheet export
- Capture metadata
- Haptic and analog sound feedback

Rana has moved beyond the prototype stage. The main challenge is no longer feature availability, but system maintainability, rendering consistency, device compatibility, performance stability, and product clarity.

This PRD defines a roadmap to improve Rana without weakening its identity as a premium, simple, analog-inspired camera.

The roadmap prioritizes:

1. Architecture stabilization
2. Preview and output consistency
3. Typed Flutter-native communication
4. Performance telemetry and adaptive rendering
5. Camera lifecycle reliability
6. Film Roll product differentiation
7. Simplified preset and style interaction
8. Semantic skin-tone preservation as a later-stage imaging feature

---

# 2. Product Vision

## 2.1 Vision Statement

Rana should become a premium Android camera application that produces aesthetically consistent, analog-inspired photos with minimal user effort.

The product should feel like using a carefully designed film camera rather than operating a professional manual camera tool.

## 2.2 Product Positioning

Rana is not intended to compete directly with:

- Professional manual camera applications
- RAW photography tools
- DSLR control interfaces
- Technical video production applications
- Generic photo filter editors

Rana should compete through:

- Distinct visual identity
- Real-time analog rendering
- Reliable preview-to-output consistency
- Fast capture experience
- Film Roll ritual and storytelling
- Curated controls rather than technical complexity

## 2.3 Core Product Promise

> What users see in the Rana viewfinder should closely match the final saved photo.

---

# 3. Problem Statement

The application has grown rapidly and now contains several architectural and product risks.

## 3.1 Architecture Problems

- `CameraScreen` has too many UI and workflow responsibilities.
- Native `CameraPreviewView` handles too many camera, renderer, capture, lifecycle, and media responsibilities.
- Renderer parameters are passed individually and may become inconsistent.
- Flutter-native communication relies heavily on untyped maps.
- Several state variables can create illegal UI state combinations.
- Some native errors are silently ignored.

## 3.2 Performance Problems

- Multiple expensive effects may run simultaneously.
- Preview and capture may use equivalent resolution constraints.
- There is insufficient structured performance telemetry.
- Texture and shader processing can create device-specific performance problems.
- Adaptive quality currently requires a more formal architecture.
- The effect pipeline may become unstable when semantic face processing is added.

## 3.3 Product Problems

- Preset, style, mood, tone, color, texture, strength, and undertone may feel overlapping.
- The Film Roll feature is valuable but not yet positioned as the main differentiator.
- Adding more manual camera controls may dilute the product identity.
- Advanced skin-tone preservation could increase technical complexity before the current rendering pipeline is fully stabilized.

## 3.4 Release Readiness Problems

- Release signing is not finalized.
- Package identity still requires production review.
- README and technical documentation do not represent the actual application.
- Permission requirements need auditing.
- Device compatibility validation is not yet formalized.

---

# 4. Goals

## 4.1 Primary Goals

### G1 — Improve maintainability

Reduce the number of responsibilities handled by major UI and native classes.

### G2 — Guarantee recipe consistency

Use one structured rendering recipe across:

- Live preview
- Final capture
- Gallery re-rendering
- Film Roll
- Saved metadata

### G3 — Improve preview-output parity

Ensure that crop, orientation, color, style, and effect strength remain consistent between preview and final export.

### G4 — Improve camera lifecycle reliability

Prevent:

- Black preview
- Frozen camera state
- Capture deadlock
- Camera resource leakage
- Broken state after app resume
- Lens-switch timeout
- Invalid Film Roll capture state

### G5 — Improve performance across devices

Create a measurable and adaptive rendering system that degrades gracefully on weaker devices.

### G6 — Strengthen Rana's product identity

Make Film Roll and curated film rendering the center of the product experience.

### G7 — Prepare for advanced imaging

Build the necessary architecture before introducing semantic skin-tone preservation.

---

# 5. Non-Goals

The following are outside the current roadmap:

- Full manual ISO control
- Full manual shutter-speed control
- RAW capture workflow
- Professional histogram
- Zebra exposure overlay
- Focus peaking
- Waveform monitor
- Log video
- Professional video recording controls
- Desktop support
- iOS support
- Cloud-based image processing
- Social network features
- Public preset marketplace
- AI generative photo editing

These features may be reviewed later but should not block the current roadmap.

---

# 6. Target Users

## 6.1 Primary User

A mobile photography user who wants:

- Attractive photos without editing
- Analog film aesthetics
- A premium camera interface
- Fast and simple capture
- Consistent style
- Minimal technical controls
- A more intentional photography experience

## 6.2 Secondary User

A visual-content creator who wants:

- A repeatable visual identity
- Curated camera presets
- Film Roll-based shooting sessions
- Contact sheets
- Quick export
- Reliable Android camera performance

---

# 7. Core User Experience Principles

## 7.1 Minimal friction

The user should be able to:

1. Open Rana
2. Frame the subject
3. Select a film
4. Capture
5. Receive a finished image

## 7.2 Curated, not technical

Controls should represent visual outcomes rather than shader implementation details.

## 7.3 Consistency

The app should not surprise users with a saved image that looks materially different from the preview.

## 7.4 Premium interaction

Animations, haptics, sound, spacing, typography, and transitions should feel deliberate.

## 7.5 Graceful degradation

On lower-performance devices, Rana should simplify effects instead of dropping frames or becoming unstable.

---

# 8. Product Information Architecture

The product should use three primary style levels.

## 8.1 Film

The main visual identity.

Examples:

- Natural
- Amber
- Moody
- Faded
- Mono
- Cinematic

A Film defines the core rendering recipe.

## 8.2 Look

A curated variation of the selected Film.

Examples:

- Soft
- Warm
- Deep
- Clean
- Muted

A Look should adjust a controlled subset of the Film recipe.

## 8.3 Tune

Fine personalization controls.

Recommended Tune controls:

- Tone
- Color
- Grain
- Undertone
- Strength

Technical terms such as bloom threshold, halation radius, or color matrix should remain internal.

---

# 9. Functional Requirements

# 9.1 Camera Initialization

The application must:

- Request camera permission only when needed.
- Initialize the camera after permission is granted.
- Display a recoverable error when initialization fails.
- Prevent duplicate initialization requests.
- Restore the camera after app resume.
- Release camera resources when backgrounded.
- Recover from renderer recreation.
- Show a stable fallback state when camera initialization fails.

## Acceptance Criteria

- Camera initializes successfully after permission grant.
- App resumes to an active preview after backgrounding.
- Repeated background-resume cycles do not create a black preview.
- Failed initialization produces a structured user-visible error.
- No duplicate CameraX binding occurs during one lifecycle generation.

---

# 9.2 Preview Rendering

The live preview must support:

- Correct crop
- Correct orientation
- Front-camera mirroring
- Aspect-ratio switching
- Real-time Film recipe
- Tune adjustments
- Performance telemetry
- Adaptive quality tier
- Safe mode fallback

## Acceptance Criteria

- Preview orientation matches device capture orientation.
- Front-camera preview is mirrored correctly.
- Aspect-ratio framing matches the final output.
- Effect changes appear without camera reinitialization.
- Preview remains responsive while changing Film or Tune controls.
- Renderer can fall back to a reduced-quality tier.

---

# 9.3 Capture

The capture system must:

- Prevent overlapping capture requests.
- Support single capture.
- Support Film Roll capture.
- Preserve the active rendering recipe.
- Store durable metadata.
- Save through Android MediaStore.
- Support supported output formats.
- Return structured capture status.
- Recover from processing failure.
- Avoid blocking the UI thread.

## Acceptance Criteria

- Rapid shutter taps do not create duplicate invalid capture pipelines.
- Every successful capture receives a durable URI.
- Every Film Roll capture stores the correct Film Roll identifier.
- Capture metadata matches the applied recipe.
- Capture failure does not leave the shutter permanently disabled.
- User can capture again after a recoverable error.

---

# 9.4 Focus and Metering

The camera must support:

- Tap-to-focus
- Tap-to-meter
- Focus lock feedback
- Focus reset
- Focus cancellation after timeout
- Correct coordinate transformation
- Front-camera handling

## Acceptance Criteria

- Tapping the viewfinder maps to the correct camera coordinate.
- Focus indicator matches the touched location.
- Focus lock resets after the configured timeout.
- Pinch-to-zoom does not accidentally trigger focus.
- Focus state resets after camera switching.

---

# 9.5 Zoom and Lens Switching

The application must:

- Clamp user zoom to a safe range.
- Support smooth pinch zoom.
- Commit zoom after gesture completion.
- Handle logical and physical lens changes.
- Recover from unsupported physical-camera selection.
- Preserve UI state through lens switching.
- Display a stable transition overlay.

## Acceptance Criteria

- Zoom never exceeds supported native limits.
- Lens switching does not leave the preview black.
- Unsupported physical lenses are blocked after failure.
- Lens-switch timeout returns the app to a usable state.
- Zoom value remains synchronized between Flutter and native code.

---

# 9.6 Film Roll

Film Roll must become a first-class product workflow.

The user must be able to:

- Start a Film Roll
- Select exposure count
- Lock Film during an active roll
- View remaining exposures
- Capture into the active roll
- End a roll
- Abandon a roll
- Recover an interrupted roll
- View completed rolls
- Export a contact sheet
- Duplicate a completed roll recipe

## Acceptance Criteria

- A Film Roll cannot contain captures from inconsistent Film recipes.
- Exposure count decreases only after durable capture success.
- Interrupted Film Roll state is recoverable after restart.
- Film Roll completion is presented once.
- Contact sheet includes roll identity and capture order.
- Completed roll can be archived and reopened.

---

# 9.7 Gallery and Non-Destructive Re-rendering

The gallery must:

- Display Rana captures
- Load metadata in batches
- Reconstruct the original rendering recipe
- Re-render images non-destructively
- Use bounded image and texture caches
- Open the original media through Android
- Remain responsive with large capture libraries

## Acceptance Criteria

- Gallery thumbnails load progressively.
- Recipe metadata is loaded in batches.
- Re-rendered output matches the saved recipe.
- Cache memory has a defined maximum.
- Cache eviction releases bitmap and GL resources.

---

# 9.8 Error Handling

All significant errors must use structured error codes.

Required categories:

- `CAMERA_PERMISSION_DENIED`
- `CAMERA_INITIALIZATION_FAILED`
- `CAMERA_BIND_FAILED`
- `GL_INITIALIZATION_FAILED`
- `GL_RENDER_FAILED`
- `CAPTURE_PIPELINE_BUSY`
- `CAPTURE_FAILED`
- `CAPTURE_PROCESSING_FAILED`
- `MEDIASTORE_WRITE_FAILED`
- `OUTPUT_ENCODING_FAILED`
- `LENS_SWITCH_TIMEOUT`
- `PHYSICAL_LENS_UNSUPPORTED`
- `FILM_ROLL_RECOVERY_FAILED`
- `METADATA_READ_FAILED`
- `METADATA_WRITE_FAILED`

Each error must define:

- Code
- User-safe message
- Developer log message
- Whether it is recoverable
- Recommended recovery action

---

# 10. Architecture Requirements

# 10.1 Flutter Architecture

Recommended Flutter structure:

```text
lib/
├── core/
│   ├── error/
│   ├── logging/
│   ├── platform/
│   ├── router/
│   └── telemetry/
├── features/
│   ├── camera/
│   │   ├── application/
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   └── presentation/
│   ├── film_roll/
│   ├── gallery/
│   ├── preset/
│   └── settings/
```

## Camera presentation decomposition

```text
CameraScreen
├── CameraScreenCoordinator
├── CameraViewfinder
├── CameraTopControls
├── CameraBottomControls
├── FocusReticle
├── CaptureFeedbackOverlay
├── StyleEditorOverlay
├── PresetSelectorOverlay
└── FilmRollFlowCoordinator
```

## Camera UI mode

Use a sealed state model rather than multiple booleans.

```dart
sealed class CameraUiMode {}

class CaptureMode extends CameraUiMode {}

class FilmSelectionMode extends CameraUiMode {}

class StyleEditingMode extends CameraUiMode {}

class UndertoneEditingMode extends CameraUiMode {}

class FilmRollManagementMode extends CameraUiMode {}
```

Only one primary camera UI mode may be active at one time.

---

# 10.2 Native Android Architecture

Recommended native structure:

```text
android/app/src/main/kotlin/com/rana/app/rana/
├── camera/
│   ├── RanaCameraEngine.kt
│   ├── CameraBinder.kt
│   ├── CameraLensCoordinator.kt
│   ├── CameraFocusController.kt
│   ├── CameraZoomController.kt
│   ├── CameraCaptureCoordinator.kt
│   ├── CameraOrientationController.kt
│   ├── CameraSurfaceProvider.kt
│   └── CameraPreviewPlatformView.kt
├── rendering/
│   ├── CameraGlRenderer.kt
│   ├── RenderPipeline.kt
│   ├── RenderRecipe.kt
│   ├── RenderQualityController.kt
│   ├── ShaderProgramRegistry.kt
│   ├── TextureRepository.kt
│   └── PreviewTransform.kt
├── media/
│   ├── CaptureProcessor.kt
│   ├── MediaStoreWriter.kt
│   ├── HeicEncoder.kt
│   └── CaptureMetadataRepository.kt
└── platform/
    ├── RanaCameraHostApi.kt
    └── RanaCameraEventApi.kt
```

---

# 10.3 Render Recipe

A typed Render Recipe must become the single source of truth.

Example:

```kotlin
data class RenderRecipe(
    val recipeVersion: Int,
    val filmId: String,
    val color: ColorRecipe,
    val film: FilmRecipe,
    val optics: OpticsRecipe,
    val overlays: OverlayRecipe,
    val output: OutputRecipe
)

data class ColorRecipe(
    val temperature: Float,
    val saturation: Float,
    val contrast: Float,
    val tone: Float,
    val color: Float,
    val styleStrength: Float,
    val undertoneX: Float,
    val undertoneY: Float,
    val shadowsTint: ColorVector,
    val highlightsTint: ColorVector
)

data class FilmRecipe(
    val grain: Float,
    val grainSize: Float,
    val grainShadowsLimit: Float,
    val grainHighlightsLimit: Float,
    val fade: Float,
    val highlightRollOff: Float,
    val shadowRollOff: Float
)

data class OpticsRecipe(
    val vignette: Float,
    val vignetteRoundness: Float,
    val softness: Float,
    val lensDistortion: Float,
    val chromaticAberration: Float,
    val bloom: Float,
    val halation: Float
)

data class OverlayRecipe(
    val lightLeakVariant: Int?,
    val lightLeakIntensity: Float,
    val dustIntensity: Float,
    val filmBorderStyle: Int
)

data class OutputRecipe(
    val aspectRatio: String,
    val format: String,
    val qualityTier: String
)
```

The same recipe must be used by:

- Live preview renderer
- Offline capture processor
- Gallery re-renderer
- Film Roll metadata
- Contact sheet renderer

---

# 10.4 Typed Platform Communication

Flutter-native communication should migrate from raw maps to Pigeon-generated APIs.

Required typed operations:

- Initialize camera
- Release camera
- Select Film
- Apply recipe
- Begin capture
- Query capture status
- Set zoom
- Set focus and metering
- Cancel focus
- Switch camera
- Set aspect ratio
- Get output capabilities
- Read Film Roll captures
- Read capture metadata
- Load captured image bytes
- Open media in gallery

## Acceptance Criteria

- Platform API changes fail at compile time when incompatible.
- No production camera method relies on arbitrary string keys.
- Native error codes map to typed Dart exceptions.
- Render Recipe schema is versioned.

---

# 11. Performance Requirements

# 11.1 Performance Metrics

Rana must record the following metrics in development and beta builds:

- `camera_initialize_ms`
- `camera_bind_ms`
- `first_preview_frame_ms`
- `preview_average_fps`
- `preview_p95_frame_ms`
- `preview_dropped_frame_count`
- `preset_apply_ms`
- `shader_compile_ms`
- `texture_upload_ms`
- `capture_accept_ms`
- `capture_process_ms`
- `capture_save_ms`
- `gallery_thumbnail_decode_ms`
- `gallery_render_ms`
- `memory_java_mb`
- `memory_native_mb`
- `memory_gpu_estimate_mb`
- `thermal_status`
- `active_render_quality_tier`

---

# 11.2 Render Quality Tiers

## Tier A — High

- Full bloom
- Full halation
- Full overlay quality
- Higher-resolution intermediate buffer
- Full grain quality
- Full chromatic aberration

## Tier B — Balanced

- Reduced bloom resolution
- Reduced halation radius
- Limited overlay resolution
- Balanced intermediate buffer

## Tier C — Compatibility

- Single-pass color
- LUT
- Grain
- Vignette
- Basic light leak
- Bloom and halation disabled

## Tier D — Safe Mode

- Color matrix
- Tone
- Basic LUT
- Basic vignette
- No multipass effects
- No animated overlays

## Tier Selection Inputs

- GPU renderer
- Android version
- Device memory
- Preview resolution
- Average frame time
- Dropped-frame count
- Thermal state
- Recent renderer failures

---

# 11.3 Preview Resolution Strategy

Preview and capture resolution should be selected independently.

Recommended strategy:

- Preview: match device viewport with a practical upper limit
- Capture: use the highest stable quality supported by the selected aspect ratio
- Preview and capture: share the same viewport and crop semantics
- Output: preserve final framing consistency

---

# 11.4 Texture and Shader Management

The renderer must:

- Compile shaders once per supported pipeline.
- Prewarm required shaders after camera initialization.
- Avoid decoding textures on the render thread.
- Use bounded texture caches.
- Delete GL textures after eviction.
- Reuse framebuffers.
- Avoid repeated buffer allocation during rendering.
- Record texture upload duration.

---

# 12. Preview-to-Output Parity

# 12.1 Parity Requirements

The following must remain consistent:

- Crop
- Rotation
- Mirror behavior
- Film recipe
- LUT strength
- Undertone
- Grain intensity
- Vignette
- Bloom
- Halation
- Light leak
- Dust
- Film border
- Aspect ratio

# 12.2 Visual Parity Test

Use a fixed source image and compare:

1. Preview renderer output
2. Offline capture output
3. Gallery re-render output

Recommended metrics:

- Mean absolute pixel error
- SSIM
- Histogram delta
- Crop alignment markers
- Edge alignment
- Color patch delta

## Acceptance Criteria

- No visible crop shift between preview and output.
- No unintended rotation difference.
- No unintentional front-camera mirror difference.
- Recipe values are identical across all rendering paths.
- Output differences remain below the agreed visual threshold.

---

# 13. Semantic Skin-Tone Preservation

Semantic skin-tone preservation is planned after architecture and parity stabilization.

# 13.1 Objective

Reduce excessive Film effect changes on detected facial skin while preserving the overall visual style.

# 13.2 Phase 1 — Face Region Protection

Pipeline:

```text
Low-resolution camera frame
→ Face detection
→ Coordinate transformation
→ Soft elliptical mask
→ Temporal smoothing
→ Reduced style strength inside mask
```

Requirements:

- Detection does not run at full preview resolution.
- Detection may run at 5–10 FPS.
- Rendering remains at preview frame rate.
- Mask persists briefly after temporary detection loss.
- Front-camera mirroring is handled correctly.
- Orientation transformation is tested.

# 13.3 Phase 2 — Temporal Stability

Add:

- Exponential smoothing
- Position interpolation
- Size interpolation
- Lost-face grace period
- Confidence threshold
- Mask fade-in and fade-out

# 13.4 Phase 3 — Skin Segmentation

Use semantic segmentation only if face-region protection is insufficient.

Non-goal:

- Beauty retouching
- Face reshaping
- Skin smoothing
- Skin whitening

---

# 14. Permission and Privacy Requirements

The application must minimize permission scope.

## Requirements

- Request camera permission only when entering the camera experience.
- Request broad gallery access only when technically required.
- Prefer Android Photo Picker for importing external photos.
- Use Rana-owned MediaStore URIs when possible.
- Explain permission purpose before requesting.
- Do not collect facial images or detection data externally.
- Semantic face processing must remain on-device.
- Do not store face detection masks unless required for debugging in development builds.
- Development logs must not expose private image content.

---

# 15. Release Engineering Requirements

Before public beta:

- Finalize application ID.
- Create production signing configuration.
- Remove debug signing from release builds.
- Add `dev`, `beta`, and `prod` flavors.
- Configure secure CI secrets.
- Define versioning rules.
- Add release notes process.
- Add crash reporting or structured local diagnostics.
- Validate R8 and ProGuard behavior.
- Create Play Store internal testing build.
- Document supported Android versions.
- Document tested devices.
- Add privacy policy.
- Add permission disclosure.

---

# 16. Documentation Requirements

The repository must contain:

```text
README.md
docs/
├── architecture/
│   ├── overview.md
│   ├── camera-pipeline.md
│   ├── render-pipeline.md
│   ├── preview-transform.md
│   ├── capture-pipeline.md
│   └── platform-api.md
├── product/
│   ├── film-system.md
│   ├── film-roll.md
│   └── tune-controls.md
├── testing/
│   ├── device-matrix.md
│   ├── parity-testing.md
│   └── lifecycle-testing.md
└── releases/
    └── release-checklist.md
```

README must include:

- Product overview
- Current features
- Architecture diagram
- Setup
- Supported Android versions
- Tested devices
- Known limitations
- Roadmap
- Contribution rules

---

# 17. Testing Strategy

# 17.1 Flutter Unit Tests

Required tests:

- Camera UI mode transitions
- Camera recipe serialization
- Zoom clamping
- Capture block reasons
- Film Roll state transitions
- Permission capabilities
- Metadata parsing
- Error mapping
- Preset and Tune state restoration

# 17.2 Native JVM Tests

Required tests:

- Lens decision
- Physical lens fallback
- Target rotation selection
- Capture pipeline limiter
- MediaStore filename generation
- Recipe parsing
- Recipe version migration
- Transform matrix
- Render quality tier decision
- Error mapping

# 17.3 Android Instrumentation Tests

Required scenarios:

- Background and resume repeatedly
- Switch front and rear camera repeatedly
- Rapid capture requests
- Change Film during capture processing
- Change aspect ratio during active camera
- Revoke permission while backgrounded
- Low-storage state
- Activity recreation
- Renderer recreation
- Lens-switch timeout
- Film Roll nearly full
- Film Roll interrupted during capture
- App process restart during active Film Roll

# 17.4 Device Matrix

Minimum recommended categories:

- Current flagship device
- Mid-range Android device
- Low-memory Android device
- Samsung device
- Xiaomi device
- Google Pixel device
- Device with multiple physical rear cameras
- Device without HEIC support
- Android version at minimum supported SDK
- Latest supported Android version

---

# 18. Analytics and Diagnostics

Development and beta builds should expose a diagnostic report containing:

- Device model
- Android version
- GPU renderer
- App version
- Active Film
- Render quality tier
- Preview resolution
- Capture resolution
- Camera lens identifier
- Physical lens identifier
- Recent camera errors
- Recent render errors
- Average FPS
- Capture processing time
- Memory status
- Thermal status

No image data should be included.

---

# 19. Success Metrics

## Architecture

- `CameraScreen` reduced into maintainable feature widgets.
- Native camera responsibilities split across dedicated components.
- Raw platform maps removed from primary camera workflows.
- One Render Recipe used by all render paths.

## Stability

- No unrecoverable black preview in lifecycle stress tests.
- No permanent shutter lock after capture error.
- No duplicate Film Roll completion presentation.
- No camera resource leak after repeated resume cycles.

## Performance

- Stable preview on supported device tiers.
- Automatic degradation before severe frame drops.
- Capture processing duration visible in telemetry.
- Memory use remains within defined test limits.

## Visual Quality

- Preview and saved output remain visually consistent.
- Film recipe is reproduced from metadata.
- Gallery re-rendering matches capture rendering.
- Undertone remains consistent across preview and output.

## Product

- Film Roll becomes accessible from the main camera workflow.
- Film, Look, and Tune hierarchy is understandable.
- Core camera flow remains minimal.
- No professional camera control clutter is added.

---

# 20. Roadmap

# Phase P0 — Foundation and Stability

## Objective

Stabilize architecture and reduce critical technical risk.

## Deliverables

- Split `CameraScreen`.
- Replace local camera UI booleans with a typed UI mode.
- Split native `CameraPreviewView`.
- Create typed `RenderRecipe`.
- Introduce recipe versioning.
- Migrate primary platform communication to Pigeon.
- Replace silent native errors with structured errors.
- Add render and capture telemetry.
- Add preview-output parity tests.
- Audit Android permissions.
- Finalize release signing strategy.
- Rewrite README and architecture documentation.

## Exit Criteria

- No primary camera workflow uses arbitrary platform map keys.
- Preview, capture, and gallery use the same recipe.
- Major camera classes have clear ownership boundaries.
- Structured errors are visible in logs and UI.
- Basic parity test passes.

---

# Phase P1 — Performance and Compatibility

## Objective

Make Rana stable across a broader Android device range.

## Deliverables

- Render quality tier system.
- Preview and capture resolution separation.
- Shader prewarming.
- Texture preloading.
- Bounded GL texture cache.
- Thermal-aware degradation.
- Compatibility renderer.
- Device capability registry.
- Camera lifecycle stress tests.
- Performance dashboard for development builds.

## Exit Criteria

- Rana selects an appropriate quality tier automatically.
- Lower-performance devices remain usable.
- Renderer failure can fall back to safe mode.
- Camera lifecycle stress test passes on target device matrix.
- Texture cache does not grow without a defined limit.

---

# Phase P2 — Product Differentiation

## Objective

Strengthen Rana as a premium film-camera experience.

## Deliverables

- Film, Look, and Tune hierarchy.
- Improved Film Roll start flow.
- Locked Film recipe during active roll.
- Better remaining-exposure indicator.
- Completed Film Roll archive.
- Improved contact sheet.
- Duplicate Film Roll recipe.
- Non-destructive gallery re-rendering.
- Custom style versioning.
- Refined undertone interaction.

## Exit Criteria

- User can understand the difference between Film, Look, and Tune.
- Film Roll supports a complete start-to-archive workflow.
- Film Roll recipe remains internally consistent.
- Gallery can reproduce an older capture recipe.
- Undertone interaction has reset, center haptic, and safe clamping.

---

# Phase P3 — Advanced Imaging

## Objective

Add intelligent imaging without weakening performance and privacy.

## Deliverables

- Face-region protection
- Temporal mask stabilization
- Skin segmentation evaluation
- Device-specific render calibration
- Highlight-aware halation
- Resolution-aware grain
- Optional capture sharpening

## Exit Criteria

- Face protection does not cause visible mask jitter.
- Processing remains on-device.
- Preview performance remains within the selected quality tier.
- Skin protection does not create unnatural face boundaries.
- Advanced imaging can be disabled automatically on unsupported devices.

---

# 21. Priority Backlog

## Critical

- Typed Render Recipe
- Preview-output parity
- CameraScreen decomposition
- Native camera decomposition
- Structured error handling
- Platform API typing
- Release signing
- Permission audit

## High

- Performance telemetry
- Render quality tiers
- Device compatibility testing
- Shader prewarming
- Texture cache management
- Film Roll recipe locking
- Lifecycle stress tests

## Medium

- Film, Look, and Tune restructuring
- Contact sheet improvement
- Custom style versioning
- Non-destructive gallery re-render
- Diagnostic report
- Device capability registry

## Later

- Face-region protection
- Semantic skin segmentation
- Device-specific calibration
- Advanced grain model
- Highlight-aware halation

---

# 22. Major Risks

## Risk 1 — Rendering divergence

Preview and capture could use different parameter defaults or effect implementations.

**Mitigation:** Single typed Render Recipe and automated parity tests.

## Risk 2 — Camera lifecycle race condition

Flutter lifecycle, CameraX binding, renderer lifecycle, and capture processing may overlap.

**Mitigation:** Generation identifiers, dedicated lifecycle coordinator, and instrumentation stress tests.

## Risk 3 — Device-specific camera behavior

Physical camera selection and Camera2 interop may behave differently across manufacturers.

**Mitigation:** Device capability registry, fallback logic, blocklist, and device matrix testing.

## Risk 4 — GPU overload

Bloom, halation, overlays, grain, and future face masks may exceed weaker GPU capacity.

**Mitigation:** Render quality tiers, telemetry, safe mode, and thermal-aware degradation.

## Risk 5 — Product complexity

Additional controls may make Rana feel like a professional camera interface.

**Mitigation:** Film, Look, and Tune hierarchy with curated controls.

## Risk 6 — Metadata incompatibility

Future recipe changes may prevent older captures from being reproduced.

**Mitigation:** Recipe schema versioning and migration.

---

# 23. Recommended Initial Implementation Sequence

1. Define `RenderRecipe` schema.
2. Add recipe version.
3. Make preview renderer consume `RenderRecipe`.
4. Make offline processor consume the same `RenderRecipe`.
5. Make gallery rendering consume the same `RenderRecipe`.
6. Add parity test fixture.
7. Introduce typed platform API.
8. Split CameraScreen into presentation components.
9. Split CameraPreviewView into native coordinators.
10. Add structured camera errors.
11. Add performance telemetry.
12. Implement quality tiers.
13. Refine Film Roll product flow.
14. Implement face-region protection prototype.

---

# 24. Definition of Done

A roadmap item is complete only when:

- Implementation is merged.
- Unit tests pass.
- Relevant instrumentation tests pass.
- No new analyzer or lint errors are introduced.
- Architecture documentation is updated.
- User-facing behavior is documented.
- Error states have recovery behavior.
- Performance impact is measured.
- Device compatibility impact is recorded.
- Preview-output consistency is verified when rendering is affected.

---

# 25. Final Product Direction

Rana should continue as a focused analog-inspired camera product.

The roadmap should avoid uncontrolled feature expansion.

The highest-value improvements are:

1. Stabilize the rendering recipe.
2. Guarantee preview-output parity.
3. Improve camera lifecycle reliability.
4. Build adaptive performance.
5. Establish Film Roll as the main differentiator.
6. Add semantic skin preservation only after the foundation is stable.

The intended outcome is not the camera application with the most controls.

The intended outcome is a camera application with a distinct visual identity, reliable output, premium interaction, and a technically stable rendering pipeline.
