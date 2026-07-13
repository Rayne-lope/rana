package com.rana.app.rana

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureSourceStoreTest {
    @Test
    fun `capture id is sanitized and bounded for private filenames`() {
        assertEquals("capture__1", sanitizeCaptureSourceId("capture:/1"))
        assertEquals("capture", sanitizeCaptureSourceId("..."))
        assertEquals(96, sanitizeCaptureSourceId("a".repeat(120)).length)
    }

    @Test
    fun `source writes atomically without leaving temporary files`() {
        withTemporaryDirectory { directory ->
            val store = CaptureSourceStore(directory)
            val source = store.writeAtomically("capture:/1") { output ->
                output.write(byteArrayOf(1, 2, 3))
                true
            }

            assertEquals("capture__1.jpg", source.name)
            assertEquals(listOf(1, 2, 3), source.readBytes().map(Byte::toInt))
            assertEquals(listOf(source), directory.listFiles()?.toList())
        }
    }

    @Test
    fun `failed source write removes temporary output`() {
        withTemporaryDirectory { directory ->
            val store = CaptureSourceStore(directory)

            val failure = runCatching {
                store.writeAtomically("capture") { false }
            }.exceptionOrNull()

            assertTrue(failure != null)
            assertTrue(directory.listFiles().isNullOrEmpty())
        }
    }

    @Test
    fun `delete only accepts owned jpeg source paths`() {
        withTemporaryDirectory { directory ->
            val store = CaptureSourceStore(directory)
            val source = store.writeAtomically("capture") { output ->
                output.write(1)
                true
            }
            val external = Files.createTempFile("rana-external", ".jpg").toFile().apply {
                writeBytes(byteArrayOf(1))
            }

            assertFalse(store.delete(external.absolutePath))
            assertTrue(external.exists())
            assertTrue(store.delete(source.absolutePath))
            assertFalse(source.exists())
            external.delete()
        }
    }

    @Test
    fun `missing media selection supports orphan pruning`() {
        val metadata = listOf(
            captureMetadata("content://capture/1"),
            captureMetadata("content://capture/2"),
            captureMetadata("content://capture/unknown")
        )

        val missing = missingCaptureMedia(metadata) { uri ->
            when {
                uri.endsWith("/1") -> true
                uri.endsWith("/2") -> false
                else -> null
            }
        }

        assertEquals(listOf("content://capture/2"), missing.map { it.mediaUri })
    }

    private fun captureMetadata(uri: String) = CaptureStyleMetadata(
        mediaUri = uri,
        sourceImagePath = "/private/source.jpg",
        mediaIsRendered = true,
        presetId = "preset",
        undertoneX = 0f,
        undertoneY = 0f,
        params = emptyMap(),
        createdAtEpochMs = 100L
    )

    private fun withTemporaryDirectory(block: (File) -> Unit) {
        val directory = Files.createTempDirectory("rana-capture-source").toFile()
        try {
            block(directory)
        } finally {
            directory.deleteRecursively()
        }
    }
}
