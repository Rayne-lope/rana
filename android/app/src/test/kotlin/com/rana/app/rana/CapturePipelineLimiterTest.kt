package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CapturePipelineLimiterTest {
    @Test
    fun `rejects work beyond configured processing capacity`() {
        val limiter = CapturePipelineLimiter(capacity = 3)

        assertEquals(1, limiter.tryAcquire())
        assertEquals(2, limiter.tryAcquire())
        assertEquals(3, limiter.tryAcquire())
        assertNull(limiter.tryAcquire())
    }

    @Test
    fun `released processing slot accepts the next capture`() {
        val limiter = CapturePipelineLimiter(capacity = 1)

        assertEquals(1, limiter.tryAcquire())
        assertNull(limiter.tryAcquire())
        assertEquals(0, limiter.release())
        assertEquals(1, limiter.tryAcquire())
        assertEquals(0, limiter.release())
        assertEquals(0, limiter.release())
    }
}
