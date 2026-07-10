package com.rana.app.rana

import androidx.camera.core.AspectRatio
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
    fun `ratio mappings provide matching camera x fallback and viewport rationals`() {
        assertEquals(AspectRatio.RATIO_4_3, CameraAspectRatio.PORTRAIT_3_4.cameraXTargetAspectRatio)
        assertEquals(3, CameraAspectRatio.PORTRAIT_3_4.viewportNumerator)
        assertEquals(4, CameraAspectRatio.PORTRAIT_3_4.viewportDenominator)

        assertEquals(AspectRatio.RATIO_4_3, CameraAspectRatio.SQUARE_1_1.cameraXTargetAspectRatio)
        assertEquals(1, CameraAspectRatio.SQUARE_1_1.viewportNumerator)
        assertEquals(1, CameraAspectRatio.SQUARE_1_1.viewportDenominator)

        assertEquals(AspectRatio.RATIO_16_9, CameraAspectRatio.PORTRAIT_9_16.cameraXTargetAspectRatio)
        assertEquals(9, CameraAspectRatio.PORTRAIT_9_16.viewportNumerator)
        assertEquals(16, CameraAspectRatio.PORTRAIT_9_16.viewportDenominator)
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

    @Test
    fun `sampled crop rect scales to downsampled bitmap coordinates`() {
        val bounds = calculateSampledCropBounds(
            cropLeft = 0,
            cropTop = 378,
            cropRight = 4032,
            cropBottom = 2646,
            sampleSize = 2,
            bitmapWidth = 2016,
            bitmapHeight = 1512,
        )

        assertEquals(0, bounds.left)
        assertEquals(189, bounds.top)
        assertEquals(2016, bounds.width)
        assertEquals(1134, bounds.height)
    }

    @Test
    fun `full CameraX crops remain full for wide and four by three buffers`() {
        listOf(
            Triple(4032, 2268, Pair(2016, 1134)),
            Triple(4032, 3024, Pair(2016, 1512)),
        ).forEach { (sourceWidth, sourceHeight, sampledSize) ->
            val bounds = calculateSampledCropBounds(
                cropLeft = 0,
                cropTop = 0,
                cropRight = sourceWidth,
                cropBottom = sourceHeight,
                sampleSize = 2,
                bitmapWidth = sampledSize.first,
                bitmapHeight = sampledSize.second,
            )

            assertEquals(0, bounds.left)
            assertEquals(0, bounds.top)
            assertEquals(sampledSize.first, bounds.width)
            assertEquals(sampledSize.second, bounds.height)
        }
    }

    @Test
    fun `square CameraX crop scales once into sampled buffer coordinates`() {
        val bounds = calculateSampledCropBounds(
            cropLeft = 504,
            cropTop = 0,
            cropRight = 3528,
            cropBottom = 3024,
            sampleSize = 2,
            bitmapWidth = 2016,
            bitmapHeight = 1512,
        )

        assertEquals(252, bounds.left)
        assertEquals(0, bounds.top)
        assertEquals(1512, bounds.width)
        assertEquals(1512, bounds.height)
    }
}
