package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraZoomTest {
    @Test
    fun `zoom bounds default to Rana 1x to 3x range`() {
        val bounds = cameraZoomBounds(null, null)

        assertEquals(1f, bounds.minZoomRatio, 0.0001f)
        assertEquals(3f, bounds.maxZoomRatio, 0.0001f)
        assertEquals(3f, bounds.effectiveMaxZoomRatio, 0.0001f)
        assertFalse(bounds.isZoomLimited)
    }

    @Test
    fun `effective max zoom is limited by device capability`() {
        val bounds = cameraZoomBounds(1f, 2.25f)

        assertEquals(1f, bounds.minZoomRatio, 0.0001f)
        assertEquals(2.25f, bounds.maxZoomRatio, 0.0001f)
        assertEquals(2.25f, bounds.effectiveMaxZoomRatio, 0.0001f)
        assertTrue(bounds.isZoomLimited)
    }

    @Test
    fun `zoom clamp never exceeds Rana 3x maximum`() {
        val zoomRatio = clampUserZoomRatio(
            requestedZoomRatio = 8f,
            nativeMinZoomRatio = 1f,
            nativeMaxZoomRatio = 12f
        )

        assertEquals(3f, zoomRatio, 0.0001f)
    }

    @Test
    fun `zoom clamp respects lower native maximum`() {
        val zoomRatio = clampUserZoomRatio(
            requestedZoomRatio = 3f,
            nativeMinZoomRatio = 1f,
            nativeMaxZoomRatio = 1.8f
        )

        assertEquals(1.8f, zoomRatio, 0.0001f)
    }

    @Test
    fun `invalid requested zoom falls back to minimum`() {
        val zoomRatio = clampUserZoomRatio(
            requestedZoomRatio = Float.NaN,
            nativeMinZoomRatio = 1f,
            nativeMaxZoomRatio = 3f
        )

        assertEquals(1f, zoomRatio, 0.0001f)
    }
}
