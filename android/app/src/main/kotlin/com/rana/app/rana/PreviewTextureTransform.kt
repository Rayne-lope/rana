package com.rana.app.rana

import kotlin.math.abs

internal data class PreviewCropRect(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int
) {
    val width: Int
        get() = right - left

    val height: Int
        get() = bottom - top
}

internal data class Affine2D(
    val a: Double,
    val b: Double,
    val c: Double,
    val d: Double,
    val e: Double,
    val f: Double
) {
    fun mapPoint(x: Double, y: Double): Pair<Double, Double> {
        return Pair(
            (a * x) + (b * y) + c,
            (d * x) + (e * y) + f
        )
    }

    operator fun times(other: Affine2D): Affine2D {
        return Affine2D(
            a = a * other.a + b * other.d,
            b = a * other.b + b * other.e,
            c = a * other.c + b * other.f + c,
            d = d * other.a + e * other.d,
            e = d * other.b + e * other.e,
            f = d * other.c + e * other.f + f
        )
    }

    fun invert(): Affine2D {
        val det = (a * e) - (b * d)
        if (abs(det) < 1e-12) {
            return identity()
        }

        val invDet = 1.0 / det
        return Affine2D(
            a = e * invDet,
            b = -b * invDet,
            c = ((b * f) - (e * c)) * invDet,
            d = -d * invDet,
            e = a * invDet,
            f = ((d * c) - (a * f)) * invDet
        )
    }

    fun toGlMatrix(): FloatArray {
        return floatArrayOf(
            a.toFloat(), d.toFloat(), 0f, 0f,
            b.toFloat(), e.toFloat(), 0f, 0f,
            0f, 0f, 1f, 0f,
            c.toFloat(), f.toFloat(), 0f, 1f
        )
    }

    companion object {
        fun identity(): Affine2D = Affine2D(1.0, 0.0, 0.0, 0.0, 1.0, 0.0)

        fun flipY(): Affine2D = Affine2D(1.0, 0.0, 0.0, 0.0, -1.0, 1.0)

        fun fromSurfaceTextureMatrix(matrix: FloatArray): Affine2D {
            if (matrix.size < 16) return identity()
            return Affine2D(
                a = matrix[0].toDouble(),
                b = matrix[4].toDouble(),
                c = matrix[12].toDouble(),
                d = matrix[1].toDouble(),
                e = matrix[5].toDouble(),
                f = matrix[13].toDouble()
            )
        }
    }
}

internal fun buildPreviewTextureMatrix(
    surfaceTextureMatrix: FloatArray,
    bufferWidth: Int,
    bufferHeight: Int,
    cropRect: PreviewCropRect?,
    rotationDegrees: Int,
    mirrorHorizontally: Boolean,
    fallbackAspectRatio: Float
): FloatArray {
    if (bufferWidth <= 0 || bufferHeight <= 0) {
        return surfaceTextureMatrix.clone()
    }

    val effectiveCropRect = cropRect?.takeIf { it.width > 0 && it.height > 0 }
        ?: calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = fallbackAspectRatio
        ).toPreviewCropRect()

    // OES texture coordinates (s, t) map [0,1]^2 to raw buffer space with a bottom-left origin.
    // Android cropRect coordinates map to buffer space with a top-left origin.
    // Thus:
    // s_cropped = left / bufferWidth + s * (cropWidth / bufferWidth)
    // t_cropped = (1.0 - bottom / bufferHeight) + t * (cropHeight / bufferHeight)
    val scaleS = effectiveCropRect.width.toDouble() / bufferWidth.toDouble()
    val scaleT = effectiveCropRect.height.toDouble() / bufferHeight.toDouble()
    val translateS = effectiveCropRect.left.toDouble() / bufferWidth.toDouble()
    val translateT = 1.0 - (effectiveCropRect.bottom.toDouble() / bufferHeight.toDouble())

    val cropMatrix = Affine2D(
        a = scaleS,
        b = 0.0,
        c = translateS,
        d = 0.0,
        e = scaleT,
        f = translateT
    )

    // finalMatrix = cropMatrix * ST_matrix
    return cropMatrix.times(Affine2D.fromSurfaceTextureMatrix(surfaceTextureMatrix)).toGlMatrix()
}

internal fun buildPreviewDisplayToSourceMatrix(
    bufferWidth: Int,
    bufferHeight: Int,
    cropRect: PreviewCropRect?,
    rotationDegrees: Int,
    mirrorHorizontally: Boolean,
    fallbackAspectRatio: Float
): Affine2D {
    if (bufferWidth <= 0 || bufferHeight <= 0) {
        return Affine2D.identity()
    }

    val effectiveCropRect = cropRect?.takeIf { it.width > 0 && it.height > 0 }
        ?: calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = fallbackAspectRatio
        ).toPreviewCropRect()

    val source = normalizedRectVertices(
        rect = effectiveCropRect,
        bufferWidth = bufferWidth,
        bufferHeight = bufferHeight
    )
    val destination = normalizedUnitVertices(
        rotationDegrees = rotationDegrees,
        mirrorHorizontally = mirrorHorizontally
    )

    // Solve the CameraX crop rect -> preview quad transform, then invert it so
    // the shader can map preview-space coordinates back into the source crop.
    val sourceToDisplay = solveAffineFromPoints(source, destination)
    if (sourceToDisplay == null) return Affine2D.identity()

    return sourceToDisplay.invert()
}

internal fun applyAffine(matrix: Affine2D, x: Double, y: Double): Pair<Double, Double> {
    return matrix.mapPoint(x, y)
}

private fun normalizedRectVertices(
    rect: PreviewCropRect,
    bufferWidth: Int,
    bufferHeight: Int
): DoubleArray {
    val left = rect.left.toDouble() / bufferWidth.toDouble()
    val top = rect.top.toDouble() / bufferHeight.toDouble()
    val right = rect.right.toDouble() / bufferWidth.toDouble()
    val bottom = rect.bottom.toDouble() / bufferHeight.toDouble()

    return doubleArrayOf(
        left, top,
        right, top,
        right, bottom,
        left, bottom
    )
}

private fun normalizedUnitVertices(
    rotationDegrees: Int,
    mirrorHorizontally: Boolean
): DoubleArray {
    val normalizedRotation = ((rotationDegrees % 360) + 360) % 360
    val vertices = doubleArrayOf(
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0
    )

    if (normalizedRotation != 0) {
        val shiftOffset = (normalizedRotation / 90) * 2
        val shifted = vertices.clone()
        for (index in vertices.indices) {
            val fromIndex = (index + shiftOffset) % vertices.size
            vertices[index] = shifted[fromIndex]
        }
    }

    if (mirrorHorizontally) {
        for (index in vertices.indices step 2) {
            vertices[index] = 1.0 - vertices[index]
        }
    }

    return vertices
}

private fun solveAffineFromPoints(
    source: DoubleArray,
    destination: DoubleArray
): Affine2D? {
    if (source.size < 6 || destination.size < 6) return null

    val matrix = arrayOf(
        doubleArrayOf(source[0], source[1], 1.0),
        doubleArrayOf(source[2], source[3], 1.0),
        doubleArrayOf(source[4], source[5], 1.0)
    )
    val xVector = doubleArrayOf(destination[0], destination[2], destination[4])
    val yVector = doubleArrayOf(destination[1], destination[3], destination[5])

    val xSolution = solve3x3(matrix, xVector) ?: return null
    val ySolution = solve3x3(matrix, yVector) ?: return null

    return Affine2D(
        a = xSolution[0],
        b = xSolution[1],
        c = xSolution[2],
        d = ySolution[0],
        e = ySolution[1],
        f = ySolution[2]
    )
}

private fun solve3x3(
    source: Array<DoubleArray>,
    target: DoubleArray
): DoubleArray? {
    val matrix = Array(3) { row -> source[row].clone() }
    val vector = target.clone()

    for (pivot in 0 until 3) {
        var bestRow = pivot
        var bestValue = abs(matrix[pivot][pivot])
        for (row in (pivot + 1) until 3) {
            val candidate = abs(matrix[row][pivot])
            if (candidate > bestValue) {
                bestValue = candidate
                bestRow = row
            }
        }

        if (bestValue < 1e-12) {
            return null
        }

        if (bestRow != pivot) {
            val tempRow = matrix[pivot]
            matrix[pivot] = matrix[bestRow]
            matrix[bestRow] = tempRow

            val tempValue = vector[pivot]
            vector[pivot] = vector[bestRow]
            vector[bestRow] = tempValue
        }

        val pivotValue = matrix[pivot][pivot]
        for (column in pivot until 3) {
            matrix[pivot][column] /= pivotValue
        }
        vector[pivot] /= pivotValue

        for (row in 0 until 3) {
            if (row == pivot) continue
            val factor = matrix[row][pivot]
            if (abs(factor) < 1e-12) continue

            for (column in pivot until 3) {
                matrix[row][column] -= factor * matrix[pivot][column]
            }
            vector[row] -= factor * vector[pivot]
        }
    }

    return vector
}

private fun CenterCropBounds.toPreviewCropRect(): PreviewCropRect {
    return PreviewCropRect(left, top, left + width, top + height)
}
