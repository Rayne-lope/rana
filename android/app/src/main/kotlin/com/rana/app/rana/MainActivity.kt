package com.rana.app.rana

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import androidx.camera.core.CameraSelector

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.rana.app/camera_control"
    private val EVENT_CHANNEL = "com.rana.app/camera_status"

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var fpsRunnable: Runnable? = null
    private var isStreamingFps = false
    var activePreviewView: CameraPreviewView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the camera preview platform view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.rana.app/camera_preview",
            CameraPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
        )

        // Setup MethodChannel for camera control actions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeCamera" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        preview.bindPreview()
                    }
                    val lensStr = if (preview?.getCurrentLensFacing() == CameraSelector.LENS_FACING_FRONT) "front" else "back"
                    result.success(mapOf("status" to "initialized", "lens" to lensStr))
                }
                "selectPreset" -> {
                    val presetId = call.argument<String>("presetId") ?: "normal"
                    val params = call.argument<Map<String, Any>>("params")
                    val preview = activePreviewView
                    if (preview != null) {
                        if (params != null) {
                            preview.setPresetParams(params)
                        }
                        result.success(mapOf("status" to "preset_selected", "presetId" to presetId))
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "executeCapture" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val params = offlineParamsFromArgs(call.arguments)
                        preview.takePicture(params) { success, filePathOrUri, qualityMetadata, errorCode, errorMsg ->
                            if (success) {
                                result.success(
                                    mapOf(
                                        "status" to "captured",
                                        "filePath" to filePathOrUri,
                                        "qualityReduced" to (
                                            qualityMetadata?.qualityReduced
                                                ?: false
                                            ),
                                        "inSampleSize" to (
                                            qualityMetadata?.inSampleSize ?: 1
                                            ),
                                        "lutSkipped" to (
                                            qualityMetadata?.lutSkipped ?: false
                                            )
                                    )
                                )
                            } else {
                                result.error(errorCode ?: "CAPTURE_FAILED", errorMsg ?: "Unknown error", null)
                            }
                        }
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "loadCapturedImageBytes" -> {
                    val uriArg = call.argument<String>("uri")
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        try {
                            val imageBytes = loadCapturedImageBytes(Uri.parse(uriArg))
                            result.success(imageBytes)
                        } catch (e: Exception) {
                            result.error("LOAD_IMAGE_FAILED", e.message, null)
                        }
                    }
                }
                "openMediaInGallery" -> {
                    val uriArg = call.argument<String>("uri")
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        openMediaInGallery(Uri.parse(uriArg), result)
                    }
                }
                "setFlashMode" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val flashModeStr = call.argument<String>("flashMode") ?: "off"
                        val nativeFlashMode = when (flashModeStr) {
                            "on" -> androidx.camera.core.ImageCapture.FLASH_MODE_ON
                            "auto" -> androidx.camera.core.ImageCapture.FLASH_MODE_AUTO
                            else -> androidx.camera.core.ImageCapture.FLASH_MODE_OFF
                        }
                        preview.setFlashMode(nativeFlashMode)
                        result.success(mapOf("status" to "flash_set", "flashMode" to flashModeStr))
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "toggleLens" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val currentLens = call.argument<String>("lens") ?: "back"
                        val targetLensFacing = if (currentLens == "back") {
                            CameraSelector.LENS_FACING_FRONT
                        } else {
                            CameraSelector.LENS_FACING_BACK
                        }
                        preview.setLensFacing(targetLensFacing)
                        val nextLensStr = if (targetLensFacing == CameraSelector.LENS_FACING_BACK) "back" else "front"
                        result.success(mapOf("status" to "lens_toggled", "lens" to nextLensStr))
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "releaseCamera" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        preview.unbindCamera()
                    }
                    result.success(mapOf("status" to "released"))
                }
                "testOfflineProcessing" -> {
                    val temp = (call.argument<Number>("temperature"))
                        ?.toFloat() ?: 0f
                    val sat = (call.argument<Number>("saturation"))
                        ?.toFloat() ?: 0f
                    val cont = (call.argument<Number>("contrast"))
                        ?.toFloat() ?: 0f
                    val grain = (call.argument<Number>("grain"))
                        ?.toFloat() ?: 0f
                    val vignette = (call.argument<Number>("vignette"))
                        ?.toFloat() ?: 0f
                    val lutPath = call.argument<String>("lutPath")
                    val lutStrength = (call.argument<Number>("lutStrength"))
                        ?.toFloat() ?: 0f
                    val lightLeakIntensity = (call.argument<Number>("lightLeakIntensity"))
                        ?.toFloat() ?: 0f
                    val lightLeakVariant = (call.argument<Number>("lightLeakVariant"))
                        ?.toInt() ?: -1
                    val dustIntensity = (call.argument<Number>("dustIntensity"))
                        ?.toFloat() ?: 0f

                    val bitmap = android.graphics.Bitmap.createBitmap(
                        512, 512, android.graphics.Bitmap.Config.ARGB_8888
                    )
                    val canvas = android.graphics.Canvas(bitmap)
                    val paint = android.graphics.Paint()
                    val gradient = android.graphics.LinearGradient(
                        0f, 0f, 512f, 512f,
                        android.graphics.Color.RED, android.graphics.Color.BLUE,
                        android.graphics.Shader.TileMode.CLAMP
                    )
                    paint.shader = gradient
                    canvas.drawRect(0f, 0f, 512f, 512f, paint)

                    val executor = java.util.concurrent.Executors
                        .newSingleThreadExecutor()
                    executor.execute {
                        try {
                            val params = OfflineProcessParams(
                                temperature = temp,
                                saturation = sat,
                                contrast = cont,
                                grain = grain,
                                vignette = vignette,
                                lutAssetPath = lutPath,
                                lutStrength = lutStrength,
                                lightLeakIntensity = lightLeakIntensity,
                                lightLeakVariant = lightLeakVariant,
                                dustIntensity = dustIntensity
                            )
                            val out = OfflineGlProcessor.processImage(
                                context, bitmap, params
                            )
                            if (out != null) {
                                val cacheDir = context.externalCacheDir 
                                    ?: context.cacheDir
                                val file = java.io.File(
                                    cacheDir, "offline_test_output.png"
                                )
                                java.io.FileOutputStream(file).use { stream ->
                                    out.compress(
                                        android.graphics.Bitmap
                                            .CompressFormat.PNG,
                                        100, stream
                                    )
                                }
                                out.safeRecycle()
                                bitmap.safeRecycle()
                                handler.post {
                                    result.success(
                                        mapOf(
                                            "status" to "success",
                                            "filePath" to file.absolutePath
                                        )
                                    )
                                }
                            } else {
                                bitmap.safeRecycle()
                                handler.post {
                                    result.error(
                                        "PROCESS_FAILED",
                                        "OfflineGlProcessor returned null", null
                                    )
                                }
                            }
                        } catch (e: Exception) {
                            bitmap.safeRecycle()
                            handler.post {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Setup EventChannel for streaming camera status (e.g. FPS metrics)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startFpsStreaming()
                }

                override fun onCancel(arguments: Any?) {
                    stopFpsStreaming()
                    eventSink = null
                }
            }
        )
    }

    private fun offlineParamsFromArgs(arguments: Any?): OfflineProcessParams {
        val args = arguments as? Map<*, *>
        fun numberArg(key: String): Float {
            return (args?.get(key) as? Number)?.toFloat() ?: 0f
        }

        return OfflineProcessParams(
            temperature = numberArg("temperature"),
            saturation = numberArg("saturation"),
            contrast = numberArg("contrast"),
            grain = numberArg("grain"),
            vignette = numberArg("vignette"),
            lutAssetPath = args?.get("lutPath") as? String,
            lutStrength = numberArg("lutStrength"),
            lightLeakIntensity = numberArg("lightLeakIntensity"),
            lightLeakVariant = (args?.get("lightLeakVariant") as? Number)?.toInt() ?: -1,
            dustIntensity = numberArg("dustIntensity")
        )
    }

    private fun startFpsStreaming() {
        if (isStreamingFps) return
        isStreamingFps = true
        fpsRunnable = object : Runnable {
            override fun run() {
                if (!isStreamingFps) return
                // Emit random FPS values between 24 and 30 for realism
                val mockFps = (24..30).random()
                val eventData = mapOf(
                    "type" to "status_update",
                    "fps" to mockFps,
                    "active" to true,
                    "timestamp" to System.currentTimeMillis()
                )
                eventSink?.success(eventData)
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(fpsRunnable!!)
    }

    private fun loadCapturedImageBytes(uri: Uri): ByteArray {
        return contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes()
        } ?: throw IllegalStateException("Unable to open image stream")
    }

    private fun openMediaInGallery(
        uri: Uri,
        result: MethodChannel.Result
    ) {
        handler.post {
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "image/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val activity = intent.resolveActivity(packageManager)
                if (activity == null) {
                    result.error(
                        "NO_GALLERY_APP",
                        "No application available to view images",
                        null
                    )
                    return@post
                }
                startActivity(intent)
                result.success(null)
            } catch (e: Exception) {
                result.error("OPEN_GALLERY_FAILED", e.message, null)
            }
        }
    }

    private fun stopFpsStreaming() {
        isStreamingFps = false
        fpsRunnable?.let { handler.removeCallbacks(it) }
        fpsRunnable = null
    }

    private fun android.graphics.Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
    }
}
