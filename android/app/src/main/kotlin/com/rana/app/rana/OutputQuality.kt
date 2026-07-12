package com.rana.app.rana

import android.media.MediaCodecList
import android.os.Build

/** Final export profiles. Keep [channelValue] stable for Flutter persistence. */
enum class OutputQualityProfile(
    val channelValue: String,
    val extension: String,
    val mimeType: String,
    val encoderQuality: Int,
    val requiresHeic: Boolean = false
) {
    STANDARD_JPEG("standard_jpeg", "jpg", "image/jpeg", 88),
    HIGH_JPEG("high_jpeg", "jpg", "image/jpeg", 95),
    EFFICIENT_HEIC("efficient_heic", "heic", "image/heic", 90, true);

    companion object {
        fun fromChannelValue(value: String?): OutputQualityProfile =
            entries.firstOrNull { it.channelValue == value } ?: HIGH_JPEG
    }
}

internal data class OutputCapabilities(
    val isHeicSupported: Boolean,
    val unavailableReason: String? = null
) {
    fun asChannelMap(): Map<String, Any?> = mapOf(
        "isHeicSupported" to isHeicSupported,
        "unavailableReason" to unavailableReason
    )
}

internal fun outputCapabilities(): OutputCapabilities {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
        return OutputCapabilities(false, "android_version")
    }
    val hasHevcEncoder = try {
        MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.any { codec ->
            codec.isEncoder && codec.supportedTypes.any { type ->
                type.equals("video/hevc", ignoreCase = true)
            }
        }
    } catch (_: Exception) {
        false
    }
    return if (hasHevcEncoder) {
        OutputCapabilities(true)
    } else {
        OutputCapabilities(false, "hevc_encoder_unavailable")
    }
}

internal data class ResolvedOutputQuality(
    val requested: OutputQualityProfile,
    val actual: OutputQualityProfile,
    val fallbackReason: String? = null
)

internal fun resolveOutputQuality(
    requested: OutputQualityProfile,
    capabilities: OutputCapabilities = outputCapabilities()
): ResolvedOutputQuality = if (requested.requiresHeic && !capabilities.isHeicSupported) {
    ResolvedOutputQuality(requested, OutputQualityProfile.HIGH_JPEG, "heic_unsupported")
} else {
    ResolvedOutputQuality(requested, requested)
}
