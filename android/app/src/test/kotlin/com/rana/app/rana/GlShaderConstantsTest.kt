package com.rana.app.rana

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
            "vec4 texColor = texture2D(sTexture, sourceUv);"
        )
    }

    @Test
    fun `base export shader warps uv before sampling source texture`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT

        assertOrder(
            shader,
            "vec2 sourceUv = applyLensDistortion(vTextureCoord);",
            "vec4 texColor = texture2D(sTexture, sourceUv);"
        )
    }

    @Test
    fun `color grade applies lut before temperature saturation and contrast`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertOrder(
            shader,
            "color = applyLut(color);",
            "if (uTemperature > 0.0)"
        )
        assertOrder(
            shader,
            "if (uTemperature > 0.0)",
            "float luma = dot(color, vec3(0.299, 0.587, 0.114));"
        )
        assertOrder(
            shader,
            "float luma = dot(color, vec3(0.299, 0.587, 0.114));",
            "color = (color - 0.5) * (1.0 + uContrast) + 0.5;"
        )
    }

    @Test
    fun `single pass shader keeps final effects in analog stack order`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_EXPORT

        assertOrder(shader, "color = applyLightLeak(color, vTextureCoord);", "color = applyDust(color, vTextureCoord);")
        assertOrder(shader, "color = applyDust(color, vTextureCoord);", "color = applyFilmGrain(color);")
        assertOrder(shader, "color = applyFilmGrain(color);", "color = applyVignette(color);")
    }

    @Test
    fun `bloom composite shader applies rana styles before bloom and final effects`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BLOOM_COMPOSITE

        assertTrue(shader.contains("uniform float uTone;"))
        assertTrue(shader.contains("uniform float uColor;"))
        assertTrue(shader.contains("uniform float uStyleStrength;"))
        assertTrue(shader.contains("color += vec3(uTextureVal * 0.0);"))
        assertOrder(shader, "color = applyRanaStyles(color);", "if (uBloomIntensity > 0.0)")
        assertOrder(shader, "color = applyRanaStyles(color);", "color = applyLightLeak(color, vTextureCoord);")
    }

    @Test
    fun `base color shader leaves rana styles to bloom composite`() {
        val shader = GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT

        assertTrue(shader.contains("vec3 color = applyColorGrade(texColor.rgb);"))
        assertTrue(!shader.contains("color = applyRanaStyles(color);"))
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
