package com.rana.app.rana

import android.content.Context
import android.view.View
import io.flutter.plugin.platform.PlatformView

/** Android PlatformView shell; all camera ownership lives in [RanaCameraEngine]. */
internal class CameraPreviewView(
    context: Context,
    activity: MainActivity,
    viewId: Int
) : PlatformView {
    private val engine = RanaCameraEngine(
        context = context,
        activity = activity,
        viewId = viewId,
        onDisposed = { activity.unregisterCameraPreview(viewId, this) }
    )
    private val binder = RanaCameraBinder(engine)
    private val lens = RanaLensCoordinator(engine)
    private val zoom = RanaZoomController(engine)
    private val focus = RanaFocusController(engine)
    private val capture = RanaCaptureCoordinator(engine)

    override fun getView(): View = engine.getView()

    override fun dispose() = engine.dispose()

    fun initialize(
        request: InitializeCameraRequest,
        callback: (Result<CameraOperationResult>) -> Unit
    ) = binder.initialize(request, callback)

    fun bindPreview() = binder.bind()

    fun unbindCamera() = binder.release()

    fun setFlashMode(flashMode: Int) = engine.setFlashMode(flashMode)

    fun setAspectRatio(aspectRatio: String) = engine.setAspectRatio(aspectRatio)

    fun setLensFacing(lensFacing: Int) = lens.select(lensFacing)

    fun getCurrentLensFacing(): Int = lens.current()

    fun setZoomRatio(
        zoomRatio: Float,
        callback: (Map<String, Any>?, String?, String?) -> Unit
    ) = zoom.set(zoomRatio, callback)

    fun zoomStateFields(
        requestedZoomRatio: Float = USER_MIN_ZOOM_RATIO
    ): Map<String, Any> = zoom.state(requestedZoomRatio)

    fun setFocusAndMetering(x: Float, y: Float) =
        focus.start(x, y)

    fun cancelFocusAndMetering() = focus.cancel()

    fun setPresetParams(params: Map<String, Any>) = engine.setPresetParams(params)

    fun applyRecipe(recipe: RenderRecipeV1) = engine.applyRecipe(recipe)

    fun takePicture(
        params: OfflineProcessParams,
        captureId: String? = null,
        onProgress: ((phase: String) -> Unit)? = null,
        callback: (
            success: Boolean,
            filePathOrUri: String?,
            qualityMetadata: RanaCameraEngine.CaptureQualityMetadata?,
            errorCode: String?,
            errorMsg: String?
        ) -> Unit
    ) = capture.capture(params, captureId, onProgress, callback)
}
