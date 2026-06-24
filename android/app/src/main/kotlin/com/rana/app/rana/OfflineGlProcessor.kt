package com.rana.app.rana

import android.graphics.Bitmap
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.atomic.AtomicBoolean

object OfflineGlProcessor {
    private const val TAG = "OfflineGlProcessor"
    private val isProcessing = AtomicBoolean(false)
    private val lutBitmapCache =
        java.util.concurrent.ConcurrentHashMap<String, Bitmap>()
    private val lightLeakBitmapCache =
        java.util.concurrent.ConcurrentHashMap<Int, Bitmap>()
    private val dustBitmapCache =
        java.util.concurrent.ConcurrentHashMap<String, Bitmap>()

    private data class SinglePassProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val texMatrixLoc: Int,
        val lensDistortionStrengthLoc: Int,
        val temperatureLoc: Int,
        val saturationLoc: Int,
        val contrastLoc: Int,
        val grainLoc: Int,
        val vignetteLoc: Int,
        val lutTextureLoc: Int,
        val lutStrengthLoc: Int,
        val lightLeakTextureLoc: Int,
        val lightLeakIntensityLoc: Int,
        val dustTextureLoc: Int,
        val dustIntensityLoc: Int,
        val dustUvOffsetXLoc: Int,
        val dustUvOffsetYLoc: Int,
        val bloomTextureLoc: Int,
        val bloomIntensityLoc: Int,
        val halationIntensityLoc: Int,
        val textureLoc: Int,
        val timeLoc: Int,
        val toneLoc: Int,
        val colorLoc: Int,
        val textureValLoc: Int,
        val styleStrengthLoc: Int,
        val undertoneXLoc: Int,
        val undertoneYLoc: Int
    )

    private data class BasePassProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val texMatrixLoc: Int,
        val lensDistortionStrengthLoc: Int,
        val temperatureLoc: Int,
        val saturationLoc: Int,
        val contrastLoc: Int,
        val lutTextureLoc: Int,
        val lutStrengthLoc: Int,
        val textureLoc: Int,
        val toneLoc: Int,
        val colorLoc: Int,
        val textureValLoc: Int,
        val styleStrengthLoc: Int,
        val undertoneXLoc: Int,
        val undertoneYLoc: Int
    )

    private data class CompositeProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val texMatrixLoc: Int,
        val baseTextureLoc: Int,
        val bloomTextureLoc: Int,
        val bloomIntensityLoc: Int,
        val halationIntensityLoc: Int,
        val lightLeakTextureLoc: Int,
        val lightLeakIntensityLoc: Int,
        val dustTextureLoc: Int,
        val dustIntensityLoc: Int,
        val dustUvOffsetXLoc: Int,
        val dustUvOffsetYLoc: Int,
        val grainLoc: Int,
        val vignetteLoc: Int,
        val timeLoc: Int
    )

    private data class FramebufferTarget(
        val framebufferId: Int,
        val textureId: Int
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

    private val identityMatrix = floatArrayOf(
        1f, 0f, 0f, 0f,
        0f, 1f, 0f, 0f,
        0f, 0f, 1f, 0f,
        0f, 0f, 0f, 1f
    )

    /**
     * Processes and takes ownership of [inputBitmap].
     *
     * The input bitmap is recycled after it is uploaded to GL, or during
     * cleanup if processing fails before upload.
     */
    fun processImage(
        context: android.content.Context,
        inputBitmap: Bitmap,
        params: OfflineProcessParams
    ): Bitmap? {
        if (!isProcessing.compareAndSet(false, true)) {
            Log.e(TAG, "Processing already in progress")
            return null
        }

        Log.d(
            "GlParams",
            "[EXPORT] temp=${params.temperature} sat=${params.saturation} " +
                "contrast=${params.contrast} grain=${params.grain} " +
                "vignette=${params.vignette} lut=${params.lutAssetPath} " +
                "strength=${params.lutStrength} leakIntensity=${params.lightLeakIntensity} " +
                "leakVariant=${params.lightLeakVariant} dustIntensity=${params.dustIntensity} " +
                "bloomThreshold=${params.bloomThreshold} bloomIntensity=${params.bloomIntensity} " +
                "halationIntensity=${params.halationIntensity} " +
                "lensDistortionStrength=${params.lensDistortionStrength}"
        )

        var eglDisplay = EGL14.EGL_NO_DISPLAY
        var eglContext = EGL14.EGL_NO_CONTEXT
        var eglSurface = EGL14.EGL_NO_SURFACE
        var inputTextureId = -1
        var lutTextureId = -1
        var leakTextureId = -1
        var dustTextureId = -1
        var singlePassProgram: SinglePassProgram? = null
        var basePassProgram: BasePassProgram? = null
        var compositeProgram: CompositeProgram? = null
        var baseTarget: FramebufferTarget? = null
        var bloomProcessor: BloomProcessor? = null

        var workingBitmap = inputBitmap

        try {
            val width = workingBitmap.width
            val height = workingBitmap.height

            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
                throw RuntimeException("Unable to get EGL14 display")
            }
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                throw RuntimeException("Unable to initialize EGL14")
            }

            val configAttribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            if (!EGL14.eglChooseConfig(
                    eglDisplay,
                    configAttribs,
                    0,
                    configs,
                    0,
                    configs.size,
                    numConfigs,
                    0
                )
            ) {
                throw RuntimeException("eglChooseConfig failed")
            }
            val config = configs[0] ?: throw RuntimeException("No EGL config")

            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            eglContext = EGL14.eglCreateContext(
                eglDisplay,
                config,
                EGL14.EGL_NO_CONTEXT,
                contextAttribs,
                0
            )
            if (eglContext == EGL14.EGL_NO_CONTEXT) {
                throw RuntimeException("eglCreateContext failed")
            }

            val surfaceAttribs = intArrayOf(
                EGL14.EGL_WIDTH, width,
                EGL14.EGL_HEIGHT, height,
                EGL14.EGL_NONE
            )
            eglSurface = EGL14.eglCreatePbufferSurface(
                eglDisplay,
                config,
                surfaceAttribs,
                0
            )
            if (eglSurface == EGL14.EGL_NO_SURFACE) {
                throw RuntimeException("eglCreatePbufferSurface failed")
            }

            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                throw RuntimeException("eglMakeCurrent failed")
            }

            val maxSize = IntArray(1)
            GLES20.glGetIntegerv(GLES20.GL_MAX_RENDERBUFFER_SIZE, maxSize, 0)
            val maxLimit = maxSize[0]
            if (width > maxLimit || height > maxLimit) {
                Log.w(TAG, "Dimension exceeds limit $maxLimit. Scaling.")
                val scale = maxLimit.toFloat() / maxOf(width, height)
                val scaledWidth = (width * scale).toInt()
                val scaledHeight = (height * scale).toInt()
                val scaledBitmap = Bitmap.createScaledBitmap(
                    workingBitmap,
                    scaledWidth,
                    scaledHeight,
                    true
                )
                if (scaledBitmap != workingBitmap) {
                    workingBitmap.safeRecycle()
                }
                workingBitmap = scaledBitmap
            }

            val renderWidth = workingBitmap.width
            val renderHeight = workingBitmap.height
            val vertexBuffer = buildFloatBuffer(vertexCoords)
            val textureBuffer = buildFloatBuffer(textureCoords)
            val dustUVOffsetX = (0..1000).random() / 1000f
            val dustUVOffsetY = (0..1000).random() / 1000f

            lutTextureId = if (params.lutAssetPath != null && params.lutStrength > 0f) {
                createTextureFromBitmap(getOrLoadLutBitmap(context, params.lutAssetPath))
            } else {
                -1
            }
            leakTextureId =
                if (params.lightLeakIntensity > 0f && params.lightLeakVariant in 0..3) {
                    createTextureFromBitmap(
                        getOrLoadLightLeakBitmap(context, params.lightLeakVariant)
                    )
                } else {
                    -1
                }
            dustTextureId =
                if (params.dustIntensity > 0f) {
                    createTextureFromBitmap(getOrLoadDustBitmap(context))
                } else {
                    -1
                }

            inputTextureId = createTexture()
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, inputTextureId)
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D,
                GLES20.GL_TEXTURE_MIN_FILTER,
                GLES20.GL_NEAREST
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D,
                GLES20.GL_TEXTURE_MAG_FILTER,
                GLES20.GL_NEAREST
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
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, workingBitmap, 0)
            workingBitmap.safeRecycle()

            if (params.bloomIntensity > 0f) {
                basePassProgram = createBasePassProgram()
                compositeProgram = createCompositeProgram()
                bloomProcessor = BloomProcessor()
                baseTarget = createFramebufferTarget(renderWidth, renderHeight)

                renderBaseColorPass(
                    program = basePassProgram,
                    framebufferTarget = baseTarget,
                    inputTextureId = inputTextureId,
                    lutTextureId = lutTextureId,
                    params = params,
                    vertexBuffer = vertexBuffer,
                    textureBuffer = textureBuffer,
                    renderWidth = renderWidth,
                    renderHeight = renderHeight
                )

                val bloomResult = bloomProcessor.applyBloom(
                    inputTextureId = baseTarget.textureId,
                    sourceWidth = renderWidth,
                    sourceHeight = renderHeight,
                    bloomThreshold = params.bloomThreshold,
                    divisor = 4
                )

                renderCompositePass(
                    program = compositeProgram,
                    baseTextureId = baseTarget.textureId,
                    bloomTextureId = bloomResult.textureId,
                    lightLeakTextureId = leakTextureId,
                    dustTextureId = dustTextureId,
                    params = params,
                    dustUVOffsetX = dustUVOffsetX,
                    dustUVOffsetY = dustUVOffsetY,
                    vertexBuffer = vertexBuffer,
                    textureBuffer = textureBuffer,
                    renderWidth = renderWidth,
                    renderHeight = renderHeight
                )
            } else {
                singlePassProgram = createSinglePassProgram()
                renderSinglePass(
                    program = singlePassProgram,
                    inputTextureId = inputTextureId,
                    lutTextureId = lutTextureId,
                    lightLeakTextureId = leakTextureId,
                    dustTextureId = dustTextureId,
                    params = params,
                    dustUVOffsetX = dustUVOffsetX,
                    dustUVOffsetY = dustUVOffsetY,
                    vertexBuffer = vertexBuffer,
                    textureBuffer = textureBuffer,
                    renderWidth = renderWidth,
                    renderHeight = renderHeight
                )
            }

            val readBuf = ByteBuffer.allocateDirect(renderWidth * renderHeight * 4)
                .order(ByteOrder.LITTLE_ENDIAN)
            GLES20.glReadPixels(
                0,
                0,
                renderWidth,
                renderHeight,
                GLES20.GL_RGBA,
                GLES20.GL_UNSIGNED_BYTE,
                readBuf
            )
            readBuf.rewind()

            val outBitmap = Bitmap.createBitmap(
                renderWidth,
                renderHeight,
                Bitmap.Config.ARGB_8888
            )
            // GLUtils bitmap upload plus these texture coordinates already
            // preserve Android bitmap row order; an extra Y flip inverts exports.
            outBitmap.copyPixelsFromBuffer(readBuf)
            return outBitmap
        } catch (e: Exception) {
            Log.e(TAG, "Error processing offline image", e)
            return null
        } finally {
            workingBitmap.safeRecycle()
            if (lutTextureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(lutTextureId), 0)
            }
            if (leakTextureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(leakTextureId), 0)
            }
            if (dustTextureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(dustTextureId), 0)
            }
            if (inputTextureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(inputTextureId), 0)
            }
            baseTarget?.let {
                GLES20.glDeleteFramebuffers(1, intArrayOf(it.framebufferId), 0)
                GLES20.glDeleteTextures(1, intArrayOf(it.textureId), 0)
            }
            singlePassProgram?.let { GLES20.glDeleteProgram(it.programId) }
            basePassProgram?.let { GLES20.glDeleteProgram(it.programId) }
            compositeProgram?.let { GLES20.glDeleteProgram(it.programId) }
            bloomProcessor?.release()

            if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    eglDisplay,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT
                )
                if (eglSurface != EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(eglDisplay, eglSurface)
                }
                if (eglContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(eglDisplay, eglContext)
                }
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(eglDisplay)
            }
            isProcessing.set(false)
        }
    }

    private fun renderSinglePass(
        program: SinglePassProgram,
        inputTextureId: Int,
        lutTextureId: Int,
        lightLeakTextureId: Int,
        dustTextureId: Int,
        params: OfflineProcessParams,
        dustUVOffsetX: Float,
        dustUVOffsetY: Float,
        vertexBuffer: FloatBuffer,
        textureBuffer: FloatBuffer,
        renderWidth: Int,
        renderHeight: Int
    ) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, renderWidth, renderHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program.programId)

        bindQuad(program.positionLoc, program.textureCoordLoc, vertexBuffer, textureBuffer)
        GLES20.glUniformMatrix4fv(program.texMatrixLoc, 1, false, identityMatrix, 0)
        GLES20.glUniform1f(
            program.lensDistortionStrengthLoc,
            params.lensDistortionStrength
        )
        GLES20.glUniform1f(program.temperatureLoc, params.temperature)
        GLES20.glUniform1f(program.saturationLoc, params.saturation)
        GLES20.glUniform1f(program.contrastLoc, params.contrast)
        GLES20.glUniform1f(program.grainLoc, params.grain)
        GLES20.glUniform1f(program.vignetteLoc, params.vignette)
        GLES20.glUniform1f(program.lutStrengthLoc, params.lutStrength)
        GLES20.glUniform1f(program.lightLeakIntensityLoc, params.lightLeakIntensity)
        GLES20.glUniform1f(program.dustIntensityLoc, params.dustIntensity)
        GLES20.glUniform1f(program.dustUvOffsetXLoc, dustUVOffsetX)
        GLES20.glUniform1f(program.dustUvOffsetYLoc, dustUVOffsetY)
        GLES20.glUniform1f(program.bloomIntensityLoc, 0f)
        GLES20.glUniform1f(program.halationIntensityLoc, 0f)
        GLES20.glUniform1f(program.timeLoc, 0f)
        GLES20.glUniform1f(program.toneLoc, params.tone)
        GLES20.glUniform1f(program.colorLoc, params.color)
        GLES20.glUniform1f(program.textureValLoc, params.textureVal)
        GLES20.glUniform1f(program.styleStrengthLoc, params.styleStrength)
        GLES20.glUniform1f(program.undertoneXLoc, params.undertoneX)
        GLES20.glUniform1f(program.undertoneYLoc, params.undertoneY)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, inputTextureId)
        GLES20.glUniform1i(program.textureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (lutTextureId != -1) lutTextureId else 0
        )
        GLES20.glUniform1i(program.lutTextureLoc, 1)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (lightLeakTextureId != -1) lightLeakTextureId else 0
        )
        GLES20.glUniform1i(program.lightLeakTextureLoc, 2)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE3)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (dustTextureId != -1) dustTextureId else 0
        )
        GLES20.glUniform1i(program.dustTextureLoc, 3)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE4)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glUniform1i(program.bloomTextureLoc, 4)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(program.positionLoc, program.textureCoordLoc)
    }

    private fun renderBaseColorPass(
        program: BasePassProgram,
        framebufferTarget: FramebufferTarget,
        inputTextureId: Int,
        lutTextureId: Int,
        params: OfflineProcessParams,
        vertexBuffer: FloatBuffer,
        textureBuffer: FloatBuffer,
        renderWidth: Int,
        renderHeight: Int
    ) {
        GLES20.glBindFramebuffer(
            GLES20.GL_FRAMEBUFFER,
            framebufferTarget.framebufferId
        )
        GLES20.glViewport(0, 0, renderWidth, renderHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program.programId)

        bindQuad(program.positionLoc, program.textureCoordLoc, vertexBuffer, textureBuffer)
        GLES20.glUniformMatrix4fv(program.texMatrixLoc, 1, false, identityMatrix, 0)
        GLES20.glUniform1f(
            program.lensDistortionStrengthLoc,
            params.lensDistortionStrength
        )
        GLES20.glUniform1f(program.temperatureLoc, params.temperature)
        GLES20.glUniform1f(program.saturationLoc, params.saturation)
        GLES20.glUniform1f(program.contrastLoc, params.contrast)
        GLES20.glUniform1f(program.lutStrengthLoc, params.lutStrength)
        GLES20.glUniform1f(program.toneLoc, params.tone)
        GLES20.glUniform1f(program.colorLoc, params.color)
        GLES20.glUniform1f(program.textureValLoc, params.textureVal)
        GLES20.glUniform1f(program.styleStrengthLoc, params.styleStrength)
        GLES20.glUniform1f(program.undertoneXLoc, params.undertoneX)
        GLES20.glUniform1f(program.undertoneYLoc, params.undertoneY)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, inputTextureId)
        GLES20.glUniform1i(program.textureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (lutTextureId != -1) lutTextureId else 0
        )
        GLES20.glUniform1i(program.lutTextureLoc, 1)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(program.positionLoc, program.textureCoordLoc)
    }

    private fun renderCompositePass(
        program: CompositeProgram,
        baseTextureId: Int,
        bloomTextureId: Int,
        lightLeakTextureId: Int,
        dustTextureId: Int,
        params: OfflineProcessParams,
        dustUVOffsetX: Float,
        dustUVOffsetY: Float,
        vertexBuffer: FloatBuffer,
        textureBuffer: FloatBuffer,
        renderWidth: Int,
        renderHeight: Int
    ) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, renderWidth, renderHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program.programId)

        bindQuad(program.positionLoc, program.textureCoordLoc, vertexBuffer, textureBuffer)
        GLES20.glUniformMatrix4fv(program.texMatrixLoc, 1, false, identityMatrix, 0)
        GLES20.glUniform1f(program.bloomIntensityLoc, params.bloomIntensity)
        GLES20.glUniform1f(program.halationIntensityLoc, params.halationIntensity)
        GLES20.glUniform1f(program.lightLeakIntensityLoc, params.lightLeakIntensity)
        GLES20.glUniform1f(program.dustIntensityLoc, params.dustIntensity)
        GLES20.glUniform1f(program.dustUvOffsetXLoc, dustUVOffsetX)
        GLES20.glUniform1f(program.dustUvOffsetYLoc, dustUVOffsetY)
        GLES20.glUniform1f(program.grainLoc, params.grain)
        GLES20.glUniform1f(program.vignetteLoc, params.vignette)
        GLES20.glUniform1f(program.timeLoc, 0f)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, baseTextureId)
        GLES20.glUniform1i(program.baseTextureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, bloomTextureId)
        GLES20.glUniform1i(program.bloomTextureLoc, 1)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (lightLeakTextureId != -1) lightLeakTextureId else 0
        )
        GLES20.glUniform1i(program.lightLeakTextureLoc, 2)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE3)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (dustTextureId != -1) dustTextureId else 0
        )
        GLES20.glUniform1i(program.dustTextureLoc, 3)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(program.positionLoc, program.textureCoordLoc)
    }

    private fun bindQuad(
        positionLoc: Int,
        textureCoordLoc: Int,
        vertexBuffer: FloatBuffer,
        textureBuffer: FloatBuffer
    ) {
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
    }

    private fun unbindQuad(positionLoc: Int, textureCoordLoc: Int) {
        GLES20.glDisableVertexAttribArray(positionLoc)
        GLES20.glDisableVertexAttribArray(textureCoordLoc)
    }

    private fun buildFloatBuffer(values: FloatArray): FloatBuffer = ByteBuffer
        .allocateDirect(values.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(values)
            position(0)
        }

    private fun createTexture(): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        return textures[0]
    }

    private fun createTextureFromBitmap(bitmap: Bitmap?): Int {
        if (bitmap == null) return -1

        val textureId = createTexture()
        if (textureId == 0) return -1

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
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return textureId
    }

    private fun createFramebufferTarget(width: Int, height: Int): FramebufferTarget {
        val textureId = createTexture()
        if (textureId == 0) {
            throw RuntimeException("Failed to create base framebuffer texture")
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

        val framebuffers = IntArray(1)
        GLES20.glGenFramebuffers(1, framebuffers, 0)
        val framebufferId = framebuffers[0]
        if (framebufferId == 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            throw RuntimeException("Failed to create base framebuffer")
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
            throw RuntimeException("Base framebuffer incomplete: $status")
        }

        return FramebufferTarget(framebufferId, textureId)
    }

    private fun createSinglePassProgram(): SinglePassProgram {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_EXPORT
        )
        if (programId == 0) {
            throw RuntimeException("Failed to create single-pass export program")
        }

        return SinglePassProgram(
            programId = programId,
            positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
            textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
            texMatrixLoc = GLES20.glGetUniformLocation(programId, "uTexMatrix"),
            lensDistortionStrengthLoc = GLES20.glGetUniformLocation(
                programId,
                "uLensDistortionStrength"
            ),
            temperatureLoc = GLES20.glGetUniformLocation(programId, "uTemperature"),
            saturationLoc = GLES20.glGetUniformLocation(programId, "uSaturation"),
            contrastLoc = GLES20.glGetUniformLocation(programId, "uContrast"),
            grainLoc = GLES20.glGetUniformLocation(programId, "uGrain"),
            vignetteLoc = GLES20.glGetUniformLocation(programId, "uVignette"),
            lutTextureLoc = GLES20.glGetUniformLocation(programId, "uLutTexture"),
            lutStrengthLoc = GLES20.glGetUniformLocation(programId, "uLutStrength"),
            lightLeakTextureLoc = GLES20.glGetUniformLocation(programId, "uLightLeakTexture"),
            lightLeakIntensityLoc = GLES20.glGetUniformLocation(programId, "uLightLeakIntensity"),
            dustTextureLoc = GLES20.glGetUniformLocation(programId, "uDustTexture"),
            dustIntensityLoc = GLES20.glGetUniformLocation(programId, "uDustIntensity"),
            dustUvOffsetXLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetX"),
            dustUvOffsetYLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetY"),
            bloomTextureLoc = GLES20.glGetUniformLocation(programId, "uBloomTexture"),
            bloomIntensityLoc = GLES20.glGetUniformLocation(programId, "uBloomIntensity"),
            halationIntensityLoc = GLES20.glGetUniformLocation(programId, "uHalationIntensity"),
            textureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
            timeLoc = GLES20.glGetUniformLocation(programId, "uTime"),
            toneLoc = GLES20.glGetUniformLocation(programId, "uTone"),
            colorLoc = GLES20.glGetUniformLocation(programId, "uColor"),
            textureValLoc = GLES20.glGetUniformLocation(programId, "uTextureVal"),
            styleStrengthLoc = GLES20.glGetUniformLocation(programId, "uStyleStrength"),
            undertoneXLoc = GLES20.glGetUniformLocation(programId, "uUndertoneX"),
            undertoneYLoc = GLES20.glGetUniformLocation(programId, "uUndertoneY")
        )
    }

    private fun createBasePassProgram(): BasePassProgram {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_EXPORT
        )
        if (programId == 0) {
            throw RuntimeException("Failed to create export base-pass program")
        }

        return BasePassProgram(
            programId = programId,
            positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
            textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
            texMatrixLoc = GLES20.glGetUniformLocation(programId, "uTexMatrix"),
            lensDistortionStrengthLoc = GLES20.glGetUniformLocation(
                programId,
                "uLensDistortionStrength"
            ),
            temperatureLoc = GLES20.glGetUniformLocation(programId, "uTemperature"),
            saturationLoc = GLES20.glGetUniformLocation(programId, "uSaturation"),
            contrastLoc = GLES20.glGetUniformLocation(programId, "uContrast"),
            lutTextureLoc = GLES20.glGetUniformLocation(programId, "uLutTexture"),
            lutStrengthLoc = GLES20.glGetUniformLocation(programId, "uLutStrength"),
            textureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
            toneLoc = GLES20.glGetUniformLocation(programId, "uTone"),
            colorLoc = GLES20.glGetUniformLocation(programId, "uColor"),
            textureValLoc = GLES20.glGetUniformLocation(programId, "uTextureVal"),
            styleStrengthLoc = GLES20.glGetUniformLocation(programId, "uStyleStrength"),
            undertoneXLoc = GLES20.glGetUniformLocation(programId, "uUndertoneX"),
            undertoneYLoc = GLES20.glGetUniformLocation(programId, "uUndertoneY")
        )
    }

    private fun createCompositeProgram(): CompositeProgram {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_BLOOM_COMPOSITE
        )
        if (programId == 0) {
            throw RuntimeException("Failed to create export bloom composite program")
        }

        return CompositeProgram(
            programId = programId,
            positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
            textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
            texMatrixLoc = GLES20.glGetUniformLocation(programId, "uTexMatrix"),
            baseTextureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
            bloomTextureLoc = GLES20.glGetUniformLocation(programId, "uBloomTexture"),
            bloomIntensityLoc = GLES20.glGetUniformLocation(programId, "uBloomIntensity"),
            halationIntensityLoc = GLES20.glGetUniformLocation(programId, "uHalationIntensity"),
            lightLeakTextureLoc = GLES20.glGetUniformLocation(programId, "uLightLeakTexture"),
            lightLeakIntensityLoc = GLES20.glGetUniformLocation(programId, "uLightLeakIntensity"),
            dustTextureLoc = GLES20.glGetUniformLocation(programId, "uDustTexture"),
            dustIntensityLoc = GLES20.glGetUniformLocation(programId, "uDustIntensity"),
            dustUvOffsetXLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetX"),
            dustUvOffsetYLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetY"),
            grainLoc = GLES20.glGetUniformLocation(programId, "uGrain"),
            vignetteLoc = GLES20.glGetUniformLocation(programId, "uVignette"),
            timeLoc = GLES20.glGetUniformLocation(programId, "uTime")
        )
    }

    private fun getOrLoadLutBitmap(
        context: android.content.Context,
        assetPath: String
    ): Bitmap? {
        val cached = lutBitmapCache[assetPath]
        if (cached != null) return cached

        return try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory
                    .decodeStream(inputStream, null, options)
                if (bitmap != null) {
                    lutBitmapCache[assetPath] = bitmap
                }
                bitmap
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load LUT bitmap: $assetPath", e)
            null
        }
    }

    private fun getOrLoadLightLeakBitmap(
        context: android.content.Context,
        variant: Int
    ): Bitmap? {
        val cached = lightLeakBitmapCache[variant]
        if (cached != null) return cached

        val assetPath = "assets/textures/light_leak_${variant + 1}.png"
        return try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory
                    .decodeStream(inputStream, null, options)
                if (bitmap != null) {
                    lightLeakBitmapCache[variant] = bitmap
                }
                bitmap
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load Light Leak bitmap: $assetPath", e)
            null
        }
    }

    private fun getOrLoadDustBitmap(
        context: android.content.Context
    ): Bitmap? {
        val assetPath = "assets/textures/dust_scratches_atlas.png"
        val cached = dustBitmapCache[assetPath]
        if (cached != null) return cached

        return try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory
                    .decodeStream(inputStream, null, options)
                if (bitmap != null) {
                    dustBitmapCache[assetPath] = bitmap
                }
                bitmap
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load Dust Atlas bitmap: $assetPath", e)
            null
        }
    }

    private fun Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
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
            Log.e(TAG, "Program link failed: ${GLES20.glGetProgramInfoLog(programId)}")
            GLES20.glDeleteProgram(programId)
            return 0
        }
        return programId
    }

    private fun compileShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        if (shader == 0) return 0
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(TAG, "Shader compile failed: ${GLES20.glGetShaderInfoLog(shader)}")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }
}
