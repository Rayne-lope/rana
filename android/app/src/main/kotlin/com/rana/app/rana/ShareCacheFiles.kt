package com.rana.app.rana

import java.io.File
import java.io.IOException

/**
 * File-only utilities for transient images shared outside Rana.
 *
 * Files live beneath the FileProvider-approved internal cache directory. They
 * are deliberately not MediaStore entries: Android may evict cache data, and
 * the files exist only long enough for a target share app to read them.
 */
internal object ShareCacheFiles {
    const val directoryName = "share"
    const val maxAgeMs = 24L * 60L * 60L * 1000L
    const val contactSheetJpegQuality = 92

    private val pngSignature = byteArrayOf(
        0x89.toByte(),
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A
    )

    /** Returns true only when [bytes] begins with the PNG file signature. */
    fun hasPngSignature(bytes: ByteArray): Boolean =
        bytes.size >= pngSignature.size && pngSignature.indices.all { index ->
            bytes[index] == pngSignature[index]
        }

    /** Creates a unique JPEG destination beneath the configured share cache. */
    @Throws(IOException::class)
    fun createJpegFile(cacheDir: File, prefix: String = "rana-share-"): File {
        require(prefix.length >= 3) { "Share file prefix must contain three characters" }
        val directory = File(cacheDir, directoryName)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Unable to create Rana share cache")
        }
        if (!directory.isDirectory) {
            throw IOException("Rana share cache path is not a directory")
        }
        return File.createTempFile(prefix, ".jpg", directory)
    }

    /** Removes only stale share-cache files and leaves current shares available. */
    fun cleanup(cacheDir: File, nowMs: Long = System.currentTimeMillis()) {
        val directory = File(cacheDir, directoryName)
        directory.listFiles()?.forEach { file ->
            if (file.isFile && nowMs - file.lastModified() > maxAgeMs) {
                file.delete()
            }
        }
    }
}
