package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraQualityAuditTest {
    @Test
    fun `zoom at 1x is treated as native`() {
        val estimate = estimateZoomQuality(
            requestedZoomRatio = 1f,
            hasLogicalMultiCamera = false,
            physicalCameraCount = 0,
            minFocalLength = null,
            maxFocalLength = null
        )

        assertEquals("native", estimate.zoomQualityLabel)
        assertFalse(estimate.isLikelyDigitalZoom)
        assertFalse(estimate.shouldWarnDigitalZoom)
    }

    @Test
    fun `zoom above warning threshold without telephoto evidence is digital likely`() {
        val estimate = estimateZoomQuality(
            requestedZoomRatio = 3f,
            hasLogicalMultiCamera = false,
            physicalCameraCount = 0,
            minFocalLength = 4f,
            maxFocalLength = 4f
        )

        assertEquals("digital_likely", estimate.zoomQualityLabel)
        assertFalse(estimate.hasTelephotoCandidate)
        assertTrue(estimate.isLikelyDigitalZoom)
        assertTrue(estimate.shouldWarnDigitalZoom)
    }

    @Test
    fun `telephoto focal spread suppresses digital warning`() {
        val estimate = estimateZoomQuality(
            requestedZoomRatio = 3f,
            hasLogicalMultiCamera = true,
            physicalCameraCount = 2,
            minFocalLength = 4f,
            maxFocalLength = 9f
        )

        assertEquals("tele_candidate", estimate.zoomQualityLabel)
        assertTrue(estimate.hasTelephotoCandidate)
        assertFalse(estimate.isLikelyDigitalZoom)
        assertFalse(estimate.shouldWarnDigitalZoom)
    }
}
