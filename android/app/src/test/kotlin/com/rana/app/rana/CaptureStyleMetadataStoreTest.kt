package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureStyleMetadataStoreTest {
    @Test
    fun `supported channel parameters round trip through storage codec`() {
        val values = listOf<Any?>(
            null,
            true,
            false,
            0.35,
            -4,
            "assets/luts/look.png",
            listOf(1.0, 0.0, 0.25)
        )

        val decoded = values.map { value ->
            decodeCaptureParameter(requireNotNull(encodeCaptureParameter(value)))
        }

        assertEquals(null, decoded[0])
        assertEquals(true, decoded[1])
        assertEquals(false, decoded[2])
        assertEquals(0.35, decoded[3])
        assertEquals(-4.0, decoded[4])
        assertEquals("assets/luts/look.png", decoded[5])
        assertEquals(listOf(1.0, 0.0, 0.25), decoded[6])
    }

    @Test
    fun `unsupported and non finite values are rejected`() {
        assertNull(encodeCaptureParameter(Double.NaN))
        assertNull(encodeCaptureParameter(listOf(1.0, Double.POSITIVE_INFINITY)))
        assertNull(encodeCaptureParameter(mapOf("nested" to true)))
    }

    @Test
    fun `version five schema stores recipe version and capture context`() {
        assertEquals(5, CaptureStyleMetadataSchema.DATABASE_VERSION)
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_PARAMS.contains(
                "FOREIGN KEY (media_uri)"
            )
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_PARAMS.contains("ON DELETE CASCADE")
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains(
                "media_uri TEXT PRIMARY KEY NOT NULL"
            )
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains(
                "source_image_path TEXT"
            )
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains(
                "media_is_rendered INTEGER NOT NULL"
            )
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains("film_roll_id TEXT")
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains(
                "recipe_version INTEGER NOT NULL"
            )
        )
    }

    @Test
    fun `version three migration preserves legacy uri as unrendered media`() {
        val migration = CaptureStyleMetadataSchema.MIGRATE_V2_TO_V3.joinToString("\n")

        assertTrue(migration.contains("clean_image_uri"))
        assertTrue(migration.contains("media_uri"))
        assertTrue(migration.contains("source_image_path"))
        assertTrue(migration.contains("media_is_rendered"))
        assertTrue(Regex("NULL,\\s+0,").containsMatchIn(migration))
        assertFalse(
            "The v2→v3 table must not pre-add the v4 column.",
            migration.contains("film_roll_id")
        )
    }

    @Test
    fun `version four migration adds nullable film roll id`() {
        val migration = CaptureStyleMetadataSchema.MIGRATE_V3_TO_V4.joinToString("\\n")

        assertTrue(migration.contains("ALTER TABLE capture_styles"))
        assertTrue(migration.contains("ADD COLUMN film_roll_id TEXT"))
    }

    @Test
    fun `v2 to v4 upgrade creates then adds film roll id exactly once`() {
        val v2ToV3 = CaptureStyleMetadataSchema.MIGRATE_V2_TO_V3.joinToString("\n")
        val v3ToV4 = CaptureStyleMetadataSchema.MIGRATE_V3_TO_V4.joinToString("\n")

        assertFalse(v2ToV3.contains("film_roll_id"))
        assertEquals(1, Regex("film_roll_id").findAll(v3ToV4).count())
    }

    @Test
    fun `version five migration marks v4 rows as legacy v0 recipes`() {
        val migration = CaptureStyleMetadataSchema.MIGRATE_V4_TO_V5.joinToString("\n")

        assertTrue(migration.contains("ALTER TABLE capture_styles"))
        assertTrue(migration.contains("ADD COLUMN recipe_version INTEGER NOT NULL DEFAULT 0"))
    }

    @Test
    fun `film roll capture query scopes records and orders them deterministically`() {
        assertEquals(
            "film_roll_id = ?",
            CaptureStyleMetadataSchema.FILM_ROLL_CAPTURE_SELECTION
        )
        assertEquals(
            "created_at_epoch_ms ASC, media_uri ASC",
            CaptureStyleMetadataSchema.FILM_ROLL_CAPTURE_SORT_ORDER
        )
        assertTrue(
            CaptureStyleMetadataSchema.CREATE_CAPTURES.contains("film_roll_id TEXT")
        )
    }

    @Test
    fun `film roll record retains capture association data`() {
        val record = FilmRollCaptureRecord(
            mediaUri = "content://media/external/images/media/42",
            capturedAtEpochMs = 1_700_000_000_123L
        )

        assertEquals("content://media/external/images/media/42", record.mediaUri)
        assertEquals(1_700_000_000_123L, record.capturedAtEpochMs)
    }

    @Test
    fun `rendered capture persists metadata before publishing media`() {
        val events = mutableListOf<String>()

        val metadataPersisted = commitRenderedCapture(
            persistMetadata = { events += "metadata" },
            publishMedia = { events += "publish" },
            discardSidecar = { events += "discard_sidecar" },
            rollbackMedia = { events += "rollback_media" }
        )

        assertTrue(metadataPersisted)
        assertEquals(listOf("metadata", "publish"), events)
    }

    @Test
    fun `sidecar failure still publishes flattened rendered media`() {
        val events = mutableListOf<String>()

        val metadataPersisted = commitRenderedCapture(
            persistMetadata = {
                events += "metadata"
                error("metadata failed")
            },
            publishMedia = { events += "publish" },
            discardSidecar = { events += "discard_sidecar" },
            rollbackMedia = { events += "rollback_media" },
            onSidecarFailure = {
                events += "sidecar_failure"
                error("logging failed")
            }
        )

        assertFalse(metadataPersisted)
        assertEquals(
            listOf("metadata", "sidecar_failure", "discard_sidecar", "publish"),
            events
        )
    }

    @Test
    fun `publish failure rolls back sidecar and rendered media`() {
        val events = mutableListOf<String>()

        runCatching {
            commitRenderedCapture(
                persistMetadata = { events += "metadata" },
                publishMedia = {
                    events += "publish"
                    error("publish failed")
                },
                discardSidecar = { events += "discard_sidecar" },
                rollbackMedia = { events += "rollback_media" }
            )
        }

        assertEquals(
            listOf(
                "metadata",
                "publish",
                "discard_sidecar",
                "rollback_media"
            ),
            events
        )
    }
}
