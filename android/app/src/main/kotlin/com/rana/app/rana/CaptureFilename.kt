package com.rana.app.rana

import java.util.Locale

/** Builds an Android-safe, stable filename stem for a processed capture. */
internal fun captureFilenameStem(
    presetId: String?,
    isStyleModified: Boolean,
    timestamp: String
): String {
    val safePresetId = presetId
        ?.trim()
        ?.lowercase(Locale.ROOT)
        ?.replace(Regex("[^a-z0-9_]+"), "_")
        ?.trim('_')
        ?.ifEmpty { null }
        ?: "normal"
    val customPart = if (isStyleModified) "_custom" else ""
    return "Rana_${safePresetId}${customPart}_$timestamp"
}
