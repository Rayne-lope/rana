package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MemoryUtilsTest {
    @Test
    fun calculateMemorySampleSizeUsesCriticalLowAndNormalThresholds() {
        assertEquals(4, MemoryUtils.calculateMemorySampleSize(149))
        assertEquals(2, MemoryUtils.calculateMemorySampleSize(150))
        assertEquals(2, MemoryUtils.calculateMemorySampleSize(299))
        assertEquals(1, MemoryUtils.calculateMemorySampleSize(300))
    }

    @Test
    fun calculateDimensionSampleSizeReturnsPowerOfTwoToFitMaxDimension() {
        assertEquals(1, MemoryUtils.calculateDimensionSampleSize(4096))
        assertEquals(2, MemoryUtils.calculateDimensionSampleSize(4097))
        assertEquals(2, MemoryUtils.calculateDimensionSampleSize(8192))
        assertEquals(4, MemoryUtils.calculateDimensionSampleSize(8193))
    }

    @Test
    fun shouldSkipLutOnlyWhenMemoryIsCritical() {
        assertTrue(MemoryUtils.shouldSkipLut(149))
        assertFalse(MemoryUtils.shouldSkipLut(150))
    }
}
