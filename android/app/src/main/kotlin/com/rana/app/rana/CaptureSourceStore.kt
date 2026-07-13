package com.rana.app.rana

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

private const val CAPTURE_SOURCE_DIRECTORY = "capture_sources"
private const val CAPTURE_SOURCE_JPEG_QUALITY = 95
private const val MAX_CAPTURE_SOURCE_ID_LENGTH = 96

internal fun sanitizeCaptureSourceId(captureId: String): String {
    val sanitized = buildString {
        captureId.forEach { character ->
            append(
                if (character.isLetterOrDigit() || character == '-' || character == '_') {
                    character
                } else {
                    '_'
                }
            )
        }
    }.trim('_').take(MAX_CAPTURE_SOURCE_ID_LENGTH)
    return sanitized.ifEmpty { "capture" }
}

internal fun isOwnedCaptureSource(directory: File, path: String): Boolean = try {
    val canonicalDirectory = directory.canonicalFile
    val candidate = File(path).canonicalFile
    candidate.parentFile == canonicalDirectory && candidate.extension == "jpg"
} catch (_: IOException) {
    false
}

internal fun missingCaptureMedia(
    metadata: List<CaptureStyleMetadata>,
    mediaExists: (String) -> Boolean?
): List<CaptureStyleMetadata> = metadata.filter { mediaExists(it.mediaUri) == false }

internal class CaptureSourceStore(
    private val directory: File
) {
    constructor(context: Context) : this(
        File(context.applicationContext.filesDir, CAPTURE_SOURCE_DIRECTORY)
    )

    fun saveBitmap(bitmap: Bitmap, captureId: String): String? = try {
        writeAtomically(captureId) { output ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, CAPTURE_SOURCE_JPEG_QUALITY, output)
        }.absolutePath
    } catch (failure: OutOfMemoryError) {
        Log.e("RanaCaptureSource", "Insufficient memory for private clean source", failure)
        null
    } catch (failure: Exception) {
        Log.e("RanaCaptureSource", "Unable to save private clean source", failure)
        null
    }

    internal fun writeAtomically(
        captureId: String,
        writer: (OutputStream) -> Boolean
    ): File {
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Unable to create private capture source directory")
        }
        val safeId = sanitizeCaptureSourceId(captureId)
        val finalFile = File(directory, "$safeId.jpg")
        val temporaryFile = File(
            directory,
            ".$safeId-${UUID.randomUUID()}.tmp"
        )

        try {
            FileOutputStream(temporaryFile).use { output ->
                if (!writer(output)) {
                    throw IOException("Private capture source compression failed")
                }
                output.flush()
                output.fd.sync()
            }
            if (finalFile.exists() && !finalFile.delete()) {
                throw IOException("Unable to replace private capture source")
            }
            if (!temporaryFile.renameTo(finalFile)) {
                throw IOException("Unable to commit private capture source")
            }
            return finalFile
        } finally {
            temporaryFile.delete()
        }
    }

    fun delete(path: String?): Boolean {
        if (path == null || !isOwnedCaptureSource(directory, path)) return false
        val source = File(path)
        return !source.exists() || source.delete()
    }
}
