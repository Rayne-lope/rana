package com.rana.app.rana

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Rect
import android.content.Context
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.os.Build
import android.util.Size
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import java.util.Locale
import kotlin.math.roundToInt

const val RANA_DIGITAL_ZOOM_WARNING_RATIO = 2f

private const val RANA_QUALITY_AUDIT_TAG = "RanaQualityAudit"
private const val TELEPHOTO_FOCAL_SPREAD_THRESHOLD = 1.8f
private const val ZOOMED_THRESHOLD = 1.01f

internal data class ZoomQualityEstimate(
    val hasTelephotoCandidate: Boolean,
    val isLikelyDigitalZoom: Boolean,
    val shouldWarnDigitalZoom: Boolean,
    val focalLengthSpread: Float,
    val zoomQualityLabel: String
)

internal fun estimateZoomQuality(
    requestedZoomRatio: Float,
    hasLogicalMultiCamera: Boolean,
    physicalCameraCount: Int,
    minFocalLength: Float?,
    maxFocalLength: Float?
): ZoomQualityEstimate {
    val isZoomed = requestedZoomRatio > ZOOMED_THRESHOLD
    val focalSpread = if (
        minFocalLength != null &&
        maxFocalLength != null &&
        minFocalLength > 0f &&
        maxFocalLength >= minFocalLength
    ) {
        maxFocalLength / minFocalLength
    } else {
        1f
    }
    val hasTelephotoCandidate = focalSpread >= TELEPHOTO_FOCAL_SPREAD_THRESHOLD
    val hasCameraSwitchingHint = hasLogicalMultiCamera || physicalCameraCount > 1
    val isLikelyDigitalZoom = isZoomed && !hasTelephotoCandidate
    val shouldWarnDigitalZoom =
        requestedZoomRatio >= RANA_DIGITAL_ZOOM_WARNING_RATIO && isLikelyDigitalZoom
    val zoomQualityLabel = when {
        !isZoomed -> "native"
        hasTelephotoCandidate -> "tele_candidate"
        hasCameraSwitchingHint -> "multi_camera_unknown"
        else -> "digital_likely"
    }

    return ZoomQualityEstimate(
        hasTelephotoCandidate = hasTelephotoCandidate,
        isLikelyDigitalZoom = isLikelyDigitalZoom,
        shouldWarnDigitalZoom = shouldWarnDigitalZoom,
        focalLengthSpread = focalSpread,
        zoomQualityLabel = zoomQualityLabel
    )
}

@SuppressLint("RestrictedApi")
@androidx.annotation.OptIn(markerClass = [ExperimentalCamera2Interop::class])
object CameraQualityAudit {
    fun logBackCameraInventory(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return
        val cameraIds = runCatching { cameraManager.cameraIdList.toSet() }.getOrDefault(emptySet())

        for (cameraId in cameraIds.sorted()) {
            val characteristics = runCatching {
                cameraManager.getCameraCharacteristics(cameraId)
            }.getOrNull() ?: continue
            if (characteristics.get(CameraCharacteristics.LENS_FACING) !=
                CameraCharacteristics.LENS_FACING_BACK
            ) {
                continue
            }
            val capabilities = characteristics.get(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES
            ) ?: intArrayOf()
            if (!capabilities.contains(
                    CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                )
            ) {
                continue
            }
            val topology = buildBackCameraTopology(
                logicalCameraId = cameraId,
                physicalLenses = characteristics.physicalCameraIds.sorted().map { physicalCameraId ->
                    physicalLensDescriptor(
                        cameraId = physicalCameraId,
                        characteristics = runCatching {
                            cameraManager.getCameraCharacteristics(physicalCameraId)
                        }.getOrNull(),
                        isStandalone = physicalCameraId in cameraIds
                    )
                }
            )
            logBackCameraTopology("inventory", topology)
        }
    }

    internal fun inspectActiveBackCameraTopology(
        context: Context,
        camera: Camera?
    ): BackCameraTopology {
        if (camera == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return BackCameraTopology()
        }
        return runCatching {
            val camera2Info = Camera2CameraInfo.from(camera.cameraInfo)
            val activeCharacteristics = Camera2CameraInfo.extractCameraCharacteristics(
                camera.cameraInfo
            )
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            val cameraIds = runCatching { cameraManager?.cameraIdList?.toSet().orEmpty() }
                .getOrDefault(emptySet())
            val activeCameraId = camera2Info.cameraId
            val activeCapabilities = activeCharacteristics.get(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES
            ) ?: intArrayOf()
            val activeIsLogical = activeCapabilities.contains(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
            )
            val logicalCameraId = if (activeIsLogical) {
                activeCameraId
            } else {
                cameraIds.firstOrNull { cameraId ->
                    val characteristics = runCatching {
                        cameraManager?.getCameraCharacteristics(cameraId)
                    }.getOrNull() ?: return@firstOrNull false
                    val capabilities = characteristics.get(
                        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES
                    ) ?: intArrayOf()
                    capabilities.contains(
                        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                    ) && activeCameraId in characteristics.physicalCameraIds
                }
            }
            if (logicalCameraId == null) {
                return@runCatching BackCameraTopology(logicalCameraId = activeCameraId)
            }
            val logicalCharacteristics = if (logicalCameraId == activeCameraId) {
                activeCharacteristics
            } else {
                runCatching {
                    cameraManager?.getCameraCharacteristics(logicalCameraId)
                }.getOrNull() ?: return@runCatching BackCameraTopology(logicalCameraId)
            }
            val characteristicsMap = runCatching {
                camera2Info.cameraCharacteristicsMap
            }.getOrDefault(emptyMap())
            val physicalLenses = logicalCharacteristics.physicalCameraIds.sorted().map { physicalCameraId ->
                val physicalCharacteristics = characteristicsMap[physicalCameraId]
                    ?: runCatching {
                        cameraManager?.getCameraCharacteristics(physicalCameraId)
                    }.getOrNull()
                physicalLensDescriptor(
                    cameraId = physicalCameraId,
                    characteristics = physicalCharacteristics,
                    isStandalone = physicalCameraId in cameraIds
                )
            }
            buildBackCameraTopology(logicalCameraId, physicalLenses)
        }.getOrElse { error ->
            android.util.Log.w(
                RANA_QUALITY_AUDIT_TAG,
                "event=telephoto_topology_read_failed message=${error.message}"
            )
            BackCameraTopology()
        }
    }

    internal fun logBackCameraTopology(status: String, topology: BackCameraTopology) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=back_camera_topology status=$status " +
                "logicalCameraId=${topology.logicalCameraId ?: "unknown"} " +
                "wideCameraId=${topology.wideLens?.cameraId ?: "unknown"} " +
                "teleCameraId=${topology.telephotoLens?.cameraId ?: "none"} " +
                "teleOpticalRatio=${fmt(topology.telephotoOpticalRatio ?: 1f)} " +
                "physicalLenses=${topology.physicalLenses.toAuditValue()}"
        )
    }

    internal fun logLensSwitch(
        viewId: Int,
        status: String,
        requestedZoomRatio: Float,
        decision: LensSwitchDecision,
        observedPhysicalCameraId: String? = null
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=physical_lens_switch viewId=$viewId status=$status " +
                "requestedZoom=${fmt(requestedZoomRatio)} " +
                "target=${decision.physicalCameraId ?: "logical"} " +
                "observed=${observedPhysicalCameraId ?: "unknown"} " +
                "teleOpticalRatio=${fmt(decision.telephotoOpticalRatio ?: 1f)}"
        )
    }

    fun zoomFields(camera: Camera?, requestedZoomRatio: Float): Map<String, Any> {
        val capabilities = inspectCamera(camera)
        val estimate = estimateZoomQuality(
            requestedZoomRatio = requestedZoomRatio,
            hasLogicalMultiCamera = capabilities.hasLogicalMultiCamera,
            physicalCameraCount = capabilities.physicalCameraIds.size,
            minFocalLength = capabilities.minFocalLength,
            maxFocalLength = capabilities.maxFocalLength
        )

        return mapOf(
            "activeCameraId" to (capabilities.activeCameraId ?: "unknown"),
            "physicalCameraIds" to capabilities.physicalCameraIds.joinToString(","),
            "physicalCameraCount" to capabilities.physicalCameraIds.size,
            "hasLogicalMultiCamera" to capabilities.hasLogicalMultiCamera,
            "availableFocalLengths" to capabilities.focalLengths.joinToString(",") {
                String.format(Locale.US, "%.2f", it)
            },
            "focalLengthSpread" to estimate.focalLengthSpread.toDouble(),
            "hasTelephotoCandidate" to estimate.hasTelephotoCandidate,
            "isLikelyDigitalZoom" to estimate.isLikelyDigitalZoom,
            "shouldWarnDigitalZoom" to estimate.shouldWarnDigitalZoom,
            "zoomQualityLabel" to estimate.zoomQualityLabel
        )
    }

    fun logPreviewSurfaceRequest(
        viewId: Int,
        resolution: Size,
        aspectRatio: CameraAspectRatio,
        zoomRatio: Float
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=preview_surface_request viewId=$viewId " +
                "buffer=${resolution.width}x${resolution.height} " +
                "aspect=${aspectRatio.channelValue} zoom=${fmt(zoomRatio)}"
        )
    }

    fun logPreviewTransform(
        viewId: Int,
        cropRect: Rect,
        rotationDegrees: Int,
        zoomRatio: Float
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=preview_transform viewId=$viewId " +
                "crop=${cropRect.flattenToString()} " +
                "rotation=$rotationDegrees zoom=${fmt(zoomRatio)}"
        )
    }

    fun logCameraBinding(
        viewId: Int,
        camera: Camera?,
        preview: Preview,
        imageCapture: ImageCapture,
        aspectRatio: CameraAspectRatio,
        zoomRatio: Float
    ) {
        val fields = zoomFields(camera, zoomRatio)
        val previewResolution = preview.resolutionInfo?.resolution?.toSizeString() ?: "unknown"
        val captureInfo = imageCapture.resolutionInfo
        val captureResolution = captureInfo?.resolution?.toSizeString() ?: "unknown"
        val captureCrop = captureInfo?.cropRect?.flattenToString() ?: "unknown"
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=camera_bound viewId=$viewId aspect=${aspectRatio.channelValue} " +
                "zoom=${fmt(zoomRatio)} previewResolution=$previewResolution " +
                "captureResolution=$captureResolution captureCrop=$captureCrop " +
                fields.toAuditString()
        )
    }

    fun logZoomState(viewId: Int, status: String, fields: Map<String, Any>) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=zoom_state viewId=$viewId status=$status ${fields.toAuditString()}"
        )
    }

    fun logCaptureRequest(
        viewId: Int,
        captureId: String,
        aspectRatio: CameraAspectRatio,
        zoomRatio: Float,
        imageCapture: ImageCapture,
        targetRotation: Int,
        displayRotation: Int,
        orientationSource: String
    ) {
        val captureInfo = imageCapture.resolutionInfo
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=capture_request viewId=$viewId captureId=$captureId " +
                "aspect=${aspectRatio.channelValue} zoom=${fmt(zoomRatio)} " +
                "targetRotation=$targetRotation displayRotation=$displayRotation " +
                "orientationSource=$orientationSource " +
                "captureResolution=${captureInfo?.resolution?.toSizeString() ?: "unknown"} " +
                "captureCrop=${captureInfo?.cropRect?.flattenToString() ?: "unknown"}"
        )
    }

    fun logCaptureRotation(
        viewId: Int,
        captureId: String,
        targetRotation: Int,
        displayRotation: Int,
        orientationSource: String,
        imageRotationDegrees: Int
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=capture_rotation viewId=$viewId captureId=$captureId " +
                "targetRotation=$targetRotation displayRotation=$displayRotation " +
                "orientationSource=$orientationSource " +
                "imageRotationDegrees=$imageRotationDegrees"
        )
    }

    fun logCaptureGeometry(
        viewId: Int,
        captureId: String,
        aspectRatio: CameraAspectRatio,
        targetRotation: Int,
        imageCropRect: Rect,
        imageRotationDegrees: Int,
        outputBitmap: Bitmap
    ) {
        val expectedAspectRatio = expectedCaptureOutputAspectRatio(
            aspectRatio = aspectRatio,
            targetRotation = targetRotation
        )
        val actualAspectRatio = outputBitmap.width.toFloat() / outputBitmap.height.toFloat()
        val aspectMatches = kotlin.math.abs(actualAspectRatio - expectedAspectRatio) <= 0.02f
        val message =
            "event=capture_geometry viewId=$viewId captureId=$captureId " +
                "aspect=${aspectRatio.channelValue} targetRotation=$targetRotation " +
                "imageRotationDegrees=$imageRotationDegrees " +
                "crop=${imageCropRect.flattenToString()} " +
                "output=${outputBitmap.width}x${outputBitmap.height} " +
                "expectedRatio=${fmt(expectedAspectRatio)} " +
                "actualRatio=${fmt(actualAspectRatio)} aspectMatches=$aspectMatches"
        if (aspectMatches) {
            android.util.Log.d(RANA_QUALITY_AUDIT_TAG, message)
        } else {
            android.util.Log.w(RANA_QUALITY_AUDIT_TAG, message)
        }
    }

    fun logDecodePlan(
        viewId: Int,
        sourceWidth: Int,
        sourceHeight: Int,
        zoomRatio: Float,
        processingPlan: MemoryUtils.ProcessingPlan
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=decode_plan viewId=$viewId source=${sourceWidth}x$sourceHeight " +
                "zoom=${fmt(zoomRatio)} inSampleSize=${processingPlan.inSampleSize} " +
                "qualityReduced=${processingPlan.qualityReduced} " +
                "skipLut=${processingPlan.skipLut} " +
                "availableMb=${processingPlan.availableMb}"
        )
    }

    fun logBitmapStage(viewId: Int, stage: String, bitmap: Bitmap?, zoomRatio: Float) {
        if (bitmap == null) return
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=bitmap_stage viewId=$viewId stage=$stage " +
                "size=${bitmap.width}x${bitmap.height} zoom=${fmt(zoomRatio)}"
        )
    }

    fun logCaptureSaved(
        viewId: Int,
        bitmap: Bitmap,
        bytesWritten: Long,
        zoomRatio: Float
    ) {
        android.util.Log.d(
            RANA_QUALITY_AUDIT_TAG,
            "event=capture_saved viewId=$viewId output=${bitmap.width}x${bitmap.height} " +
                "jpegBytes=$bytesWritten zoom=${fmt(zoomRatio)}"
        )
    }

    private fun inspectCamera(camera: Camera?): CameraCapabilitySnapshot {
        if (camera == null) return CameraCapabilitySnapshot()
        return runCatching {
            val camera2Info = Camera2CameraInfo.from(camera.cameraInfo)
            val activeCharacteristics = runCatching {
                Camera2CameraInfo.extractCameraCharacteristics(camera.cameraInfo)
            }.getOrNull()
            val characteristicsMap = runCatching {
                camera2Info.cameraCharacteristicsMap
            }.getOrDefault(emptyMap())
            val allCharacteristics = if (characteristicsMap.isNotEmpty()) {
                characteristicsMap.values.toList()
            } else {
                listOfNotNull(activeCharacteristics)
            }
            val focalLengths = allCharacteristics
                .flatMap {
                    it.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                        ?.toList()
                        .orEmpty()
                }
                .filter { it > 0f && it.isFinite() }
                .distinctBy { (it * 100f).roundToInt() }
                .sorted()

            val availableCapabilities = activeCharacteristics?.get(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES
            )
            val hasLogicalMultiCamera =
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                    availableCapabilities?.contains(
                        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                    ) == true
            val physicalCameraIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                activeCharacteristics?.physicalCameraIds?.toList().orEmpty().sorted()
            } else {
                emptyList()
            }

            CameraCapabilitySnapshot(
                activeCameraId = camera2Info.cameraId,
                physicalCameraIds = physicalCameraIds,
                hasLogicalMultiCamera = hasLogicalMultiCamera,
                focalLengths = focalLengths,
                minFocalLength = focalLengths.firstOrNull(),
                maxFocalLength = focalLengths.lastOrNull()
            )
        }.getOrElse { error ->
            android.util.Log.w(
                RANA_QUALITY_AUDIT_TAG,
                "event=camera_capability_read_failed message=${error.message}"
            )
            CameraCapabilitySnapshot()
        }
    }

    private fun fmt(value: Float): String = String.format(Locale.US, "%.2f", value)

    private fun physicalLensDescriptor(
        cameraId: String,
        characteristics: CameraCharacteristics?,
        isStandalone: Boolean
    ): PhysicalLensDescriptor {
        val focalLength = characteristics
            ?.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            ?.filter { it > 0f && it.isFinite() }
            ?.maxOrNull()
        val sensorWidth = characteristics
            ?.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            ?.width
            ?.takeIf { it > 0f && it.isFinite() }
        return PhysicalLensDescriptor(cameraId, focalLength, sensorWidth, isStandalone)
    }

    private fun Size.toSizeString(): String = "${width}x${height}"

    private fun List<PhysicalLensDescriptor>.toAuditValue(): String = joinToString(";") {
        "${it.cameraId},focal=${fmt(it.focalLengthMm ?: 0f)}," +
            "sensorWidth=${fmt(it.sensorWidthMm ?: 0f)}," +
            "normalized=${fmt(it.normalizedFocalLength ?: 0f)}," +
            "longFocal=${it.hasLongFocalLength}," +
            "standalone=${it.isStandalone}"
    }

    private fun Map<String, Any>.toAuditString(): String = entries.joinToString(" ") {
        "${it.key}=${it.value}"
    }
}

private data class CameraCapabilitySnapshot(
    val activeCameraId: String? = null,
    val physicalCameraIds: List<String> = emptyList(),
    val hasLogicalMultiCamera: Boolean = false,
    val focalLengths: List<Float> = emptyList(),
    val minFocalLength: Float? = null,
    val maxFocalLength: Float? = null
)
