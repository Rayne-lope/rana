package com.rana.app.rana

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.rana.app/camera_control"
    private val EVENT_CHANNEL = "com.rana.app/camera_status"

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var fpsRunnable: Runnable? = null
    private var isStreamingFps = false

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
                    result.success(mapOf("status" to "initialized", "lens" to "back"))
                }
                "selectPreset" -> {
                    val presetId = call.argument<String>("presetId")
                    result.success(mapOf("status" to "preset_selected", "presetId" to presetId))
                }
                "executeCapture" -> {
                    // Simulate processing delay on native side if needed, or simply return path
                    result.success(mapOf("status" to "captured", "filePath" to "/mock/path/photo.jpg"))
                }
                "setFlashMode" -> {
                    val flashMode = call.argument<String>("flashMode")
                    result.success(mapOf("status" to "flash_set", "flashMode" to flashMode))
                }
                "toggleLens" -> {
                    val lens = call.argument<String>("lens")
                    val nextLens = if (lens == "back") "front" else "back"
                    result.success(mapOf("status" to "lens_toggled", "lens" to nextLens))
                }
                "releaseCamera" -> {
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

