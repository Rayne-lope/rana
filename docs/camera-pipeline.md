# Camera, render, and capture pipeline

## Preview

1. Flutter waits for stable window metrics across two frames.
2. Android creates a PlatformView and registers its numeric ID.
3. Typed initialization resolves that exact ID and rejects missing/stale IDs.
4. CameraX provider and the GL input surface become ready.
5. The engine performs one generation-aware bind and publishes first frame.
6. A `RenderRecipeV1` snapshot is converted to renderer uniforms.

Flutter handles tap focus and pinch zoom; the Android preview uses transparent
hit testing and does not own those gestures.

## Capture

1. The façade cancels conflicting timer/zoom work and serializes recipe state.
2. One immutable recipe snapshot is locked with any Film Roll reservation.
3. Native accepts a typed capture request and publishes a capture ID.
4. CameraX acquires the source, the offline GL processor applies the same recipe,
   and MediaStore writes JPEG or HEIC with a documented fallback.
5. Metadata v5 stores recipe version and visual parameters. The URI and actual
   encoder output remain capture context, not visual recipe fields.
6. Completion commits a Film Roll reservation exactly once; failure releases it.

## Gallery re-render

Gallery reads capture metadata in batches, migrates legacy recipe data in
memory, and renders from `RenderRecipeV1`. Original media is not rewritten by a
metadata migration.

## Failure and timing

Camera, GL, capture, encoding, metadata, and lens failures use structured wire
codes. Debug/beta telemetry includes initialization, first frame, FPS, capture
processing, memory, thermal state, and active quality tier without media data.
