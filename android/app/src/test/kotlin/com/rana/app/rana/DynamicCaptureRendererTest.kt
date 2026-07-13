package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class DynamicCaptureRendererTest {
    @Test
    fun `detail target is bounded while thumbnails preserve requested size`() {
        assertEquals(2048, dynamicRenderTargetSize(null))
        assertEquals(2048, dynamicRenderTargetSize(0))
        assertEquals(360, dynamicRenderTargetSize(360))
        assertEquals(64, dynamicRenderTargetSize(1))
        assertEquals(4096, dynamicRenderTargetSize(9000))
    }

    @Test
    fun `sample size keeps rendered bitmap near display target`() {
        assertEquals(1, dynamicBitmapSampleSize(1600, 1200, 2048))
        assertEquals(2, dynamicBitmapSampleSize(4032, 3024, 1600))
        assertEquals(16, dynamicBitmapSampleSize(8000, 4000, 500))
        assertEquals(1, dynamicBitmapSampleSize(0, 0, 360))
    }

    @Test
    fun `cache key changes with target size and metadata update`() {
        val base = dynamicRenderCacheKey("content://capture/1", 360, 100)

        assertNotEquals(
            base,
            dynamicRenderCacheKey("content://capture/1", 2048, 100)
        )
        assertNotEquals(
            base,
            dynamicRenderCacheKey("content://capture/1", 360, 101)
        )
    }
}
