package com.rana.app.rana

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareCacheFilesTest {
    @Test
    fun `uses the requested contact sheet JPEG quality`() {
        assertEquals(92, ShareCacheFiles.contactSheetJpegQuality)
    }

    @Test
    fun `recognizes only the PNG byte signature`() {
        val validPngPrefix = byteArrayOf(
            0x89.toByte(),
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A
        )

        assertTrue(ShareCacheFiles.hasPngSignature(validPngPrefix))
        assertFalse(ShareCacheFiles.hasPngSignature(byteArrayOf()))
        assertFalse(ShareCacheFiles.hasPngSignature("not a PNG".toByteArray()))
        assertFalse(
            ShareCacheFiles.hasPngSignature(
                validPngPrefix.copyOf().also { it[0] = 0x00 }
            )
        )
    }

    @Test
    fun `creates unique JPEG files inside the FileProvider share directory`() {
        withTemporaryCacheDir { cacheDir ->
            val first = ShareCacheFiles.createJpegFile(cacheDir)
            val second = ShareCacheFiles.createJpegFile(cacheDir)

            assertTrue(first.exists())
            assertTrue(second.exists())
            assertFalse(first == second)
            assertEquals(File(cacheDir, ShareCacheFiles.directoryName), first.parentFile)
            assertTrue(first.name.startsWith("rana-share-"))
            assertTrue(first.name.endsWith(".jpg"))
        }
    }

    @Test
    fun `cleanup retains current shares and removes stale files only`() {
        withTemporaryCacheDir { cacheDir ->
            val shareDir = File(cacheDir, ShareCacheFiles.directoryName).apply {
                assertTrue(mkdirs())
            }
            val now = System.currentTimeMillis()
            val stale = File(shareDir, "stale.jpg").apply {
                writeBytes(byteArrayOf(1))
                assertTrue(setLastModified(now - ShareCacheFiles.maxAgeMs - 60_000))
            }
            val current = File(shareDir, "current.jpg").apply {
                writeBytes(byteArrayOf(2))
                assertTrue(setLastModified(now - ShareCacheFiles.maxAgeMs + 60_000))
            }

            ShareCacheFiles.cleanup(cacheDir, now)

            assertFalse(stale.exists())
            assertTrue(current.exists())
        }
    }

    private fun withTemporaryCacheDir(block: (File) -> Unit) {
        val temporaryFile = File.createTempFile("rana-share-cache-", "")
        assertTrue(temporaryFile.delete())
        assertTrue(temporaryFile.mkdirs())
        try {
            block(temporaryFile)
        } finally {
            temporaryFile.deleteRecursively()
        }
    }
}
