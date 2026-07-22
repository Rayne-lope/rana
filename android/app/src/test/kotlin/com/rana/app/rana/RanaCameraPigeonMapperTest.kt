package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class RanaCameraPigeonMapperTest {
    @Test
    fun `recipe round trips through generated Pigeon message`() {
        val recipe = RenderRecipeV1(
            temperature = 0.25f,
            grain = 0.4f,
            lightLeakVariant = 3,
            outputQuality = "efficient_heic",
            aspectRatio = "wide_16_9",
            presetId = "warm",
            isStyleModified = true
        )

        assertEquals(recipe, recipe.toPigeonMessage().toDomainRecipe())
    }

    @Test
    fun `unknown recipe version becomes a structured bridge error`() {
        val message = RenderRecipeV1().toPigeonMessage().copy(recipeVersion = 99)

        try {
            message.toDomainRecipe()
            fail("Expected an unsupported-version error")
        } catch (error: FlutterError) {
            assertEquals("UNSUPPORTED_RECIPE_VERSION", error.code)
        }
    }

    @Test
    fun `invalid recipe vectors are rejected before rendering`() {
        val message = RenderRecipeV1().toPigeonMessage().copy(
            colorMatrix = listOf(1.0, 0.0)
        )

        try {
            message.toDomainRecipe()
            fail("Expected an invalid-recipe error")
        } catch (error: FlutterError) {
            assertEquals("INVALID_RECIPE", error.code)
        }
    }
}
