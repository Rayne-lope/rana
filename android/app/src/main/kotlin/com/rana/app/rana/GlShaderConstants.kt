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

    private val FRAGMENT_SHADER_BODY = """
        varying vec2 vTextureCoord;
        uniform sampler2D uLutTexture;
        uniform float uLutStrength;
        uniform float uTemperature;
        uniform float uSaturation;
        uniform float uContrast;
        uniform float uGrain;
        uniform float uVignette;
        uniform float uTime;
        uniform sampler2D uLightLeakTexture;
        uniform float uLightLeakIntensity;
        uniform sampler2D uDustTexture;
        uniform float uDustIntensity;
        uniform float uDustUVOffsetX;
        uniform float uDustUVOffsetY;

        float rand(vec2 co) {
            return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
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

        vec3 applyLightLeak(vec3 baseColor, vec2 uv) {
            if (uLightLeakIntensity <= 0.0) return baseColor;
            vec3 leakColor = texture2D(uLightLeakTexture, uv).rgb;
            return baseColor + leakColor * uLightLeakIntensity - baseColor * leakColor * uLightLeakIntensity;
        }

        vec3 applyDust(vec3 baseColor, vec2 uv) {
            if (uDustIntensity <= 0.0) return baseColor;
            vec2 dustUV = fract(uv + vec2(uDustUVOffsetX, uDustUVOffsetY));
            float dustAlpha = texture2D(uDustTexture, dustUV).r;
            return baseColor * (1.0 - dustAlpha * uDustIntensity * 0.35);
        }

        void main() {
            vec4 texColor = texture2D(sTexture, vTextureCoord);
            vec3 color = texColor.rgb;

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

            color = applyLightLeak(color, vTextureCoord);

            color = applyDust(color, vTextureCoord);

            if (uGrain > 0.0) {
                float noise = rand(vTextureCoord + vec2(uTime * 0.1, uTime * 0.07)) - 0.5;
                float noise2 = rand(vTextureCoord * 1.5 + vec2(uTime * 0.13)) - 0.5;
                float filmGrain = mix(noise, noise2, 0.4);
                color += vec3(filmGrain * uGrain * 0.25);
            }

            if (uVignette > 0.0) {
                vec2 uv = vTextureCoord - 0.5;
                float dist = length(uv);
                float vignette = smoothstep(0.8, 0.8 - uVignette * 0.6, dist);
                color *= vignette;
            }

            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    val FRAGMENT_SHADER_PREVIEW = """
        #extension GL_OES_EGL_image_external : require
        #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
        #else
        precision mediump float;
        #endif
        uniform samplerExternalOES sTexture;
        $FRAGMENT_SHADER_BODY
    """.trimIndent()

    val FRAGMENT_SHADER_EXPORT = """
        #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
        #else
        precision mediump float;
        #endif
        uniform sampler2D sTexture;
        $FRAGMENT_SHADER_BODY
    """.trimIndent()
}
