package com.rana.app.rana

object GlShaderConstants {
    val VERTEX_SHADER = """
        uniform mat4 uTexMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTextureCoord;
        void main() {
            gl_Position = aPosition;
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

            if (uTemperature > 0.0) {
                color.r += uTemperature * 0.15;
                color.g += uTemperature * 0.07;
                color.b -= uTemperature * 0.05;
            } else if (uTemperature < 0.0) {
                color.r += uTemperature * 0.05;
                color.g += uTemperature * 0.05;
                color.b -= uTemperature * 0.15;
            }

            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            color = mix(vec3(luma), color, 1.0 + uSaturation);
            color = (color - 0.5) * (1.0 + uContrast) + 0.5;

            if (uLutStrength > 0.0) {
                color = applyLut(color);
            }

            return color;
        }
    """.trimIndent()

    private val FINAL_EFFECT_HELPERS = """
        uniform sampler2D uLightLeakTexture;
        uniform float uLightLeakIntensity;
        uniform sampler2D uDustTexture;
        uniform float uDustIntensity;
        uniform float uDustUVOffsetX;
        uniform float uDustUVOffsetY;
        uniform float uGrain;
        uniform float uVignette;
        uniform float uTime;

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

        vec3 applyFilmGrain(vec3 color) {
            if (uGrain <= 0.0) return color;
            float noise = rand(
                vTextureCoord + vec2(uTime * 0.1, uTime * 0.07)
            ) - 0.5;
            float noise2 = rand(
                vTextureCoord * 1.5 + vec2(uTime * 0.13)
            ) - 0.5;
            float filmGrain = mix(noise, noise2, 0.4);
            return color + vec3(filmGrain * uGrain * 0.25);
        }

        vec3 applyVignette(vec3 color) {
            if (uVignette <= 0.0) return color;
            vec2 uv = vTextureCoord - 0.5;
            float dist = length(uv);
            float vignette = smoothstep(0.8, 0.8 - uVignette * 0.6, dist);
            return color * vignette;
        }
    """.trimIndent()

    private val SINGLE_PASS_BODY = """
        uniform sampler2D uBloomTexture;
        uniform float uBloomIntensity;
        uniform float uHalationIntensity;

        $LUT_HELPERS
        $FINAL_EFFECT_HELPERS

        void main() {
            vec4 texColor = texture2D(sTexture, vTextureCoord);
            vec3 color = applyColorGrade(texColor.rgb);

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

            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    private val BASE_COLOR_BODY = """
        $LUT_HELPERS

        void main() {
            vec4 texColor = texture2D(sTexture, vTextureCoord);
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
            vec3 result = texture2D(sTexture, vTextureCoord).rgb * 0.2270;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 1.0
            ).rgb * 0.1945;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 1.0
            ).rgb * 0.1945;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 2.0
            ).rgb * 0.1216;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 2.0
            ).rgb * 0.1216;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 3.0
            ).rgb * 0.0540;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 3.0
            ).rgb * 0.0540;
            result += texture2D(
                sTexture,
                vTextureCoord + uTexelOffset * 4.0
            ).rgb * 0.0162;
            result += texture2D(
                sTexture,
                vTextureCoord - uTexelOffset * 4.0
            ).rgb * 0.0162;
            gl_FragColor = vec4(result, 1.0);
        }
    """.trimIndent()

    private val BLOOM_COMPOSITE_BODY = """
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        uniform sampler2D uBloomTexture;
        uniform float uBloomIntensity;
        uniform float uHalationIntensity;

        $FINAL_EFFECT_HELPERS

        void main() {
            vec4 baseColor = texture2D(sTexture, vTextureCoord);
            vec3 color = baseColor.rgb;

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

        void main() {
            vec4 texColor = texture2D(sTexture, vTextureCoord);
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
