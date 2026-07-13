package com.rana.app.rana

object GlShaderConstants {
    val VERTEX_SHADER = """
        uniform mat4 uTexMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTextureCoord;
        varying vec2 vOutputCoord;
        void main() {
            gl_Position = aPosition;
            vOutputCoord = aTextureCoord.xy;
            vTextureCoord = (uTexMatrix * aTextureCoord).xy;
        }
    """.trimIndent()

    private val PRECISION_BLOCK = """
        #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
        #else
        precision mediump float;
        #endif
    """.trimIndent()

    private val LUT_HELPERS = """
        varying vec2 vTextureCoord;
        uniform sampler2D uLutTexture;
        uniform float uLutStrength;
        uniform float uTemperature;
        uniform float uSaturation;
        uniform float uContrast;
        uniform mat3 uColorMatrix;
        uniform float uLensDistortionStrength;

        vec2 applyLensDistortion(vec2 uv) {
            if (uLensDistortionStrength <= 0.0) return uv;
            vec2 centered = uv - 0.5;
            float r2 = dot(centered, centered);
            float distort = 1.0 + uLensDistortionStrength * r2;
            return clamp(centered * distort + 0.5, 0.0, 1.0);
        }

        vec3 applyLut(vec3 color) {
            vec3 lutInput = clamp(color, 0.0, 1.0);
            float blueVal = lutInput.b * 15.0;

            float blueCellLower = floor(blueVal);
            float xOffsetLower = mod(blueCellLower, 8.0) / 8.0;
            float blueRowLower = floor(blueCellLower / 8.0);
            float lutYLower = 1.0 - (
                (blueRowLower * 8.0 + lutInput.g * 7.0 + 0.5) / 16.0
            );
            vec2 lutUVLower = vec2(
                xOffsetLower + (lutInput.r * 63.0 + 0.5) / 512.0,
                lutYLower
            );
            vec3 lutColorLower = texture2D(uLutTexture, lutUVLower).rgb;

            float blueCellUpper = min(blueCellLower + 1.0, 15.0);
            float xOffsetUpper = mod(blueCellUpper, 8.0) / 8.0;
            float blueRowUpper = floor(blueCellUpper / 8.0);
            float lutYUpper = 1.0 - (
                (blueRowUpper * 8.0 + lutInput.g * 7.0 + 0.5) / 16.0
            );
            vec2 lutUVUpper = vec2(
                xOffsetUpper + (lutInput.r * 63.0 + 0.5) / 512.0,
                lutYUpper
            );
            vec3 lutColorUpper = texture2D(uLutTexture, lutUVUpper).rgb;

            vec3 lutColor = mix(
                lutColorLower, lutColorUpper, fract(blueVal)
            );
            return mix(color, lutColor, uLutStrength);
        }

        vec3 applyColorGrade(vec3 inputColor) {
            vec3 color = inputColor;

            if (uLutStrength > 0.0) {
                color = applyLut(color);
            }

            if (uTemperature > 0.0) {
                color.r += uTemperature * 0.15;
                color.g += uTemperature * 0.07;
                color.b -= uTemperature * 0.05;
            } else if (uTemperature < 0.0) {
                color.r += uTemperature * 0.05;
                color.g += uTemperature * 0.05;
                color.b -= uTemperature * 0.15;
            }

            color = uColorMatrix * color;

            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            color = mix(vec3(luma), color, 1.0 + uSaturation);
            color = (color - 0.5) * (1.0 + uContrast) + 0.5;

            return color;
        }

        uniform float uSoftness;
    """.trimIndent()

    private val STYLE_HELPERS = """
        uniform float uTone;
        uniform float uColor;
        uniform float uTextureVal;
        uniform float uStyleStrength;
        uniform float uUndertoneX;
        uniform float uUndertoneY;

        float skinToneProtection(vec3 inputColor) {
            vec3 color = clamp(inputColor, 0.0, 1.0);
            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            float cb = -0.168736 * color.r - 0.331264 * color.g + 0.5 * color.b + 0.5;
            float cr = 0.5 * color.r - 0.418688 * color.g - 0.081312 * color.b + 0.5;
            float maxChannel = max(max(color.r, color.g), color.b);
            float minChannel = min(min(color.r, color.g), color.b);
            float chroma = maxChannel - minChannel;

            float cbMask = smoothstep(0.24, 0.30, cb) * (1.0 - smoothstep(0.50, 0.56, cb));
            float crMask = smoothstep(0.48, 0.54, cr) * (1.0 - smoothstep(0.72, 0.78, cr));
            float lumaMask = smoothstep(0.08, 0.20, luma) * (1.0 - smoothstep(0.90, 0.98, luma));
            float chromaMask = smoothstep(0.03, 0.08, chroma) * (1.0 - smoothstep(0.55, 0.72, chroma));
            return clamp(cbMask * crMask * lumaMask * chromaMask, 0.0, 1.0);
        }

        vec3 applyRanaStyles(vec3 inputColor) {
            vec3 color = inputColor;
            float styleBlend = clamp(uStyleStrength / 100.0, 0.0, 1.0);
            float skinProtect = skinToneProtection(inputColor);
            float chromaStyleScale = mix(1.0, 0.35, skinProtect);
            
            // 1. Tone curve (Luminance power curve)
            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            float toneAmount = clamp(uTone, -100.0, 100.0);
            float newLuma = clamp(pow(max(luma, 0.0), pow(2.0, toneAmount / 100.0)), 0.0, 1.0);
            if (luma > 0.0001) {
                color = color * (newLuma / luma);
            } else {
                color = vec3(0.0);
            }
            
            // 2. Color / Saturation
            float postLuma = dot(color, vec3(0.299, 0.587, 0.114));
            float colorAmount = clamp(uColor, -100.0, 100.0);
            color = mix(vec3(postLuma), color, 1.0 + colorAmount * chromaStyleScale / 100.0);
            
            // 3. Undertone Grid (Color Balance Matrix)
            float alpha = -0.15 * uUndertoneX * chromaStyleScale;
            float beta = 0.12 * uUndertoneY * chromaStyleScale;
            color.r = color.r * (1.0 + alpha + beta);
            color.g = color.g * (1.0 - beta);
            color.b = color.b * (1.0 - alpha + beta);
            
            // 4. Blend Style Strength
            color = mix(inputColor, color, styleBlend);

            // Keep the texture uniform active in color-pass programs even
            // when texture is mapped to grain/dust in the final effects pass.
            color += vec3(uTextureVal * 0.0);
            return color;
        }
    """.trimIndent()

    private val FINAL_EFFECT_HELPERS = """
        varying vec2 vOutputCoord;
        uniform sampler2D uLightLeakTexture;
        uniform float uLightLeakIntensity;
        uniform sampler2D uDustTexture;
        uniform float uDustIntensity;
        uniform float uDustUVOffsetX;
        uniform float uDustUVOffsetY;
        uniform float uGrain;
        uniform float uVignette;
        uniform vec3 uVignetteColor;
        uniform float uVignetteRoundness;
        uniform float uTime;
        uniform float uGrainSize;
        uniform float uGrainShadowsLimit;
        uniform float uGrainHighlightsLimit;
        uniform float uFilmBorderStyle;
        uniform float uOutputAspectRatio;
        uniform float uOutputYFlip;

        const float GRAIN_SHADOW_TRANSITION = 0.18;
        const float GRAIN_HIGHLIGHT_TRANSITION = 0.15;

        float rand(vec2 co) {
            return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
        }

        vec3 applyLightLeak(vec3 baseColor, vec2 uv) {
            if (uLightLeakIntensity <= 0.0) return baseColor;
            vec3 leakColor = texture2D(uLightLeakTexture, uv).rgb;
            return baseColor + leakColor * uLightLeakIntensity -
                baseColor * leakColor * uLightLeakIntensity;
        }

        vec3 applyDust(vec3 baseColor, vec2 uv) {
            if (uDustIntensity <= 0.0) return baseColor;
            vec2 dustUV = fract(uv + vec2(uDustUVOffsetX, uDustUVOffsetY));
            float dustAlpha = texture2D(uDustTexture, dustUV).r;
            return baseColor * (1.0 - dustAlpha * uDustIntensity * 0.35);
        }

        float grainLuminanceMask(vec3 color) {
            float luma = dot(
                clamp(color, 0.0, 1.0),
                vec3(0.299, 0.587, 0.114)
            );
            float shadowCutoff = clamp(uGrainShadowsLimit, 0.0, 0.5);
            float shadowFull = shadowCutoff + GRAIN_SHADOW_TRANSITION;
            float highlightCutoff = 1.0 - clamp(
                uGrainHighlightsLimit,
                0.0,
                0.3
            );
            float highlightFull =
                highlightCutoff - GRAIN_HIGHLIGHT_TRANSITION;
            float shadowRamp = smoothstep(
                shadowCutoff,
                shadowFull,
                luma
            );
            float highlightRamp = 1.0 - smoothstep(
                highlightFull,
                highlightCutoff,
                luma
            );
            return shadowRamp * highlightRamp;
        }

        vec3 applyFilmGrain(vec3 color) {
            if (uGrain <= 0.0) return color;
            vec2 grainUv = vTextureCoord / max(uGrainSize, 0.1);
            float noise = rand(
                grainUv + vec2(uTime * 0.1, uTime * 0.07)
            ) - 0.5;
            float noise2 = rand(
                grainUv * 1.5 + vec2(uTime * 0.13)
            ) - 0.5;
            float filmGrain = mix(noise, noise2, 0.4);
            float luminanceMask = grainLuminanceMask(color);
            return color + vec3(
                filmGrain * uGrain * luminanceMask * 0.25
            );
        }

        vec3 applyVignette(vec3 color) {
            if (uVignette <= 0.0) return color;
            float roundness = clamp(uVignetteRoundness, 0.0, 1.0);
            vec2 legacyUv = vTextureCoord - 0.5;
            vec2 outputUv = vOutputCoord - 0.5;
            float aspectRatio = max(uOutputAspectRatio, 0.0001);
            vec2 circleScale = aspectRatio >= 1.0
                ? vec2(aspectRatio, 1.0)
                : vec2(1.0, 1.0 / aspectRatio);
            vec2 uv = mix(legacyUv, outputUv * circleScale, roundness);
            float dist = length(uv);
            float innerEdge = 0.8 - uVignette * 0.6;
            float vignette = 1.0 - smoothstep(innerEdge, 0.8, dist);
            if (dot(uVignetteColor, uVignetteColor) <= 0.0) {
                return color * vignette;
            }
            return mix(uVignetteColor, color, vignette);
        }

        float roundedBoxMask(
            vec2 point,
            vec2 center,
            vec2 halfSize,
            float radius
        ) {
            vec2 distanceToEdge = abs(point - center) -
                halfSize + vec2(radius);
            float signedDistance = length(max(distanceToEdge, 0.0)) +
                min(max(distanceToEdge.x, distanceToEdge.y), 0.0) -
                radius;
            return 1.0 - smoothstep(-0.003, 0.003, signedDistance);
        }

        float drawStroke(vec2 p, vec2 a, vec2 b, float w) {
            vec2 pa = p - a, ba = b - a;
            float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
            float d = length(pa - ba * h);
            return 1.0 - smoothstep(w - 0.015, w + 0.015, d);
        }

        float drawVectorChar(float charId, vec2 p, float w) {
            if (charId < 0.5) return 0.0;
            
            vec2 tl = vec2(0.18, 0.1);
            vec2 tm = vec2(0.5, 0.1);
            vec2 tr = vec2(0.82, 0.1);
            vec2 cl = vec2(0.18, 0.5);
            vec2 cr = vec2(0.82, 0.5);
            vec2 bl = vec2(0.18, 0.9);
            vec2 bm = vec2(0.5, 0.9);
            vec2 br = vec2(0.82, 0.9);
            
            // Triangle '▶'
            if (charId > 13.5) {
                if (p.x < 0.2 || p.x > 0.8 || p.y < 0.2 || p.y > 0.8) return 0.0;
                float halfH = (p.x - 0.2) / 0.6 * 0.3;
                if (p.y >= 0.5 - halfH && p.y <= 0.5 + halfH) return 1.0;
                return 0.0;
            }
            
            float s = 0.0;
            
            // '0' or 'O'
            if (charId < 1.5 || (charId > 9.5 && charId < 10.5)) {
                s = drawStroke(p, tl, tr, w);
                s = max(s, drawStroke(p, bl, br, w));
                s = max(s, drawStroke(p, tl, bl, w));
                s = max(s, drawStroke(p, tr, br, w));
            }
            // '1'
            else if (charId < 2.5) {
                s = drawStroke(p, tm, bm, w);
                s = max(s, drawStroke(p, tm, vec2(0.35, 0.2), w));
                s = max(s, drawStroke(p, vec2(0.3, 0.9), vec2(0.7, 0.9), w));
            }
            // '2'
            else if (charId < 3.5) {
                s = drawStroke(p, tl, tr, w);
                s = max(s, drawStroke(p, tr, cr, w));
                s = max(s, drawStroke(p, cr, bl, w));
                s = max(s, drawStroke(p, bl, br, w));
            }
            // '3'
            else if (charId < 4.5) {
                s = drawStroke(p, tl, tr, w);
                s = max(s, drawStroke(p, tr, cr, w));
                s = max(s, drawStroke(p, cl, cr, w));
                s = max(s, drawStroke(p, cr, br, w));
                s = max(s, drawStroke(p, bl, br, w));
            }
            // '4'
            else if (charId < 5.5) {
                s = drawStroke(p, vec2(0.75, 0.1), vec2(0.75, 0.9), w);
                s = max(s, drawStroke(p, vec2(0.15, 0.55), vec2(0.85, 0.55), w));
                s = max(s, drawStroke(p, vec2(0.75, 0.1), vec2(0.15, 0.55), w));
            }
            // '5'
            else if (charId < 6.5) {
                s = drawStroke(p, tl, tr, w);
                s = max(s, drawStroke(p, tl, cl, w));
                s = max(s, drawStroke(p, cl, cr, w));
                s = max(s, drawStroke(p, cr, br, w));
                s = max(s, drawStroke(p, br, bl, w));
            }
            // 'A'
            else if (charId < 7.5) {
                s = drawStroke(p, bl, tm, w);
                s = max(s, drawStroke(p, br, tm, w));
                s = max(s, drawStroke(p, cl, cr, w));
            }
            // 'D'
            else if (charId < 8.5) {
                s = drawStroke(p, tl, bl, w);
                s = max(s, drawStroke(p, tl, vec2(0.7, 0.1), w));
                s = max(s, drawStroke(p, bl, vec2(0.7, 0.9), w));
                s = max(s, drawStroke(p, vec2(0.7, 0.1), vec2(0.82, 0.3), w));
                s = max(s, drawStroke(p, vec2(0.82, 0.3), vec2(0.82, 0.7), w));
                s = max(s, drawStroke(p, vec2(0.82, 0.7), vec2(0.7, 0.9), w));
            }
            // 'K'
            else if (charId < 9.5) {
                s = drawStroke(p, tl, bl, w);
                s = max(s, drawStroke(p, cl, tr, w));
                s = max(s, drawStroke(p, cl, br, w));
            }
            // 'P'
            else if (charId < 11.5) {
                s = drawStroke(p, tl, bl, w);
                s = max(s, drawStroke(p, tl, tr, w));
                s = max(s, drawStroke(p, cl, cr, w));
                s = max(s, drawStroke(p, tr, cr, w));
            }
            // 'R'
            else if (charId < 12.5) {
                s = drawStroke(p, tl, bl, w);
                s = max(s, drawStroke(p, tl, tr, w));
                s = max(s, drawStroke(p, cl, cr, w));
                s = max(s, drawStroke(p, tr, cr, w));
                s = max(s, drawStroke(p, cl, br, w));
            }
            // 'T'
            else if (charId < 13.5) {
                s = drawStroke(p, tl, tr, w);
                s = max(s, drawStroke(p, tm, bm, w));
            }
            
            return s;
        }

        float getArtropChar(float idx) {
            if (idx < 0.5) return 1.0;  // '0'
            if (idx < 1.5) return 1.0;  // '0'
            if (idx < 2.5) return 5.0;  // '4'
            if (idx < 3.5) return 0.0;  // ' '
            if (idx < 4.5) return 7.0;  // 'A'
            if (idx < 5.5) return 12.0; // 'R'
            if (idx < 6.5) return 13.0; // 'T'
            if (idx < 7.5) return 12.0; // 'R'
            if (idx < 8.5) return 10.0; // 'O'
            if (idx < 9.5) return 11.0; // 'P'
            if (idx < 10.5) return 0.0; // ' '
            if (idx < 11.5) return 9.0;  // 'K'
            if (idx < 12.5) return 7.0;  // 'A'
            if (idx < 13.5) return 8.0;  // 'D'
            if (idx < 14.5) return 10.0; // 'O'
            if (idx < 15.5) return 9.0;  // 'K'
            return 0.0;
        }

        float drawArtropText(vec2 uv, float w) {
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
            float numChars = 16.0;
            float charIdx = floor(uv.x * numChars);
            float localX = fract(uv.x * numChars);
            float charWidth = 0.75;
            float charUvX = localX / charWidth;
            if (charUvX > 1.0) return 0.0;
            
            float charCode = getArtropChar(charIdx);
            return drawVectorChar(charCode, vec2(charUvX, uv.y), w);
        }

        float draw34Text(vec2 uv, float w) {
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
            float numChars = 2.0;
            float charIdx = floor(uv.x * numChars);
            float localX = fract(uv.x * numChars);
            float charWidth = 0.75;
            float charUvX = localX / charWidth;
            if (charUvX > 1.0) return 0.0;
            
            float charCode = 0.0;
            if (charIdx < 0.5) charCode = 4.0; // '3'
            else if (charIdx < 1.5) charCode = 5.0; // '4'
            
            return drawVectorChar(charCode, vec2(charUvX, uv.y), w);
        }

        float draw155Text(vec2 uv, float w) {
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
            float numChars = 5.0;
            float charIdx = floor(uv.x * numChars);
            float localX = fract(uv.x * numChars);
            float charWidth = 0.75;
            float charUvX = localX / charWidth;
            if (charUvX > 1.0) return 0.0;
            
            float charCode = 0.0;
            if (charIdx < 0.5) charCode = 2.0; // '1'
            else if (charIdx < 1.5) charCode = 6.0; // '5'
            else if (charIdx < 2.5) charCode = 0.0; // ' '
            else if (charIdx < 3.5) charCode = 0.0; // ' '
            else if (charIdx < 4.5) charCode = 6.0; // '5'
            
            return drawVectorChar(charCode, vec2(charUvX, uv.y), w);
        }

        float drawArrow4Text(vec2 uv, float w) {
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
            float numChars = 3.0;
            float charIdx = floor(uv.x * numChars);
            float localX = fract(uv.x * numChars);
            float charWidth = 0.75;
            float charUvX = localX / charWidth;
            if (charUvX > 1.0) return 0.0;
            
            float charCode = 0.0;
            if (charIdx < 0.5) charCode = 14.0; // ▶
            else if (charIdx < 1.5) charCode = 0.0; // ' '
            else if (charIdx < 2.5) charCode = 5.0;  // '4'
            
            return drawVectorChar(charCode, vec2(charUvX, uv.y), w);
        }

        vec3 applyFilmBorder(vec3 color) {
            if (uFilmBorderStyle < 0.5) return color;

            vec2 outputUv = vec2(
                vOutputCoord.x,
                mix(vOutputCoord.y, 1.0 - vOutputCoord.y, uOutputYFlip)
            );

            if (uFilmBorderStyle < 1.5) {
                // Instax mini proportions: 86x54 mm media, 62x46 mm image.
                float leftPaper = 1.0 - smoothstep(0.071, 0.077, outputUv.x);
                float rightPaper = smoothstep(0.923, 0.929, outputUv.x);
                float topPaper = 1.0 - smoothstep(0.044, 0.050, outputUv.y);
                float bottomPaper = smoothstep(0.765, 0.771, outputUv.y);
                float paperMask = max(
                    max(leftPaper, rightPaper),
                    max(topPaper, bottomPaper)
                );

                // Organic paper texture
                float noise1 = rand(outputUv * 1500.0) * 0.6;
                float noise2 = rand(outputUv * 750.0) * 0.4;
                float paperNoise = (noise1 + noise2 - 0.5) * 0.012;
                vec3 paperColor = vec3(0.965, 0.950, 0.905) + vec3(paperNoise);

                // Inner bevel shadow on the photo
                float distToLeft = outputUv.x - 0.077;
                float distToRight = 0.923 - outputUv.x;
                float distToTop = outputUv.y - 0.050;
                float distToBottom = 0.765 - outputUv.y;
                float distToEdge = min(min(distToLeft, distToRight), min(distToTop, distToBottom));
                
                float shadowFactor = 1.0 - smoothstep(0.0, 0.014, max(distToEdge, 0.0));
                vec3 finalColor = mix(color, color * 0.55, shadowFactor * 0.7);

                return mix(finalColor, paperColor, paperMask);
            }

            if (uFilmBorderStyle < 2.5) {
                // Keep sprockets on the long edges after device rotation.
                vec2 filmUv = uOutputAspectRatio >= 1.0
                    ? outputUv
                    : outputUv.yx;
                float edgeDistance = min(filmUv.y, 1.0 - filmUv.y);
                float filmMask = 1.0 - smoothstep(0.135, 0.145, edgeDistance);
                vec2 perforationUv = vec2(fract(filmUv.x * 8.0), filmUv.y);
                float topHole = roundedBoxMask(
                    perforationUv,
                    vec2(0.5, 0.067),
                    vec2(0.27, 0.035),
                    0.012
                );
                float bottomHole = roundedBoxMask(
                    perforationUv,
                    vec2(0.5, 0.933),
                    vec2(0.27, 0.035),
                    0.012
                );
                float perforationMask = max(topHole, bottomHole) * filmMask;
                vec3 framed = mix(color, vec3(0.012, 0.011, 0.010), filmMask);
                return mix(
                    framed,
                    vec3(0.900, 0.850, 0.700),
                    perforationMask
                );
            }

            if (uFilmBorderStyle < 3.5) {
                // Kodak Portra 120 film border: Left/Right = 0.085, Top/Bottom = 0.05
                float leftBorder = 1.0 - smoothstep(0.080, 0.085, outputUv.x);
                float rightBorder = smoothstep(0.915, 0.920, outputUv.x);
                float topBorder = 1.0 - smoothstep(0.045, 0.050, outputUv.y);
                float bottomBorder = smoothstep(0.950, 0.955, outputUv.y);
                float borderMask = max(max(leftBorder, rightBorder), max(topBorder, bottomBorder));

                // Draw text elements
                float textMask = 0.0;
                float strokeW = 0.07;
                
                // Box 1: 004 ARTROP KADOK (top-left)
                vec2 box1Uv = vec2((0.42 - outputUv.y) / 0.30, (0.052 - outputUv.x) / 0.024);
                textMask = max(textMask, drawArtropText(box1Uv, strokeW));

                // Box 2: 004 ARTROP KADOK (bottom-left)
                vec2 box2Uv = vec2((0.88 - outputUv.y) / 0.30, (0.052 - outputUv.x) / 0.024);
                textMask = max(textMask, drawArtropText(box2Uv, strokeW));

                // Box 3: 34 (middle-left)
                vec2 box3Uv = vec2((0.52 - outputUv.y) / 0.04, (0.052 - outputUv.x) / 0.024);
                textMask = max(textMask, draw34Text(box3Uv, strokeW));

                // Box 4: 15 5 (bottom-left corner)
                vec2 box4Uv = vec2((outputUv.x - 0.02) / 0.05, (outputUv.y - 0.962) / 0.02);
                textMask = max(textMask, draw155Text(box4Uv, strokeW));

                // Box 5: ▶ 4 (middle-right)
                vec2 box5Uv = vec2((outputUv.y - 0.48) / 0.04, (outputUv.x - 0.948) / 0.024);
                textMask = max(textMask, drawArrow4Text(box5Uv, strokeW));

                // Box 6: ▶ (top-right)
                vec2 box6Uv = vec2((outputUv.y - 0.04) / 0.02, (outputUv.x - 0.948) / 0.024);
                textMask = max(textMask, drawVectorChar(14.0, box6Uv, strokeW));

                // Inner bevel shadow on the photo
                float distToLeft = outputUv.x - 0.085;
                float distToRight = 0.915 - outputUv.x;
                float distToTop = outputUv.y - 0.050;
                float distToBottom = 0.950 - outputUv.y;
                float distToEdge = min(min(distToLeft, distToRight), min(distToTop, distToBottom));
                
                float shadowFactor = 1.0 - smoothstep(0.0, 0.012, max(distToEdge, 0.0));
                vec3 finalColor = mix(color, color * 0.50, shadowFactor * 0.75);

                vec3 blackFrame = vec3(0.012, 0.011, 0.010);
                vec3 textColor = vec3(0.92, 0.60, 0.12);
                vec3 borderCol = mix(blackFrame, textColor, textMask * 0.85);

                return mix(finalColor, borderCol, borderMask);
            }
            return color;
        }
    """.trimIndent()

    private val ANALOG_COLOR_HELPERS = """
        uniform float uChromaticAberrationIntensity;
        uniform float uFade;
        uniform float uHighlightRollOff;
        uniform float uShadowRollOff;
        uniform vec3 uShadowsTint;
        uniform vec3 uHighlightsTint;

        const float HIGHLIGHT_ROLL_OFF_START = 0.65;
        const float SHADOW_ROLL_OFF_END = 0.35;

        vec2 chromaticAberrationOffset(vec2 uv) {
            vec2 dir = uv - vec2(0.5);
            float dist = length(dir);
            return dir * dist * uChromaticAberrationIntensity * 0.015;
        }

        vec3 applyFade(vec3 color) {
            float fadeAmount = clamp(uFade, 0.0, 1.0) * 0.1;
            return vec3(fadeAmount) + color * (1.0 - fadeAmount);
        }

        vec3 applySplitToning(vec3 color) {
            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            vec3 shadowColor = color +
                uShadowsTint * (1.0 - luma) * 0.15;
            vec3 highlightColor = color +
                uHighlightsTint * luma * 0.15;
            return mix(shadowColor, highlightColor, luma);
        }

        float applyRollOffToLuma(float luma) {
            float rolled = luma;

            if (luma > HIGHLIGHT_ROLL_OFF_START) {
                float shoulder = HIGHLIGHT_ROLL_OFF_START +
                    (1.0 - HIGHLIGHT_ROLL_OFF_START) *
                    (1.0 - exp(
                        -(luma - HIGHLIGHT_ROLL_OFF_START) /
                        (1.0 - HIGHLIGHT_ROLL_OFF_START)
                    ));
                rolled = mix(
                    rolled,
                    shoulder,
                    clamp(uHighlightRollOff, 0.0, 1.0)
                );
            }

            if (luma < SHADOW_ROLL_OFF_END) {
                float normalized = luma / SHADOW_ROLL_OFF_END;
                float toe = SHADOW_ROLL_OFF_END * normalized * normalized *
                    (2.0 - normalized);
                rolled = mix(
                    rolled,
                    toe,
                    clamp(uShadowRollOff, 0.0, 1.0)
                );
            }

            return rolled;
        }

        vec3 applyToneRollOff(vec3 color) {
            float highlightStrength = clamp(uHighlightRollOff, 0.0, 1.0);
            float shadowStrength = clamp(uShadowRollOff, 0.0, 1.0);
            if (highlightStrength <= 0.0 && shadowStrength <= 0.0) {
                return color;
            }

            vec3 positiveColor = max(color, vec3(0.0));
            float luma = dot(positiveColor, vec3(0.299, 0.587, 0.114));
            if (luma <= 0.0001) {
                return positiveColor;
            }

            float rolledLuma = applyRollOffToLuma(luma);
            vec3 rolledColor = positiveColor * (rolledLuma / luma);

            float maxChannel = max(
                max(rolledColor.r, rolledColor.g),
                rolledColor.b
            );
            if (maxChannel > 1.0 && highlightStrength > 0.0) {
                vec3 whiteLimited = rolledColor / maxChannel;
                rolledColor = mix(
                    rolledColor,
                    whiteLimited,
                    highlightStrength
                );
            }

            return rolledColor;
        }
    """.trimIndent()

    private val SINGLE_PASS_BODY = """
        uniform sampler2D uBloomTexture;
        uniform float uBloomIntensity;
        uniform float uHalationIntensity;

        $LUT_HELPERS
        $STYLE_HELPERS
        $FINAL_EFFECT_HELPERS
        $ANALOG_COLOR_HELPERS

        vec4 sampleSoftSource(vec2 uv) {
            if (uSoftness <= 0.0) {
                return texture2D(sTexture, uv);
            }
            float offset = 0.005 * uSoftness;
            return (
                texture2D(sTexture, uv) +
                texture2D(sTexture, uv + vec2(offset, 0.0)) +
                texture2D(sTexture, uv + vec2(-offset, 0.0)) +
                texture2D(sTexture, uv + vec2(0.0, offset)) +
                texture2D(sTexture, uv + vec2(0.0, -offset))
            ) / 5.0;
        }

        void main() {
            vec2 sourceUv = applyLensDistortion(vTextureCoord);
            vec4 texColor = sampleSoftSource(sourceUv);
            vec3 color = applyColorGrade(texColor.rgb);
            if (uChromaticAberrationIntensity > 0.0) {
                vec2 channelOffset = chromaticAberrationOffset(sourceUv);
                vec3 redSample = applyColorGrade(
                    sampleSoftSource(clamp(sourceUv - channelOffset, 0.0, 1.0)).rgb
                );
                vec3 blueSample = applyColorGrade(
                    sampleSoftSource(clamp(sourceUv + channelOffset, 0.0, 1.0)).rgb
                );
                color.r = redSample.r;
                color.b = blueSample.b;
            }
            color = applyRanaStyles(color);
            color = applyFade(color);
            color = applySplitToning(color);

            if (uBloomIntensity > 0.0) {
                vec3 bloomColor = texture2D(uBloomTexture, vTextureCoord).rgb;
                if (uHalationIntensity > 0.0) {
                    bloomColor *= mix(
                        vec3(1.0),
                        vec3(1.0, 0.35, 0.15),
                        clamp(uHalationIntensity, 0.0, 1.0)
                    );
                }
                color += bloomColor * uBloomIntensity;
            }

            color = applyLightLeak(color, vTextureCoord);
            color = applyDust(color, vTextureCoord);
            color = applyFilmGrain(color);
            color = applyVignette(color);
            color = applyToneRollOff(color);
            color = applyFilmBorder(color);

            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    private val BASE_COLOR_BODY = """
        $LUT_HELPERS

        void main() {
            vec2 sourceUv = applyLensDistortion(vTextureCoord);
            vec4 texColor;
            if (uSoftness > 0.0) {
                float offset = 0.005 * uSoftness;
                texColor = (
                    texture2D(sTexture, sourceUv) +
                    texture2D(sTexture, sourceUv + vec2(offset, 0.0)) +
                    texture2D(sTexture, sourceUv + vec2(-offset, 0.0)) +
                    texture2D(sTexture, sourceUv + vec2(0.0, offset)) +
                    texture2D(sTexture, sourceUv + vec2(0.0, -offset))
                ) / 5.0;
            } else {
                texColor = texture2D(sTexture, sourceUv);
            }
            vec3 color = applyColorGrade(texColor.rgb);
            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    private val BRIGHT_PASS_BODY = """
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        uniform float uBloomThreshold;

        void main() {
            vec3 color = texture2D(sTexture, vTextureCoord).rgb;
            float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
            if (luma <= uBloomThreshold) {
                gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }

            vec3 brightResult = max(color.rgb - vec3(uBloomThreshold), 0.0) /
                max(1.0 - uBloomThreshold, 0.0001);
            gl_FragColor = vec4(brightResult, 1.0);
        }
    """.trimIndent()

    private val GAUSSIAN_BLUR_BODY = """
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        uniform vec2 uTexelOffset;

        void main() {
            vec3 result = texture2D(sTexture, vTextureCoord).rgb * 0.227027;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 1.384615
            ).rgb * 0.316216;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 1.384615
            ).rgb * 0.316216;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 3.230769
            ).rgb * 0.070270;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 3.230769
            ).rgb * 0.070270;
            gl_FragColor = vec4(result, 1.0);
        }
    """.trimIndent()

    private val BLOOM_COMPOSITE_BODY = """
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        uniform sampler2D uBloomTexture;
        uniform sampler2D uHalationTexture;
        uniform float uBloomIntensity;
        uniform float uHalationIntensity;
        uniform vec3 uHalationColor;

        $STYLE_HELPERS
        $FINAL_EFFECT_HELPERS
        $ANALOG_COLOR_HELPERS

        void main() {
            vec4 baseColor = texture2D(sTexture, vTextureCoord);
            vec3 color = baseColor.rgb;
            if (uChromaticAberrationIntensity > 0.0) {
                vec2 channelOffset = chromaticAberrationOffset(vTextureCoord);
                color.r = texture2D(
                    sTexture,
                    clamp(vTextureCoord - channelOffset, 0.0, 1.0)
                ).r;
                color.b = texture2D(
                    sTexture,
                    clamp(vTextureCoord + channelOffset, 0.0, 1.0)
                ).b;
            }
            color = applyRanaStyles(color);
            color = applyFade(color);
            color = applySplitToning(color);

            if (uBloomIntensity > 0.0) {
                vec3 bloomColor = texture2D(uBloomTexture, vTextureCoord).rgb;
                color += bloomColor * uBloomIntensity;
            }
            if (uHalationIntensity > 0.0) {
                vec3 reflectedLight = texture2D(
                    uHalationTexture,
                    vTextureCoord
                ).rgb;
                vec3 halationTint = mix(
                    vec3(1.0),
                    uHalationColor,
                    clamp(uHalationIntensity, 0.0, 1.0)
                );
                color += reflectedLight * (halationTint - vec3(1.0)) *
                    uBloomIntensity;
            }

            color = applyLightLeak(color, vTextureCoord);
            color = applyDust(color, vTextureCoord);
            color = applyFilmGrain(color);
            color = applyVignette(color);
            color = applyToneRollOff(color);
            color = applyFilmBorder(color);

            gl_FragColor = vec4(clamp(color, 0.0, 1.0), baseColor.a);
        }
    """.trimIndent()

    val FRAGMENT_SHADER_PREVIEW = """
        #extension GL_OES_EGL_image_external : require
        $PRECISION_BLOCK
        uniform samplerExternalOES sTexture;
        $SINGLE_PASS_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_EXPORT = """
        $PRECISION_BLOCK
        uniform sampler2D sTexture;
        $SINGLE_PASS_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_BASE_COLOR_PREVIEW = """
        #extension GL_OES_EGL_image_external : require
        $PRECISION_BLOCK
        uniform samplerExternalOES sTexture;
        $LUT_HELPERS
        $STYLE_HELPERS

        void main() {
            vec2 sourceUv = applyLensDistortion(vTextureCoord);
            vec4 texColor;
            if (uSoftness > 0.0) {
                float offset = 0.005 * uSoftness;
                texColor = (
                    texture2D(sTexture, sourceUv) +
                    texture2D(sTexture, sourceUv + vec2(offset, 0.0)) +
                    texture2D(sTexture, sourceUv + vec2(-offset, 0.0)) +
                    texture2D(sTexture, sourceUv + vec2(0.0, offset)) +
                    texture2D(sTexture, sourceUv + vec2(0.0, -offset))
                ) / 5.0;
            } else {
                texColor = texture2D(sTexture, sourceUv);
            }
            vec3 color = applyColorGrade(texColor.rgb);
            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    val FRAGMENT_SHADER_BASE_COLOR_EXPORT = """
        $PRECISION_BLOCK
        uniform sampler2D sTexture;
        $BASE_COLOR_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_BRIGHT_PASS = """
        $PRECISION_BLOCK
        $BRIGHT_PASS_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_GAUSSIAN_BLUR = """
        $PRECISION_BLOCK
        $GAUSSIAN_BLUR_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_BLOOM_COMPOSITE = """
        $PRECISION_BLOCK
        $BLOOM_COMPOSITE_BODY
    """.trimIndent()
}
