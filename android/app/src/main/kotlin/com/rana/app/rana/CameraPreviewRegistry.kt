package com.rana.app.rana

/** Owns PlatformViews by ID so stale initialize requests cannot bind a view. */
internal class CameraPreviewRegistry<T : Any> {
    private val views = linkedMapOf<Long, T>()

    fun register(viewId: Long, view: T) {
        views[viewId] = view
    }

    fun resolve(viewId: Long): T? = views[viewId]

    fun resolveOrThrow(viewId: Long): T = resolve(viewId) ?: throw FlutterError(
        "CAMERA_NOT_READY",
        "Camera preview not initialized",
        mapOf("platformViewId" to viewId)
    )

    fun unregister(viewId: Long, expected: T) {
        if (views[viewId] === expected) views.remove(viewId)
    }

    fun latest(): T? = views.values.lastOrNull()
}
