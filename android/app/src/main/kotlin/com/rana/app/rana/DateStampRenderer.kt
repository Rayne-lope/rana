package com.rana.app.rana

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

private const val DATE_STAMP_TEXT_HEIGHT_RATIO = 0.045f
private const val DATE_STAMP_MARGIN_RATIO = 0.05f

internal fun dateStampTextSize(bitmapHeight: Int): Float =
    bitmapHeight * DATE_STAMP_TEXT_HEIGHT_RATIO

internal fun dateStampMargin(bitmapDimension: Int): Float =
    bitmapDimension * DATE_STAMP_MARGIN_RATIO

internal fun formatDateStamp(
    date: Date,
    timeZone: TimeZone = TimeZone.getDefault()
): String = SimpleDateFormat("yy MM dd", Locale.US).run {
    this.timeZone = timeZone
    format(date)
}

internal fun applyDateStamp(bitmap: Bitmap, capturedAt: Date): Bitmap {
    val target = if (bitmap.isMutable) {
        bitmap
    } else {
        bitmap.copy(Bitmap.Config.ARGB_8888, true) ?: bitmap
    }
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(200, 255, 85, 0)
        textSize = dateStampTextSize(target.height)
        typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
    }
    val text = formatDateStamp(capturedAt)
    val marginX = dateStampMargin(target.width)
    val marginY = dateStampMargin(target.height)
    val x = (target.width - marginX - paint.measureText(text))
        .coerceAtLeast(marginX)
    val y = target.height - marginY - paint.fontMetrics.bottom
    Canvas(target).drawText(text, x, y, paint)
    return target
}
