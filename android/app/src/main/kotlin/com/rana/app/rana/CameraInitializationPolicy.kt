package com.rana.app.rana

internal data class CameraInitializationError(
    val code: String,
    val message: String
)

internal object CameraInitializationPolicy {
    fun errorFor(hasActivePreview: Boolean): CameraInitializationError? =
        if (hasActivePreview) {
            null
        } else {
            CameraInitializationError(
                code = "CAMERA_NOT_READY",
                message = "Camera preview not initialized"
            )
        }
}
