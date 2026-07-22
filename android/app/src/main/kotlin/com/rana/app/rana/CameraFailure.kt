package com.rana.app.rana

internal enum class RanaCameraFailureCode(val wireCode: String) {
    CAMERA_PERMISSION_DENIED("CAMERA_PERMISSION_DENIED"),
    CAMERA_NOT_READY("CAMERA_NOT_READY"),
    CAMERA_INITIALIZATION_FAILED("CAMERA_INITIALIZATION_FAILED"),
    CAMERA_BIND_FAILED("CAMERA_BIND_FAILED"),
    GL_INITIALIZATION_FAILED("GL_INITIALIZATION_FAILED"),
    GL_RENDER_FAILED("GL_RENDER_FAILED"),
    CAPTURE_PIPELINE_BUSY("CAPTURE_PIPELINE_BUSY"),
    CAPTURE_FAILED("CAPTURE_FAILED"),
    CAPTURE_PROCESSING_FAILED("CAPTURE_PROCESSING_FAILED"),
    MEDIASTORE_WRITE_FAILED("MEDIASTORE_WRITE_FAILED"),
    OUTPUT_ENCODING_FAILED("OUTPUT_ENCODING_FAILED"),
    LENS_SWITCH_TIMEOUT("LENS_SWITCH_TIMEOUT"),
    PHYSICAL_LENS_UNSUPPORTED("PHYSICAL_LENS_UNSUPPORTED"),
    FILM_ROLL_RECOVERY_FAILED("FILM_ROLL_RECOVERY_FAILED"),
    METADATA_READ_FAILED("METADATA_READ_FAILED"),
    METADATA_WRITE_FAILED("METADATA_WRITE_FAILED"),
    UNKNOWN_RECIPE_VERSION("UNKNOWN_RECIPE_VERSION"),
    UNKNOWN_CAMERA_FAILURE("UNKNOWN_CAMERA_FAILURE");

    companion object {
        fun fromWireCode(code: String): RanaCameraFailureCode =
            entries.firstOrNull { it.wireCode == code } ?: UNKNOWN_CAMERA_FAILURE
    }
}

internal enum class RanaCameraRecoveryAction {
    NONE,
    RETRY,
    REINITIALIZE,
    OPEN_SETTINGS,
    FALLBACK_LENS,
    FREE_STORAGE
}

internal data class RanaCameraFailure(
    val code: RanaCameraFailureCode,
    val userMessage: String,
    val developerMessage: String,
    val recoverable: Boolean,
    val recoveryAction: RanaCameraRecoveryAction
) {
    companion object {
        fun fromCode(code: String, developerMessage: String): RanaCameraFailure {
            val typedCode = RanaCameraFailureCode.fromWireCode(code)
            val definition = definitions.getValue(typedCode)
            return RanaCameraFailure(
                code = typedCode,
                userMessage = definition.userMessage,
                developerMessage = developerMessage,
                recoverable = definition.recoverable,
                recoveryAction = definition.recoveryAction
            )
        }
    }
}

private data class RanaFailureDefinition(
    val userMessage: String,
    val recoverable: Boolean,
    val recoveryAction: RanaCameraRecoveryAction
)

private val definitions: Map<RanaCameraFailureCode, RanaFailureDefinition> =
    RanaCameraFailureCode.entries.associateWith { code ->
        when (code) {
            RanaCameraFailureCode.CAMERA_PERMISSION_DENIED -> RanaFailureDefinition(
                "Camera access is required to take photos.", true,
                RanaCameraRecoveryAction.OPEN_SETTINGS
            )
            RanaCameraFailureCode.CAMERA_NOT_READY,
            RanaCameraFailureCode.CAMERA_INITIALIZATION_FAILED,
            RanaCameraFailureCode.CAMERA_BIND_FAILED,
            RanaCameraFailureCode.GL_INITIALIZATION_FAILED -> RanaFailureDefinition(
                "The camera could not start. Try again.", true,
                RanaCameraRecoveryAction.REINITIALIZE
            )
            RanaCameraFailureCode.LENS_SWITCH_TIMEOUT,
            RanaCameraFailureCode.PHYSICAL_LENS_UNSUPPORTED -> RanaFailureDefinition(
                "This lens is unavailable. Try the standard lens.", true,
                RanaCameraRecoveryAction.FALLBACK_LENS
            )
            RanaCameraFailureCode.MEDIASTORE_WRITE_FAILED -> RanaFailureDefinition(
                "The photo could not be saved.", true,
                RanaCameraRecoveryAction.FREE_STORAGE
            )
            RanaCameraFailureCode.UNKNOWN_RECIPE_VERSION -> RanaFailureDefinition(
                "This photo recipe uses an unsupported version.", false,
                RanaCameraRecoveryAction.NONE
            )
            RanaCameraFailureCode.UNKNOWN_CAMERA_FAILURE -> RanaFailureDefinition(
                "The camera encountered an unexpected problem.", true,
                RanaCameraRecoveryAction.RETRY
            )
            else -> RanaFailureDefinition(
                "The camera encountered a recoverable problem.", true,
                RanaCameraRecoveryAction.RETRY
            )
        }
    }
