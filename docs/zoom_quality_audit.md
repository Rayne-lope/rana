# Rana Zoom Quality Audit

Use this protocol when comparing Rana zoom quality against the stock camera.

## Goal

Find whether soft 2x or 3x output comes from digital zoom, CameraX resolution
selection, Rana's normal GL/export path, memory downsampling, or missing OEM
camera processing.

## Required Logs

Capture `adb logcat` with these tags:

```bash
adb logcat -s RanaQualityAudit RanaCaptureTimeline CameraPreviewView
```

Record the following fields for every test shot:

- `zoom`, `zoomQualityLabel`, `isLikelyDigitalZoom`, `shouldWarnDigitalZoom`
- `activeCameraId`, `physicalCameraCount`, `availableFocalLengths`
- `previewResolution`, `captureResolution`, `captureCrop`
- `source`, `inSampleSize`, `qualityReduced`, `skipLut`
- `bitmap_stage` sizes for decoded, cropped, transformed, and processed
- `capture_saved` output size and `jpegBytes`

## Capture Matrix

Shoot the same static scene with Rana and the stock camera:

- Zoom: 1x, 2x, 3x
- Aspect: 3:4 and 1:1
- Scene: bright daylight detail, sunset landscape, indoor low light
- Preset: Rana Normal with style reset
- Flash: off

Use the original saved image files, not screenshots or chat-compressed copies.

## Comparison Notes

For each pair, record:

- File dimensions and file size
- EXIF focal length, exposure time, ISO, and orientation when available
- Crop/FOV difference between Rana and stock camera
- Whether Rana logged `qualityReduced=true` or `inSampleSize>1`
- Whether Rana logged `digital_likely` or `tele_candidate`
- Visible artifacts: watercolor foliage, edge halos, smeared distant detail,
  noise reduction, highlight bloom, and oversharpening

## Decision Guide

- If `inSampleSize>1`, fix memory/downsample path before judging zoom quality.
- If Rana final dimensions are much smaller, tune capture resolution selection.
- If Normal is softer only after `processed`, investigate GL no-op/bypass.
- If 3x logs `digital_likely`, keep `DIGI` UI warning and consider lowering the
  default quality zoom ceiling to 2x.
- If device exposes a telephoto focal spread, test a Camera2/CameraX physical or
  logical camera route before adding sharpening.
- If stock camera wins mostly in highlights/shadows/noise, test CameraX
  Extensions Auto/HDR as an opt-in experiment.
