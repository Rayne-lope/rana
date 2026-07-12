package com.rana.app.rana

private const val TELEPHOTO_OPTICAL_RATIO_THRESHOLD = 1.8f
private const val TELEPHOTO_SWITCH_BACK_RATIO = 0.9f
private const val TELEPHOTO_SWITCH_EPSILON = 0.0001f

internal enum class LensOutputTarget {
    LOGICAL_WIDE,
    PHYSICAL_TELE
}

internal data class PhysicalLensDescriptor(
    val cameraId: String,
    val focalLengthMm: Float?,
    val sensorWidthMm: Float?,
    val isStandalone: Boolean
) {
    val normalizedFocalLength: Float?
        get() = if (
            focalLengthMm != null &&
            sensorWidthMm != null &&
            focalLengthMm > 0f &&
            sensorWidthMm > 0f
        ) {
            focalLengthMm / sensorWidthMm
        } else {
            null
        }

    val hasLongFocalLength: Boolean
        get() = (focalLengthMm ?: 0f) >= 6f
}

internal data class BackCameraTopology(
    val logicalCameraId: String? = null,
    val physicalLenses: List<PhysicalLensDescriptor> = emptyList(),
    val wideLens: PhysicalLensDescriptor? = null,
    val telephotoLens: PhysicalLensDescriptor? = null,
    val telephotoOpticalRatio: Float? = null
) {
    val hasTelephotoCandidate: Boolean
        get() = telephotoLens != null && telephotoOpticalRatio != null
}

internal data class LensSwitchDecision(
    val outputTarget: LensOutputTarget,
    val physicalCameraId: String? = null,
    val telephotoOpticalRatio: Float? = null
)

internal fun buildBackCameraTopology(
    logicalCameraId: String?,
    physicalLenses: List<PhysicalLensDescriptor>
): BackCameraTopology {
    val usableLenses = physicalLenses.filter { it.focalLengthMm != null }
    val wideLens = usableLenses.minWithOrNull(
        compareBy<PhysicalLensDescriptor>(
            { it.normalizedFocalLength ?: it.focalLengthMm ?: Float.MAX_VALUE },
            { it.cameraId }
        )
    )
    if (wideLens == null) {
        return BackCameraTopology(logicalCameraId, physicalLenses)
    }

    val telephoto = usableLenses
        .asSequence()
        .filter { it.cameraId != wideLens.cameraId }
        .mapNotNull { lens ->
            opticalRatioBetween(wideLens, lens)?.let { ratio -> lens to ratio }
        }
        .filter { (_, ratio) -> ratio >= TELEPHOTO_OPTICAL_RATIO_THRESHOLD }
        .maxByOrNull { (_, ratio) -> ratio }

    return BackCameraTopology(
        logicalCameraId = logicalCameraId,
        physicalLenses = physicalLenses,
        wideLens = wideLens,
        telephotoLens = telephoto?.first,
        telephotoOpticalRatio = telephoto?.second
    )
}

internal fun decideLensSwitch(
    requestedZoomRatio: Float,
    currentOutputTarget: LensOutputTarget,
    topology: BackCameraTopology?,
    blockedPhysicalCameraIds: Set<String>,
    maxUserZoomRatio: Float = USER_MAX_ZOOM_RATIO
): LensSwitchDecision {
    val telephoto = topology?.telephotoLens
    val opticalRatio = topology?.telephotoOpticalRatio
    if (
        telephoto == null ||
        opticalRatio == null ||
        opticalRatio > maxUserZoomRatio ||
        telephoto.cameraId in blockedPhysicalCameraIds
    ) {
        return LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
    }

    val useTelephoto = when (currentOutputTarget) {
        LensOutputTarget.LOGICAL_WIDE -> requestedZoomRatio >= opticalRatio
        LensOutputTarget.PHYSICAL_TELE ->
            requestedZoomRatio >
                opticalRatio * TELEPHOTO_SWITCH_BACK_RATIO + TELEPHOTO_SWITCH_EPSILON
    }

    return if (useTelephoto) {
        LensSwitchDecision(
            outputTarget = LensOutputTarget.PHYSICAL_TELE,
            physicalCameraId = telephoto.cameraId,
            telephotoOpticalRatio = opticalRatio
        )
    } else {
        LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
    }
}

internal fun localZoomRatioFor(
    requestedZoomRatio: Float,
    decision: LensSwitchDecision
): Float {
    val opticalRatio = decision.telephotoOpticalRatio
    return if (
        decision.outputTarget == LensOutputTarget.PHYSICAL_TELE &&
        opticalRatio != null &&
        opticalRatio > 0f
    ) {
        requestedZoomRatio / opticalRatio
    } else {
        requestedZoomRatio
    }
}

private fun opticalRatioBetween(
    wideLens: PhysicalLensDescriptor,
    candidateLens: PhysicalLensDescriptor
): Float? {
    val wideNormalized = wideLens.normalizedFocalLength
    val candidateNormalized = candidateLens.normalizedFocalLength
    if (wideNormalized != null && candidateNormalized != null && wideNormalized > 0f) {
        return candidateNormalized / wideNormalized
    }

    val wideFocalLength = wideLens.focalLengthMm
    val candidateFocalLength = candidateLens.focalLengthMm
    return if (
        wideFocalLength != null &&
        candidateFocalLength != null &&
        wideFocalLength > 0f
    ) {
        candidateFocalLength / wideFocalLength
    } else {
        null
    }
}
