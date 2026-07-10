package com.rana.app.rana

import android.view.Surface

internal enum class CaptureTargetRotationSource(val auditValue: String) {
    SENSOR("sensor"),
    DISPLAY_FALLBACK("display_fallback")
}

internal data class CaptureTargetRotationDecision(
    val targetRotation: Int,
    val source: CaptureTargetRotationSource
)

/** Maps an OrientationEventListener reading to CameraX's target rotation. */
internal fun sensorOrientationToSurfaceRotation(orientationDegrees: Int): Int? =
    when (orientationDegrees) {
        in 0..44, in 315..359 -> Surface.ROTATION_0
        in 45..134 -> Surface.ROTATION_270
        in 135..224 -> Surface.ROTATION_180
        in 225..314 -> Surface.ROTATION_90
        else -> null
    }

/** Prefers physical orientation and falls back to display rotation until it is known. */
internal fun selectCaptureTargetRotation(
    lastSensorTargetRotation: Int?,
    displayRotation: Int
): CaptureTargetRotationDecision =
    if (lastSensorTargetRotation != null) {
        CaptureTargetRotationDecision(
            targetRotation = lastSensorTargetRotation,
            source = CaptureTargetRotationSource.SENSOR
        )
    } else {
        CaptureTargetRotationDecision(
            targetRotation = displayRotation,
            source = CaptureTargetRotationSource.DISPLAY_FALLBACK
        )
    }
