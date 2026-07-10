package com.rana.app.rana

import java.util.concurrent.atomic.AtomicInteger

/** Bounds encoded captures waiting for background GL/JPEG processing. */
internal class CapturePipelineLimiter(private val capacity: Int) {
    private val pendingCount = AtomicInteger(0)

    init {
        require(capacity > 0) { "Capture pipeline capacity must be positive" }
    }

    /** Returns the new pending count, or null when the queue is full. */
    fun tryAcquire(): Int? {
        while (true) {
            val current = pendingCount.get()
            if (current >= capacity) return null
            if (pendingCount.compareAndSet(current, current + 1)) {
                return current + 1
            }
        }
    }

    /** Releases one slot and never lets accounting fall below zero. */
    fun release(): Int {
        while (true) {
            val current = pendingCount.get()
            if (current == 0) return 0
            if (pendingCount.compareAndSet(current, current - 1)) {
                return current - 1
            }
        }
    }
}
