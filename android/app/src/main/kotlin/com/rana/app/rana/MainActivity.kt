package com.rana.app.rana

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ClipData
import android.content.Intent
import android.content.IntentSender
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.camera.core.CameraSelector
import androidx.core.content.FileProvider
import android.provider.MediaStore
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.rana.app/camera_control"
    private val EVENT_CHANNEL = "com.rana.app/camera_status"
    private val DELETE_MEDIA_REQUEST_CODE = 4107

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val mediaStoreExecutor = Executors.newSingleThreadExecutor()
    private val captureSequence = AtomicInteger(0)
    private var pendingDeleteResult: MethodChannel.Result? = null
    var activePreviewView: CameraPreviewView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cleanupShareCache()

        // Register the camera preview platform view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.rana.app/camera_preview",
            CameraPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
        )

        // Setup MethodChannel for camera control actions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOutputCapabilities" -> {
                    result.success(outputCapabilities().asChannelMap())
                }
                "getPermissionCapabilities" -> {
                    result.success(
                        mapOf(
                            "requiresLegacyStorageForCapture" to
                                (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P),
                            "galleryReadPermission" to if (
                                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                            ) {
                                "photos"
                            } else {
                                "storage"
                            }
                        )
                    )
                }
                "initializeCamera" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        preview.bindPreview()
                    }
                    val lensStr = if (preview?.getCurrentLensFacing() == CameraSelector.LENS_FACING_FRONT) "front" else "back"
                    val response = mutableMapOf<String, Any>(
                        "status" to "initialized",
                        "lens" to lensStr
                    )
                    preview?.zoomStateFields()?.let { response.putAll(it) }
                    result.success(response)
                }
                "setFocusAndMetering" -> {
                    val x = call.argument<Double>("x") ?: 0.5
                    val y = call.argument<Double>("y") ?: 0.5
                    val preview = activePreviewView
                    if (preview != null) {
                        preview.setFocusAndMetering(x.toFloat(), y.toFloat())
                        result.success(null)
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "cancelFocusAndMetering" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        preview.cancelFocusAndMetering()
                        result.success(null)
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
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
                                        ),
                                        "requestedOutputQuality" to (
                                            qualityMetadata?.requestedOutputQuality
                                                ?: OutputQualityProfile.HIGH_JPEG.channelValue
                                        ),
                                        "actualOutputFormat" to (
                                            qualityMetadata?.actualOutputFormat ?: "jpeg"
                                        ),
                                        "outputMimeType" to (
                                            qualityMetadata?.outputMimeType ?: "image/jpeg"
                                        ),
                                        "outputWidth" to (qualityMetadata?.outputWidth ?: 0),
                                        "outputHeight" to (qualityMetadata?.outputHeight ?: 0),
                                        "fileSizeBytes" to (
                                            qualityMetadata?.fileSizeBytes ?: 0
                                        ),
                                        "fallbackReason" to qualityMetadata?.fallbackReason
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
                "beginCapture" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val params = offlineParamsFromArgs(call.arguments)
                        val captureId = "capture-${System.currentTimeMillis()}-${captureSequence.incrementAndGet()}"
                        val startedAt = SystemClock.elapsedRealtime()
                        android.util.Log.d(
                            "RanaCaptureTimeline",
                            "captureId=$captureId event=begin_capture elapsedMs=0"
                        )
                        result.success(
                            mapOf(
                                "status" to "capture_started",
                                "captureId" to captureId
                            )
                        )
                        dispatchCaptureProgress(captureId, "native_request", startedAt)
                        preview.takePicture(
                            params,
                            captureId = captureId,
                            onProgress = { phase ->
                                dispatchCaptureProgress(captureId, phase, startedAt)
                            }
                        ) { success, filePathOrUri, qualityMetadata, errorCode, errorMsg ->
                            if (success) {
                                dispatchCaptureCompleted(
                                    captureId,
                                    filePathOrUri,
                                    qualityMetadata,
                                    startedAt
                                )
                            } else {
                                dispatchCaptureFailed(
                                    captureId,
                                    errorCode ?: "CAPTURE_FAILED",
                                    errorMsg ?: "Unknown error",
                                    startedAt
                                )
                            }
                        }
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "loadCapturedImageBytes" -> {
                    val uriArg = call.argument<String>("uri")
                    val targetSize = (call.argument<Number>("targetSize"))?.toInt()
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        mediaStoreExecutor.execute {
                            val startedAt = SystemClock.elapsedRealtime()
                            try {
                                val imageBytes = loadCapturedImageBytes(
                                    Uri.parse(uriArg),
                                    targetSize
                                )
                                android.util.Log.d(
                                    "RanaCaptureTimeline",
                                    "event=image_bytes_loaded uri=$uriArg " +
                                        "targetSize=$targetSize elapsedMs=${
                                            SystemClock.elapsedRealtime() - startedAt
                                        }"
                                )
                                handler.post { result.success(imageBytes) }
                            } catch (e: Exception) {
                                handler.post {
                                    result.error("LOAD_IMAGE_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                }
                "listGalleryMedia" -> {
                    mediaStoreExecutor.execute {
                        try {
                            val items = listGalleryMedia()
                            handler.post { result.success(items) }
                        } catch (e: SecurityException) {
                            handler.post {
                                result.error("PERMISSION_DENIED", e.message, null)
                            }
                        } catch (e: Exception) {
                            handler.post {
                                result.error("LIST_GALLERY_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "loadGalleryThumbnailBytes" -> {
                    val uriArg = call.argument<String>("uri")
                    val targetSize = (call.argument<Number>("targetSize"))
                        ?.toInt() ?: 360
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        mediaStoreExecutor.execute {
                            try {
                                val thumbBytes = loadGalleryThumbnailBytes(
                                    Uri.parse(uriArg),
                                    targetSize
                                )
                                handler.post { result.success(thumbBytes) }
                            } catch (e: Exception) {
                                handler.post {
                                    result.error(
                                        "LOAD_THUMBNAIL_FAILED",
                                        e.message,
                                        null
                                    )
                                }
                            }
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
                "shareGalleryMedia" -> {
                    val uriArg = call.argument<String>("uri")
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        shareGalleryMedia(Uri.parse(uriArg), result)
                    }
                }
                "deleteGalleryMedia" -> {
                    val uriArg = call.argument<String>("uri")
                    if (uriArg.isNullOrBlank()) {
                        result.error("INVALID_URI", "Image URI is required", null)
                    } else {
                        deleteGalleryMedia(Uri.parse(uriArg), result)
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
                "setAspectRatio" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val aspectRatio = call.argument<String>("aspectRatio") ?: "portrait_3_4"
                        preview.setAspectRatio(aspectRatio)
                        val label = CameraAspectRatio.fromChannelValue(aspectRatio).label
                        val response = mutableMapOf<String, Any>(
                            "status" to "aspect_ratio_set",
                            "aspectRatio" to aspectRatio,
                            "label" to label
                        )
                        response.putAll(preview.zoomStateFields())
                        result.success(response)
                    } else {
                        result.error("CAMERA_NOT_READY", "Camera preview not initialized", null)
                    }
                }
                "setZoomRatio" -> {
                    val preview = activePreviewView
                    if (preview != null) {
                        val zoomRatio = (call.argument<Number>("zoomRatio"))
                            ?.toFloat() ?: USER_MIN_ZOOM_RATIO
                        preview.setZoomRatio(zoomRatio) { payload, errorCode, errorMsg ->
                            if (payload != null) {
                                result.success(payload)
                            } else {
                                result.error(
                                    errorCode ?: "ZOOM_FAILED",
                                    errorMsg ?: "Unable to set camera zoom",
                                    null
                                )
                            }
                        }
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
                        val response = mutableMapOf<String, Any>(
                            "status" to "lens_toggled",
                            "lens" to nextLensStr
                        )
                        response.putAll(preview.zoomStateFields(USER_MIN_ZOOM_RATIO))
                        result.success(response)
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
                    val params = offlineProcessParamsFromArguments(call.arguments)

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
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun offlineParamsFromArgs(arguments: Any?): OfflineProcessParams {
        return offlineProcessParamsFromArguments(arguments)
    }

    fun dispatchPreviewFps(fps: Int) {
        handler.post {
            eventSink?.success(
                mapOf(
                    "type" to "status_update",
                    "fps" to fps,
                    "active" to true,
                    "timestamp" to System.currentTimeMillis()
                )
            )
        }
    }

    private fun dispatchCaptureProgress(
        captureId: String,
        phase: String,
        startedAt: Long
    ) {
        val elapsedMs = SystemClock.elapsedRealtime() - startedAt
        android.util.Log.d(
            "RanaCaptureTimeline",
            "captureId=$captureId event=$phase elapsedMs=$elapsedMs"
        )
        handler.post {
            eventSink?.success(
                mapOf(
                    "type" to "capture_progress",
                    "captureId" to captureId,
                    "phase" to phase,
                    "elapsedMs" to elapsedMs
                )
            )
        }
    }

    private fun dispatchCaptureCompleted(
        captureId: String,
        uri: String?,
        qualityMetadata: CameraPreviewView.CaptureQualityMetadata?,
        startedAt: Long
    ) {
        val elapsedMs = SystemClock.elapsedRealtime() - startedAt
        android.util.Log.d(
            "RanaCaptureTimeline",
            "captureId=$captureId event=capture_completed uri=$uri elapsedMs=$elapsedMs"
        )
        handler.post {
            eventSink?.success(
                mapOf(
                    "type" to "capture_completed",
                    "captureId" to captureId,
                    "uri" to uri,
                    "elapsedMs" to elapsedMs,
                    "qualityReduced" to (qualityMetadata?.qualityReduced ?: false),
                    "inSampleSize" to (qualityMetadata?.inSampleSize ?: 1),
                    "lutSkipped" to (qualityMetadata?.lutSkipped ?: false),
                    "requestedOutputQuality" to (
                        qualityMetadata?.requestedOutputQuality
                            ?: OutputQualityProfile.HIGH_JPEG.channelValue
                    ),
                    "actualOutputFormat" to (
                        qualityMetadata?.actualOutputFormat ?: "jpeg"
                    ),
                    "outputMimeType" to (
                        qualityMetadata?.outputMimeType ?: "image/jpeg"
                    ),
                    "outputWidth" to (qualityMetadata?.outputWidth ?: 0),
                    "outputHeight" to (qualityMetadata?.outputHeight ?: 0),
                    "fileSizeBytes" to (qualityMetadata?.fileSizeBytes ?: 0),
                    "fallbackReason" to qualityMetadata?.fallbackReason
                )
            )
        }
    }

    private fun dispatchCaptureFailed(
        captureId: String,
        errorCode: String,
        message: String,
        startedAt: Long
    ) {
        val elapsedMs = SystemClock.elapsedRealtime() - startedAt
        android.util.Log.e(
            "RanaCaptureTimeline",
            "captureId=$captureId event=capture_failed code=$errorCode " +
                "message=$message elapsedMs=$elapsedMs"
        )
        handler.post {
            eventSink?.success(
                mapOf(
                    "type" to "capture_failed",
                    "captureId" to captureId,
                    "errorCode" to errorCode,
                    "message" to message,
                    "elapsedMs" to elapsedMs
                )
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DELETE_MEDIA_REQUEST_CODE) return

        val result = pendingDeleteResult ?: return
        pendingDeleteResult = null
        if (resultCode == Activity.RESULT_OK) {
            result.success(null)
        } else {
            result.error("DELETE_CANCELLED", "Delete request was cancelled", null)
        }
    }

    private fun loadCapturedImageBytes(uri: Uri, targetSize: Int? = null): ByteArray {
        val safeTargetSize = targetSize ?: 0
        if (safeTargetSize <= 0) {
            return contentResolver.openInputStream(uri)?.use { stream ->
                stream.readBytes()
            } ?: throw IllegalStateException("Unable to open image stream")
        }

        return loadResizedImageBytes(uri, safeTargetSize) ?: contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes()
        } ?: throw IllegalStateException("Unable to open image stream")
    }

    private fun loadResizedImageBytes(uri: Uri, targetSize: Int): ByteArray? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, bounds)
        } ?: return null

        val sourceWidth = bounds.outWidth
        val sourceHeight = bounds.outHeight
        if (sourceWidth <= 0 || sourceHeight <= 0) return null

        var sampleSize = 1
        while (
            sourceWidth / sampleSize > targetSize ||
            sourceHeight / sampleSize > targetSize
        ) {
            sampleSize *= 2
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: return null

        return try {
            ByteArrayOutputStream().use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output)) {
                    return null
                }
                output.toByteArray()
            }
        } finally {
            bitmap.safeRecycle()
        }
    }

    private fun listGalleryMedia(): List<Map<String, Any?>> {
        val includeRelativePath = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val projection = if (includeRelativePath) {
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_TAKEN,
                MediaStore.Images.Media.DATE_ADDED,
                MediaStore.MediaColumns.WIDTH,
                MediaStore.MediaColumns.HEIGHT,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.RELATIVE_PATH,
            )
        } else {
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_TAKEN,
                MediaStore.Images.Media.DATE_ADDED,
                MediaStore.MediaColumns.WIDTH,
                MediaStore.MediaColumns.HEIGHT,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.Images.Media.DATA,
            )
        }

        val (selection, selectionArgs) = gallerySelection()
        val sortOrder = buildString {
            append(MediaStore.Images.Media.DATE_TAKEN)
            append(" DESC, ")
            append(MediaStore.Images.Media.DATE_ADDED)
            append(" DESC")
        }

        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            items.addAll(cursor.toGalleryRows(includeRelativePath))
        }
        return items
    }

    private fun Cursor.toGalleryRows(includeRelativePath: Boolean): List<Map<String, Any?>> {
        val idCol = getColumnIndexOrThrow(MediaStore.Images.Media._ID)
        val displayNameCol = getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
        val dateTakenCol = getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
        val dateAddedCol = getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
        val widthCol = getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH)
        val heightCol = getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT)
        val sizeCol = getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
        val mimeTypeCol = getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
        val relativePathCol = if (includeRelativePath) {
            getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
        } else {
            getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
        }

        val rows = mutableListOf<Map<String, Any?>>()
        while (moveToNext()) {
            val id = getLong(idCol)
            val dateTaken = if (!isNull(dateTakenCol) && getLong(dateTakenCol) > 0L) {
                getLong(dateTakenCol)
            } else {
                getLong(dateAddedCol) * 1000L
            }
            val contentUri = ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                id
            )
            rows.add(
                mapOf(
                    "id" to id,
                    "contentUri" to contentUri.toString(),
                    "displayName" to (getString(displayNameCol) ?: "Rana photo"),
                    "dateTaken" to dateTaken,
                    "dateAdded" to getLong(dateAddedCol) * 1000L,
                    "width" to if (isNull(widthCol)) 0 else getInt(widthCol),
                    "height" to if (isNull(heightCol)) 0 else getInt(heightCol),
                    "sizeBytes" to if (isNull(sizeCol)) null else getLong(sizeCol),
                    "mimeType" to getString(mimeTypeCol),
                    "relativePath" to if (isNull(relativePathCol)) null else getString(relativePathCol),
                )
            )
        }
        return rows
    }

    private fun gallerySelection(): Pair<String?, Array<String>?> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection = buildString {
                append("(")
                append(MediaStore.MediaColumns.RELATIVE_PATH)
                append(" = ? OR ")
                append(MediaStore.MediaColumns.RELATIVE_PATH)
                append(" LIKE ?)")
            }
            selection to arrayOf("Pictures/Rana", "Pictures/Rana/%")
        } else {
            "${MediaStore.Images.Media.DATA} LIKE ?" to arrayOf("%/Pictures/Rana/%")
        }
    }

    private fun loadGalleryThumbnailBytes(uri: Uri, targetSizePx: Int): ByteArray {
        val bitmap = decodeSampledBitmapFromUri(uri, targetSizePx)
        return ByteArrayOutputStream().use { output ->
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output)) {
                bitmap.safeRecycle()
                throw IOException("Bitmap compression failed")
            }
            bitmap.safeRecycle()
            output.toByteArray()
        }
    }

    private fun decodeSampledBitmapFromUri(uri: Uri, targetSizePx: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }

        val streamForBounds = contentResolver.openInputStream(uri)
            ?: throw IOException("Unable to open image stream for bounds")
        streamForBounds.use { stream ->
            BitmapFactory.decodeStream(stream, null, bounds)
        }

        val sampleSize = calculateSampleSize(bounds.outWidth, bounds.outHeight, targetSizePx)
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.RGB_565
        }

        return contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: throw IOException("Unable to decode image thumbnail")
    }

    private fun calculateSampleSize(
        width: Int,
        height: Int,
        targetSizePx: Int
    ): Int {
        if (width <= 0 || height <= 0 || targetSizePx <= 0) {
            return 1
        }

        var sampleSize = 1
        var halfWidth = width / 2
        var halfHeight = height / 2
        while (halfWidth / sampleSize >= targetSizePx ||
            halfHeight / sampleSize >= targetSizePx
        ) {
            sampleSize *= 2
        }
        return sampleSize.coerceAtLeast(1)
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

    private fun shareGalleryMedia(
        uri: Uri,
        result: MethodChannel.Result
    ) {
        mediaStoreExecutor.execute {
            try {
                val sourceMimeType = contentResolver.getType(uri) ?: "image/*"
                val shareUri = if (sourceMimeType.equals("image/heic", true) ||
                    sourceMimeType.equals("image/heif", true)
                ) {
                    createCompatibleShareJpeg(uri)
                } else {
                    uri
                }
                val shareMimeType = if (shareUri == uri) sourceMimeType else "image/jpeg"
                handler.post {
                    try {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = shareMimeType
                            putExtra(Intent.EXTRA_STREAM, shareUri)
                            clipData = ClipData.newRawUri("Rana photo", shareUri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(shareIntent, "Share Rana photo"))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SHARE_MEDIA_FAILED", e.message, null)
                    }
                }
            } catch (e: Exception) {
                handler.post { result.error("SHARE_MEDIA_FAILED", e.message, null) }
            }
        }
    }

    /** Produces a share-only JPEG; the original HEIC in MediaStore is untouched. */
    private fun createCompatibleShareJpeg(sourceUri: Uri): Uri {
        cleanupShareCache()
        val bitmap = decodeShareBitmap(sourceUri)
        val directory = File(cacheDir, "share").apply { mkdirs() }
        val file = File.createTempFile("rana-share-", ".jpg", directory)
        try {
            FileOutputStream(file).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 95, output)) {
                    throw IOException("Unable to encode compatible share image")
                }
            }
        } finally {
            bitmap.safeRecycle()
        }
        return FileProvider.getUriForFile(this, "$packageName.rana.share", file)
    }

    private fun decodeShareBitmap(uri: Uri): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, bounds)
        } ?: throw IOException("Unable to open image for share")
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IOException("Unable to read image dimensions for share")
        }
        val sampleSize = calculateSampleSize(bounds.outWidth, bounds.outHeight, 4096)
        val bitmap = contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(
                stream,
                null,
                BitmapFactory.Options().apply {
                    inSampleSize = sampleSize
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }
            )
        } ?: throw IOException("Unable to decode image for share")
        val longestEdge = maxOf(bitmap.width, bitmap.height)
        if (longestEdge <= 4096) return bitmap
        val scale = 4096f / longestEdge
        val scaled = Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true
        )
        if (scaled !== bitmap) bitmap.safeRecycle()
        return scaled
    }

    private fun cleanupShareCache() {
        val now = System.currentTimeMillis()
        val maxAgeMs = 24L * 60L * 60L * 1000L
        val directory = File(cacheDir, "share")
        directory.listFiles()?.forEach { file ->
            if (now - file.lastModified() > maxAgeMs) file.delete()
        }
    }

    private fun deleteGalleryMedia(
        uri: Uri,
        result: MethodChannel.Result
    ) {
        mediaStoreExecutor.execute {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    requestScopedDelete(uri, result)
                    return@execute
                }

                val deleted = tryDeleteUri(uri)
                handler.post {
                    if (deleted) {
                        result.success(null)
                    } else {
                        result.error("DELETE_MEDIA_FAILED", "MediaStore item was not deleted", null)
                    }
                }
            } catch (e: RecoverableSecurityException) {
                handler.post {
                    requestDeleteWithIntentSender(
                        e.userAction.actionIntent.intentSender,
                        result
                    )
                }
            } catch (e: SecurityException) {
                handler.post { result.error("PERMISSION_DENIED", e.message, null) }
            } catch (e: Exception) {
                handler.post { result.error("DELETE_MEDIA_FAILED", e.message, null) }
            }
        }
    }

    private fun tryDeleteUri(uri: Uri): Boolean {
        return contentResolver.delete(uri, null, null) > 0
    }

    private fun requestScopedDelete(
        uri: Uri,
        result: MethodChannel.Result
    ) {
        val intentSender = MediaStore.createDeleteRequest(
            contentResolver,
            listOf(uri)
        ).intentSender
        handler.post { requestDeleteWithIntentSender(intentSender, result) }
    }

    private fun requestDeleteWithIntentSender(
        intentSender: IntentSender,
        result: MethodChannel.Result
    ) {
        if (pendingDeleteResult != null) {
            result.error("DELETE_ALREADY_PENDING", "Another delete request is pending", null)
            return
        }

        pendingDeleteResult = result
        try {
            startIntentSenderForResult(
                intentSender,
                DELETE_MEDIA_REQUEST_CODE,
                null,
                0,
                0,
                0,
                null
            )
        } catch (e: Exception) {
            pendingDeleteResult = null
            result.error("DELETE_REQUEST_FAILED", e.message, null)
        }
    }

    private fun android.graphics.Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
    }
}
