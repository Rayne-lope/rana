package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Test

class CaptureFilenameTest {
    private val timestamp = "2026-07-12-13-35-42-123"

    @Test
    fun `uses stable preset id without custom suffix`() {
        assertEquals(
            "Rana_rana_chroma_$timestamp",
            captureFilenameStem("rana_chroma", false, timestamp)
        )
    }

    @Test
    fun `adds custom suffix and sanitizes preset id`() {
        assertEquals(
            "Rana_rana_chroma_v2_custom_$timestamp",
            captureFilenameStem(" Rana Chroma V2! ", true, timestamp)
        )
    }

    @Test
    fun `falls back to normal for blank or invalid preset ids`() {
        assertEquals(
            "Rana_normal_$timestamp",
            captureFilenameStem(" !!! ", false, timestamp)
        )
    }

    @Test
    fun `the same stem works with actual JPEG and HEIC extensions`() {
        val stem = captureFilenameStem("rana_chroma", true, timestamp)

        assertEquals("$stem.jpg", "$stem.${OutputQualityProfile.HIGH_JPEG.extension}")
        assertEquals("$stem.heic", "$stem.${OutputQualityProfile.EFFICIENT_HEIC.extension}")
    }
}
