# Preview transform

Rana treats preview framing as an explicit viewport transform shared with
offline capture.

- Supported ratios are 3:4, 1:1, and 9:16.
- The fixed camera stage computes a contained PlatformView size from the chosen
  ratio; CameraX and offline processing receive the same aspect ratio value.
- Sensor/display rotation is evaluated independently from Flutter orientation.
- Front-camera output is mirrored for the user-facing preview and normalized in
  captured output by the capture-orientation transform.
- Crop semantics use center crop. Parity fixtures place markers at all four
  corners and permit at most one pixel of alignment error.
- A real metrics change invalidates the preview generation, releases the old
  camera, waits for two stable frames, and mounts a new PlatformView.

Android manifest portrait orientation is the single Android orientation
authority. The app does not issue a redundant startup orientation request.
