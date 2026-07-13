# Rana Preset Configuration Guide

This document describes all the JSON parameters available for custom film emulation presets in the **Rana** camera application. 

Presets are stored in `assets/presets/` as JSON files. New parameters are designed to be optional, ensuring backward compatibility with existing presets.

---

## 1. Structure Overview

Here is a complete JSON layout showing all available parameters, including color adjustments, grain emulation, vignette, native styling parameters, and low-level OpenGL shader effects:

```json
{
  "id": "vintage_custom",
  "name": "Vintage Custom",
  "category": "Retro",
  "color": {
    "temperature": 0.15,
    "contrast": 0.05,
    "saturation": -0.1,
    "fade": 0.15,
    "matrix": [
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0,
      0.0, 0.0, 1.0
    ]
  },
  "grain": {
    "intensity": 0.25,
    "size": 1.5
  },
  "vignette": {
    "intensity": 0.35
  },
  "lut": "assets/luts/vintage_warm.png",
  "overlay": null,
  "behavior": null,
  "effects": {
    "lightLeak": {
      "intensity": 0.4,
      "variant": 2
    },
    "dust": {
      "intensity": 0.15
    },
    "bloom": {
      "threshold": 0.75,
      "intensity": 0.3
    },
    "halation": {
      "intensity": 0.2,
      "radius": 1.5,
      "color": [1.0, 0.35, 0.15]
    },
    "lensDistortion": {
      "strength": 0.08
    },
    "chromaticAberration": {
      "intensity": 0.12
    },
    "softness": 0.25,
    "dateStamp": {
      "enable": true
    }
  },
  "style": {
    "tone": -15.0,
    "color": 10.0,
    "styleStrength": 100.0,
    "undertoneX": 0.5,
    "undertoneY": -0.2,
    "textureVal": 20.0
  }
}
```

---

## 2. Parameter Details

### 2.1 Basic Properties
* **`id`** *(String, Required)*: A unique string identifier for the preset.
* **`name`** *(String, Required)*: The human-readable name displayed in the UI.
* **`category`** *(String, Required)*: Categorization (e.g. `"Classic"`, `"Retro"`, `"Disposable"`).

---

### 2.2 Color Parameters (`color`)
Color grading properties processed inside the color grading shader pass:
* **`temperature`** *(Float, Range: -1.0 to 1.0)*: Warmth/coolness tint. Positive values tint warm (yellow/orange), negative values tint cool (blue).
* **`contrast`** *(Float, Range: -1.0 to 1.0)*: Contrast factor.
* **`saturation`** *(Float, Range: -1.0 to 1.0)*: Color saturation factor.
* **`fade`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Shadows fade or matte look. Lifts the black floor of the image to produce faded, vintage film shadows. Default: `0.0`.
* **`matrix`** *(Array of 9 Floats, **Optional**)*: Row-major 3×3 RGB channel matrix applied after LUT and temperature, before saturation and contrast. Rows produce output red, green, and blue respectively, allowing film-specific channel scaling and crosstalk. Default: identity `[1, 0, 0, 0, 1, 0, 0, 0, 1]`. Invalid or non-finite matrices fall back to identity.

---

### 2.3 Grain Parameters (`grain`)
* **`intensity`** *(Float, Range: 0.0 to 1.0)*: Overall intensity of procedural film grain noise. Grain amplitude is luminance-adaptive: strongest across midtones and smoothly suppressed in deep shadows and near-white highlights.
* **`size`** *(Float, Range: 0.1 to 5.0, **Optional**)*: The size multiplier of individual grain noise flakes. Default: `1.0`.

---

### 2.4 Vignette Parameters (`vignette`)
* **`intensity`** *(Float, Range: 0.0 to 1.0)*: Darkness of the corners. Uses a smooth radial gradient towards the outer edges of the frame.

---

### 2.5 OpenGL Effects (`effects`)
Low-level shader operations applied in the final compositing step:
* **`lightLeak`** *(Object)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Blending strength of the overlay light leak texture.
  * `variant` *(Int, 0 to 3, or -1 for random)*: Selection of the light leak variant pattern.
* **`dust`** *(Object)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Blending strength of dust and scratches.
* **`bloom`** *(Object)*:
  * `threshold` *(Float, 0.0 to 1.0)*: Luminance threshold for highlight extraction (bright-pass filter).
  * `intensity` *(Float, 0.0 to 1.0)*: Glow strength of the blurred highlights overlay.
* **`halation`** *(Object)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Red-orange glow bleeding around bright highlight edges, simulating vintage chemical film halation.
  * `radius` *(Float, 0.25 to 4.0, **Optional**)*: Multiplier for the reflected-highlight blur spread. `1.0` matches the legacy spread; values are clamped to the supported range. Default: `1.0`.
  * `color` *(Array of 3 Floats, each 0.0 to 1.0, **Optional**)*: Normalized RGB hue of the halation flare. Default: legacy red-orange `[1.0, 0.35, 0.15]`. Invalid arrays fall back to the default hue.
* **`lensDistortion`** *(Object)*:
  * `strength` *(Float, -1.0 to 1.0)*: Radial barrel/pincushion lens distortion.
* **`chromaticAberration`** *(Object, **Optional**)*:
  * `intensity` *(Float, Range: 0.0 to 1.0)*: Red-blue color fringing shift towards the edges of the frame, simulating vintage lens dispersion. Default: `0.0`.
* **`softness`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Soft-focus factor. Blurs the image slightly using box-blur sampling to emulate vintage soft-focus lenses. Default: `0.0`.
* **`highlightRollOff`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Shoulder strength that progressively compresses bright values to preserve highlight detail. Default: `0.0`.
* **`shadowRollOff`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Toe strength that gently rolls deep shadows toward black. Default: `0.0`.
* **`dateStamp`** *(Object, **Optional**)*:
  * `enable` *(Boolean)*: When enabled, burns a classic monospace orange digital-clock date stamp (e.g. `'26 07 10`) at the bottom-right corner of the saved photo. Default: `false`.

---

### 2.6 Style Parameters (`style`)
Phase-based color tuning parameters:
* **`tone`** *(Float, Range: -100.0 to 100.0)*: Tone curve scaling.
* **`color`** *(Float, Range: -100.0 to 100.0)*: Color saturation boost/decrease under style mapping.
* **`styleStrength`** *(Float, Range: 0.0 to 100.0)*: Opacity blend of the style mapping over the color graded input.
* **`undertoneX`** / **`undertoneY`** *(Float, Range: -1.0 to 1.0)*: Color balance split mapping (warmer/cooler balance grid).
* **`textureVal`** *(Float, Range: 0.0 to 100.0, **Optional**)*: Custom texture uniform mapping factor. Default: `0.0`.
