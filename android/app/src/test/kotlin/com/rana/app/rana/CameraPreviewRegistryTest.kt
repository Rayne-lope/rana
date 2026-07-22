package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.fail
import org.junit.Test

class CameraPreviewRegistryTest {
    @Test
    fun `resolves only registered PlatformView IDs`() {
        val registry = CameraPreviewRegistry<Any>()
        val first = Any()
        val second = Any()

        registry.register(7, first)
        registry.register(8, second)

        assertSame(first, registry.resolve(7))
        assertSame(second, registry.resolve(8))
        assertNull(registry.resolve(9))
    }

    @Test
    fun `unregister ignores stale view instances`() {
        val registry = CameraPreviewRegistry<Any>()
        val active = Any()
        registry.register(7, active)

        registry.unregister(7, Any())
        assertSame(active, registry.resolve(7))

        registry.unregister(7, active)
        assertNull(registry.resolve(7))
    }

    @Test
    fun `missing PlatformView ID returns CAMERA_NOT_READY`() {
        val registry = CameraPreviewRegistry<Any>()

        try {
            registry.resolveOrThrow(404)
            fail("Expected a typed FlutterError")
        } catch (error: FlutterError) {
            assertEquals("CAMERA_NOT_READY", error.code)
            assertEquals("Camera preview not initialized", error.message)
        }
    }
}
