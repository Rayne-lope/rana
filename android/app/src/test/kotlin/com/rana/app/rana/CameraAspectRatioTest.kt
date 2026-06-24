package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Test

class CameraAspectRatioTest {
    @Test
    fun `maps channel values to supported aspect ratios`() {
        assertEquals(CameraAspectRatio.PORTRAIT_3_4, CameraAspectRatio.fromChannelValue(null))
        assertEquals(CameraAspectRatio.PORTRAIT_3_4, CameraAspectRatio.fromChannelValue("portrait_3_4"))
        assertEquals(CameraAspectRatio.SQUARE_1_1, CameraAspectRatio.fromChannelValue("1:1"))
        assertEquals(CameraAspectRatio.PORTRAIT_9_16, CameraAspectRatio.fromChannelValue("portrait_9_16"))
    }

    @Test
    fun `square crop trims the longer edge evenly`() {
        val bounds = calculateCenterCropBounds(3000, 4000, 1f)

        assertEquals(0, bounds.left)
        assertEquals(500, bounds.top)
        assertEquals(3000, bounds.width)
        assertEquals(3000, bounds.height)
    }

    @Test
    fun `portrait crop preserves matching ratio`() {
        val bounds = calculateCenterCropBounds(3000, 4000, 3f / 4f)

        assertEquals(0, bounds.left)
        assertEquals(0, bounds.top)
        assertEquals(3000, bounds.width)
        assertEquals(4000, bounds.height)
    }
}
