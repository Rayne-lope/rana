package com.rana.app.rana

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CameraPreviewFactory(
    private val activity: MainActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = CameraPreviewView(context, activity, viewId)
        activity.registerCameraPreview(viewId, view)
        activity.logCameraPreviewCreated(viewId, view.getView())
        return view
    }
}
