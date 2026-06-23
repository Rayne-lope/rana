package com.rana.app.rana

import android.graphics.Bitmap
import android.graphics.Matrix
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

    private val vertexShaderCode = """
        uniform mat4 uTexMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTextureCoord;
        void main() {
            gl_Position = aPosition;
            vTextureCoord = (uTexMatrix * aTextureCoord).xy;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
        #else
        precision mediump float;
        #endif
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        uniform sampler2D uLutTexture;
        uniform float uLutStrength;
        uniform float uTemperature;
        uniform float uSaturation;
        uniform float uContrast;
        uniform float uGrain;
        uniform float uVignette;

        float rand(vec2 co) {
            return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
        }

        vec3 applyLut(vec3 color) {
            vec3 lutInput = clamp(color, 0.0, 1.0);
            float blueVal = lutInput.b * 15.0;
            
            float blueCellLower = floor(blueVal);
            float xOffsetLower = mod(blueCellLower, 8.0) / 8.0;
            float blueRowLower = floor(blueCellLower / 8.0);
            float lutYLower = 1.0 - (
                (blueRowLower * 8.0 + lutInput.g * 7.0 + 0.5) / 16.0
            );
            vec2 lutUVLower = vec2(
                xOffsetLower + (lutInput.r * 63.0 + 0.5) / 512.0,
                lutYLower
            );
            vec3 lutColorLower = texture2D(uLutTexture, lutUVLower).rgb;
            
            float blueCellUpper = min(blueCellLower + 1.0, 15.0);
            float xOffsetUpper = mod(blueCellUpper, 8.0) / 8.0;
            float blueRowUpper = floor(blueCellUpper / 8.0);
            float lutYUpper = 1.0 - (
                (blueRowUpper * 8.0 + lutInput.g * 7.0 + 0.5) / 16.0
            );
            vec2 lutUVUpper = vec2(
                xOffsetUpper + (lutInput.r * 63.0 + 0.5) / 512.0,
                lutYUpper
            );
            vec3 lutColorUpper = texture2D(uLutTexture, lutUVUpper).rgb;
            
            vec3 lutColor = mix(
                lutColorLower, lutColorUpper, fract(blueVal)
            );
            return mix(color, lutColor, uLutStrength);
        }

        void main() {
            vec4 texColor = texture2D(sTexture, vTextureCoord);
            vec3 color = texColor.rgb;

            if (uTemperature > 0.0) {
                color.r += uTemperature * 0.15;
                color.g += uTemperature * 0.07;
                color.b -= uTemperature * 0.05;
            } else if (uTemperature < 0.0) {
                color.r += uTemperature * 0.05;
                color.g += uTemperature * 0.05;
                color.b -= uTemperature * 0.15;
            }

            float luma = dot(color, vec3(0.299, 0.587, 0.114));
            color = mix(vec3(luma), color, 1.0 + uSaturation);

            color = (color - 0.5) * (1.0 + uContrast) + 0.5;

            if (uLutStrength > 0.0) {
                color = applyLut(color);
            }

            if (uGrain > 0.0) {
                float noise = rand(vTextureCoord) - 0.5;
                color += vec3(noise * uGrain * 0.25);
            }

            if (uVignette > 0.0) {
                vec2 uv = vTextureCoord - 0.5;
                float dist = length(uv);
                float vignette = smoothstep(0.8, 0.8 - uVignette * 0.6, dist);
                color *= vignette;
            }

            gl_FragColor = vec4(clamp(color, 0.0, 1.0), texColor.a);
        }
    """.trimIndent()

    fun processImage(
        context: android.content.Context,
        inputBitmap: Bitmap,
        params: OfflineProcessParams
    ): Bitmap? {
        if (!isProcessing.compareAndSet(false, true)) {
            Log.e(TAG, "Processing already in progress")
            return null
        }

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
                workingBitmap = Bitmap.createScaledBitmap(
                    workingBitmap, scaledWidth, scaledHeight, true
                )
            }

            // 6. Setup Program & Shaders
            programId = createProgram(vertexShaderCode, fragmentShaderCode)
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
            val sTextureLoc = GLES20.glGetUniformLocation(
                programId, "sTexture"
            )
            GLES20.glUniform1i(sTextureLoc, 0)

            // Clear viewport and Draw
            GLES20.glViewport(0, 0, workingBitmap.width, workingBitmap.height)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            // 9. Read back pixels
            val readBuf = ByteBuffer.allocateDirect(
                workingBitmap.width * workingBitmap.height * 4
            ).order(ByteOrder.LITTLE_ENDIAN)

            GLES20.glReadPixels(
                0, 0, workingBitmap.width, workingBitmap.height,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, readBuf
            )
            readBuf.rewind()

            val outBitmap = Bitmap.createBitmap(
                workingBitmap.width, workingBitmap.height,
                Bitmap.Config.ARGB_8888
            )
            outBitmap.copyPixelsFromBuffer(readBuf)

            // 10. Flip Y axis
            val flipMatrix = Matrix().apply { preScale(1f, -1f) }
            val flippedBitmap = Bitmap.createBitmap(
                outBitmap, 0, 0, outBitmap.width, outBitmap.height,
                flipMatrix, false
            )
            
            if (outBitmap != flippedBitmap) {
                outBitmap.recycle()
            }
            if (workingBitmap != inputBitmap) {
                workingBitmap.recycle()
            }

            return flippedBitmap

        } catch (e: Exception) {
            Log.e(TAG, "Error processing offline image", e)
            return null
        } finally {
            // Clean up resources cleanly
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
