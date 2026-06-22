package com.rana.app.rana

import android.content.Context
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView

class CameraPreviewView(
    private val context: Context,
    private val activity: MainActivity,
    private val viewId: Int,
    private val creationParams: Map<String, Any>?
) : PlatformView {

    private val previewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private var cameraProvider: ProcessCameraProvider? = null

    init {
        startCamera()
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        activity.runOnUiThread {
            try {
                cameraProvider?.unbindAll()
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
                bindPreview()
            } catch (e: Exception) {
                // Ignore
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindPreview() {
        val provider = cameraProvider ?: return
        activity.runOnUiThread {
            try {
                provider.unbindAll()

                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                provider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview
                )
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}
