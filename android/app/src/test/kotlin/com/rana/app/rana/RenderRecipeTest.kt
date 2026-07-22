package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class RenderRecipeTest {
    @Test
    fun `legacy flat recipe migrates to v1 and clamps invalid style values`() {
        val recipe = RenderRecipeV1.fromMap(
            mapOf(
                "tone" to 140.0,
                "textureVal" to -2.0,
                "undertoneX" to 3.0,
                "presetId" to "portra"
            )
        )

        assertEquals(100f, recipe.tone)
        assertEquals(0f, recipe.texture)
        assertEquals(1f, recipe.undertoneX)
        assertEquals("portra", recipe.presetId)
        assertEquals(RENDER_RECIPE_VERSION, recipe.toMap()["recipeVersion"])
    }

    @Test
    fun `v1 recipe round trips through its compatibility map`() {
        val original = RenderRecipeV1(
            temperature = 0.2f,
            colorMatrix = listOf(1f, 0.1f, 0f, 0f, 1f, 0f, 0f, 0.2f, 1f),
            lightLeakVariant = 2,
            aspectRatio = "square_1_1",
            outputQuality = "heic",
            presetId = "test"
        )

        assertEquals(original, RenderRecipeV1.fromMap(original.toMap()))
    }

    @Test
    fun `unknown recipe versions fail without discarding metadata`() {
        val error = assertThrows(UnsupportedRenderRecipeVersionException::class.java) {
            RenderRecipeV1.fromMap(mapOf("recipeVersion" to 99))
        }

        assertEquals(99, error.recipeVersion)
    }
}
