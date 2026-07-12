package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OutputQualityTest {
    @Test
    fun `legacy output payload defaults to high JPEG`() {
        val profile = OutputQualityProfile.fromChannelValue(null)

        assertEquals(OutputQualityProfile.HIGH_JPEG, profile)
        assertEquals("jpg", profile.extension)
        assertEquals("image/jpeg", profile.mimeType)
        assertEquals(95, profile.encoderQuality)
    }

    @Test
    fun `profiles expose stable storage and encoder values`() {
        assertEquals("standard_jpeg", OutputQualityProfile.STANDARD_JPEG.channelValue)
        assertEquals(88, OutputQualityProfile.STANDARD_JPEG.encoderQuality)
        assertEquals("efficient_heic", OutputQualityProfile.EFFICIENT_HEIC.channelValue)
        assertEquals("heic", OutputQualityProfile.EFFICIENT_HEIC.extension)
        assertTrue(OutputQualityProfile.EFFICIENT_HEIC.requiresHeic)
        assertFalse(OutputQualityProfile.HIGH_JPEG.requiresHeic)
    }

    @Test
    fun `unsupported HEIC resolves to high JPEG with fallback`() {
        val resolved = resolveOutputQuality(
            OutputQualityProfile.EFFICIENT_HEIC,
            OutputCapabilities(false, "android_version")
        )

        assertEquals(OutputQualityProfile.HIGH_JPEG, resolved.actual)
        assertEquals("heic_unsupported", resolved.fallbackReason)
    }
}
