package com.rana.app.rana

import android.graphics.Bitmap
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.os.Build
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
        Log.d("GlParams", "[EXPORT] temp=${params.temperature} sat=${params.saturation} contrast=${params.contrast} grain=${params.grain} vignette=${params.vignette} lut=${params.lutAssetPath} strength=${params.lutStrength}")

        var eglDisplay = EGL14.EGL_NO_DISPLAY
        var eglContext = EGL14.EGL_NO_CONTEXT
        var eglSurface = EGL14.EGL_NO_SURFACE
        var textureId = -1
        var lutTextureId = -1
        var programId = -1

        var workingBitmap = inputBitmap

        try {
            val width = workingBitmap.width
            val height = workingBitmap.height

            // 1. EGL Display Init
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
                throw RuntimeException("Unable to get EGL14 display")
            }
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                throw RuntimeException("Unable to initialize EGL14")
            }

            // 2. Choose Config
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
                    eglDisplay, configAttribs, 0, configs, 0,
                    configs.size, numConfigs, 0
                )
            ) {
                throw RuntimeException("eglChooseConfig failed")
            }
            val config = configs[0] ?: throw RuntimeException("No EGL config")

            // 3. Create EGL Context
            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            eglContext = EGL14.eglCreateContext(
                eglDisplay, config, EGL14.EGL_NO_CONTEXT,
                contextAttribs, 0
            )
            if (eglContext == EGL14.EGL_NO_CONTEXT) {
                throw RuntimeException("eglCreateContext failed")
            }

            // 4. Create Pbuffer Surface (attrib list must specify width & height)
            val surfaceAttribs = intArrayOf(
                EGL14.EGL_WIDTH, width,
                EGL14.EGL_HEIGHT, height,
                EGL14.EGL_NONE
            )
            eglSurface = EGL14.eglCreatePbufferSurface(
                eglDisplay, config, surfaceAttribs, 0
            )
            if (eglSurface == EGL14.EGL_NO_SURFACE) {
                throw RuntimeException("eglCreatePbufferSurface failed")
            }

            // 5. Make Current
            if (!EGL14.eglMakeCurrent(
                    eglDisplay, eglSurface, eglSurface,
                    eglContext
                )
            ) {
                throw RuntimeException("eglMakeCurrent failed")
            }

            // Check max size
            val maxSize = IntArray(1)
            GLES20.glGetIntegerv(GLES20.GL_MAX_RENDERBUFFER_SIZE, maxSize, 0)
            val maxLimit = maxSize[0]
            if (width > maxLimit || height > maxLimit) {
                Log.w(TAG, "Dimension exceeds limit $maxLimit. Scaling.")
                val scale = maxLimit.toFloat() / maxOf(width, height)
                val scaledWidth = (width * scale).toInt()
                val scaledHeight = (height * scale).toInt()
                val scaledBitmap = Bitmap.createScaledBitmap(
                    workingBitmap, scaledWidth, scaledHeight, true
                )
                if (scaledBitmap != workingBitmap) {
                    workingBitmap.safeRecycle()
                }
                workingBitmap = scaledBitmap
            }
            val renderWidth = workingBitmap.width
            val renderHeight = workingBitmap.height

            // 6. Setup Program & Shaders
            programId = createProgram(GlShaderConstants.VERTEX_SHADER, GlShaderConstants.FRAGMENT_SHADER_EXPORT)
            if (programId == 0) {
                throw RuntimeException("Failed to create GL program")
            }
            GLES20.glUseProgram(programId)

            // 7. Setup vertex coordinates buffer
            val vertexBuffer = ByteBuffer
                .allocateDirect(vertexCoords.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .put(vertexCoords)
            vertexBuffer.position(0)

            val textureBuffer = ByteBuffer
                .allocateDirect(textureCoords.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .put(textureCoords)
            textureBuffer.position(0)

            val aPositionLoc = GLES20.glGetAttribLocation(programId, "aPosition")
            GLES20.glEnableVertexAttribArray(aPositionLoc)
            GLES20.glVertexAttribPointer(
                aPositionLoc, 3, GLES20.GL_FLOAT, false,
                12, vertexBuffer
            )

            val aTextureCoordLoc = GLES20.glGetAttribLocation(
                programId, "aTextureCoord"
            )
            GLES20.glEnableVertexAttribArray(aTextureCoordLoc)
            GLES20.glVertexAttribPointer(
                aTextureCoordLoc, 2, GLES20.GL_FLOAT, false,
                8, textureBuffer
            )

            // Set identity transform matrix
            val identityMatrix = floatArrayOf(
                1f, 0f, 0f, 0f,
                0f, 1f, 0f, 0f,
                0f, 0f, 1f, 0f,
                0f, 0f, 0f, 1f
            )
            val uTexMatrixLoc = GLES20.glGetUniformLocation(
                programId, "uTexMatrix"
            )
            GLES20.glUniformMatrix4fv(
                uTexMatrixLoc, 1, false, identityMatrix, 0
            )

            // Setup Uniforms
            val uTemperatureLoc = GLES20.glGetUniformLocation(
                programId, "uTemperature"
            )
            val uSaturationLoc = GLES20.glGetUniformLocation(
                programId, "uSaturation"
            )
            val uContrastLoc = GLES20.glGetUniformLocation(
                programId, "uContrast"
            )
            val uGrainLoc = GLES20.glGetUniformLocation(
                programId, "uGrain"
            )
            val uVignetteLoc = GLES20.glGetUniformLocation(
                programId, "uVignette"
            )

            GLES20.glUniform1f(uTemperatureLoc, params.temperature)
            GLES20.glUniform1f(uSaturationLoc, params.saturation)
            GLES20.glUniform1f(uContrastLoc, params.contrast)
            GLES20.glUniform1f(uGrainLoc, params.grain)
            GLES20.glUniform1f(uVignetteLoc, params.vignette)

            val uTimeLoc = GLES20.glGetUniformLocation(
                programId, "uTime"
            )
            GLES20.glUniform1f(uTimeLoc, 0f)

            val uLutTextureLoc = GLES20.glGetUniformLocation(
                programId, "uLutTexture"
            )
            val uLutStrengthLoc = GLES20.glGetUniformLocation(
                programId, "uLutStrength"
            )
            GLES20.glUniform1f(uLutStrengthLoc, params.lutStrength)

            if (params.lutAssetPath != null && params.lutStrength > 0f) {
                val lutBitmap = getOrLoadLutBitmap(
                    context, params.lutAssetPath
                )
                if (lutBitmap != null) {
                    val lutTextures = IntArray(1)
                    GLES20.glGenTextures(1, lutTextures, 0)
                    lutTextureId = lutTextures[0]
                    if (lutTextureId != 0 && lutTextureId != -1) {
                        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
                        GLES20.glBindTexture(
                            GLES20.GL_TEXTURE_2D, lutTextureId
                        )
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
                        GLUtils.texImage2D(
                            GLES20.GL_TEXTURE_2D, 0, lutBitmap, 0
                        )
                    }
                }
            }

            // Always bind texture unit 1 to prevent conflicts
            GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
            GLES20.glBindTexture(
                GLES20.GL_TEXTURE_2D,
                if (lutTextureId != -1) lutTextureId else 0
            )
            GLES20.glUniform1i(uLutTextureLoc, 1)

            // 8. Upload Input Bitmap Texture
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            textureId = textures[0]

            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER,
                GLES20.GL_NEAREST
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER,
                GLES20.GL_NEAREST
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S,
                GLES20.GL_CLAMP_TO_EDGE
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T,
                GLES20.GL_CLAMP_TO_EDGE
            )

            // Upload via GLUtils to handle format conversion
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, workingBitmap, 0)
            workingBitmap.safeRecycle()
            val sTextureLoc = GLES20.glGetUniformLocation(
                programId, "sTexture"
            )
            GLES20.glUniform1i(sTextureLoc, 0)

            // Clear viewport and Draw
            GLES20.glViewport(0, 0, renderWidth, renderHeight)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            // 9. Read back pixels
            val readBuf = ByteBuffer.allocateDirect(
                renderWidth * renderHeight * 4
            ).order(ByteOrder.LITTLE_ENDIAN)

            GLES20.glReadPixels(
                0, 0, renderWidth, renderHeight,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, readBuf
            )
            readBuf.rewind()

            val outBitmap = Bitmap.createBitmap(
                renderWidth, renderHeight,
                Bitmap.Config.ARGB_8888
            )
            outBitmap.copyPixelsFromBuffer(readBuf)

            // GLUtils bitmap upload plus these texture coordinates already
            // preserve Android bitmap row order; an extra Y flip inverts exports.
            return outBitmap

        } catch (e: Exception) {
            Log.e(TAG, "Error processing offline image", e)
            return null
        } finally {
            // Clean up resources cleanly
            workingBitmap.safeRecycle()
            if (lutTextureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(lutTextureId), 0)
            }
            if (textureId != -1) {
                GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            }
            if (programId != -1) {
                GLES20.glDeleteProgram(programId)
            }
            if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
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

    private fun getOrLoadLutBitmap(
        context: android.content.Context,
        assetPath: String
    ): Bitmap? {
        val cached = lutBitmapCache[assetPath]
        if (cached != null) return cached

        try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory
                    .decodeStream(inputStream, null, options)
                if (bitmap != null) {
                    Log.i(
                        TAG,
                        "Loaded Offline LUT: $assetPath, size: " +
                        "${bitmap.width}x${bitmap.height}"
                    )
                    lutBitmapCache[assetPath] = bitmap
                }
                return bitmap
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load LUT bitmap: $assetPath", e)
            return null
        }
    }

    private fun Bitmap.safeRecycle() {
        if (!isRecycled) recycle()
    }

    private fun compileShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        if (shader == 0) return 0
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(
                TAG, "Shader compilation error: " +
                GLES20.glGetShaderInfoLog(shader)
            )
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }

    private fun createProgram(
        vertexSource: String,
        fragmentSource: String
    ): Int {
        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        if (vertexShader == 0) return 0
        val fragmentShader = compileShader(
            GLES20.GL_FRAGMENT_SHADER, fragmentSource
        )
        if (fragmentShader == 0) {
            GLES20.glDeleteShader(vertexShader)
            return 0
        }
        val program = GLES20.glCreateProgram()
        if (program != 0) {
            GLES20.glAttachShader(program, vertexShader)
            GLES20.glAttachShader(program, fragmentShader)
            GLES20.glLinkProgram(program)
            val linkStatus = IntArray(1)
            GLES20.glGetProgramiv(
                program, GLES20.GL_LINK_STATUS,
                linkStatus, 0
            )
            if (linkStatus[0] == 0) {
                Log.e(
                    TAG, "Shader program link error: " +
                    GLES20.glGetProgramInfoLog(program)
                )
                GLES20.glDeleteProgram(program)
                return 0
            }
        }
        return program
    }
}
