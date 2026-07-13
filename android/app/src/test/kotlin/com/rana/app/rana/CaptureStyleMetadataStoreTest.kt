package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureStyleMetadataStoreTest {
    @Test
    fun `supported channel parameters round trip through storage codec`() {
        val values = listOf<Any?>(
            null,
            true,
            false,
            0.35,
            -4,
            "assets/luts/look.png",
            listOf(1.0, 0.0, 0.25)
        )

        val decoded = values.map { value ->
            decodeCaptureParameter(requireNotNull(encodeCaptureParameter(value)))
        }

        assertEquals(null, decoded[0])
        assertEquals(true, decoded[1])
        assertEquals(false, decoded[2])
        assertEquals(0.35, decoded[3])
        assertEquals(-4.0, decoded[4])
        assertEquals("assets/luts/look.png", decoded[5])
        assertEquals(listOf(1.0, 0.0, 0.25), decoded[6])
    }

    @Test
    fun `unsupported and non finite values are rejected`() {
        assertNull(encodeCaptureParameter(Double.NaN))
        assertNull(encodeCaptureParameter(listOf(1.0, Double.POSITIVE_INFINITY)))
        assertNull(encodeCaptureParameter(mapOf("nested" to true)))
    }

    @Test
    fun `schema cascades parameter deletion from clean capture`() {
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_PARAMS.contains(
                "FOREIGN KEY (clean_image_uri)"
            )
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_PARAMS.contains("ON DELETE CASCADE")
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains(
                "clean_image_uri TEXT PRIMARY KEY NOT NULL"
            )
        )
    }
}
