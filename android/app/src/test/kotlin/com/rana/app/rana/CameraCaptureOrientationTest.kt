package com.rana.app.rana

import android.view.OrientationEventListener
import android.view.Surface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CameraCaptureOrientationTest {
    @Test
    fun `maps portrait orientation boundaries to rotation zero`() {
        assertEquals(Surface.ROTATION_0, sensorOrientationToSurfaceRotation(0))
        assertEquals(Surface.ROTATION_0, sensorOrientationToSurfaceRotation(44))
        assertEquals(Surface.ROTATION_0, sensorOrientationToSurfaceRotation(315))
        assertEquals(Surface.ROTATION_0, sensorOrientationToSurfaceRotation(359))
    }

    @Test
    fun `maps landscape and reverse portrait orientation boundaries`() {
        assertEquals(Surface.ROTATION_270, sensorOrientationToSurfaceRotation(45))
        assertEquals(Surface.ROTATION_270, sensorOrientationToSurfaceRotation(134))
        assertEquals(Surface.ROTATION_180, sensorOrientationToSurfaceRotation(135))
        assertEquals(Surface.ROTATION_180, sensorOrientationToSurfaceRotation(224))
        assertEquals(Surface.ROTATION_90, sensorOrientationToSurfaceRotation(225))
        assertEquals(Surface.ROTATION_90, sensorOrientationToSurfaceRotation(314))
    }

    @Test
    fun `unknown orientation does not provide a replacement rotation`() {
        assertNull(
            sensorOrientationToSurfaceRotation(
                OrientationEventListener.ORIENTATION_UNKNOWN
            )
        )
    }

    @Test
    fun `sensor rotation wins while display remains portrait`() {
        val decision = selectCaptureTargetRotation(
            lastSensorTargetRotation = Surface.ROTATION_270,
            displayRotation = Surface.ROTATION_0
        )

        assertEquals(Surface.ROTATION_270, decision.targetRotation)
        assertEquals(CaptureTargetRotationSource.SENSOR, decision.source)
    }

    @Test
    fun `display rotation is used before a sensor reading exists`() {
        val decision = selectCaptureTargetRotation(
            lastSensorTargetRotation = null,
            displayRotation = Surface.ROTATION_90
        )

        assertEquals(Surface.ROTATION_90, decision.targetRotation)
        assertEquals(CaptureTargetRotationSource.DISPLAY_FALLBACK, decision.source)
    }

    @Test
    fun `portrait ratios become wide ratios in physical landscape`() {
        assertEquals(
            4f / 3f,
            expectedCaptureOutputAspectRatio(
                CameraAspectRatio.PORTRAIT_3_4,
                Surface.ROTATION_90
            ),
            0.0001f
        )
        assertEquals(
            16f / 9f,
            expectedCaptureOutputAspectRatio(
                CameraAspectRatio.PORTRAIT_9_16,
                Surface.ROTATION_270
            ),
            0.0001f
        )
    }

    @Test
    fun `portrait and reverse portrait keep portrait ratios`() {
        assertEquals(
            3f / 4f,
            expectedCaptureOutputAspectRatio(
                CameraAspectRatio.PORTRAIT_3_4,
                Surface.ROTATION_0
            ),
            0.0001f
        )
        assertEquals(
            9f / 16f,
            expectedCaptureOutputAspectRatio(
                CameraAspectRatio.PORTRAIT_9_16,
                Surface.ROTATION_180
            ),
            0.0001f
        )
    }

    @Test
    fun `square output remains square for every orientation`() {
        listOf(
            Surface.ROTATION_0,
            Surface.ROTATION_90,
            Surface.ROTATION_180,
            Surface.ROTATION_270
        ).forEach { rotation ->
            assertEquals(
                1f,
                expectedCaptureOutputAspectRatio(CameraAspectRatio.SQUARE_1_1, rotation),
                0.0001f
            )
        }
    }
}
