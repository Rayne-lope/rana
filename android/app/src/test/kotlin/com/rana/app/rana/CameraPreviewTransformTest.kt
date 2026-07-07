package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Test

class CameraPreviewTransformTest {
    private val epsilon = 0.0001

    @Test
    fun `square fallback keeps preview centered in source crop space`() {
        val bufferWidth = 4000
        val bufferHeight = 3000
        val expectedCrop = calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = 1f
        )
        val matrix = buildPreviewDisplayToSourceMatrix(
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            cropRect = null,
            rotationDegrees = 0,
            mirrorHorizontally = false,
            fallbackAspectRatio = 1f
        )

        assertCornerMapping(
            matrix = matrix,
            displayX = 0.0,
            displayY = 0.0,
            expectedX = expectedCrop.left.toDouble() / bufferWidth,
            expectedY = expectedCrop.top.toDouble() / bufferHeight
        )
        assertCornerMapping(
            matrix = matrix,
            displayX = 1.0,
            displayY = 1.0,
            expectedX = (expectedCrop.left + expectedCrop.width).toDouble() / bufferWidth,
            expectedY = (expectedCrop.top + expectedCrop.height).toDouble() / bufferHeight
        )

        assertAspectRatio(
            matrix = matrix,
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            expectedWidth = expectedCrop.width.toDouble(),
            expectedHeight = expectedCrop.height.toDouble()
        )
    }

    @Test
    fun `portrait fallback preserves 3 by 4 crop ratio`() {
        val bufferWidth = 4000
        val bufferHeight = 3000
        val expectedCrop = calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = 3f / 4f
        )
        val matrix = buildPreviewDisplayToSourceMatrix(
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            cropRect = null,
            rotationDegrees = 0,
            mirrorHorizontally = false,
            fallbackAspectRatio = 3f / 4f
        )

        assertAspectRatio(
            matrix = matrix,
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            expectedWidth = expectedCrop.width.toDouble(),
            expectedHeight = expectedCrop.height.toDouble()
        )
    }

    @Test
    fun `portrait fallback preserves 9 by 16 crop ratio`() {
        val bufferWidth = 4000
        val bufferHeight = 3000
        val expectedCrop = calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = 9f / 16f
        )
        val matrix = buildPreviewDisplayToSourceMatrix(
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            cropRect = null,
            rotationDegrees = 0,
            mirrorHorizontally = false,
            fallbackAspectRatio = 9f / 16f
        )

        assertAspectRatio(
            matrix = matrix,
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            expectedWidth = expectedCrop.width.toDouble(),
            expectedHeight = expectedCrop.height.toDouble()
        )
    }

    @Test
    fun `rotation 90 reorders corners without changing crop bounds`() {
        val bufferWidth = 4000
        val bufferHeight = 3000
        val expectedCrop = calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = 1f
        )
        val matrix = buildPreviewDisplayToSourceMatrix(
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            cropRect = PreviewCropRect(
                expectedCrop.left,
                expectedCrop.top,
                expectedCrop.left + expectedCrop.width,
                expectedCrop.top + expectedCrop.height
            ),
            rotationDegrees = 90,
            mirrorHorizontally = false,
            fallbackAspectRatio = 1f
        )

        assertCornerMapping(
            matrix = matrix,
            displayX = 0.0,
            displayY = 0.0,
            expectedX = expectedCrop.left.toDouble() / bufferWidth,
            expectedY = (expectedCrop.top + expectedCrop.height).toDouble() / bufferHeight
        )
        assertCornerMapping(
            matrix = matrix,
            displayX = 1.0,
            displayY = 0.0,
            expectedX = expectedCrop.left.toDouble() / bufferWidth,
            expectedY = expectedCrop.top.toDouble() / bufferHeight
        )
        assertCornerMapping(
            matrix = matrix,
            displayX = 1.0,
            displayY = 1.0,
            expectedX = (expectedCrop.left + expectedCrop.width).toDouble() / bufferWidth,
            expectedY = expectedCrop.top.toDouble() / bufferHeight
        )
        assertCornerMapping(
            matrix = matrix,
            displayX = 0.0,
            displayY = 1.0,
            expectedX = (expectedCrop.left + expectedCrop.width).toDouble() / bufferWidth,
            expectedY = (expectedCrop.top + expectedCrop.height).toDouble() / bufferHeight
        )
    }

    @Test
    fun `front camera mirror flips the horizontal corners`() {
        val bufferWidth = 4000
        val bufferHeight = 3000
        val expectedCrop = calculateCenterCropBounds(
            sourceWidth = bufferWidth,
            sourceHeight = bufferHeight,
            targetAspectRatio = 1f
        )
        val matrix = buildPreviewDisplayToSourceMatrix(
            bufferWidth = bufferWidth,
            bufferHeight = bufferHeight,
            cropRect = PreviewCropRect(
                expectedCrop.left,
                expectedCrop.top,
                expectedCrop.left + expectedCrop.width,
                expectedCrop.top + expectedCrop.height
            ),
            rotationDegrees = 0,
            mirrorHorizontally = true,
            fallbackAspectRatio = 1f
        )

        assertCornerMapping(
            matrix = matrix,
            displayX = 0.0,
            displayY = 0.0,
            expectedX = (expectedCrop.left + expectedCrop.width).toDouble() / bufferWidth,
            expectedY = expectedCrop.top.toDouble() / bufferHeight
        )
        assertCornerMapping(
            matrix = matrix,
            displayX = 1.0,
            displayY = 0.0,
            expectedX = expectedCrop.left.toDouble() / bufferWidth,
            expectedY = expectedCrop.top.toDouble() / bufferHeight
        )
    }

    @Test
    fun `texture matrix keeps the surface texture flip for a full frame crop`() {
        val surfaceTextureMatrix = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, -1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 1f, 0f, 1f
        )

        val matrix = buildPreviewTextureMatrix(
            surfaceTextureMatrix = surfaceTextureMatrix,
            bufferWidth = 4000,
            bufferHeight = 3000,
            cropRect = PreviewCropRect(0, 0, 4000, 3000),
            rotationDegrees = 0,
            mirrorHorizontally = false,
            fallbackAspectRatio = 1f
        )
        val affine = Affine2D.fromSurfaceTextureMatrix(matrix)

        assertCornerMapping(
            matrix = affine,
            displayX = 0.0,
            displayY = 0.0,
            expectedX = 0.0,
            expectedY = 1.0
        )
        assertCornerMapping(
            matrix = affine,
            displayX = 1.0,
            displayY = 1.0,
            expectedX = 1.0,
            expectedY = 0.0
        )
    }

    @Test
    fun `texture matrix does not double apply CameraX preview rotation`() {
        val surfaceTextureMatrix = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f
        )

        val matrix = buildPreviewTextureMatrix(
            surfaceTextureMatrix = surfaceTextureMatrix,
            bufferWidth = 4000,
            bufferHeight = 3000,
            cropRect = PreviewCropRect(0, 0, 4000, 3000),
            rotationDegrees = 90,
            mirrorHorizontally = false,
            fallbackAspectRatio = 3f / 4f
        )
        val affine = Affine2D.fromSurfaceTextureMatrix(matrix)

        assertCornerMapping(
            matrix = affine,
            displayX = 0.0,
            displayY = 0.0,
            expectedX = 0.0,
            expectedY = 0.0
        )
        assertCornerMapping(
            matrix = affine,
            displayX = 1.0,
            displayY = 1.0,
            expectedX = 1.0,
            expectedY = 1.0
        )
    }

    private fun assertAspectRatio(
        matrix: Affine2D,
        bufferWidth: Int,
        bufferHeight: Int,
        expectedWidth: Double,
        expectedHeight: Double
    ) {
        val mappedCorners = listOf(
            mapAffine(matrix, 0.0, 0.0),
            mapAffine(matrix, 1.0, 0.0),
            mapAffine(matrix, 1.0, 1.0),
            mapAffine(matrix, 0.0, 1.0)
        )
        val minX = mappedCorners.minOf { it.first } * bufferWidth
        val maxX = mappedCorners.maxOf { it.first } * bufferWidth
        val minY = mappedCorners.minOf { it.second } * bufferHeight
        val maxY = mappedCorners.maxOf { it.second } * bufferHeight

        assertEquals(expectedWidth, maxX - minX, 1.0)
        assertEquals(expectedHeight, maxY - minY, 1.0)
    }

    private fun assertCornerMapping(
        matrix: Affine2D,
        displayX: Double,
        displayY: Double,
        expectedX: Double,
        expectedY: Double
    ) {
        val mapped = mapAffine(matrix, displayX, displayY)
        assertEquals(expectedX, mapped.first, epsilon)
        assertEquals(expectedY, mapped.second, epsilon)
    }

    private fun mapAffine(matrix: Affine2D, x: Double, y: Double): Pair<Double, Double> {
        return applyAffine(matrix, x, y)
    }
}
