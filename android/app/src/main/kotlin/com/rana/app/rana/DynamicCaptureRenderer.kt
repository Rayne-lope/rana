package com.rana.app.rana

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.Date

private const val DEFAULT_DETAIL_TARGET_SIZE = 2048
private const val MIN_RENDER_TARGET_SIZE = 64
private const val MAX_RENDER_TARGET_SIZE = 4096
private const val RENDER_CACHE_BYTES = 24 * 1024 * 1024

internal fun dynamicRenderTargetSize(requestedTargetSize: Int?): Int =
    if (requestedTargetSize == null || requestedTargetSize <= 0) {
        DEFAULT_DETAIL_TARGET_SIZE
    } else {
        requestedTargetSize.coerceIn(
            MIN_RENDER_TARGET_SIZE,
            MAX_RENDER_TARGET_SIZE
        )
    }

internal fun dynamicBitmapSampleSize(
    sourceWidth: Int,
    sourceHeight: Int,
    targetSize: Int
): Int {
    if (sourceWidth <= 0 || sourceHeight <= 0 || targetSize <= 0) return 1
    var sampleSize = 1
    while (
        sourceWidth / (sampleSize * 2) >= targetSize ||
        sourceHeight / (sampleSize * 2) >= targetSize
    ) {
        sampleSize *= 2
    }
    return sampleSize
}

internal fun dynamicRenderCacheKey(
    uri: String,
    targetSize: Int,
    metadataUpdatedAt: Long
): String = "$uri|$targetSize|$metadataUpdatedAt"

internal fun shouldRenderCaptureDynamically(
    metadata: CaptureStyleMetadata
): Boolean = !metadata.mediaIsRendered

internal class DynamicCaptureRenderer(
    context: Context,
    private val metadataStore: CaptureStyleMetadataStore
) {
    private val appContext = context.applicationContext
    private val renderedBytesCache = object : LruCache<String, ByteArray>(
        RENDER_CACHE_BYTES
    ) {
        override fun sizeOf(key: String, value: ByteArray): Int = value.size
    }

    fun loadBytes(
        uri: Uri,
        requestedTargetSize: Int?,
        loadLegacyBytes: () -> ByteArray
    ): ByteArray {
        val metadata = try {
            metadataStore.find(uri.toString())
        } catch (e: Exception) {
            Log.e("DynamicCaptureRenderer", "Metadata lookup failed for $uri", e)
            null
        } ?: return loadLegacyBytes()
        if (!shouldRenderCaptureDynamically(metadata)) {
            return loadLegacyBytes()
        }

        val targetSize = dynamicRenderTargetSize(requestedTargetSize)
        val cacheKey = dynamicRenderCacheKey(
            uri.toString(),
            targetSize,
            metadata.updatedAtEpochMs
        )
        renderedBytesCache.get(cacheKey)?.let { return it }

        val rendered = try {
            renderBytes(uri, targetSize, metadata)
        } catch (e: Exception) {
            Log.e("DynamicCaptureRenderer", "Dynamic render failed for $uri", e)
            null
        } ?: return loadLegacyBytes()

        renderedBytesCache.put(cacheKey, rendered)
        return rendered
    }

    fun invalidate(uri: String) {
        renderedBytesCache.snapshot().keys
            .filter { key -> key.startsWith("$uri|") }
            .forEach(renderedBytesCache::remove)
    }

    fun release() {
        renderedBytesCache.evictAll()
    }

    private fun renderBytes(
        uri: Uri,
        targetSize: Int,
        metadata: CaptureStyleMetadata
    ): ByteArray? {
        val cleanBitmap = decodeCleanBitmap(uri, targetSize)
        val params = offlineProcessParamsFromArguments(metadata.params)
        val processed = OfflineGlProcessor.processImage(
            appContext,
            cleanBitmap,
            params
        ) ?: run {
            if (!cleanBitmap.isRecycled) cleanBitmap.recycle()
            return null
        }

        var output = processed
        if (params.dateStampEnable) {
            val stamped = applyDateStamp(
                processed,
                Date(metadata.createdAtEpochMs)
            )
            if (stamped !== processed && !processed.isRecycled) {
                processed.recycle()
            }
            output = stamped
        }

        return try {
            ByteArrayOutputStream().use { bytes ->
                if (!output.compress(Bitmap.CompressFormat.JPEG, 90, bytes)) {
                    throw IOException("Dynamic render compression failed")
                }
                bytes.toByteArray()
            }
        } finally {
            if (!output.isRecycled) output.recycle()
        }
    }

    private fun decodeCleanBitmap(uri: Uri, targetSize: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        appContext.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, bounds)
        } ?: throw IOException("Unable to open clean image bounds")

        val options = BitmapFactory.Options().apply {
            inSampleSize = dynamicBitmapSampleSize(
                bounds.outWidth,
                bounds.outHeight,
                targetSize
            )
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return appContext.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: throw IOException("Unable to decode clean image")
    }
}
