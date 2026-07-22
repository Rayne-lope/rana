package com.rana.app.rana

import android.content.Context
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Explicit command ownership around the stateful CameraX engine. */
internal class RanaCameraBinder(private val engine: RanaCameraEngine) {
    fun initialize(
        request: InitializeCameraRequest,
        callback: (Result<CameraOperationResult>) -> Unit
    ) = engine.initialize(request, callback)

    fun bind() = engine.bindPreview()

    fun release() = engine.unbindCamera()
}

internal class RanaLensCoordinator(private val engine: RanaCameraEngine) {
    fun select(lensFacing: Int) = engine.setLensFacing(lensFacing)

    fun current(): Int = engine.getCurrentLensFacing()
}

internal class RanaZoomController(private val engine: RanaCameraEngine) {
    fun set(
        ratio: Float,
        callback: (Map<String, Any>?, String?, String?) -> Unit
    ) = engine.setZoomRatio(ratio, callback)

    fun state(requestedRatio: Float): Map<String, Any> =
        engine.zoomStateFields(requestedRatio)
}

internal class RanaFocusController(private val engine: RanaCameraEngine) {
    fun start(x: Float, y: Float) = engine.setFocusAndMetering(x, y)

    fun cancel() = engine.cancelFocusAndMetering()
}

internal class RanaCaptureCoordinator(private val engine: RanaCameraEngine) {
    fun capture(
        params: OfflineProcessParams,
        captureId: String?,
        onProgress: ((String) -> Unit)?,
        callback: (
            Boolean,
            String?,
            RanaCameraEngine.CaptureQualityMetadata?,
            String?,
            String?
        ) -> Unit
    ) = engine.takePicture(params, captureId, onProgress, callback)
}

internal class RanaCaptureProcessor(maxPendingPipelines: Int) {
    val captureExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    val processingExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    val limiter = CapturePipelineLimiter(maxPendingPipelines)

    fun release() {
        captureExecutor.shutdown()
        processingExecutor.shutdown()
    }
}

internal class RanaMetadataRepository(context: Context) {
    val styles = CaptureStyleMetadataStore(context)
    val sources = CaptureSourceStore(context)
}
