package com.rana.app.rana

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
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
import androidx.camera.core.CameraSelector
import android.provider.MediaStore
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.rana.app/camera_control"
    private val EVENT_CHANNEL = "com.rana.app/camera_status"
    private val DELETE_MEDIA_REQUEST_CODE = 4107

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private val mediaStoreExecutor = Executors.newSingleThreadExecutor()
    private var pendingDeleteResult: MethodChannel.Result? = null
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
                        result.success(
                            mapOf(
                                "status" to "aspect_ratio_set",
                                "aspectRatio" to aspectRatio,
                                "label" to label
                            )
                        )
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
                    val bloomThreshold = (call.argument<Number>("bloomThreshold"))
                        ?.toFloat() ?: 0.8f
                    val bloomIntensity = (call.argument<Number>("bloomIntensity"))
                        ?.toFloat() ?: 0f
                    val halationIntensity = (call.argument<Number>("halationIntensity"))
                        ?.toFloat() ?: 0f
                    val lensDistortionStrength = (
                        call.argument<Number>("lensDistortionStrength")
                    )?.toFloat() ?: 0f
                    val tone = (call.argument<Number>("tone"))
                        ?.toFloat() ?: 0f
                    val color = (call.argument<Number>("color"))
                        ?.toFloat() ?: 0f
                    val textureVal = (call.argument<Number>("textureVal"))
                        ?.toFloat() ?: 0f
                    val styleStrength = (call.argument<Number>("styleStrength"))
                        ?.toFloat() ?: 100f
                    val undertoneX = (call.argument<Number>("undertoneX"))
                        ?.toFloat() ?: 0f
                    val undertoneY = (call.argument<Number>("undertoneY"))
                        ?.toFloat() ?: 0f
                    val grainSize = (call.argument<Number>("grainSize"))
                        ?.toFloat() ?: 1f
                    val softness = (call.argument<Number>("softness"))
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
                                dustIntensity = dustIntensity,
                                bloomThreshold = bloomThreshold,
                                bloomIntensity = bloomIntensity,
                                halationIntensity = halationIntensity,
                                lensDistortionStrength = lensDistortionStrength,
                                tone = tone,
                                color = color,
                                textureVal = textureVal,
                                styleStrength = styleStrength,
                                undertoneX = undertoneX,
                                undertoneY = undertoneY,
                                grainSize = grainSize,
                                softness = softness
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
                }

                override fun onCancel(arguments: Any?) {
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
            dustIntensity = numberArg("dustIntensity"),
            bloomThreshold = (args?.get("bloomThreshold") as? Number)?.toFloat() ?: 0.8f,
            bloomIntensity = numberArg("bloomIntensity"),
            halationIntensity = numberArg("halationIntensity"),
            lensDistortionStrength = numberArg("lensDistortionStrength"),
            tone = numberArg("tone"),
            color = numberArg("color"),
            textureVal = numberArg("textureVal"),
            styleStrength = (args?.get("styleStrength") as? Number)?.toFloat() ?: 100f,
            undertoneX = numberArg("undertoneX"),
            undertoneY = numberArg("undertoneY"),
            grainSize = (args?.get("grainSize") as? Number)?.toFloat() ?: 1f,
            softness = numberArg("softness")
        )
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

    private fun loadCapturedImageBytes(uri: Uri): ByteArray {
        return contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes()
        } ?: throw IllegalStateException("Unable to open image stream")
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
        handler.post {
            try {
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/*"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(shareIntent, "Share Rana photo"))
                result.success(null)
            } catch (e: Exception) {
                result.error("SHARE_MEDIA_FAILED", e.message, null)
            }
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
