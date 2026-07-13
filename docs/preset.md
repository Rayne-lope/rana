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
    "intensity": 0.35,
    "color": [0.0, 0.0, 0.0],
    "roundness": 0.5
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
    "highlightRollOff": 0.6,
    "shadowRollOff": 0.4,
    "filmBorder": {
      "style": "instant"
    },
    "dateStamp": {
      "enable": true
    },
    "splitToning": {
      "shadowsTint": [-0.08, 0.02, 0.12],
      "highlightsTint": [0.16, 0.10, -0.02]
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
* **`color`** *(Object, Required)*: Base color-grading parameters described below.
* **`grain`** *(Object, Required)*: Film-grain parameters described below.
* **`vignette`** *(Object, Required)*: Vignette parameters described below.
* **`lut`** *(String or `null`, Optional)*: Asset path of the preset's LUT. Use `null` for shader-only presets.
* **`overlay`** *(Any or `null`, Optional)*: Reserved for future preset-level overlay configuration. It is currently passed through by the model but is not rendered directly.
* **`behavior`** *(Any or `null`, Optional)*: Reserved for future randomization or preset behavior configuration.
* **`effects`** *(Object, Optional)*: Analog effects described below. A missing block resolves to neutral legacy defaults.
* **`style`** *(Object, Optional)*: Rana Style parameters described below.

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

* **`intensity`** *(Float, Range: 0.0 to 1.0)*: Blend strength at the corners. Uses a smooth radial gradient towards the outer edges of the frame.
* **`color`** *(Array of 3 Floats, each 0.0 to 1.0, **Optional**)*: Normalized RGB color blended into the edges. Black `[0, 0, 0]` preserves the legacy dark vignette; near-white colors create a light, dreamy edge fade. Invalid arrays fall back to black. Default: `[0, 0, 0]`.
* **`roundness`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Aspect-ratio correction for the vignette shape. `0.0` preserves the legacy frame-relative oval, while `1.0` approaches a pixel-space circle on portrait or landscape output. Values are clamped. Default: `0.0`.

---

### 2.5 OpenGL Effects (`effects`)

Low-level shader operations applied in the final compositing step:

* **`lightLeak`** *(Object, **Optional**)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Blending strength of the overlay light leak texture. Default: `0.0`.
  * `variant` *(Int, 0 to 3, or -1 for random)*: Selection of the light leak pattern. Default: `-1`.
* **`dust`** *(Object, **Optional**)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Blending strength of dust and scratches. Default: `0.0`.
* **`bloom`** *(Object, **Optional**)*:
  * `threshold` *(Float, 0.0 to 1.0)*: Luminance threshold for highlight extraction (bright-pass filter). Default: `0.8`.
  * `intensity` *(Float, 0.0 to 1.0)*: Glow strength of the blurred highlights overlay. Default: `0.0`.
* **`halation`** *(Object, **Optional**)*:
  * `intensity` *(Float, 0.0 to 1.0)*: Colored glow bleeding around bright highlight edges, simulating film-base reflection. Default: `0.0`.
  * `radius` *(Float, 0.25 to 4.0, **Optional**)*: Multiplier for the reflected-highlight blur spread. `1.0` matches the legacy spread; values are clamped to the supported range. Default: `1.0`.
  * `color` *(Array of 3 Floats, each 0.0 to 1.0, **Optional**)*: Normalized RGB hue of the halation flare. Default: legacy red-orange `[1.0, 0.35, 0.15]`. Invalid arrays fall back to the default hue.
* **`lensDistortion`** *(Object, **Optional**)*:
  * `strength` *(Float, -1.0 to 1.0)*: Radial barrel/pincushion lens distortion. Default: `0.0`.
* **`chromaticAberration`** *(Object, **Optional**)*:
  * `intensity` *(Float, Range: 0.0 to 1.0)*: Red-blue color fringing shift towards the edges of the frame, simulating vintage lens dispersion. Default: `0.0`.
* **`softness`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Soft-focus factor. Blurs the image slightly using box-blur sampling to emulate vintage soft-focus lenses. Default: `0.0`.
* **`highlightRollOff`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Strength of an exponential shoulder beginning at luminance `0.65` and approaching white asymptotically, preserving bright detail. Default: `0.0`.
* **`shadowRollOff`** *(Float, Range: 0.0 to 1.0, **Optional**)*: Strength of a smooth toe below luminance `0.35`, using `y²(2-y)` to roll deep shadows toward black. Default: `0.0`.
* **`filmBorder`** *(Object, **Optional**)*:
  * `style` *(String)*: Final analog frame rendered after grading, vignette, and tone roll-off. Supported values are `"none"` (legacy output), `"instant"` (warm instant-film paper with a thicker bottom margin), and `"35mm"` (black long-edge film bands with eight sprocket perforations per edge). The 35 mm bands rotate with portrait output. Default: `"none"`.
* **`dateStamp`** *(Object, **Optional**)*:
  * `enable` *(Boolean)*: When enabled, burns a classic monospace orange digital-clock date stamp (e.g. `'26 07 10`) at the bottom-right corner of the saved photo. Default: `false`.
* **`splitToning`** *(Object, **Optional**)*:
  * `shadowsTint` *(Array of 3 signed Floats, recommended -1.0 to 1.0)*: RGB offsets weighted toward darker pixels. Positive components add a channel and negative components subtract it.
  * `highlightsTint` *(Array of 3 signed Floats, recommended -1.0 to 1.0)*: RGB offsets weighted toward brighter pixels. Positive components add a channel and negative components subtract it.
  * Both arrays default to `[0.0, 0.0, 0.0]`, which is neutral. Missing, short, or non-numeric components resolve individually to `0.0`.

Effects are applied consistently to live preview and offline export. The final-stage order is color/style and fade, split toning, bloom/halation, light leak, dust, grain, vignette, highlight/shadow roll-off, optional film border, then output clamping. The date stamp is added only to the saved capture after GL rendering.

---

### 2.6 Style Parameters (`style`)

Phase-based color tuning parameters. Every property is optional when the `style` block is present:

* **`tone`** *(Float, Range: -100.0 to 100.0)*: Tone curve scaling. Default: `0.0`.
* **`color`** *(Float, Range: -100.0 to 100.0)*: Color saturation boost/decrease under style mapping. Default: `0.0`.
* **`styleStrength`** *(Float, Range: 0.0 to 100.0)*: Opacity blend of the style mapping over the color-graded input. Default: `100.0`.
* **`undertoneX`** *(Float, Range: -1.0 to 1.0)*: Warm-to-cool balance axis. Default: `0.0`.
* **`undertoneY`** *(Float, Range: -1.0 to 1.0)*: Green-to-magenta balance axis. Default: `0.0`.
* **`textureVal`** *(Float, Range: 0.0 to 100.0)*: Texture control that modulates grain intensity and size, dust, and softness according to `styleStrength`. Default: `0.0`.
* **`texture`** *(Float, Range: 0.0 to 100.0, legacy alias)*: Backward-compatible alias for `textureVal`. If both are supplied, `textureVal` wins. New presets should use `textureVal`.

---

## 3. Backward Compatibility and Authoring Notes

* New effect properties are optional. Omitting them preserves legacy rendering through neutral defaults.
* Use finite JSON numbers. RGB color arrays for `vignette.color` and `halation.color` must contain exactly three values; invalid arrays fall back to their documented defaults.
* `color.matrix` must contain exactly nine finite numbers in row-major order; otherwise Rana uses the identity matrix.
* Unknown `filmBorder.style` values resolve to `"none"`.
* Keep values inside the documented ranges even where a shader also clamps the final strength. This keeps preview, capture metadata, and future renderers predictable.
