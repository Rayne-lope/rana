package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class CameraFailureTelemetryTest {
    @Test
    fun `native failure codes map to recovery metadata`() {
        val failure = RanaCameraFailure.fromCode(
            "LENS_SWITCH_TIMEOUT",
            "physical camera did not produce a frame"
        )

        assertEquals(RanaCameraFailureCode.LENS_SWITCH_TIMEOUT, failure.code)
        assertEquals(RanaCameraRecoveryAction.FALLBACK_LENS, failure.recoveryAction)
        assertEquals("physical camera did not produce a frame", failure.developerMessage)
    }

    @Test
    fun `telemetry evicts oldest sample and rejects non finite values`() {
        var timestamp = 0L
        val telemetry = RanaCameraTelemetry(capacity = 2) { ++timestamp }

        telemetry.record(RanaTelemetryMetric.CAMERA_BIND_MS, 1.0)
        telemetry.record(RanaTelemetryMetric.PREVIEW_AVERAGE_FPS, 2.0)
        telemetry.record(RanaTelemetryMetric.CAPTURE_PROCESS_MS, 3.0)
        assertNull(telemetry.record(RanaTelemetryMetric.CAPTURE_SAVE_MS, Double.NaN))

        val samples = telemetry.snapshot()
        assertEquals(2, samples.size)
        assertEquals("preview_average_fps", samples.first().name)
        assertEquals(3.0, samples.last().value, 0.0)
        assertFalse(samples.any { it.name.contains("uri", ignoreCase = true) })
    }
}
