package com.rana.app.rana

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal data class CaptureStyleMetadata(
    val cleanImageUri: String,
    val presetId: String,
    val undertoneX: Float,
    val undertoneY: Float,
    val params: Map<String, Any?>,
    val createdAtEpochMs: Long
)

internal data class StoredCaptureParameter(
    val type: String,
    val value: String?
)

internal object CaptureStyleMetadataSchema {
    const val DATABASE_NAME = "rana_capture_styles.db"
    const val DATABASE_VERSION = 1
    const val CAPTURES_TABLE = "capture_styles"
    const val PARAMS_TABLE = "capture_style_params"

    const val CREATE_CAPTURES = """
        CREATE TABLE capture_styles (
            clean_image_uri TEXT PRIMARY KEY NOT NULL,
            preset_id TEXT NOT NULL,
            undertone_x REAL NOT NULL,
            undertone_y REAL NOT NULL,
            created_at_epoch_ms INTEGER NOT NULL
        )
    """
    const val CREATE_PARAMS = """
        CREATE TABLE capture_style_params (
            clean_image_uri TEXT NOT NULL,
            param_key TEXT NOT NULL,
            value_type TEXT NOT NULL,
            value_text TEXT,
            PRIMARY KEY (clean_image_uri, param_key),
            FOREIGN KEY (clean_image_uri)
                REFERENCES capture_styles(clean_image_uri)
                ON DELETE CASCADE
        )
    """
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
        // Version 1 is the initial schema. Future versions migrate in place.
    }

    fun upsert(metadata: CaptureStyleMetadata) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val captureValues = ContentValues().apply {
                put("clean_image_uri", metadata.cleanImageUri)
                put("preset_id", metadata.presetId)
                put("undertone_x", metadata.undertoneX)
                put("undertone_y", metadata.undertoneY)
                put("created_at_epoch_ms", metadata.createdAtEpochMs)
            }
            db.insertWithOnConflict(
                CaptureStyleMetadataSchema.CAPTURES_TABLE,
                null,
                captureValues,
                SQLiteDatabase.CONFLICT_REPLACE
            )
            db.delete(
                CaptureStyleMetadataSchema.PARAMS_TABLE,
                "clean_image_uri = ?",
                arrayOf(metadata.cleanImageUri)
            )
            metadata.params.forEach { (key, value) ->
                val stored = encodeCaptureParameter(value) ?: return@forEach
                val paramValues = ContentValues().apply {
                    put("clean_image_uri", metadata.cleanImageUri)
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

    fun find(cleanImageUri: String): CaptureStyleMetadata? {
        val db = readableDatabase
        val core = db.query(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            arrayOf(
                "preset_id",
                "undertone_x",
                "undertone_y",
                "created_at_epoch_ms"
            ),
            "clean_image_uri = ?",
            arrayOf(cleanImageUri),
            null,
            null,
            null,
            "1"
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            CaptureStyleMetadata(
                cleanImageUri = cleanImageUri,
                presetId = cursor.getString(0),
                undertoneX = cursor.getFloat(1),
                undertoneY = cursor.getFloat(2),
                createdAtEpochMs = cursor.getLong(3),
                params = emptyMap()
            )
        }

        val params = linkedMapOf<String, Any?>()
        db.query(
            CaptureStyleMetadataSchema.PARAMS_TABLE,
            arrayOf("param_key", "value_type", "value_text"),
            "clean_image_uri = ?",
            arrayOf(cleanImageUri),
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

    fun delete(cleanImageUri: String) {
        writableDatabase.delete(
            CaptureStyleMetadataSchema.CAPTURES_TABLE,
            "clean_image_uri = ?",
            arrayOf(cleanImageUri)
        )
    }
}
