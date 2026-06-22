package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.provider.MediaStore
import android.view.OrientationEventListener
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView
import java.text.SimpleDateFormat
import java.util.Locale

class CameraPreviewView(
    private val context: Context,
    private val activity: MainActivity,
    private val viewId: Int,
    private val creationParams: Map<String, Any>?
) : PlatformView {

    private val previewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var previewUseCase: Preview? = null

    private var currentLensFacing = CameraSelector.LENS_FACING_BACK
    private var currentFlashMode = ImageCapture.FLASH_MODE_OFF

    private val orientationEventListener = object : OrientationEventListener(context) {
        override fun onOrientationChanged(orientation: Int) {
            if (orientation == ORIENTATION_UNKNOWN) return
            val rotation = when (orientation) {
                in 45 until 135 -> Surface.ROTATION_270
                in 135 until 225 -> Surface.ROTATION_180
                in 225 until 315 -> Surface.ROTATION_90
                else -> Surface.ROTATION_0
            }
            imageCapture?.targetRotation = rotation
            previewUseCase?.targetRotation = rotation
        }
    }

    init {
        startCamera()
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        activity.runOnUiThread {
            try {
                if (activity.activePreviewView == this) {
                    activity.activePreviewView = null
                }
                unbindCamera()
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

    fun bindPreview() {
        val provider = cameraProvider ?: return
        activity.runOnUiThread {
            try {
                provider.unbindAll()

                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                previewUseCase = preview

                imageCapture = ImageCapture.Builder()
                    .setFlashMode(currentFlashMode)
                    .build()

                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(currentLensFacing)
                    .build()

                provider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageCapture
                )

                if (orientationEventListener.canDetectOrientation()) {
                    orientationEventListener.enable()
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun setLensFacing(lensFacing: Int) {
        if (currentLensFacing == lensFacing) return
        currentLensFacing = lensFacing
        bindPreview()
    }

    fun setFlashMode(flashMode: Int) {
        currentFlashMode = flashMode
        imageCapture?.flashMode = flashMode
    }

    fun takePicture(callback: (success: Boolean, filePathOrUri: String?, errorMsg: String?) -> Unit) {
        val capture = imageCapture
        if (capture == null) {
            callback(false, null, "Camera not initialized")
            return
        }

        val name = SimpleDateFormat("yyyy-MM-dd-HH-mm-ss-SSS", Locale.US)
            .format(System.currentTimeMillis())
        
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "Rana_$name.jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if (android.os.Build.VERSION.SDK_INT > android.os.Build.VERSION_CODES.P) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Rana")
            }
        }

        val metadata = ImageCapture.Metadata().apply {
            isReversedHorizontal = (currentLensFacing == CameraSelector.LENS_FACING_FRONT)
        }

        val outputOptions = ImageCapture.OutputFileOptions.Builder(
            context.contentResolver,
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ).setMetadata(metadata)
         .build()

        capture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    val savedUri = outputFileResults.savedUri
                    callback(true, savedUri?.toString() ?: "", null)
                }

                override fun onError(exception: ImageCaptureException) {
                    callback(false, null, exception.message)
                }
            }
        )
    }

    fun unbindCamera() {
        activity.runOnUiThread {
            try {
                orientationEventListener.disable()
                cameraProvider?.unbindAll()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun getCurrentLensFacing(): Int {
        return currentLensFacing
    }
}
