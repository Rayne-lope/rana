package com.rana.app.rana

import android.os.SystemClock

internal enum class RanaTelemetryMetric(val wireName: String) {
    CAMERA_INITIALIZE_MS("camera_initialize_ms"),
    CAMERA_BIND_MS("camera_bind_ms"),
    FIRST_PREVIEW_FRAME_MS("first_preview_frame_ms"),
    PREVIEW_AVERAGE_FPS("preview_average_fps"),
    PREVIEW_P95_FRAME_MS("preview_p95_frame_ms"),
    PREVIEW_DROPPED_FRAME_COUNT("preview_dropped_frame_count"),
    PRESET_APPLY_MS("preset_apply_ms"),
    SHADER_COMPILE_MS("shader_compile_ms"),
    TEXTURE_UPLOAD_MS("texture_upload_ms"),
    CAPTURE_ACCEPT_MS("capture_accept_ms"),
    CAPTURE_PROCESS_MS("capture_process_ms"),
    CAPTURE_SAVE_MS("capture_save_ms"),
    MEMORY_JAVA_MB("memory_java_mb"),
    MEMORY_NATIVE_MB("memory_native_mb"),
    MEMORY_GPU_ESTIMATE_MB("memory_gpu_estimate_mb"),
    THERMAL_STATUS("thermal_status"),
    ACTIVE_RENDER_QUALITY_TIER("active_render_quality_tier")
}

internal data class RanaTelemetrySample(
    val name: String,
    val monotonicTimestampUs: Long,
    val value: Double
)

/** Privacy-safe in-memory telemetry; values are numeric and media IDs are impossible. */
internal class RanaCameraTelemetry(
    private val capacity: Int = 256,
    private val monotonicClockUs: () -> Long = { SystemClock.elapsedRealtimeNanos() / 1_000 }
) {
    private val samples = ArrayDeque<RanaTelemetrySample>()

    init {
        require(capacity > 0) { "Telemetry capacity must be positive" }
    }

    @Synchronized
    fun record(metric: RanaTelemetryMetric, value: Double): RanaTelemetrySample? {
        if (!value.isFinite()) return null
        if (samples.size == capacity) samples.removeFirst()
        return RanaTelemetrySample(metric.wireName, monotonicClockUs(), value).also {
            samples.addLast(it)
        }
    }

    @Synchronized
    fun snapshot(): List<RanaTelemetrySample> = samples.toList()
}
