package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RanaCameraComponentsTest {
    @Test
    fun `capture processor owns bounded queue and executors`() {
        val processor = RanaCaptureProcessor(maxPendingPipelines = 2)

        assertEquals(1, processor.limiter.tryAcquire())
        assertEquals(2, processor.limiter.tryAcquire())
        assertEquals(null, processor.limiter.tryAcquire())

        processor.release()

        assertTrue(processor.captureExecutor.isShutdown)
        assertTrue(processor.processingExecutor.isShutdown)
    }
}
