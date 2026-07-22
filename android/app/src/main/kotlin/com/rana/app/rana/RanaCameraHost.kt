package com.rana.app.rana

import android.net.Uri
import android.os.Build
import android.os.SystemClock
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture

/** Typed Pigeon host adapter. Camera and media ownership remain outside the Activity. */
internal class RanaCameraHost(private val activity: MainActivity) : RanaCameraHostApi {
    override fun initializeCamera(
        request: InitializeCameraRequest,
        callback: (Result<CameraOperationResult>) -> Unit
    ) {
        val preview = try {
            activity.resolveAndActivateCameraPreview(request.platformViewId)
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        val startedAt = SystemClock.elapsedRealtime()
        preview.initialize(request) { result ->
            activity.recordTelemetry(
                RanaTelemetryMetric.CAMERA_INITIALIZE_MS,
                (SystemClock.elapsedRealtime() - startedAt).toDouble()
            )
            callback(result)
        }
    }

    override fun releaseCamera(): CameraOperationResult {
        activity.releaseActiveCameraPreview()
        return CameraOperationResult(status = "released")
    }

    override fun getOutputCapabilities(): OutputCapabilitiesMessage {
        val capabilities = outputCapabilities()
        return OutputCapabilitiesMessage(
            isHeicSupported = capabilities.isHeicSupported,
            unavailableReason = capabilities.unavailableReason
        )
    }

    override fun getPermissionCapabilities(): PermissionCapabilitiesMessage =
        PermissionCapabilitiesMessage(
            requiresLegacyStorageForCapture =
                Build.VERSION.SDK_INT <= Build.VERSION_CODES.P,
            galleryReadPermission = if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            ) {
                "photos"
            } else {
                "storage"
            }
        )

    override fun applyRecipe(recipe: RenderRecipeMessage): CameraOperationResult {
        activity.requireActiveCameraPreview().applyRecipe(recipe.toDomainRecipe())
        return CameraOperationResult(status = "preset_selected")
    }

    override fun beginCapture(
        request: CaptureRequestMessage,
        callback: (Result<CaptureAcceptedMessage>) -> Unit
    ) {
        val preview = try {
            activity.requireActiveCameraPreview()
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        val params = try {
            request.recipe.toDomainRecipe().toOfflineProcessParams(request.filmRollId)
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        val captureId = activity.nextCaptureId()
        val startedAt = SystemClock.elapsedRealtime()
        callback(Result.success(CaptureAcceptedMessage("capture_started", captureId)))
        activity.recordTelemetry(
            RanaTelemetryMetric.CAPTURE_ACCEPT_MS,
            (SystemClock.elapsedRealtime() - startedAt).toDouble()
        )
        activity.dispatchCaptureProgress(captureId, "native_request", startedAt)
        preview.takePicture(
            params,
            captureId = captureId,
            onProgress = { phase ->
                activity.dispatchCaptureProgress(captureId, phase, startedAt)
            }
        ) { success, uri, quality, errorCode, errorMessage ->
            if (success && uri != null) {
                activity.dispatchCaptureCompleted(captureId, uri, quality, startedAt)
            } else {
                activity.dispatchCaptureFailed(
                    captureId,
                    errorCode ?: "CAPTURE_FAILED",
                    errorMessage ?: "Unknown error",
                    startedAt
                )
            }
        }
    }

    override fun executeCapture(
        request: CaptureRequestMessage,
        callback: (Result<CaptureResultMessage>) -> Unit
    ) {
        val preview = try {
            activity.requireActiveCameraPreview()
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        val params = try {
            request.recipe.toDomainRecipe().toOfflineProcessParams(request.filmRollId)
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        preview.takePicture(params) { success, uri, quality, errorCode, errorMessage ->
            if (success) {
                callback(Result.success(quality.toPigeonCaptureResult("captured", uri)))
            } else {
                callback(
                    Result.failure(
                        FlutterError(
                            errorCode ?: "CAPTURE_FAILED",
                            errorMessage ?: "Unknown error",
                            null
                        )
                    )
                )
            }
        }
    }

    override fun setFlashMode(flashMode: String): CameraOperationResult {
        val nativeMode = when (flashMode) {
            "on" -> ImageCapture.FLASH_MODE_ON
            "auto" -> ImageCapture.FLASH_MODE_AUTO
            else -> ImageCapture.FLASH_MODE_OFF
        }
        activity.requireActiveCameraPreview().setFlashMode(nativeMode)
        return CameraOperationResult(status = "flash_set")
    }

    override fun setZoomRatio(
        zoomRatio: Double,
        callback: (Result<CameraOperationResult>) -> Unit
    ) {
        val preview = try {
            activity.requireActiveCameraPreview()
        } catch (failure: Throwable) {
            callback(Result.failure(failure))
            return
        }
        preview.setZoomRatio(zoomRatio.toFloat()) { payload, errorCode, errorMessage ->
            if (payload != null) {
                callback(Result.success(payload.toOperationResult()))
            } else {
                callback(
                    Result.failure(
                        FlutterError(
                            errorCode ?: "ZOOM_FAILED",
                            errorMessage ?: "Unable to set camera zoom",
                            null
                        )
                    )
                )
            }
        }
    }

    override fun setFocusAndMetering(x: Double, y: Double) {
        activity.requireActiveCameraPreview().setFocusAndMetering(x.toFloat(), y.toFloat())
    }

    override fun cancelFocusAndMetering() {
        activity.requireActiveCameraPreview().cancelFocusAndMetering()
    }

    override fun toggleLens(currentLens: String): CameraOperationResult {
        val preview = activity.requireActiveCameraPreview()
        val targetLens = if (currentLens == "back") {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }
        preview.setLensFacing(targetLens)
        val lens = if (targetLens == CameraSelector.LENS_FACING_BACK) "back" else "front"
        return preview.zoomStateFields(USER_MIN_ZOOM_RATIO).toOperationResult(
            status = "lens_toggled",
            lens = lens
        )
    }

    override fun setAspectRatio(aspectRatio: String): CameraOperationResult {
        val preview = activity.requireActiveCameraPreview()
        preview.setAspectRatio(aspectRatio)
        return preview.zoomStateFields().toOperationResult(
            status = "aspect_ratio_set",
            aspectRatio = aspectRatio,
            label = CameraAspectRatio.fromChannelValue(aspectRatio).label
        )
    }

    override fun loadCapturedImageBytes(
        uri: String,
        targetSize: Long?,
        callback: (Result<ByteArray>) -> Unit
    ) {
        if (uri.isBlank()) {
            callback(Result.failure(FlutterError("INVALID_URI", "Image URI is required")))
            return
        }
        activity.executeMediaTask {
            callback(
                runCatching {
                    activity.readCapturedImageBytes(Uri.parse(uri), targetSize?.toInt())
                }.mapFailure("LOAD_IMAGE_FAILED")
            )
        }
    }

    override fun listFilmRollCaptures(
        filmRollId: String,
        callback: (Result<List<FilmRollCaptureMessage>>) -> Unit
    ) {
        if (filmRollId.isBlank()) {
            callback(
                Result.failure(FlutterError("INVALID_FILM_ROLL_ID", "Film Roll ID is required"))
            )
            return
        }
        activity.executeMediaTask {
            callback(
                runCatching {
                    activity.readFilmRollCaptures(filmRollId).map {
                        FilmRollCaptureMessage(it.mediaUri, it.capturedAtEpochMs)
                    }
                }.mapFailure("LIST_FILM_ROLL_CAPTURES_FAILED")
            )
        }
    }

    override fun getCaptureStyleMetadata(
        uri: String,
        callback: (Result<CaptureStyleMetadataMessage?>) -> Unit
    ) {
        if (uri.isBlank()) {
            callback(Result.failure(FlutterError("INVALID_URI", "Image URI is required")))
            return
        }
        activity.executeMediaTask {
            callback(
                runCatching { activity.readCaptureStyleMetadata(uri)?.toPigeonMessage() }
                    .mapFailure("GET_METADATA_FAILED")
            )
        }
    }

    override fun getCaptureStyleMetadataBatch(
        uris: List<String>,
        callback: (Result<List<CaptureStyleMetadataMessage>>) -> Unit
    ) {
        activity.executeMediaTask {
            callback(
                runCatching {
                    activity.readCaptureStyleMetadataBatch(uris).map { it.toPigeonMessage() }
                }.mapFailure("GET_METADATA_BATCH_FAILED")
            )
        }
    }

    override fun openMediaInGallery(uri: String) {
        if (uri.isBlank()) throw FlutterError("INVALID_URI", "Image URI is required")
        activity.openMediaInGallery(Uri.parse(uri))
    }
}

private fun Map<String, Any>.toOperationResult(
    status: String = this["status"] as? String ?: "zoom_set",
    lens: String? = null,
    aspectRatio: String? = null,
    label: String? = null
): CameraOperationResult = CameraOperationResult(
    status = status,
    lens = lens,
    aspectRatio = aspectRatio,
    label = label,
    zoomRatio = (this["zoomRatio"] as? Number)?.toDouble(),
    minZoomRatio = (this["minZoomRatio"] as? Number)?.toDouble(),
    maxZoomRatio = (this["maxZoomRatio"] as? Number)?.toDouble(),
    isLikelyDigitalZoom = this["isLikelyDigitalZoom"] as? Boolean,
    shouldWarnDigitalZoom = this["shouldWarnDigitalZoom"] as? Boolean,
    hasTelephotoCandidate = this["hasTelephotoCandidate"] as? Boolean,
    zoomQualityLabel = this["zoomQualityLabel"] as? String
)

private fun <T> Result<T>.mapFailure(code: String): Result<T> = fold(
    onSuccess = Result.Companion::success,
    onFailure = { failure -> Result.failure(FlutterError(code, failure.message, null)) }
)
