package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CameraInitializationPolicyTest {
    @Test
    fun `rejects initialization without an active preview`() {
        val error = CameraInitializationPolicy.errorFor(hasActivePreview = false)

        assertEquals("CAMERA_NOT_READY", error?.code)
        assertEquals("Camera preview not initialized", error?.message)
    }

    @Test
    fun `allows initialization with an active preview`() {
        assertNull(CameraInitializationPolicy.errorFor(hasActivePreview = true))
    }
}
