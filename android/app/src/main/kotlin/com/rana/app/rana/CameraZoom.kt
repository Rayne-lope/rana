package com.rana.app.rana

const val USER_MIN_ZOOM_RATIO = 1f
const val USER_MAX_ZOOM_RATIO = 3f

data class CameraZoomBounds(
    val minZoomRatio: Float,
    val maxZoomRatio: Float,
    val effectiveMaxZoomRatio: Float,
) {
    val isZoomLimited: Boolean
        get() = effectiveMaxZoomRatio < USER_MAX_ZOOM_RATIO
}

internal fun cameraZoomBounds(
    nativeMinZoomRatio: Float?,
    nativeMaxZoomRatio: Float?,
): CameraZoomBounds {
    val nativeMin = validZoomRatio(nativeMinZoomRatio) ?: USER_MIN_ZOOM_RATIO
    val nativeMax = validZoomRatio(nativeMaxZoomRatio) ?: USER_MAX_ZOOM_RATIO
    val minZoomRatio = kotlin.math.max(USER_MIN_ZOOM_RATIO, nativeMin)
    val maxZoomRatio = kotlin.math.max(minZoomRatio, nativeMax)
    val effectiveMaxZoomRatio = kotlin.math.max(
        minZoomRatio,
        kotlin.math.min(USER_MAX_ZOOM_RATIO, maxZoomRatio)
    )

    return CameraZoomBounds(
        minZoomRatio = minZoomRatio,
        maxZoomRatio = maxZoomRatio,
        effectiveMaxZoomRatio = effectiveMaxZoomRatio,
    )
}

internal fun clampUserZoomRatio(
    requestedZoomRatio: Float,
    nativeMinZoomRatio: Float?,
    nativeMaxZoomRatio: Float?,
): Float {
    val bounds = cameraZoomBounds(nativeMinZoomRatio, nativeMaxZoomRatio)
    val safeRequestedZoomRatio = if (
        requestedZoomRatio > 0f &&
        java.lang.Float.isFinite(requestedZoomRatio)
    ) {
        requestedZoomRatio
    } else {
        bounds.minZoomRatio
    }

    return safeRequestedZoomRatio.coerceIn(
        bounds.minZoomRatio,
        bounds.effectiveMaxZoomRatio,
    )
}

private fun validZoomRatio(value: Float?): Float? {
    if (value == null || value <= 0f || !java.lang.Float.isFinite(value)) {
        return null
    }
    return value
}
