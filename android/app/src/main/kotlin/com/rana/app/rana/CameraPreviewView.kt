package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.SurfaceTexture
import android.graphics.drawable.BitmapDrawable
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Display
import android.view.OrientationEventListener
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.core.Camera
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.DisplayOrientedMeteringPointFactory
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@OptIn(ExperimentalCamera2Interop::class)
class CameraPreviewView(
    private val context: Context,
    private val activity: MainActivity,
    private val viewId: Int,
    private val creationParams: Map<String, Any>?
) : PlatformView {

    private val previewContainer = FrameLayout(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    private val textureView = TextureView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    private val lensSwitchOverlay = ImageView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        scaleType = ImageView.ScaleType.CENTER_CROP
        visibility = View.GONE
    }
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var previewUseCase: Preview? = null
    private var glRenderer: CameraGlRenderer? = null
    private var lastPresetParams: Map<String, Any>? = null
    private var currentAspectRatio = CameraAspectRatio.fromChannelValue(
        creationParams?.get("aspectRatio") as? String
    )

    private var currentLensFacing = when (creationParams?.get("lens") as? String) {
        "front" -> CameraSelector.LENS_FACING_FRONT
        else -> CameraSelector.LENS_FACING_BACK
    }
    private var currentFlashMode = when (creationParams?.get("flashMode") as? String) {
        "on" -> ImageCapture.FLASH_MODE_ON
        "auto" -> ImageCapture.FLASH_MODE_AUTO
        else -> ImageCapture.FLASH_MODE_OFF
    }
    private var currentZoomRatio = clampUserZoomRatio(
        requestedZoomRatio =
            (creationParams?.get("zoomRatio") as? Number)?.toFloat()
                ?: USER_MIN_ZOOM_RATIO,
        nativeMinZoomRatio = null,
        nativeMaxZoomRatio = null
    )
    private var lastSensorTargetRotation: Int? = null
    private val captureExecutor = Executors.newSingleThreadExecutor()
    private val isCapturing = AtomicBoolean(false)
    private var previewBindGeneration = 0
    private var backCameraTopology = BackCameraTopology()
    private var activeLensDecision = LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
    private var pendingLensDecision: LensSwitchDecision? = null
    private val blockedPhysicalCameraIds = mutableSetOf<String>()
    private var observedPhysicalCameraId: String? = null
    private var currentLocalZoomRatio = USER_MIN_ZOOM_RATIO
    private var isLensSwitching = false
    private var lensSwitchTimeout: Runnable? = null

    private val orientationEventListener = object : OrientationEventListener(context) {
        override fun onOrientationChanged(orientation: Int) {
            val rotation = sensorOrientationToSurfaceRotation(orientation) ?: return
            lastSensorTargetRotation = rotation
            previewUseCase?.targetRotation = rotation
            imageCapture?.targetRotation = rotation
        }
    }

    init {
        android.util.Log.d(
            "CameraPreviewView",
            "Initializing CameraPreviewView: id=$viewId, lens=$currentLensFacing, flash=$currentFlashMode, aspectRatio=$currentAspectRatio"
        )
        previewContainer.addView(textureView)
        previewContainer.addView(lensSwitchOverlay)
        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(
                surfaceTexture: SurfaceTexture, width: Int, height: Int
            ) {
                val renderer = CameraGlRenderer(
                    context,
                    surfaceTexture,
                    width,
                    height,
                    onInputSurfaceReady = { _ -> bindPreview() },
                    onFpsUpdate = { fps ->
                        activity.dispatchPreviewFps(fps)
                    },
                    onGlError = { error ->
                        android.util.Log.e(
                            "CameraPreviewView",
                            "OpenGL ES initialization failed: $error"
                        )
                    },
                    onPreviewFrameRendered = { bindingGeneration ->
                        activity.runOnUiThread {
                            onPreviewFrameRendered(bindingGeneration)
                        }
                    }
                )
                glRenderer = renderer
                lastPresetParams?.let { applyPresetParamsToRenderer(renderer, it) }
            }

            override fun onSurfaceTextureSizeChanged(surfaceTexture: SurfaceTexture, width: Int, height: Int) {
                glRenderer?.setViewportSize(width, height)
            }

            override fun onSurfaceTextureDestroyed(surfaceTexture: SurfaceTexture): Boolean {
                unbindCamera()
                glRenderer?.release()
                glRenderer = null
                return true
            }

            override fun onSurfaceTextureUpdated(surfaceTexture: SurfaceTexture) {
                // No-op
            }
        }
        startCamera()
    }

    override fun getView(): View {
        return previewContainer
    }

    override fun dispose() {
        activity.runOnUiThread {
            try {
                if (activity.activePreviewView == this) {
                    activity.activePreviewView = null
                }
                unbindCamera()
                glRenderer?.release()
                glRenderer = null
                OfflineGlProcessor.release()
                captureExecutor.shutdown()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                CameraQualityAudit.logBackCameraInventory(context)
                bindPreview()
            } catch (e: Exception) {
                // Ignore
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun bindPreview() {
        rebindCamera(activeLensDecision, "preview_bind")
    }

    private fun rebindCamera(
        requestedDecision: LensSwitchDecision,
        reason: String
    ) {
        val provider = cameraProvider ?: return
        val renderer = glRenderer ?: return
        activity.runOnUiThread {
            val decision = if (currentLensFacing == CameraSelector.LENS_FACING_BACK) {
                requestedDecision
            } else {
                LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
            }
            try {
                previewBindGeneration += 1
                val bindGeneration = previewBindGeneration
                camera?.cameraControl?.cancelFocusAndMetering()
                provider.unbindAll()
                camera = null
                previewUseCase = null
                imageCapture = null

                val displayRotation = currentDisplayRotation()
                val resolutionSelector = currentAspectRatio.resolutionSelector()
                val viewPort = currentAspectRatio.viewPort(displayRotation)

                val previewBuilder = Preview.Builder()
                    .setTargetRotation(displayRotation)
                    .setResolutionSelector(resolutionSelector)
                decision.physicalCameraId?.let { physicalCameraId ->
                    Camera2Interop.Extender(previewBuilder)
                        .setPhysicalCameraId(physicalCameraId)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    Camera2Interop.Extender(previewBuilder)
                        .setSessionCaptureCallback(
                            physicalCameraCaptureCallback(bindGeneration, decision)
                        )
                }
                val previewUseCase = previewBuilder.build().also { preview ->
                    preview.setSurfaceProvider { request ->
                        val resolution = request.resolution
                        CameraQualityAudit.logPreviewSurfaceRequest(
                            viewId = viewId,
                            resolution = resolution,
                            aspectRatio = currentAspectRatio,
                            zoomRatio = currentZoomRatio
                        )
                        val cameraSurfaceTexture = renderer.cameraSurfaceTexture
                        if (cameraSurfaceTexture != null) {
                            cameraSurfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
                            renderer.setPreviewFrameConfig(
                                bufferWidth = resolution.width,
                                bufferHeight = resolution.height,
                                fallbackAspectRatio = currentAspectRatio.viewfinderRatio,
                                mirrorHorizontally =
                                    currentLensFacing == CameraSelector.LENS_FACING_FRONT,
                                bindingGeneration = bindGeneration
                            )

                            request.setTransformationInfoListener(
                                ContextCompat.getMainExecutor(context)
                            ) { info ->
                                if (bindGeneration != previewBindGeneration) return@setTransformationInfoListener
                                CameraQualityAudit.logPreviewTransform(
                                    viewId = viewId,
                                    cropRect = info.cropRect,
                                    rotationDegrees = info.rotationDegrees,
                                    zoomRatio = currentZoomRatio
                                )
                                renderer.setCameraTransform(
                                    info.cropRect,
                                    info.rotationDegrees,
                                    bindGeneration
                                )
                            }

                            val surface = Surface(cameraSurfaceTexture)
                            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                                surface.release()
                            }
                        } else {
                            request.willNotProvideSurface()
                        }
                    }
                }
                this.previewUseCase = previewUseCase

                val initialCaptureRotation = selectCaptureTargetRotation(
                    lastSensorTargetRotation = lastSensorTargetRotation,
                    displayRotation = displayRotation
                )
                val imageCaptureBuilder = ImageCapture.Builder()
                    .setTargetRotation(initialCaptureRotation.targetRotation)
                    .setResolutionSelector(resolutionSelector)
                    .setFlashMode(currentFlashMode)
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                decision.physicalCameraId?.let { physicalCameraId ->
                    Camera2Interop.Extender(imageCaptureBuilder)
                        .setPhysicalCameraId(physicalCameraId)
                }
                val imageCaptureUseCase = imageCaptureBuilder.build()
                imageCapture = imageCaptureUseCase

                val selectorBuilder = CameraSelector.Builder()
                    .requireLensFacing(currentLensFacing)
                val logicalCameraId = backCameraTopology.logicalCameraId
                if (
                    currentLensFacing == CameraSelector.LENS_FACING_BACK &&
                    logicalCameraId != null
                ) {
                    selectorBuilder.addCameraFilter { cameraInfos ->
                        cameraInfos.filter { cameraInfo ->
                            runCatching {
                                androidx.camera.camera2.interop.Camera2CameraInfo
                                    .from(cameraInfo)
                                    .cameraId == logicalCameraId
                            }.getOrDefault(false)
                        }
                    }
                }
                val cameraSelector = selectorBuilder.build()

                val useCaseGroup = UseCaseGroup.Builder()
                    .addUseCase(previewUseCase)
                    .addUseCase(imageCaptureUseCase)
                    .setViewPort(viewPort)
                    .build()

                this.camera = provider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    useCaseGroup
                )
                activeLensDecision = decision
                observedPhysicalCameraId = null
                if (
                    currentLensFacing == CameraSelector.LENS_FACING_BACK &&
                    backCameraTopology.physicalLenses.isEmpty()
                ) {
                    backCameraTopology = CameraQualityAudit.inspectActiveBackCameraTopology(
                        context,
                        camera
                    )
                    CameraQualityAudit.logBackCameraTopology("active", backCameraTopology)
                }
                applyCurrentZoomRatio()
                CameraQualityAudit.logCameraBinding(
                    viewId = viewId,
                    camera = camera,
                    preview = previewUseCase,
                    imageCapture = imageCaptureUseCase,
                    aspectRatio = currentAspectRatio,
                    zoomRatio = currentZoomRatio
                )

                if (orientationEventListener.canDetectOrientation()) {
                    orientationEventListener.enable()
                }
                if (isLensSwitching) {
                    scheduleLensSwitchTimeout(bindGeneration, decision)
                } else {
                    applyLensDecisionForCurrentZoom()
                }
            } catch (e: Exception) {
                handleRebindFailure(decision, reason, e)
            }
        }
    }

    fun setLensFacing(lensFacing: Int) {
        if (currentLensFacing == lensFacing) return
        currentLensFacing = lensFacing
        currentZoomRatio = USER_MIN_ZOOM_RATIO
        backCameraTopology = BackCameraTopology()
        activeLensDecision = LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
        pendingLensDecision = null
        blockedPhysicalCameraIds.clear()
        isLensSwitching = false
        cancelLensSwitchTimeout()
        hideLensSwitchOverlay(immediate = true)
        bindPreview()
    }

    fun setFlashMode(flashMode: Int) {
        currentFlashMode = flashMode
        imageCapture?.flashMode = flashMode
    }

    fun setAspectRatio(aspectRatioValue: String) {
        val nextAspectRatio = CameraAspectRatio.fromChannelValue(aspectRatioValue)
        if (currentAspectRatio == nextAspectRatio) return

        currentAspectRatio = nextAspectRatio
        bindPreview()
    }

    fun setZoomRatio(
        zoomRatio: Float,
        callback: (
            payload: Map<String, Any>?,
            errorCode: String?,
            errorMsg: String?
        ) -> Unit
    ) {
        activity.runOnUiThread {
            try {
                currentZoomRatio = clampUserZoomRatio(
                    requestedZoomRatio = zoomRatio,
                    nativeMinZoomRatio = null,
                    nativeMaxZoomRatio = null
                )
                if (camera == null) {
                    callback(zoomStatePayload("zoom_deferred", zoomRatio), null, null)
                    return@runOnUiThread
                }

                val desiredDecision = lensDecisionForCurrentZoom()
                if (isLensSwitching) {
                    pendingLensDecision = desiredDecision
                    callback(zoomStatePayload("lens_switching", zoomRatio), null, null)
                    return@runOnUiThread
                }
                if (!sameLensOutput(activeLensDecision, desiredDecision)) {
                    if (isCapturing.get()) {
                        pendingLensDecision = desiredDecision
                        CameraQualityAudit.logLensSwitch(
                            viewId,
                            "deferred_capture",
                            currentZoomRatio,
                            desiredDecision
                        )
                        callback(zoomStatePayload("lens_switch_deferred", zoomRatio), null, null)
                    } else {
                        beginLensSwitch(desiredDecision, "zoom_threshold")
                        callback(zoomStatePayload("lens_switching", zoomRatio), null, null)
                    }
                    return@runOnUiThread
                }

                val future = applyCurrentZoomRatio()
                if (future == null) {
                    callback(zoomStatePayload("zoom_deferred", zoomRatio), null, null)
                    return@runOnUiThread
                }
                future.addListener(
                    {
                        try {
                            future.get()
                            callback(zoomStatePayload("zoom_set", zoomRatio), null, null)
                        } catch (e: Exception) {
                            val cause = e.cause ?: e
                            if (cause.isZoomOperationCanceled()) {
                                callback(
                                    zoomStatePayload("zoom_superseded", zoomRatio),
                                    null,
                                    null
                                )
                            } else {
                                callback(
                                    null,
                                    "ZOOM_FAILED",
                                    cause.message ?: "Unable to set camera zoom"
                                )
                            }
                        }
                    },
                    ContextCompat.getMainExecutor(context)
                )
            } catch (e: Exception) {
                callback(null, "ZOOM_FAILED", e.message ?: "Unable to set camera zoom")
            }
        }
    }

    fun zoomStateFields(requestedZoomRatio: Float = currentZoomRatio): Map<String, Any> {
        val bounds = cameraZoomBounds(null, null)
        currentZoomRatio = clampUserZoomRatio(
            requestedZoomRatio = currentZoomRatio,
            nativeMinZoomRatio = null,
            nativeMaxZoomRatio = null
        )

        return mapOf(
            "requestedZoomRatio" to requestedZoomRatio.toDouble(),
            "zoomRatio" to currentZoomRatio.toDouble(),
            "minZoomRatio" to bounds.minZoomRatio.toDouble(),
            "maxZoomRatio" to bounds.maxZoomRatio.toDouble(),
            "effectiveMaxZoomRatio" to bounds.effectiveMaxZoomRatio.toDouble(),
            "isZoomLimited" to bounds.isZoomLimited,
            "activePhysicalCameraId" to (activeLensDecision.physicalCameraId ?: ""),
            "targetPhysicalCameraId" to
                (pendingLensDecision?.physicalCameraId ?: activeLensDecision.physicalCameraId ?: ""),
            "teleOpticalRatio" to (activeLensDecision.telephotoOpticalRatio ?: 1f).toDouble(),
            "localZoomRatio" to currentLocalZoomRatio.toDouble(),
            "lensSwitchState" to lensSwitchState()
        ) + CameraQualityAudit.zoomFields(camera, currentZoomRatio)
    }

    private fun zoomStatePayload(
        status: String,
        requestedZoomRatio: Float = currentZoomRatio
    ): Map<String, Any> {
        val fields = zoomStateFields(requestedZoomRatio)
        CameraQualityAudit.logZoomState(viewId, status, fields)
        return mapOf("status" to status) + fields
    }

    private fun applyCurrentZoomRatio(): ListenableFuture<Void>? {
        val cameraInstance = camera ?: return null
        val zoomState = cameraInstance.cameraInfo.zoomState.value
        val requestedLocalZoom = localZoomRatioFor(currentZoomRatio, activeLensDecision)
        val minLocalZoom = zoomState?.minZoomRatio ?: USER_MIN_ZOOM_RATIO
        val maxLocalZoom = zoomState?.maxZoomRatio ?: USER_MAX_ZOOM_RATIO
        currentLocalZoomRatio = requestedLocalZoom.coerceIn(minLocalZoom, maxLocalZoom)
        return cameraInstance.cameraControl.setZoomRatio(currentLocalZoomRatio)
    }

    private fun lensDecisionForCurrentZoom(): LensSwitchDecision {
        if (currentLensFacing != CameraSelector.LENS_FACING_BACK) {
            return LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
        }
        return decideLensSwitch(
            requestedZoomRatio = currentZoomRatio,
            currentOutputTarget = activeLensDecision.outputTarget,
            topology = backCameraTopology,
            blockedPhysicalCameraIds = blockedPhysicalCameraIds
        )
    }

    private fun applyLensDecisionForCurrentZoom() {
        val desiredDecision = lensDecisionForCurrentZoom()
        if (sameLensOutput(activeLensDecision, desiredDecision)) {
            applyCurrentZoomRatio()
            return
        }
        if (isCapturing.get() || isLensSwitching) {
            pendingLensDecision = desiredDecision
            return
        }
        beginLensSwitch(desiredDecision, "zoom_reconcile")
    }

    private fun beginLensSwitch(decision: LensSwitchDecision, reason: String) {
        if (sameLensOutput(activeLensDecision, decision)) {
            applyCurrentZoomRatio()
            return
        }
        isLensSwitching = true
        pendingLensDecision = null
        showLensSwitchOverlay()
        CameraQualityAudit.logLensSwitch(viewId, "started:$reason", currentZoomRatio, decision)
        rebindCamera(decision, reason)
    }

    private fun sameLensOutput(
        first: LensSwitchDecision,
        second: LensSwitchDecision
    ): Boolean {
        return first.outputTarget == second.outputTarget &&
            first.physicalCameraId == second.physicalCameraId
    }

    private fun physicalCameraCaptureCallback(
        bindingGeneration: Int,
        decision: LensSwitchDecision
    ): CameraCaptureSession.CaptureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            result: android.hardware.camera2.TotalCaptureResult
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
            val observedCameraId = result.get(
                CaptureResult.LOGICAL_MULTI_CAMERA_ACTIVE_PHYSICAL_ID
            ) ?: return
            activity.runOnUiThread {
                onPhysicalCameraObserved(bindingGeneration, decision, observedCameraId)
            }
        }
    }

    private fun onPhysicalCameraObserved(
        bindingGeneration: Int,
        decision: LensSwitchDecision,
        observedCameraId: String
    ) {
        if (bindingGeneration != previewBindGeneration) return
        observedPhysicalCameraId = observedCameraId
        CameraQualityAudit.logLensSwitch(
            viewId,
            "observed",
            currentZoomRatio,
            decision,
            observedCameraId
        )
        val targetCameraId = decision.physicalCameraId ?: return
        if (targetCameraId != observedCameraId) {
            handlePhysicalCameraFailure(decision, "observed_mismatch")
        }
    }

    private fun handleRebindFailure(
        decision: LensSwitchDecision,
        reason: String,
        error: Exception
    ) {
        android.util.Log.w(
            "CameraPreviewView",
            "Camera rebind failed for $reason target=${decision.physicalCameraId}",
            error
        )
        if (decision.physicalCameraId != null) {
            handlePhysicalCameraFailure(decision, "bind_failed")
            return
        }
        isLensSwitching = false
        cancelLensSwitchTimeout()
        hideLensSwitchOverlay(immediate = true)
        CameraQualityAudit.logLensSwitch(viewId, "logical_bind_failed", currentZoomRatio, decision)
    }

    private fun handlePhysicalCameraFailure(
        decision: LensSwitchDecision,
        reason: String
    ) {
        val physicalCameraId = decision.physicalCameraId ?: return
        blockedPhysicalCameraIds += physicalCameraId
        CameraQualityAudit.logLensSwitch(
            viewId,
            "failed:$reason",
            currentZoomRatio,
            decision,
            observedPhysicalCameraId
        )
        if (isCapturing.get()) {
            pendingLensDecision = LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE)
            return
        }
        isLensSwitching = true
        showLensSwitchOverlay()
        rebindCamera(LensSwitchDecision(LensOutputTarget.LOGICAL_WIDE), "tele_fallback")
    }

    private fun onPreviewFrameRendered(bindingGeneration: Int) {
        if (bindingGeneration != previewBindGeneration || !isLensSwitching) return
        cancelLensSwitchTimeout()
        isLensSwitching = false
        hideLensSwitchOverlay()
        CameraQualityAudit.logLensSwitch(
            viewId,
            "completed",
            currentZoomRatio,
            activeLensDecision,
            observedPhysicalCameraId
        )
        val pendingDecision = pendingLensDecision
        pendingLensDecision = null
        if (pendingDecision != null && !sameLensOutput(activeLensDecision, pendingDecision)) {
            beginLensSwitch(pendingDecision, "pending_zoom")
        } else {
            applyLensDecisionForCurrentZoom()
        }
    }

    private fun scheduleLensSwitchTimeout(
        bindingGeneration: Int,
        decision: LensSwitchDecision
    ) {
        cancelLensSwitchTimeout()
        val timeout = Runnable {
            if (bindingGeneration != previewBindGeneration || !isLensSwitching) return@Runnable
            if (decision.physicalCameraId != null) {
                handlePhysicalCameraFailure(decision, "first_frame_timeout")
            } else {
                isLensSwitching = false
                hideLensSwitchOverlay(immediate = true)
                CameraQualityAudit.logLensSwitch(
                    viewId,
                    "logical_first_frame_timeout",
                    currentZoomRatio,
                    decision
                )
            }
        }
        lensSwitchTimeout = timeout
        previewContainer.postDelayed(timeout, 2_000L)
    }

    private fun cancelLensSwitchTimeout() {
        lensSwitchTimeout?.let { previewContainer.removeCallbacks(it) }
        lensSwitchTimeout = null
    }

    private fun showLensSwitchOverlay() {
        lensSwitchOverlay.animate().cancel()
        clearLensSwitchOverlayBitmap()
        val snapshot = textureView.bitmap ?: return
        lensSwitchOverlay.setImageBitmap(snapshot)
        lensSwitchOverlay.alpha = 1f
        lensSwitchOverlay.visibility = View.VISIBLE
    }

    private fun hideLensSwitchOverlay(immediate: Boolean = false) {
        if (lensSwitchOverlay.visibility != View.VISIBLE) return
        lensSwitchOverlay.animate().cancel()
        if (immediate) {
            lensSwitchOverlay.visibility = View.GONE
            lensSwitchOverlay.alpha = 1f
            clearLensSwitchOverlayBitmap()
            return
        }
        lensSwitchOverlay.animate()
            .alpha(0f)
            .setDuration(120L)
            .withEndAction {
                lensSwitchOverlay.visibility = View.GONE
                lensSwitchOverlay.alpha = 1f
                clearLensSwitchOverlayBitmap()
            }
            .start()
    }

    private fun clearLensSwitchOverlayBitmap() {
        val bitmap = (lensSwitchOverlay.drawable as? BitmapDrawable)?.bitmap
        lensSwitchOverlay.setImageDrawable(null)
        bitmap?.safeRecycle()
    }

    private fun lensSwitchState(): String = when {
        isLensSwitching -> "switching"
        activeLensDecision.outputTarget == LensOutputTarget.PHYSICAL_TELE -> "tele"
        else -> "logical"
    }

    private fun applyDeferredLensSwitchAfterCapture() {
        activity.runOnUiThread {
            if (isCapturing.get() || isLensSwitching) return@runOnUiThread
            val pendingDecision = pendingLensDecision
            pendingLensDecision = null
            if (pendingDecision != null && !sameLensOutput(activeLensDecision, pendingDecision)) {
                beginLensSwitch(pendingDecision, "capture_complete")
            } else {
                applyLensDecisionForCurrentZoom()
            }
        }
    }

    private fun Throwable.isZoomOperationCanceled(): Boolean {
        return this is CancellationException ||
            javaClass.simpleName == "OperationCanceledException"
    }

    fun setPresetParams(params: Map<String, Any>) {
        lastPresetParams = params
        val renderer = glRenderer ?: return
        applyPresetParamsToRenderer(renderer, params)
    }

    private fun applyPresetParamsToRenderer(
        renderer: CameraGlRenderer,
        params: Map<String, Any>
    ) {
        val temp = (params["temperature"] as? Number)?.toFloat() ?: 0.0f
        val sat = (params["saturation"] as? Number)?.toFloat() ?: 0.0f
        val cont = (params["contrast"] as? Number)?.toFloat() ?: 0.0f
        val grain = (params["grain"] as? Number)?.toFloat() ?: 0.0f
        val vignette = (params["vignette"] as? Number)?.toFloat() ?: 0.0f
        val lutPath = params["lutPath"] as? String
        val lutStrength = (params["lutStrength"] as? Number)
            ?.toFloat() ?: 0.0f
        val lightLeakIntensity = (params["lightLeakIntensity"] as? Number)?.toFloat() ?: 0.0f
        val lightLeakVariant = (params["lightLeakVariant"] as? Number)?.toInt() ?: -1
        val dustIntensity = (params["dustIntensity"] as? Number)?.toFloat() ?: 0.0f
        val bloomThreshold = (params["bloomThreshold"] as? Number)?.toFloat() ?: 0.8f
        val bloomIntensity = (params["bloomIntensity"] as? Number)?.toFloat() ?: 0.0f
        val halationIntensity = (params["halationIntensity"] as? Number)?.toFloat() ?: 0.0f
        val lensDistortionStrength = (
            params["lensDistortionStrength"] as? Number
        )?.toFloat() ?: 0.0f
        val tone = (params["tone"] as? Number)?.toFloat() ?: 0.0f
        val color = (params["color"] as? Number)?.toFloat() ?: 0.0f
        val textureVal = (params["textureVal"] as? Number)?.toFloat() ?: 0.0f
        val styleStrength = (params["styleStrength"] as? Number)?.toFloat() ?: 100.0f
        val undertoneX = (params["undertoneX"] as? Number)?.toFloat() ?: 0.0f
        val undertoneY = (params["undertoneY"] as? Number)?.toFloat() ?: 0.0f
        val grainSize = (params["grainSize"] as? Number)?.toFloat() ?: 1.0f
        val softness = (params["softness"] as? Number)?.toFloat() ?: 0.0f

        renderer.applyPresetParams(
            temperature = temp,
            saturation = sat,
            contrast = cont,
            grain = grain,
            vignette = vignette,
            lutPath = lutPath,
            lutStrength = lutStrength,
            lightLeakIntensity = lightLeakIntensity,
            lightLeakVariant = lightLeakVariant,
            dustIntensity = dustIntensity,
            bloomThreshold = bloomThreshold,
            bloomIntensity = bloomIntensity,
            halationIntensity = halationIntensity,
            lensDistortionStrength = lensDistortionStrength,
            tone = tone,
            color = color,
            textureVal = textureVal,
            styleStrength = styleStrength,
            undertoneX = undertoneX,
            undertoneY = undertoneY,
            grainSize = grainSize,
            softness = softness
        )
    }

    fun takePicture(
        params: OfflineProcessParams,
        captureId: String? = null,
        onProgress: ((phase: String) -> Unit)? = null,
        callback: (
            success: Boolean,
            filePathOrUri: String?,
            qualityMetadata: CaptureQualityMetadata?,
            errorCode: String?,
            errorMsg: String?
        ) -> Unit
    ) {
        fun markProgress(phase: String) {
            val id = captureId ?: "executeCapture"
            android.util.Log.d(
                "RanaCaptureTimeline",
                "captureId=$id event=$phase"
            )
            onProgress?.invoke(phase)
        }

        val finishOnce = AtomicBoolean(false)
        fun finish(
            success: Boolean,
            filePathOrUri: String?,
            qualityMetadata: CaptureQualityMetadata?,
            errorCode: String?,
            errorMsg: String?
        ) {
            if (!finishOnce.compareAndSet(false, true)) return
            ContextCompat.getMainExecutor(context).execute {
                callback(success, filePathOrUri, qualityMetadata, errorCode, errorMsg)
            }
        }

        val capture = imageCapture
        if (capture == null) {
            finish(false, null, null, "CAMERA_NOT_READY", "Camera not initialized")
            return
        }
        if (isLensSwitching) {
            finish(false, null, null, "CAMERA_SWITCHING", "Camera lens is switching")
            return
        }
        if (!isCapturing.compareAndSet(false, true)) {
            finish(
                false,
                null,
                null,
                "CAPTURE_IN_PROGRESS",
                "Capture already in progress"
            )
            return
        }

        val captureDisplayRotation = currentDisplayRotation()
        val captureRotationDecision = selectCaptureTargetRotation(
            lastSensorTargetRotation = lastSensorTargetRotation,
            displayRotation = captureDisplayRotation
        )
        capture.targetRotation = captureRotationDecision.targetRotation
        val captureZoomRatio = currentZoomRatio
        val captureAspectRatio = currentAspectRatio
        val effectiveCaptureId = captureId ?: "executeCapture"
        markProgress("camera_request")
        CameraQualityAudit.logCaptureRequest(
            viewId = viewId,
            captureId = effectiveCaptureId,
            aspectRatio = captureAspectRatio,
            zoomRatio = captureZoomRatio,
            imageCapture = capture,
            targetRotation = captureRotationDecision.targetRotation,
            displayRotation = captureDisplayRotation,
            orientationSource = captureRotationDecision.source.auditValue
        )

        capture.takePicture(
            captureExecutor,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    markProgress("image_captured")
                    CameraQualityAudit.logCaptureRotation(
                        viewId = viewId,
                        captureId = effectiveCaptureId,
                        targetRotation = captureRotationDecision.targetRotation,
                        displayRotation = captureDisplayRotation,
                        orientationSource = captureRotationDecision.source.auditValue,
                        imageRotationDegrees = image.imageInfo.rotationDegrees
                    )
                    var decodedBitmap: Bitmap? = null
                    var inputBitmap: Bitmap? = null
                    var processedBitmap: Bitmap? = null
                    var savedUri: Uri? = null
                    var qualityMetadata: CaptureQualityMetadata? = null
                    var errorCode: String? = null
                    var errorMessage: String? = null

                    try {
                        val decodedCapture = decodeImageProxy(image, captureZoomRatio)
                        markProgress("decode_done")
                        decodedBitmap = decodedCapture?.bitmap
                        CameraQualityAudit.logBitmapStage(
                            viewId,
                            "decoded",
                            decodedBitmap,
                            captureZoomRatio
                        )
                        qualityMetadata = decodedCapture?.qualityMetadata
                        if (decodedCapture == null || decodedBitmap == null) {
                            errorCode = "DECODE_FAILED"
                            errorMessage = "Unable to decode captured image"
                        } else {
                            val effectiveParams =
                                if (qualityMetadata?.lutSkipped == true) {
                                    params.copy(
                                        lutAssetPath = null,
                                        lutStrength = 0f
                                    )
                                } else {
                                    params
                                }
                            inputBitmap = cropCapturedBitmap(
                                decodedBitmap,
                                image.cropRect,
                                qualityMetadata?.inSampleSize ?: 1
                            )
                            markProgress("crop_done")
                            CameraQualityAudit.logBitmapStage(
                                viewId,
                                "cropped",
                                inputBitmap,
                                captureZoomRatio
                            )
                            if (inputBitmap !== decodedBitmap) {
                                decodedBitmap.recycle()
                            }
                            decodedBitmap = null

                            inputBitmap = transformCapturedBitmap(
                                inputBitmap,
                                image.imageInfo.rotationDegrees,
                                currentLensFacing == CameraSelector.LENS_FACING_FRONT
                            )
                            markProgress("transform_done")
                            CameraQualityAudit.logCaptureGeometry(
                                viewId = viewId,
                                captureId = effectiveCaptureId,
                                aspectRatio = captureAspectRatio,
                                targetRotation = captureRotationDecision.targetRotation,
                                imageCropRect = image.cropRect,
                                imageRotationDegrees = image.imageInfo.rotationDegrees,
                                outputBitmap = inputBitmap
                            )
                            CameraQualityAudit.logBitmapStage(
                                viewId,
                                "transformed",
                                inputBitmap,
                                captureZoomRatio
                            )

                            processedBitmap = OfflineGlProcessor.processImage(
                                context,
                                inputBitmap,
                                effectiveParams
                            )
                            markProgress("gl_process_done")
                            CameraQualityAudit.logBitmapStage(
                                viewId,
                                "processed",
                                processedBitmap,
                                captureZoomRatio
                            )
                            inputBitmap = null
                            if (processedBitmap == null) {
                                errorCode = "PROCESS_FAILED"
                                errorMessage = "OfflineGlProcessor returned null"
                            } else {
                                savedUri = saveProcessedBitmap(processedBitmap, captureZoomRatio)
                                markProgress("save_done")
                                if (savedUri == null) {
                                    errorCode = "SAVE_FAILED"
                                    errorMessage = "Unable to save processed image"
                                }
                            }
                        }
                    } catch (oom: OutOfMemoryError) {
                        errorCode = "CAPTURE_OOM"
                        errorMessage = oom.message ?: "Out of memory during capture"
                    } catch (e: Exception) {
                        errorCode = "CAPTURE_FAILED"
                        errorMessage = e.message ?: "Capture failed"
                    } finally {
                        image.close()
                        decodedBitmap?.safeRecycle()
                        inputBitmap?.safeRecycle()
                        processedBitmap?.safeRecycle()
                        isCapturing.set(false)
                        applyDeferredLensSwitchAfterCapture()
                    }

                    if (savedUri != null) {
                        finish(true, savedUri.toString(), qualityMetadata, null, null)
                    } else {
                        finish(
                            false,
                            null,
                            null,
                            errorCode ?: "CAPTURE_FAILED",
                            errorMessage ?: "Unknown capture error"
                        )
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    isCapturing.set(false)
                    applyDeferredLensSwitchAfterCapture()
                    finish(
                        false,
                        null,
                        null,
                        "CAPTURE_FAILED",
                        exception.message ?: "CameraX capture failed"
                    )
                }
            }
        )
    }

    private fun decodeImageProxy(image: ImageProxy, zoomRatio: Float): DecodedCapture? {
        val buffer = image.planes.firstOrNull()?.buffer ?: return null
        buffer.rewind()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)

        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, boundsOptions)
        val sourceWidth = boundsOptions.outWidth
        val sourceHeight = boundsOptions.outHeight
        if (sourceWidth <= 0 || sourceHeight <= 0) return null

        val processingPlan = MemoryUtils.createProcessingPlan(
            context,
            sourceWidth,
            sourceHeight
        )
        CameraQualityAudit.logDecodePlan(
            viewId = viewId,
            sourceWidth = sourceWidth,
            sourceHeight = sourceHeight,
            zoomRatio = zoomRatio,
            processingPlan = processingPlan
        )
        if (processingPlan.qualityReduced || processingPlan.skipLut) {
            android.util.Log.w(
                "CameraPreviewView",
                "Reduced capture processing: " +
                    "availableMb=${processingPlan.availableMb}, " +
                    "inSampleSize=${processingPlan.inSampleSize}, " +
                    "skipLut=${processingPlan.skipLut}"
            )
        }

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = processingPlan.inSampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = BitmapFactory.decodeByteArray(
            bytes,
            0,
            bytes.size,
            decodeOptions
        ) ?: return null

        return DecodedCapture(
            bitmap = bitmap,
            qualityMetadata = CaptureQualityMetadata(
                qualityReduced = processingPlan.qualityReduced,
                inSampleSize = processingPlan.inSampleSize,
                lutSkipped = processingPlan.skipLut
            )
        )
    }

    private fun cropCapturedBitmap(
        bitmap: Bitmap,
        cropRect: Rect,
        sampleSize: Int
    ): Bitmap {
        val sampledCropRect = calculateSampledCropBounds(
            cropLeft = cropRect.left,
            cropTop = cropRect.top,
            cropRight = cropRect.right,
            cropBottom = cropRect.bottom,
            sampleSize = sampleSize,
            bitmapWidth = bitmap.width,
            bitmapHeight = bitmap.height
        )

        return cropBitmapToRect(
            bitmap,
            Rect(
                sampledCropRect.left,
                sampledCropRect.top,
                sampledCropRect.right,
                sampledCropRect.bottom
            )
        )
    }

    private fun currentDisplayRotation(): Int {
        val displayRotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.rotation
        }
        return displayRotation
    }

    private fun transformCapturedBitmap(
        bitmap: Bitmap,
        rotationDegrees: Int,
        mirrorHorizontally: Boolean
    ): Bitmap {
        if (rotationDegrees == 0 && !mirrorHorizontally) return bitmap

        val matrix = Matrix().apply {
            if (rotationDegrees != 0) {
                postRotate(rotationDegrees.toFloat())
            }
            if (mirrorHorizontally) {
                postScale(-1f, 1f)
            }
        }
        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true
        )
    }

    private fun saveProcessedBitmap(bitmap: Bitmap, zoomRatio: Float): Uri? {
        val name = SimpleDateFormat("yyyy-MM-dd-HH-mm-ss-SSS", Locale.US)
            .format(System.currentTimeMillis())
        val displayName = "Rana_$name.jpg"
        val resolver = context.contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Rana")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            } else {
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_PICTURES
                    ),
                    "Rana"
                )
                if (!directory.exists()) {
                    directory.mkdirs()
                }
                put(
                    MediaStore.Images.Media.DATA,
                    File(directory, displayName).absolutePath
                )
            }
        }

        val uri = resolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: return null

        var success = false
        var bytesWritten = 0L
        try {
            resolver.openOutputStream(uri)?.use { stream ->
                val countingStream = CountingOutputStream(stream)
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 95, countingStream)) {
                    throw IOException("Bitmap compression failed")
                }
                bytesWritten = countingStream.bytesWritten
            } ?: throw IOException("Unable to open MediaStore output stream")
            CameraQualityAudit.logCaptureSaved(
                viewId = viewId,
                bitmap = bitmap,
                bytesWritten = bytesWritten,
                zoomRatio = zoomRatio
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val publishValues = ContentValues().apply {
                    put(MediaStore.Images.Media.IS_PENDING, 0)
                }
                resolver.update(uri, publishValues, null, null)
            }
            success = true
            return uri
        } catch (e: Exception) {
            android.util.Log.e("CameraPreviewView", "Failed to save capture", e)
            return null
        } finally {
            if (!success) {
                resolver.delete(uri, null, null)
            }
        }
    }

    private class CountingOutputStream(
        private val delegate: OutputStream
    ) : OutputStream() {
        var bytesWritten: Long = 0
            private set

        override fun write(b: Int) {
            delegate.write(b)
            bytesWritten += 1
        }

        override fun write(b: ByteArray, off: Int, len: Int) {
            delegate.write(b, off, len)
            bytesWritten += len.toLong()
        }

        override fun flush() {
            delegate.flush()
        }

        override fun close() {
            delegate.close()
        }
    }

    private fun Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
    }

    fun unbindCamera() {
        activity.runOnUiThread {
            try {
                previewBindGeneration += 1
                isLensSwitching = false
                pendingLensDecision = null
                cancelLensSwitchTimeout()
                hideLensSwitchOverlay(immediate = true)
                orientationEventListener.disable()
                cameraProvider?.unbindAll()
                camera = null
                previewUseCase = null
                imageCapture = null
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun setFocusAndMetering(x: Float, y: Float) {
        activity.runOnUiThread {
            try {
                val cameraInstance = camera ?: return@runOnUiThread
                val control = cameraInstance.cameraControl ?: return@runOnUiThread
                
                val display = textureView.display ?: @Suppress("DEPRECATION") activity.windowManager.defaultDisplay
                val factory = DisplayOrientedMeteringPointFactory(
                    display,
                    cameraInstance.cameraInfo,
                    textureView.width.toFloat(),
                    textureView.height.toFloat()
                )
                val px = x * textureView.width
                val py = y * textureView.height
                val meteringPoint = factory.createPoint(px, py)
                
                val action = FocusMeteringAction.Builder(
                    meteringPoint,
                    FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE
                )
                .disableAutoCancel()
                .build()
                
                control.startFocusAndMetering(action)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun cancelFocusAndMetering() {
        activity.runOnUiThread {
            try {
                val cameraInstance = camera ?: return@runOnUiThread
                cameraInstance.cameraControl?.cancelFocusAndMetering()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun getCurrentLensFacing(): Int {
        return currentLensFacing
    }

    data class CaptureQualityMetadata(
        val qualityReduced: Boolean,
        val inSampleSize: Int,
        val lutSkipped: Boolean
    )

    private data class DecodedCapture(
        val bitmap: Bitmap,
        val qualityMetadata: CaptureQualityMetadata
    )
}
