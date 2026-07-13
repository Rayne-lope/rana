package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GlShaderConstantsTest {
    @Test
    fun `preview shader warps uv before sampling source texture`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_PREVIEW

        assertTrue(shader.contains("vec2 applyLensDistortion(vec2 uv)"))
        assertOrder(
            shader,
            "vec2 sourceUv = applyLensDistortion(vTextureCoord);",
            "vec4 texColor = sampleSoftSource(sourceUv);"
        )
    }

    @Test
    fun `base export shader warps uv before sampling source texture`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT

        assertOrder(
            shader,
            "vec2 sourceUv = applyLensDistortion(vTextureCoord);",
            "texColor = texture2D(sTexture, sourceUv);"
        )
    }

    @Test
    fun `color grade applies lut temperature matrix saturation and contrast`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertTrue(shader.contains("uniform mat3 uColorMatrix;"))
        assertOrder(
            shader,
            "color = applyLut(color);",
            "if (uTemperature > 0.0)"
        )
        assertOrder(
            shader,
            "if (uTemperature > 0.0)",
            "color = uColorMatrix * color;"
        )
        assertOrder(
            shader,
            "color = uColorMatrix * color;",
            "float luma = dot(color, vec3(0.299, 0.587, 0.114));"
        )
        assertOrder(
            shader,
            "float luma = dot(color, vec3(0.299, 0.587, 0.114));",
            "color = (color - 0.5) * (1.0 + uContrast) + 0.5;"
        )
    }

    @Test
    fun `color matrix is shared by single and bloom base paths`() {
        val singlePass = GlShaderConstants.FRAGMENT_SHADER_EXPORT
        val previewBase = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_PREVIEW
        val exportBase = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT

        for (shader in listOf(singlePass, previewBase, exportBase)) {
            assertTrue(shader.contains("uniform mat3 uColorMatrix;"))
            assertTrue(shader.contains("color = uColorMatrix * color;"))
        }
    }

    @Test
    fun `single pass shader keeps final effects in analog stack order`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertTrue(shader.contains("uniform float uChromaticAberrationIntensity;"))
        assertTrue(shader.contains("uniform float uFade;"))
        assertTrue(shader.contains("uniform float uHighlightRollOff;"))
        assertTrue(shader.contains("uniform float uShadowRollOff;"))
        assertTrue(shader.contains("uniform vec3 uShadowsTint;"))
        assertTrue(shader.contains("uniform vec3 uHighlightsTint;"))
        assertTrue(shader.contains("uChromaticAberrationIntensity * 0.015"))
        assertOrder(shader, "color = applyRanaStyles(color);", "color = applyFade(color);")
        assertOrder(shader, "color = applyFade(color);", "color = applySplitToning(color);")
        assertOrder(shader, "color = applySplitToning(color);", "if (uBloomIntensity > 0.0)")
        assertOrder(shader, "color = applyLightLeak(color, vTextureCoord);", "color = applyDust(color, vTextureCoord);")
        assertOrder(shader, "color = applyDust(color, vTextureCoord);", "color = applyFilmGrain(color);")
        assertOrder(shader, "color = applyFilmGrain(color);", "color = applyVignette(color);")
        assertOrder(shader, "color = applyVignette(color);", "color = applyToneRollOff(color);")
    }

    @Test
    fun `bloom composite shader applies rana styles before bloom and final effects`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BLOOM_COMPOSITE

        assertTrue(shader.contains("uniform float uTone;"))
        assertTrue(shader.contains("uniform float uColor;"))
        assertTrue(shader.contains("uniform float uStyleStrength;"))
        assertTrue(shader.contains("uniform float uChromaticAberrationIntensity;"))
        assertTrue(shader.contains("uniform float uFade;"))
        assertTrue(shader.contains("uniform float uHighlightRollOff;"))
        assertTrue(shader.contains("uniform float uShadowRollOff;"))
        assertTrue(shader.contains("uniform sampler2D uHalationTexture;"))
        assertTrue(shader.contains("uniform vec3 uHalationColor;"))
        assertTrue(shader.contains("uniform vec3 uShadowsTint;"))
        assertTrue(shader.contains("uniform vec3 uHighlightsTint;"))
        assertTrue(shader.contains("color += vec3(uTextureVal * 0.0);"))
        assertOrder(shader, "color = applyRanaStyles(color);", "if (uBloomIntensity > 0.0)")
        assertOrder(shader, "color = applyRanaStyles(color);", "color = applyFade(color);")
        assertOrder(shader, "color = applyFade(color);", "color = applySplitToning(color);")
        assertOrder(shader, "color = applySplitToning(color);", "if (uBloomIntensity > 0.0)")
        assertOrder(shader, "color = applyRanaStyles(color);", "color = applyLightLeak(color, vTextureCoord);")
        assertOrder(shader, "color = applyVignette(color);", "color = applyToneRollOff(color);")
    }

    @Test
    fun `halation uses independent texture and backward compatible custom hue`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BLOOM_COMPOSITE

        assertTrue(shader.contains("texture2D(\n                    uHalationTexture"))
        assertTrue(shader.contains("vec3 halationTint = mix("))
        assertTrue(shader.contains("uHalationColor,"))
        assertTrue(shader.contains("reflectedLight * (halationTint - vec3(1.0))"))
        assertOrder(
            shader,
            "color += bloomColor * uBloomIntensity;",
            "if (uHalationIntensity > 0.0)"
        )
    }

    @Test
    fun `roll-off helper uses film shoulder and toe curves`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertTrue(shader.contains("const float HIGHLIGHT_ROLL_OFF_START = 0.65;"))
        assertTrue(shader.contains("const float SHADOW_ROLL_OFF_END = 0.35;"))
        assertTrue(shader.contains("exp("))
        assertTrue(shader.contains("normalized * normalized *"))
        assertTrue(shader.contains("(2.0 - normalized)"))
        assertTrue(shader.contains("float rolledLuma = applyRollOffToLuma(luma);"))
        assertTrue(shader.contains("positiveColor * (rolledLuma / luma)"))
        assertTrue(shader.contains("vec3 whiteLimited = rolledColor / maxChannel;"))
    }

    @Test
    fun `rana styles reduce color and undertone shifts on skin tones`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertTrue(shader.contains("float skinToneProtection(vec3 inputColor)"))
        assertTrue(shader.contains("float chromaStyleScale = mix(1.0, 0.35, skinProtect);"))
        assertTrue(shader.contains("colorAmount * chromaStyleScale / 100.0"))
        assertTrue(shader.contains("uUndertoneX * chromaStyleScale"))
        assertTrue(shader.contains("uUndertoneY * chromaStyleScale"))
        assertOrder(shader, "float skinProtect = skinToneProtection(inputColor);", "float toneAmount = clamp(uTone, -100.0, 100.0);")
    }

    @Test
    fun `base color shader leaves rana styles to bloom composite`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT

        assertTrue(shader.contains("vec3 color = applyColorGrade(texColor.rgb);"))
        assertTrue(!shader.contains("color = applyRanaStyles(color);"))
    }

    @Test
    fun `gaussian blur combines adjacent taps through bilinear filtering`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_GAUSSIAN_BLUR

        assertTrue(shader.contains("uTexelOffset * 1.384615"))
        assertTrue(shader.contains("uTexelOffset * 3.230769"))
        assertEquals(5, Regex("texture2D\\s*\\(").findAll(shader).count())
    }

    private fun assertOrder(shader: String, first: String, second: String) {
        val firstIndex = shader.indexOf(first)
        val secondIndex = shader.indexOf(second)

        assertTrue("Missing shader fragment: $first", firstIndex >= 0)
        assertTrue("Missing shader fragment: $second", secondIndex >= 0)
        assertTrue(
            "Expected `$first` before `$second`",
            firstIndex < secondIndex
        )
    }
}
