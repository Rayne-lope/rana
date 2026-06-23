package com.rana.app.rana

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

class BloomProcessor {
    companion object {
        private const val TAG = "BloomProcessor"
    }

    data class BloomResult(
        val textureId: Int,
        val width: Int,
        val height: Int,
        val divisor: Int
    )

    private data class BrightPassProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val textureLoc: Int,
        val thresholdLoc: Int
    )

    private data class BlurProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val textureLoc: Int,
        val texelOffsetLoc: Int
    )

    private val vertexCoords = floatArrayOf(
        -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f
    )

    private val textureCoords = floatArrayOf(
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f
    )

    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(vertexCoords.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(vertexCoords)
            position(0)
        }

    private val textureBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(textureCoords.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(textureCoords)
            position(0)
        }

    private val brightPassProgram = createBrightPassProgram()
    private val blurProgram = createBlurProgram()

    private var framebufferA = 0
    private var textureA = 0
    private var framebufferB = 0
    private var textureB = 0
    private var sourceWidth = 0
    private var sourceHeight = 0
    private var downsampleWidth = 0
    private var downsampleHeight = 0
    private var currentDivisor = 4

    fun applyBloom(
        inputTextureId: Int,
        sourceWidth: Int,
        sourceHeight: Int,
        bloomThreshold: Float,
        divisor: Int
    ): BloomResult {
        ensureFramebuffers(sourceWidth, sourceHeight, divisor)

        renderPass(
            framebufferId = framebufferA,
            viewportWidth = downsampleWidth,
            viewportHeight = downsampleHeight,
            programId = brightPassProgram.programId,
            positionLoc = brightPassProgram.positionLoc,
            textureCoordLoc = brightPassProgram.textureCoordLoc
        ) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, inputTextureId)
            GLES20.glUniform1i(brightPassProgram.textureLoc, 0)
            GLES20.glUniform1f(brightPassProgram.thresholdLoc, bloomThreshold)
        }

        renderPass(
            framebufferId = framebufferB,
            viewportWidth = downsampleWidth,
            viewportHeight = downsampleHeight,
            programId = blurProgram.programId,
            positionLoc = blurProgram.positionLoc,
            textureCoordLoc = blurProgram.textureCoordLoc
        ) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureA)
            GLES20.glUniform1i(blurProgram.textureLoc, 0)
            GLES20.glUniform2f(
                blurProgram.texelOffsetLoc,
                1f / downsampleWidth.toFloat(),
                0f
            )
        }

        renderPass(
            framebufferId = framebufferA,
            viewportWidth = downsampleWidth,
            viewportHeight = downsampleHeight,
            programId = blurProgram.programId,
            positionLoc = blurProgram.positionLoc,
            textureCoordLoc = blurProgram.textureCoordLoc
        ) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureB)
            GLES20.glUniform1i(blurProgram.textureLoc, 0)
            GLES20.glUniform2f(
                blurProgram.texelOffsetLoc,
                0f,
                1f / downsampleHeight.toFloat()
            )
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        return BloomResult(
            textureId = textureA,
            width = downsampleWidth,
            height = downsampleHeight,
            divisor = currentDivisor
        )
    }

    fun releaseFramebuffers() {
        if (framebufferA != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(framebufferA), 0)
            framebufferA = 0
        }
        if (framebufferB != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(framebufferB), 0)
            framebufferB = 0
        }
        if (textureA != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureA), 0)
            textureA = 0
        }
        if (textureB != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureB), 0)
            textureB = 0
        }
        sourceWidth = 0
        sourceHeight = 0
        downsampleWidth = 0
        downsampleHeight = 0
    }

    fun release() {
        releaseFramebuffers()
        if (brightPassProgram.programId != 0) {
            GLES20.glDeleteProgram(brightPassProgram.programId)
        }
        if (blurProgram.programId != 0) {
            GLES20.glDeleteProgram(blurProgram.programId)
        }
    }

    private fun ensureFramebuffers(
        sourceWidth: Int,
        sourceHeight: Int,
        divisor: Int
    ) {
        val safeDivisor = divisor.coerceAtLeast(1)
        val targetWidth = maxOf(1, sourceWidth / safeDivisor)
        val targetHeight = maxOf(1, sourceHeight / safeDivisor)
        val needsRecreate =
            this.sourceWidth != sourceWidth ||
                this.sourceHeight != sourceHeight ||
                currentDivisor != safeDivisor ||
                framebufferA == 0 ||
                framebufferB == 0

        if (!needsRecreate) return

        releaseFramebuffers()
        this.sourceWidth = sourceWidth
        this.sourceHeight = sourceHeight
        this.downsampleWidth = targetWidth
        this.downsampleHeight = targetHeight
        this.currentDivisor = safeDivisor

        val targetA = createFramebufferTarget(targetWidth, targetHeight)
        val targetB = createFramebufferTarget(targetWidth, targetHeight)
        framebufferA = targetA.first
        textureA = targetA.second
        framebufferB = targetB.first
        textureB = targetB.second

        Log.i(
            TAG,
            "Bloom FBO dimensions = ${downsampleWidth}x${downsampleHeight} " +
                "from ${sourceWidth}x${sourceHeight} (/${currentDivisor})"
        )
    }

    private fun renderPass(
        framebufferId: Int,
        viewportWidth: Int,
        viewportHeight: Int,
        programId: Int,
        positionLoc: Int,
        textureCoordLoc: Int,
        configureUniforms: () -> Unit
    ) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, framebufferId)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(programId)

        vertexBuffer.position(0)
        textureBuffer.position(0)
        GLES20.glEnableVertexAttribArray(positionLoc)
        GLES20.glVertexAttribPointer(
            positionLoc,
            3,
            GLES20.GL_FLOAT,
            false,
            12,
            vertexBuffer
        )
        GLES20.glEnableVertexAttribArray(textureCoordLoc)
        GLES20.glVertexAttribPointer(
            textureCoordLoc,
            2,
            GLES20.GL_FLOAT,
            false,
            8,
            textureBuffer
        )

        configureUniforms()

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(positionLoc)
        GLES20.glDisableVertexAttribArray(textureCoordLoc)
    }

    private fun createFramebufferTarget(width: Int, height: Int): Pair<Int, Int> {
        val textureId = createRenderTexture(width, height)
        val framebuffers = IntArray(1)
        GLES20.glGenFramebuffers(1, framebuffers, 0)
        val framebufferId = framebuffers[0]
        if (framebufferId == 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            throw RuntimeException("Failed to create bloom framebuffer")
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, framebufferId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER,
            GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D,
            textureId,
            0
        )

        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(framebufferId), 0)
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            throw RuntimeException("Incomplete bloom framebuffer: $status")
        }

        return framebufferId to textureId
    }

    private fun createRenderTexture(width: Int, height: Int): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        val textureId = textures[0]
        if (textureId == 0) {
            throw RuntimeException("Failed to create bloom render texture")
        }

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE
        )
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D,
            0,
            GLES20.GL_RGBA,
            width,
            height,
            0,
            GLES20.GL_RGBA,
            GLES20.GL_UNSIGNED_BYTE,
            null
        )
        return textureId
    }

    private fun createBrightPassProgram(): BrightPassProgram {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_BRIGHT_PASS
        )
        if (programId == 0) {
            throw RuntimeException("Failed to create bright-pass program")
        }

        return BrightPassProgram(
            programId = programId,
            positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
            textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
            textureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
            thresholdLoc = GLES20.glGetUniformLocation(programId, "uBloomThreshold")
        )
    }

    private fun createBlurProgram(): BlurProgram {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_GAUSSIAN_BLUR
        )
        if (programId == 0) {
            throw RuntimeException("Failed to create Gaussian blur program")
        }

        return BlurProgram(
            programId = programId,
            positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
            textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
            textureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
            texelOffsetLoc = GLES20.glGetUniformLocation(programId, "uTexelOffset")
        )
    }

    private fun createProgram(vertexCode: String, fragmentCode: String): Int {
        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexCode)
        if (vertexShader == 0) return 0
        val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentCode)
        if (fragmentShader == 0) {
            GLES20.glDeleteShader(vertexShader)
            return 0
        }

        val programId = GLES20.glCreateProgram()
        GLES20.glAttachShader(programId, vertexShader)
        GLES20.glAttachShader(programId, fragmentShader)
        GLES20.glLinkProgram(programId)

        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(programId, GLES20.GL_LINK_STATUS, linkStatus, 0)
        GLES20.glDeleteShader(vertexShader)
        GLES20.glDeleteShader(fragmentShader)
        if (linkStatus[0] == 0) {
            Log.e(TAG, "Failed to link bloom program: ${GLES20.glGetProgramInfoLog(programId)}")
            GLES20.glDeleteProgram(programId)
            return 0
        }
        return programId
    }

    private fun compileShader(type: Int, shaderCode: String): Int {
        val shaderId = GLES20.glCreateShader(type)
        if (shaderId == 0) return 0

        GLES20.glShaderSource(shaderId, shaderCode)
        GLES20.glCompileShader(shaderId)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shaderId, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(TAG, "Failed to compile bloom shader: ${GLES20.glGetShaderInfoLog(shaderId)}")
            GLES20.glDeleteShader(shaderId)
            return 0
        }
        return shaderId
    }
}
