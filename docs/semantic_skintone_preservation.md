# Semantic Skin-Tone Preservation (Future Roadmap)

This document outlines the design concept and implementation guidelines for future development of **Semantic Skin-Tone Preservation (Option A)** in the Rana camera application.

---

## 1. The Core Problem
Rana currently applies color presets and undertone adjustments globally to the entire camera frame via an OpenGL fragment shader. While this works well for backgrounds and scenic elements, adjusting undertones (especially towards green, cyan, or magenta) can make human skin tones look artificial, sickly, or unrealistic.

---

## 2. Target Concept
To achieve professional-grade results (similar to Apple's Photographic Styles), the styling filter should only apply to the background and clothing, while keeping skin tones natural and true-to-life.

```
+--------------------------+
|  Camera Frame Input      |
+--------------------------+
             |
             v
+--------------------------+     (Real-time Face/Skin Detection)
|   Face/Skin Segmenter    |----------------------------+
+--------------------------+                            |
             |                                          v
             |                                +-------------------+
             | (RGB Texture)                  |   Binarized Mask  |
             |                                |   (Face Area)     |
             v                                +-------------------+
+-------------------------------------------------------+
|  OpenGL Fragment Shader (GL_TEXTURE_EXTERNAL_OES)     |
|                                                       |
|  // In Shader:                                         |
|  if (mask.r > 0.5) {                                  |
|      // Apply minimal or no color styling (Keep skin) |
|  } else {                                             |
|      // Apply full color preset & undertones          |
|  }                                                    |
+-------------------------------------------------------+
             |
             v
      Styled Output
```

---

## 3. Recommended Implementation Pipeline

### Phase 1: On-Device Face & Skin Segmentation
- **Technology**: Use **Google ML Kit (Selfie Segmentation)** or **TensorFlow Lite (Lite Segmenter)**. These libraries run 100% offline, on-device, and utilize the mobile neural engine (NPU/GPU) for maximum performance.
- **Output**: A low-resolution grayscale mask (e.g., 256x256) where white (`1.0`) represents human skin/faces and black (`0.0`) represents the background.

### Phase 2: Native-to-OpenGL Texture Bridge
- Upload the generated mask as a dynamic OpenGL texture (`GL_TEXTURE_2D`) in real-time inside `CameraGlRenderer.kt` on every frame update.
- Ensure texture operations are optimized (e.g., using `glTexSubImage2D` with low-res masks) to prevent dropping frames below 30 FPS.

### Phase 3: Fragment Shader Mask Sampling
- Update the fragment shader in `GlShaderConstants.kt` to read both the OES camera stream and the 2D skin mask.
- Interpolate color styling parameters using the mask value:
  ```glsl
  vec3 styledColor = applyRanaStyles(originalColor);
  float maskVal = texture2D(uSkinMaskTexture, vTextureCoord).r;
  
  // Mix original and styled colors based on face mask
  vec3 finalColor = mix(styledColor, originalColor, maskVal * 0.85);
  ```

---

## 4. Performance & Hardware Considerations
- Run segmentation on a separate background thread or worker.
- Keep the segmentation model footprint small to prevent excessive battery drain and thermal throttling.
