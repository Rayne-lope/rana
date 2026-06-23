package com.rana.app.rana

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
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
                        preview.takePicture { success, filePathOrUri, errorMsg ->
                            if (success) {
                                result.success(mapOf("status" to "captured", "filePath" to filePathOrUri))
                            } else {
                                result.error("CAPTURE_FAILED", errorMsg ?: "Unknown error", null)
                            }
                        }
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
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

    private fun stopFpsStreaming() {
        isStreamingFps = false
        fpsRunnable?.let { handler.removeCallbacks(it) }
        fpsRunnable = null
    }
}

