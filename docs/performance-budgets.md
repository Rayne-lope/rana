# Performance budgets and device capabilities

Rana builds one privacy-safe capability profile per application session. The
profile is execution metadata: it never changes `RenderRecipe`, capture
metadata, or the visual intent of a photo.

## Capability inventory

The Android collector records the SDK level, total and application memory
class, low-memory flag, GL renderer, thermal API availability, best rear-camera
hardware level, rear and physical camera counts, logical multi-camera support,
HEIC support, and the number of renderer failures in the current session.

Collection failures produce `unknown` values and never interrupt camera
startup. The profile and its diagnostic representation contain no URI, file
path, capture identifier, Film Roll identifier, or image data.

## Classification

Classification uses the following precedence:

1. A local evidence-backed device override.
2. Safe for low-RAM devices, less than 3 GB RAM, SDK below 26, legacy Camera2,
   software GL, or two renderer failures in one session.
3. Compatibility when RAM, GPU, or camera hardware data is incomplete, RAM is
   below 4 GB, or SDK is below 29.
4. High for at least 8 GB RAM, SDK 31 or newer, known GPU, and Camera2 Full or
   Level 3.
5. Balanced otherwise.

The production override table starts empty. Add an entry only with a linked
device-matrix result that demonstrates a repeatable OEM-specific problem.

## Initial budgets

| Class | Target/min FPS | Maximum p95 | Dropped frames | Minimum free memory | GL cache | Preview long edge |
|---|---:|---:|---:|---:|---:|---:|
| High | 30/28 | 40 ms | 3% | 512 MB | 96 MB | 1920 px |
| Balanced | 30/26 | 45 ms | 5% | 384 MB | 64 MB | 1600 px |
| Compatibility | 24/22 | 55 ms | 8% | 256 MB | 32 MB | 1280 px |
| Safe | 24/20 | 66.7 ms | 12% | 192 MB | 16 MB | 960 px |

These are calibration baselines for the later quality-tier, resolution, cache,
and adaptive-quality workstreams. Update a value only with recorded device
matrix evidence and keep the previous result in the issue history.

## Debug verification

Debug builds log the latest safe snapshot under `RanaCapabilities` after GL
identification, renderer failure, or an explicit typed profile query:

```bash
adb logcat -c
adb logcat -s RanaCapabilities
```

Production builds do not emit this log. Flutter receives the profile through
the generated Pigeon contract; generated transport classes remain outside the
camera domain API.
