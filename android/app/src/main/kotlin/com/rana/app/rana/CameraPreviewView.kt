package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.graphics.SurfaceTexture
import android.os.Build
import android.provider.MediaStore
import android.view.OrientationEventListener
import android.view.Surface
import android.view.TextureView
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

    private val textureView = TextureView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var previewUseCase: Preview? = null
    private var glRenderer: CameraGlRenderer? = null

    private var currentLensFacing = CameraSelector.LENS_FACING_BACK
    private var currentFlashMode = ImageCapture.FLASH_MODE_OFF
    private var currentRotation: Int = Surface.ROTATION_0

    private val orientationEventListener = object : OrientationEventListener(context) {
        override fun onOrientationChanged(orientation: Int) {
            if (orientation == ORIENTATION_UNKNOWN) return
            val rotation = when (orientation) {
                in 45 until 135 -> Surface.ROTATION_270
                in 135 until 225 -> Surface.ROTATION_180
                in 225 until 315 -> Surface.ROTATION_90
                else -> Surface.ROTATION_0
            }
            currentRotation = rotation
            imageCapture?.targetRotation = rotation
            previewUseCase?.targetRotation = rotation
        }
    }

    init {
        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(surfaceTexture: SurfaceTexture, width: Int, height: Int) {
                activity.runOnUiThread {
                    glRenderer = CameraGlRenderer(surfaceTexture, width, height) { _ ->
                        bindPreview()
                    }
                }
            }

            override fun onSurfaceTextureSizeChanged(surfaceTexture: SurfaceTexture, width: Int, height: Int) {
                // Ignore for MVP
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
        return textureView
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
        val renderer = glRenderer ?: return
        activity.runOnUiThread {
            try {
                provider.unbindAll()

                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider { request ->
                        val resolution = request.resolution
                        val cameraSurfaceTexture = renderer.cameraSurfaceTexture
                        if (cameraSurfaceTexture != null) {
                            cameraSurfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
                            val surface = Surface(cameraSurfaceTexture)
                            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                                surface.release()
                            }
                        } else {
                            request.willNotProvideSurface()
                        }
                    }
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

                val displayRotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    activity.display?.rotation ?: Surface.ROTATION_0
                } else {
                    @Suppress("DEPRECATION")
                    activity.windowManager.defaultDisplay.rotation
                }
                currentRotation = displayRotation
                imageCapture?.targetRotation = displayRotation
                previewUseCase?.targetRotation = displayRotation

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

    fun setPreset(presetId: String) {
        val (temp, sat, cont) = when (presetId) {
            "rana_warm" -> Triple(0.3f, 0.1f, 0.0f)
            "rana_cool" -> Triple(-0.3f, 0.05f, 0.0f)
            "rana_mono" -> Triple(0.0f, -1.0f, 0.1f)
            else -> Triple(0.0f, 0.0f, 0.0f) // normal/none
        }
        glRenderer?.updateFilterParams(temp, sat, cont)
    }

    fun takePicture(callback: (success: Boolean, filePathOrUri: String?, errorMsg: String?) -> Unit) {
        val capture = imageCapture
        if (capture == null) {
            callback(false, null, "Camera not initialized")
            return
        }

        capture.targetRotation = currentRotation

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
