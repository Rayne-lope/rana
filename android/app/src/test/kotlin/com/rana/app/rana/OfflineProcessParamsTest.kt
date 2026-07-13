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
        assertEquals(0, params.filmBorderStyle)
        assertEquals(-1f, params.dustOffsetX)
        assertEquals(-1f, params.dustOffsetY)
        assertArrayEquals(IDENTITY_COLOR_MATRIX, params.colorMatrix, 0f)
        assertEquals(1f, params.halationRadius)
        assertEquals(1f, params.halationColorR)
        assertEquals(0.35f, params.halationColorG)
        assertEquals(0.15f, params.halationColorB)
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
                "halationRadius" to 2.5,
                "halationColorR" to 0.9,
                "halationColorG" to 0.25,
                "halationColorB" to 0.05,
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
        assertEquals(2.5f, params.halationRadius)
        assertEquals(0.9f, params.halationColorR)
        assertEquals(0.25f, params.halationColorG)
        assertEquals(0.05f, params.halationColorB)
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
    fun `halation blur radius is bounded and only shared at legacy radius`() {
        assertEquals(0.25f, normalizedHalationRadius(0f))
        assertEquals(4f, normalizedHalationRadius(9f))
        assertEquals(1f, normalizedHalationRadius(Float.NaN))
        assertEquals(0.4f, normalizedHalationColor(0.4f, 1f))
        assertEquals(1f, normalizedHalationColor(Float.NaN, 1f))
        assertTrue(canShareHalationBlur(0.2f, 1f))
        assertFalse(canShareHalationBlur(0.2f, 1.5f))
        assertFalse(canShareHalationBlur(0f, 1f))
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

    @Test
    fun `metadata payload restores rendering parameters`() {
        val original = OfflineProcessParams(
            temperature = 0.2f,
            colorMatrix = floatArrayOf(
                1f, 0.1f, 0f,
                0f, 0.9f, 0f,
                0f, 0.1f, 1f
            ),
            grain = 0.3f,
            dustOffsetX = 0.2f,
            dustOffsetY = 0.7f,
            filmBorderStyle = 2,
            halationRadius = 1.8f,
            undertoneX = -0.4f,
            undertoneY = 0.25f,
            dateStampEnable = true,
            outputQuality = OutputQualityProfile.EFFICIENT_HEIC,
            presetId = "cinestill_800t",
            isStyleModified = true
        )

        val restored = offlineProcessParamsFromArguments(
            original.asMetadataParams()
        )

        assertEquals(original.temperature, restored.temperature)
        assertArrayEquals(original.colorMatrix, restored.colorMatrix, 0f)
        assertEquals(original.grain, restored.grain)
        assertEquals(original.dustOffsetX, restored.dustOffsetX)
        assertEquals(original.dustOffsetY, restored.dustOffsetY)
        assertEquals(original.filmBorderStyle, restored.filmBorderStyle)
        assertEquals(original.halationRadius, restored.halationRadius)
        assertEquals(original.undertoneX, restored.undertoneX)
        assertEquals(original.undertoneY, restored.undertoneY)
        assertEquals(original.dateStampEnable, restored.dateStampEnable)
        assertEquals(original.outputQuality, restored.outputQuality)
        assertEquals(original.presetId, restored.presetId)
        assertEquals(original.isStyleModified, restored.isStyleModified)
    }

    @Test
    fun `film border parser accepts supported styles and rejects unknown values`() {
        assertEquals(
            1,
            offlineProcessParamsFromArguments(
                mapOf("filmBorderStyle" to 1)
            ).filmBorderStyle
        )
        assertEquals(
            0,
            offlineProcessParamsFromArguments(
                mapOf("filmBorderStyle" to 99)
            ).filmBorderStyle
        )
    }
}
