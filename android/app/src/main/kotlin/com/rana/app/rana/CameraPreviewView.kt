package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.OrientationEventListener
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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
    private val captureExecutor = Executors.newSingleThreadExecutor()
    private val isCapturing = AtomicBoolean(false)

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
            override fun onSurfaceTextureAvailable(
                surfaceTexture: SurfaceTexture, width: Int, height: Int
            ) {
                glRenderer = CameraGlRenderer(
                    context,
                    surfaceTexture,
                    width,
                    height,
                    onInputSurfaceReady = { _ -> bindPreview() },
                    onGlError = { error ->
                        android.util.Log.e(
                            "CameraPreviewView",
                            "OpenGL ES initialization failed: $error"
                        )
                    }
                )
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
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
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

    fun setPresetParams(params: Map<String, Any>) {
        val temp = (params["temperature"] as? Number)?.toFloat() ?: 0.0f
        val sat = (params["saturation"] as? Number)?.toFloat() ?: 0.0f
        val cont = (params["contrast"] as? Number)?.toFloat() ?: 0.0f
        val grain = (params["grain"] as? Number)?.toFloat() ?: 0.0f
        val vignette = (params["vignette"] as? Number)?.toFloat() ?: 0.0f
        val lutPath = params["lutPath"] as? String
        val lutStrength = (params["lutStrength"] as? Number)
            ?.toFloat() ?: 0.0f
        
        glRenderer?.applyPresetParams(
            temperature = temp,
            saturation = sat,
            contrast = cont,
            grain = grain,
            vignette = vignette,
            lutPath = lutPath,
            lutStrength = lutStrength
        )
    }

    fun takePicture(
        params: OfflineProcessParams,
        callback: (
            success: Boolean,
            filePathOrUri: String?,
            errorCode: String?,
            errorMsg: String?
        ) -> Unit
    ) {
        val finishOnce = AtomicBoolean(false)
        fun finish(
            success: Boolean,
            filePathOrUri: String?,
            errorCode: String?,
            errorMsg: String?
        ) {
            if (!finishOnce.compareAndSet(false, true)) return
            ContextCompat.getMainExecutor(context).execute {
                callback(success, filePathOrUri, errorCode, errorMsg)
            }
        }

        val capture = imageCapture
        if (capture == null) {
            finish(false, null, "CAMERA_NOT_READY", "Camera not initialized")
            return
        }
        if (!isCapturing.compareAndSet(false, true)) {
            finish(
                false,
                null,
                "CAPTURE_IN_PROGRESS",
                "Capture already in progress"
            )
            return
        }

        capture.targetRotation = currentRotation

        capture.takePicture(
            captureExecutor,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    var decodedBitmap: Bitmap? = null
                    var inputBitmap: Bitmap? = null
                    var processedBitmap: Bitmap? = null
                    var savedUri: Uri? = null
                    var errorCode: String? = null
                    var errorMessage: String? = null

                    try {
                        decodedBitmap = decodeImageProxy(image)
                        if (decodedBitmap == null) {
                            errorCode = "DECODE_FAILED"
                            errorMessage = "Unable to decode captured image"
                        } else {
                            inputBitmap = transformCapturedBitmap(
                                decodedBitmap,
                                image.imageInfo.rotationDegrees,
                                currentLensFacing == CameraSelector.LENS_FACING_FRONT
                            )
                            if (inputBitmap !== decodedBitmap) {
                                decodedBitmap.recycle()
                            }
                            decodedBitmap = null

                            processedBitmap = OfflineGlProcessor.processImage(
                                context,
                                inputBitmap,
                                params
                            )
                            if (processedBitmap == null) {
                                errorCode = "PROCESS_FAILED"
                                errorMessage = "OfflineGlProcessor returned null"
                            } else {
                                savedUri = saveProcessedBitmap(processedBitmap)
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
                    }

                    if (savedUri != null) {
                        finish(true, savedUri.toString(), null, null)
                    } else {
                        finish(
                            false,
                            null,
                            errorCode ?: "CAPTURE_FAILED",
                            errorMessage ?: "Unknown capture error"
                        )
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    isCapturing.set(false)
                    finish(
                        false,
                        null,
                        "CAPTURE_FAILED",
                        exception.message ?: "CameraX capture failed"
                    )
                }
            }
        )
    }

    private fun decodeImageProxy(image: ImageProxy): Bitmap? {
        val buffer = image.planes.firstOrNull()?.buffer ?: return null
        buffer.rewind()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
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

    private fun saveProcessedBitmap(bitmap: Bitmap): Uri? {
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
        try {
            resolver.openOutputStream(uri)?.use { stream ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)) {
                    throw IOException("Bitmap compression failed")
                }
            } ?: throw IOException("Unable to open MediaStore output stream")

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

    private fun Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
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
