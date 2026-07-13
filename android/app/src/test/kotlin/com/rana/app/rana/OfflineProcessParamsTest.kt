package com.rana.app.rana

import java.util.Date
import java.util.TimeZone
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OfflineProcessParamsTest {
    @Test
    fun `legacy payload uses neutral analog defaults`() {
        val params = offlineProcessParamsFromArguments(
            mapOf("temperature" to 0.2, "grain" to 0.4)
        )

        assertEquals(0.2f, params.temperature)
        assertEquals(0.4f, params.grain)
        assertEquals(1f, params.grainSize)
        assertEquals(0f, params.chromaticAberrationIntensity)
        assertEquals(0f, params.fade)
        assertEquals(0f, params.highlightRollOff)
        assertEquals(0f, params.shadowRollOff)
        assertArrayEquals(IDENTITY_COLOR_MATRIX, params.colorMatrix, 0f)
        assertFalse(params.dateStampEnable)
        assertEquals(0f, params.shadowsTintR)
        assertEquals(0f, params.highlightsTintB)
        assertEquals("normal", params.presetId)
        assertFalse(params.isStyleModified)
    }

    @Test
    fun `complete analog payload is parsed`() {
        val params = offlineProcessParamsFromArguments(
            mapOf(
                "chromaticAberrationIntensity" to 0.15,
                "fade" to 0.25,
                "highlightRollOff" to 0.6,
                "shadowRollOff" to 0.4,
                "colorMatrix" to listOf(
                    1.1, 0.1, 0.2,
                    0.3, 0.9, 0.4,
                    0.5, 0.6, 0.8
                ),
                "dateStampEnable" to true,
                "shadowsTintR" to 0.1,
                "shadowsTintG" to 0.2,
                "shadowsTintB" to 0.3,
                "highlightsTintR" to 0.7,
                "highlightsTintG" to 0.8,
                "highlightsTintB" to 0.9
            )
        )

        assertEquals(0.15f, params.chromaticAberrationIntensity)
        assertEquals(0.25f, params.fade)
        assertEquals(0.6f, params.highlightRollOff)
        assertEquals(0.4f, params.shadowRollOff)
        assertArrayEquals(
            floatArrayOf(
                1.1f, 0.1f, 0.2f,
                0.3f, 0.9f, 0.4f,
                0.5f, 0.6f, 0.8f
            ),
            params.colorMatrix,
            0f
        )
        assertTrue(params.dateStampEnable)
        assertEquals(0.1f, params.shadowsTintR)
        assertEquals(0.2f, params.shadowsTintG)
        assertEquals(0.3f, params.shadowsTintB)
        assertEquals(0.7f, params.highlightsTintR)
        assertEquals(0.8f, params.highlightsTintG)
        assertEquals(0.9f, params.highlightsTintB)
    }

    @Test
    fun `invalid color matrix falls back to identity`() {
        val tooShort = offlineProcessParamsFromArguments(
            mapOf("colorMatrix" to listOf(1, 0, 0))
        )
        val nonNumeric = offlineProcessParamsFromArguments(
            mapOf("colorMatrix" to listOf(1, 0, 0, 0, 1, 0, 0, "bad", 1))
        )

        assertArrayEquals(IDENTITY_COLOR_MATRIX, tooShort.colorMatrix, 0f)
        assertArrayEquals(IDENTITY_COLOR_MATRIX, nonNumeric.colorMatrix, 0f)
    }

    @Test
    fun `row major color matrix is transposed for OpenGL`() {
        assertArrayEquals(
            floatArrayOf(1f, 4f, 7f, 2f, 5f, 8f, 3f, 6f, 9f),
            colorMatrixForGl(
                floatArrayOf(1f, 2f, 3f, 4f, 5f, 6f, 7f, 8f, 9f)
            ),
            0f
        )
    }

    @Test
    fun `date stamp helpers scale and format deterministically`() {
        assertEquals(180f, dateStampTextSize(4000))
        assertEquals(200f, dateStampMargin(4000))
        assertEquals(
            "70 01 01",
            formatDateStamp(Date(0), TimeZone.getTimeZone("UTC"))
        )
    }

    @Test
    fun `capture filename metadata is parsed`() {
        val params = offlineProcessParamsFromArguments(
            mapOf("presetId" to "rana_chroma", "isStyleModified" to true)
        )

        assertEquals("rana_chroma", params.presetId)
        assertTrue(params.isStyleModified)
    }
}
