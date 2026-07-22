package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import androidx.heifwriter.HeifWriter
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Locale

internal data class RanaSavedOutput(
    val uri: android.net.Uri,
    val profile: OutputQualityProfile,
    val fileSizeBytes: Long,
    val fallbackReason: String?
)

internal class RanaHeicEncoder {
    fun write(bitmap: Bitmap, descriptor: ParcelFileDescriptor, quality: Int) {
        val writer = HeifWriter.Builder(
            descriptor.fileDescriptor,
            bitmap.width,
            bitmap.height,
            HeifWriter.INPUT_MODE_BITMAP
        ).setQuality(quality).setMaxImages(1).build()
        try {
            writer.start()
            writer.addBitmap(bitmap)
            writer.stop(10_000)
        } finally {
            writer.close()
        }
    }
}

/** Owns MediaStore insertion, encoding fallback, and failed-row cleanup. */
internal class RanaMediaStoreWriter(
    context: Context,
    private val viewId: Int,
    private val heicEncoder: RanaHeicEncoder = RanaHeicEncoder()
) {
    private val context = context.applicationContext

    fun save(bitmap: Bitmap, zoomRatio: Float, params: OfflineProcessParams): RanaSavedOutput? {
        val filenameStem = captureFilenameStem(
            presetId = params.presetId,
            isStyleModified = params.isStyleModified,
            timestamp = SimpleDateFormat("yyyy-MM-dd-HH-mm-ss-SSS", Locale.US)
                .format(System.currentTimeMillis())
        )
        val resolved = resolveOutputQuality(params.outputQuality)
        val primary = saveProfile(
            bitmap,
            zoomRatio,
            filenameStem,
            resolved.actual,
            resolved.fallbackReason
        )
        if (primary != null) return primary
        return if (resolved.actual == OutputQualityProfile.EFFICIENT_HEIC) {
            saveProfile(
                bitmap,
                zoomRatio,
                filenameStem,
                OutputQualityProfile.HIGH_JPEG,
                "heic_encode_failed"
            )
        } else {
            null
        }
    }

    fun publish(uri: android.net.Uri) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.IS_PENDING, 0)
        }
        if (context.contentResolver.update(uri, values, null, null) != 1) {
            throw IOException("Unable to publish MediaStore capture")
        }
    }

    private fun saveProfile(
        bitmap: Bitmap,
        zoomRatio: Float,
        filenameStem: String,
        profile: OutputQualityProfile,
        fallbackReason: String?
    ): RanaSavedOutput? {
        val displayName = "$filenameStem.${profile.extension}"
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, profile.mimeType)
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
                if (!directory.exists()) directory.mkdirs()
                put(MediaStore.Images.Media.DATA, File(directory, displayName).absolutePath)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null
        var success = false
        try {
            val bytes = when (profile) {
                OutputQualityProfile.STANDARD_JPEG,
                OutputQualityProfile.HIGH_JPEG -> resolver.openOutputStream(uri)?.use { output ->
                    val counting = CountingStream(output)
                    if (!bitmap.compress(
                            Bitmap.CompressFormat.JPEG,
                            profile.encoderQuality,
                            counting
                        )
                    ) {
                        throw IOException("Bitmap compression failed")
                    }
                    counting.bytesWritten
                } ?: throw IOException("Unable to open MediaStore output stream")

                OutputQualityProfile.EFFICIENT_HEIC -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        throw IOException("HEIC requires Android 9 or later")
                    }
                    resolver.openFileDescriptor(uri, "w")?.use { descriptor ->
                        heicEncoder.write(bitmap, descriptor, profile.encoderQuality)
                    } ?: throw IOException("Unable to open MediaStore file descriptor")
                    resolver.openAssetFileDescriptor(uri, "r")?.use {
                        it.length.coerceAtLeast(0L)
                    } ?: 0L
                }
            }
            CameraQualityAudit.logCaptureSaved(viewId, bitmap, bytes, zoomRatio)
            success = true
            return RanaSavedOutput(uri, profile, bytes, fallbackReason)
        } catch (error: Exception) {
            android.util.Log.e("RanaMediaStoreWriter", "Failed to save capture", error)
            return null
        } finally {
            if (!success) resolver.delete(uri, null, null)
        }
    }

    private class CountingStream(private val delegate: OutputStream) : OutputStream() {
        var bytesWritten = 0L
            private set

        override fun write(value: Int) {
            delegate.write(value)
            bytesWritten += 1
        }

        override fun write(bytes: ByteArray, offset: Int, length: Int) {
            delegate.write(bytes, offset, length)
            bytesWritten += length
        }

        override fun flush() = delegate.flush()

        override fun close() = delegate.close()
    }
}
