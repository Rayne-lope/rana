package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Test

class OfflineEffectScaleTest {
    @Test
    fun `1080p export keeps preview effect parameters`() {
        val scale = OfflineGlProcessor.calculateEffectScale(
            renderWidth = 1920,
            renderHeight = 1080,
            params = OfflineProcessParams(grain = 0.36f, grainSize = 1f)
        )

        assertEquals(1f, scale.resolutionScale, 0.0001f)
        assertEquals(0.36f, scale.grainIntensity, 0.0001f)
        assertEquals(1f, scale.grainSize, 0.0001f)
        assertEquals(4, scale.bloomDivisor)
        assertEquals(1f, scale.blurRadiusScale, 0.0001f)
    }

    @Test
    fun `12 megapixel export scales effects from its short edge`() {
        val scale = OfflineGlProcessor.calculateEffectScale(
            renderWidth = 4000,
            renderHeight = 3000,
            params = OfflineProcessParams(grain = 0.36f, grainSize = 1f)
        )

        assertEquals(3000f / 1080f, scale.resolutionScale, 0.0001f)
        assertEquals(0.6f, scale.grainIntensity, 0.0001f)
        assertEquals(3000f / 1080f, scale.grainSize, 0.0001f)
        assertEquals(11, scale.bloomDivisor)
        assertEquals((4f * (3000f / 1080f)) / 11f, scale.blurRadiusScale, 0.0001f)
    }

    @Test
    fun `portrait and landscape use the same short edge scale`() {
        val portrait = OfflineGlProcessor.calculateEffectScale(
            renderWidth = 3000,
            renderHeight = 4000,
            params = OfflineProcessParams()
        )
        val landscape = OfflineGlProcessor.calculateEffectScale(
            renderWidth = 4000,
            renderHeight = 3000,
            params = OfflineProcessParams()
        )

        assertEquals(landscape.resolutionScale, portrait.resolutionScale, 0.0001f)
        assertEquals(landscape.bloomDivisor, portrait.bloomDivisor)
        assertEquals(landscape.blurRadiusScale, portrait.blurRadiusScale, 0.0001f)
    }
}
