package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal data class CaptureStyleMetadata(
    val mediaUri: String,
    val sourceImagePath: String? = null,
    val mediaIsRendered: Boolean = false,
    val presetId: String,
    val undertoneX: Float,
    val undertoneY: Float,
    val params: Map<String, Any?>,
    val createdAtEpochMs: Long,
    val updatedAtEpochMs: Long = createdAtEpochMs,
    val filmRollId: String? = null
) {
    fun toChannelMap(): Map<String, Any?> {
        return mapOf(
            "mediaUri" to mediaUri,
            "sourceImagePath" to sourceImagePath,
            "mediaIsRendered" to mediaIsRendered,
            "presetId" to presetId,
            "undertoneX" to undertoneX,
            "undertoneY" to undertoneY,
            "params" to params,
            "createdAtEpochMs" to createdAtEpochMs,
            "updatedAtEpochMs" to updatedAtEpochMs,
            "filmRollId" to filmRollId
        )
    }
}

/**
 * The minimal, read-only capture metadata needed to reconcile an active Film
 * Roll after the Flutter process or camera lifecycle has been interrupted.
 */
internal data class FilmRollCaptureRecord(
    val mediaUri: String,
    val capturedAtEpochMs: Long
)

internal data class StoredCaptureParameter(
    val type: String,
    val value: String?
)

internal object CaptureStyleMetadataSchema {
    const val DATABASE_NAME = "rana_capture_styles.db"
    const val DATABASE_VERSION = 4
    const val CAPTURES_TABLE = "capture_styles"
    const val PARAMS_TABLE = "capture_style_params"
    const val FILM_ROLL_CAPTURE_SELECTION = "film_roll_id = ?"
    const val FILM_ROLL_CAPTURE_SORT_ORDER =
        "created_at_epoch_ms ASC, media_uri ASC"
    private const val LEGACY_CAPTURES_TABLE = "capture_styles_v2"
    private const val LEGACY_PARAMS_TABLE = "capture_style_params_v2"

    const val CREATE_CAPTURES = """
        CREATE TABLE capture_styles (
            media_uri TEXT PRIMARY KEY NOT NULL,
            source_image_path TEXT,
            media_is_rendered INTEGER NOT NULL DEFAULT 0
                CHECK (media_is_rendered IN (0, 1)),
            preset_id TEXT NOT NULL,
            undertone_x REAL NOT NULL,
            undertone_y REAL NOT NULL,
            created_at_epoch_ms INTEGER NOT NULL,
            updated_at_epoch_ms INTEGER NOT NULL,
            film_roll_id TEXT
        )
    """
    // Keep the historical v3 table shape separate from the latest create
    // schema. An upgrade from v1/v2 first rebuilds into v3, then the v3→v4
    // step adds `film_roll_id` exactly once. Fresh v4 installs use
    // [CREATE_CAPTURES] above and already contain the column.
    private const val CREATE_CAPTURES_V3 = """
        CREATE TABLE capture_styles (
            media_uri TEXT PRIMARY KEY NOT NULL,
            source_image_path TEXT,
            media_is_rendered INTEGER NOT NULL DEFAULT 0
                CHECK (media_is_rendered IN (0, 1)),
            preset_id TEXT NOT NULL,
            undertone_x REAL NOT NULL,
            undertone_y REAL NOT NULL,
            created_at_epoch_ms INTEGER NOT NULL,
            updated_at_epoch_ms INTEGER NOT NULL
        )
    """
    const val CREATE_PARAMS = """
        CREATE TABLE capture_style_params (
            media_uri TEXT NOT NULL,
            param_key TEXT NOT NULL,
            value_type TEXT NOT NULL,
            value_text TEXT,
            PRIMARY KEY (media_uri, param_key),
            FOREIGN KEY (media_uri)
                REFERENCES capture_styles(media_uri)
                ON DELETE CASCADE
        )
    """

    val MIGRATE_V2_TO_V3 = listOf(
        "ALTER TABLE $PARAMS_TABLE RENAME TO $LEGACY_PARAMS_TABLE",
        "ALTER TABLE $CAPTURES_TABLE RENAME TO $LEGACY_CAPTURES_TABLE",
        CREATE_CAPTURES_V3,
        CREATE_PARAMS,
        """
            INSERT INTO $CAPTURES_TABLE (
                media_uri,
                source_image_path,
                media_is_rendered,
                preset_id,
                undertone_x,
                undertone_y,
                created_at_epoch_ms,
                updated_at_epoch_ms
            )
            SELECT
                clean_image_uri,
                NULL,
                0,
                preset_id,
                undertone_x,
                undertone_y,
                created_at_epoch_ms,
                updated_at_epoch_ms
            FROM $LEGACY_CAPTURES_TABLE
        """.trimIndent(),
        """
            INSERT INTO $PARAMS_TABLE (
                media_uri,
                param_key,
                value_type,
                value_text
            )
            SELECT
                clean_image_uri,
                param_key,
                value_type,
                value_text
            FROM $LEGACY_PARAMS_TABLE
        """.trimIndent(),
        "DROP TABLE $LEGACY_PARAMS_TABLE",
        "DROP TABLE $LEGACY_CAPTURES_TABLE"
    )

    /** V3 → V4: add optional film_roll_id column for Film Roll feature. */
    val MIGRATE_V3_TO_V4 = listOf(
        "ALTER TABLE $CAPTURES_TABLE ADD COLUMN film_roll_id TEXT"
    )
}

internal fun encodeCaptureParameter(value: Any?): StoredCaptureParameter? {
    return when (value) {
        null -> StoredCaptureParameter("null", null)
        is Boolean -> StoredCaptureParameter("bool", if (value) "1" else "0")
        is Number -> {
            val number = value.toDouble()
            if (number.isFinite()) {
                StoredCaptureParameter("number", number.toString())
            } else {
                null
            }
        }
        is String -> StoredCaptureParameter("string", value)
        is List<*> -> {
            val numbers = value.map { component ->
                (component as? Number)?.toDouble()?.takeIf(Double::isFinite)
                    ?: return null
            }
            StoredCaptureParameter("number_list", numbers.joinToString(","))
        }
        else -> null
    }
}

internal fun decodeCaptureParameter(
    stored: StoredCaptureParameter
): Any? = when (stored.type) {
    "null" -> null
    "bool" -> stored.value == "1"
    "number" -> stored.value?.toDoubleOrNull()
    "string" -> stored.value.orEmpty()
    "number_list" -> stored.value
        .orEmpty()
        .takeIf(String::isNotEmpty)
        ?.split(',')
        ?.mapNotNull(String::toDoubleOrNull)
        ?: emptyList<Double>()
    else -> null
}

internal fun commitRenderedCapture(
    persistMetadata: () -> Unit,
    publishMedia: () -> Unit,
    discardSidecar: () -> Unit,
    rollbackMedia: () -> Unit,
    onSidecarFailure: (Throwable) -> Unit = {}
): Boolean {
    var metadataPersisted = false
    try {
        try {
            persistMetadata()
            metadataPersisted = true
        } catch (failure: Throwable) {
            runCatching { onSidecarFailure(failure) }
            runCatching(discardSidecar)
        }
        publishMedia()
        return metadataPersisted
    } catch (failure: Throwable) {
        runCatching(discardSidecar)
        runCatching(rollbackMedia)
        throw failure
    }
}

internal class CaptureStyleMetadataStore(context: Context) : SQLiteOpenHelper(
    context.applicationContext,
    CaptureStyleMetadataSchema.DATABASE_NAME,
    null,
    CaptureStyleMetadataSchema.DATABASE_VERSION
) {
    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(CaptureStyleMetadataSchema.CREATE_CAPTURES)
        db.execSQL(CaptureStyleMetadataSchema.CREATE_PARAMS)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL(
                "ALTER TABLE capture_styles " +
                    "ADD COLUMN updated_at_epoch_ms INTEGER NOT NULL DEFAULT 0"
            )
            db.execSQL(
                "UPDATE capture_styles SET updated_at_epoch_ms = " +
                    "created_at_epoch_ms WHERE updated_at_epoch_ms = 0"
            )
        }
        if (oldVersion < 3) {
            CaptureStyleMetadataSchema.MIGRATE_V2_TO_V3.forEach(db::execSQL)
        }
        if (oldVersion < 4) {
            CaptureStyleMetadataSchema.MIGRATE_V3_TO_V4.forEach(db::execSQL)
        }
    }

    fun upsert(metadata: CaptureStyleMetadata) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val captureValues = ContentValues().apply {
                put("media_uri", metadata.mediaUri)
                put("source_image_path", metadata.sourceImagePath)
                put("media_is_rendered", if (metadata.mediaIsRendered) 1 else 0)
                put("preset_id", metadata.presetId)
                put("undertone_x", metadata.undertoneX)
                put("undertone_y", metadata.undertoneY)
                put("created_at_epoch_ms", metadata.createdAtEpochMs)
                put("updated_at_epoch_ms", metadata.updatedAtEpochMs)
                if (metadata.filmRollId != null) {
                    put("film_roll_id", metadata.filmRollId)
                }
            }
            db.insertWithOnConflict(
                CaptureStyleMetadataSchema.CAPTURES_TABLE,
                null,
                captureValues,
                SQLiteDatabase.CONFLICT_REPLACE
            )
            db.delete(
                CaptureStyleMetadataSchema.PARAMS_TABLE,
                "media_uri = ?",
                arrayOf(metadata.mediaUri)
            )
            metadata.params.forEach { (key, value) ->
                val stored = encodeCaptureParameter(value) ?: return@forEach
                val paramValues = ContentValues().apply {
                    put("media_uri", metadata.mediaUri)
                    put("param_key", key)
                    put("value_type", stored.type)
                    put("value_text", stored.value)
                }
                db.insertOrThrow(
                    CaptureStyleMetadataSchema.PARAMS_TABLE,
                    null,
                    paramValues
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun find(mediaUri: String): CaptureStyleMetadata? {
        val db = readableDatabase
        val core = db.query(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            arrayOf(
                "source_image_path",
                "media_is_rendered",
                "preset_id",
                "undertone_x",
                "undertone_y",
                "created_at_epoch_ms",
                "updated_at_epoch_ms",
                "film_roll_id"
            ),
            "media_uri = ?",
            arrayOf(mediaUri),
            null,
            null,
            null,
            "1"
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            CaptureStyleMetadata(
                mediaUri = mediaUri,
                sourceImagePath = if (cursor.isNull(0)) null else cursor.getString(0),
                mediaIsRendered = cursor.getInt(1) != 0,
                presetId = cursor.getString(2),
                undertoneX = cursor.getFloat(3),
                undertoneY = cursor.getFloat(4),
                createdAtEpochMs = cursor.getLong(5),
                updatedAtEpochMs = cursor.getLong(6),
                params = emptyMap(),
                filmRollId = if (cursor.isNull(7)) null else cursor.getString(7)
            )
        }

        val params = linkedMapOf<String, Any?>()
        db.query(
            CaptureStyleMetadataSchema.PARAMS_TABLE,
            arrayOf("param_key", "value_type", "value_text"),
            "media_uri = ?",
            arrayOf(mediaUri),
            null,
            null,
            "param_key ASC"
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val stored = StoredCaptureParameter(
                    type = cursor.getString(1),
                    value = if (cursor.isNull(2)) null else cursor.getString(2)
                )
                params[cursor.getString(0)] = decodeCaptureParameter(stored)
            }
        }

        return core.copy(params = params)
    }

    fun findBatch(mediaUris: List<String>): List<CaptureStyleMetadata> {
        if (mediaUris.isEmpty()) return emptyList()
        return mediaUris.mapNotNull { find(it) }
    }

    fun listAll(): List<CaptureStyleMetadata> {
        val metadata = mutableListOf<CaptureStyleMetadata>()
        readableDatabase.query(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            arrayOf(
                "media_uri",
                "source_image_path",
                "media_is_rendered",
                "preset_id",
                "undertone_x",
                "undertone_y",
                "created_at_epoch_ms",
                "updated_at_epoch_ms",
                "film_roll_id"
            ),
            null,
            null,
            null,
            null,
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                metadata += CaptureStyleMetadata(
                    mediaUri = cursor.getString(0),
                    sourceImagePath = if (cursor.isNull(1)) null else cursor.getString(1),
                    mediaIsRendered = cursor.getInt(2) != 0,
                    presetId = cursor.getString(3),
                    undertoneX = cursor.getFloat(4),
                    undertoneY = cursor.getFloat(5),
                    createdAtEpochMs = cursor.getLong(6),
                    updatedAtEpochMs = cursor.getLong(7),
                    params = emptyMap(),
                    filmRollId = if (cursor.isNull(8)) null else cursor.getString(8)
                )
            }
        }
        return metadata
    }

    /**
     * Returns the persisted native captures associated with one Film Roll.
     *
     * This deliberately reads the capture sidecar database only: callers use
     * it as the authoritative durable record of successful Film Roll captures
     * and must not infer success from transient camera events.
     */
    fun listFilmRollCaptures(filmRollId: String): List<FilmRollCaptureRecord> {
        require(filmRollId.isNotBlank()) { "Film Roll ID must not be blank" }

        val records = mutableListOf<FilmRollCaptureRecord>()
        readableDatabase.query(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            arrayOf("media_uri", "created_at_epoch_ms"),
            CaptureStyleMetadataSchema.FILM_ROLL_CAPTURE_SELECTION,
            arrayOf(filmRollId),
            null,
            null,
            CaptureStyleMetadataSchema.FILM_ROLL_CAPTURE_SORT_ORDER
        ).use { cursor ->
            while (cursor.moveToNext()) {
                records += FilmRollCaptureRecord(
                    mediaUri = cursor.getString(0),
                    capturedAtEpochMs = cursor.getLong(1)
                )
            }
        }
        return records
    }

    fun delete(mediaUri: String) {
        writableDatabase.delete(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            "media_uri = ?",
            arrayOf(mediaUri)
        )
    }
}
