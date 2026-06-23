package com.rana.app.rana

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

class CameraGlRenderer(
    private val context: android.content.Context,
    private val outputSurfaceTexture: SurfaceTexture,
    private val width: Int,
    private val height: Int,
    private val onInputSurfaceReady: (SurfaceTexture) -> Unit,
    private val onGlError: (String) -> Unit
) {
    private val tag = "CameraGlRenderer"

    private val renderThread = HandlerThread("CameraGLThread").apply { start() }
    private val renderHandler = Handler(renderThread.looper)

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    private var oesTextureId: Int = -1
    var cameraSurfaceTexture: SurfaceTexture? = null
        private set

    private var programId: Int = -1
    private var aPositionLoc: Int = -1
    private var aTextureCoordLoc: Int = -1
    private var uTexMatrixLoc: Int = -1
    private var uTemperatureLoc: Int = -1
    private var uSaturationLoc: Int = -1
    private var uContrastLoc: Int = -1
    private var uGrainLoc: Int = -1
    private var uVignetteLoc: Int = -1
    private var uLutTextureLoc: Int = -1
    private var uLutStrengthLoc: Int = -1
    private var sTextureLoc: Int = -1

    private var uTemperature = 0.0f
    private var uSaturation = 0.0f
    private var uContrast = 0.0f
    private var uGrain = 0.0f
    private var uVignette = 0.0f
    private var uLutStrength = 0.0f
    private var activeLutTextureId: Int = -1
    private var activeLutPath: String? = null
    private val lutTextureCache = mutableMapOf<String, Int>()

    private val vertexCoords = floatArrayOf(
        -1.0f, -1.0f, 0.0f,
         1.0f, -1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f, 0.0f
    )

    private val textureCoords = floatArrayOf(
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f
    )

    private val vertexBuffer: FloatBuffer = ByteBuffer.allocateDirect(vertexCoords.size * 4).run {
        order(ByteOrder.nativeOrder())
        asFloatBuffer().apply {
            put(vertexCoords)
            position(0)
        }
    }

    private val textureBuffer: FloatBuffer = ByteBuffer.allocateDirect(textureCoords.size * 4).run {
        order(ByteOrder.nativeOrder())
        asFloatBuffer().apply {
            put(textureCoords)
            position(0)
        }
    }

    private val vertexShaderCode = """
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTextureCoord;
        uniform mat4 uTexMatrix;
        void main() {
            gl_Position = aPosition;
            vTextureCoord = (uTexMatrix * aTextureCoord).xy;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        #extension GL_OES_EGL_image_external : require
        #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
        #else
        precision mediump float;
        #endif
        varying vec2 vTextureCoord;
        uniform samplerExternalOES sTexture;
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

    init {
        renderHandler.post {
            try {
                initEgl()
                setupShaders()
                setupInputSurface()
            } catch (e: Exception) {
                val errorMsg = e.message ?: "Unknown error"
                Log.e(tag, "Initialization failed: $errorMsg")
                onGlError(errorMsg)
            }
        }
    }

    private fun initEgl() {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
            throw RuntimeException("unable to get EGL14 display")
        }

        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            throw RuntimeException("unable to initialize EGL14")
        }

        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, configs.size, numConfigs, 0)
        val config = configs[0] ?: throw RuntimeException("unable to find a suitable EGLConfig")

        val contextAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL14.EGL_NONE
        )
        eglContext = EGL14.eglCreateContext(eglDisplay, config, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            throw RuntimeException("Failed to create EGL context")
        }

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, config, outputSurfaceTexture, surfaceAttribs, 0)
        if (eglSurface == EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("Failed to create window surface")
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            throw RuntimeException("eglMakeCurrent failed")
        }

        GLES20.glViewport(0, 0, width, height)
    }

    private fun setupShaders() {
        programId = createProgram(vertexShaderCode, fragmentShaderCode)
        if (programId == 0) {
            throw RuntimeException("Could not create shader program")
        }

        aPositionLoc = GLES20.glGetAttribLocation(programId, "aPosition")
        aTextureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord")
        uTexMatrixLoc = GLES20.glGetUniformLocation(programId, "uTexMatrix")
        uTemperatureLoc = GLES20.glGetUniformLocation(programId, "uTemperature")
        uSaturationLoc = GLES20.glGetUniformLocation(programId, "uSaturation")
        uContrastLoc = GLES20.glGetUniformLocation(programId, "uContrast")
        uGrainLoc = GLES20.glGetUniformLocation(programId, "uGrain")
        uVignetteLoc = GLES20.glGetUniformLocation(programId, "uVignette")
        uLutTextureLoc = GLES20.glGetUniformLocation(programId, "uLutTexture")
        uLutStrengthLoc = GLES20.glGetUniformLocation(programId, "uLutStrength")
        sTextureLoc = GLES20.glGetUniformLocation(programId, "sTexture")
    }

    private fun setupInputSurface() {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        oesTextureId = textures[0]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        cameraSurfaceTexture = SurfaceTexture(oesTextureId).apply {
            setOnFrameAvailableListener({
                renderHandler.post {
                    drawFrame()
                }
            }, renderHandler)
        }

        onInputSurfaceReady(cameraSurfaceTexture!!)
    }

    private fun drawFrame() {
        val surfaceTexture = cameraSurfaceTexture ?: return
        if (eglDisplay == EGL14.EGL_NO_DISPLAY || eglSurface == EGL14.EGL_NO_SURFACE) return

        try {
            surfaceTexture.updateTexImage()
        } catch (e: Exception) {
            Log.e(tag, "Failed to update texture image: ${e.message}")
            return
        }

        val texMatrix = FloatArray(16)
        surfaceTexture.getTransformMatrix(texMatrix)

        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        GLES20.glUseProgram(programId)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(sTextureLoc, 0)

        GLES20.glEnableVertexAttribArray(aPositionLoc)
        GLES20.glVertexAttribPointer(aPositionLoc, 3, GLES20.GL_FLOAT, false, 12, vertexBuffer)

        GLES20.glEnableVertexAttribArray(aTextureCoordLoc)
        GLES20.glVertexAttribPointer(aTextureCoordLoc, 2, GLES20.GL_FLOAT, false, 8, textureBuffer)

        GLES20.glUniformMatrix4fv(uTexMatrixLoc, 1, false, texMatrix, 0)
        GLES20.glUniform1f(uTemperatureLoc, uTemperature)
        GLES20.glUniform1f(uSaturationLoc, uSaturation)
        GLES20.glUniform1f(uContrastLoc, uContrast)
        GLES20.glUniform1f(uGrainLoc, uGrain)
        GLES20.glUniform1f(uVignetteLoc, uVignette)
        GLES20.glUniform1f(uLutStrengthLoc, uLutStrength)

        // Always bind texture unit 1 to prevent conflicts on different GPU drivers
        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (activeLutTextureId != -1) activeLutTextureId else 0
        )
        GLES20.glUniform1i(uLutTextureLoc, 1)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(aPositionLoc)
        GLES20.glDisableVertexAttribArray(aTextureCoordLoc)

        if (!EGL14.eglSwapBuffers(eglDisplay, eglSurface)) {
            Log.w(tag, "eglSwapBuffers failed")
        }
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(tag, "Could not compile shader $type: ${GLES20.glGetShaderInfoLog(shader)}")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }

    private fun createProgram(vertexCode: String, fragmentCode: String): Int {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexCode)
        if (vertexShader == 0) return 0
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentCode)
        if (fragmentShader == 0) return 0

        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)
        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            Log.e(tag, "Could not link program: ${GLES20.glGetProgramInfoLog(program)}")
            GLES20.glDeleteProgram(program)
            return 0
        }
        return program
    }

    fun applyPresetParams(
        temperature: Float,
        saturation: Float,
        contrast: Float,
        grain: Float,
        vignette: Float,
        lutPath: String?,
        lutStrength: Float
    ) {
        renderHandler.post {
            uTemperature = temperature
            uSaturation = saturation
            uContrast = contrast
            uGrain = grain
            uVignette = vignette
            uLutStrength = lutStrength

            if (lutPath != activeLutPath) {
                activeLutPath = lutPath
                activeLutTextureId = if (lutPath != null) {
                    getOrLoadLutTexture(lutPath)
                } else {
                    -1
                }
            }
        }
    }

    private fun getOrLoadLutTexture(assetPath: String): Int {
        val cachedId = lutTextureCache[assetPath]
        if (cachedId != null && cachedId != -1) {
            return cachedId
        }
        val texId = loadLutTextureFromAsset(assetPath)
        if (texId != -1) {
            lutTextureCache[assetPath] = texId
        }
        return texId
    }

    private fun loadLutTextureFromAsset(assetPath: String): Int {
        try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory
                    .decodeStream(inputStream, null, options) ?: return -1

                Log.i(
                    tag,
                    "Loaded LUT: $assetPath, size: " +
                    "${bitmap.width}x${bitmap.height}"
                )
                
                val textures = IntArray(1)
                GLES20.glGenTextures(1, textures, 0)
                val texId = textures[0]
                if (texId == 0) {
                    bitmap.recycle()
                    return -1
                }
                
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
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
                
                android.opengl.GLUtils.texImage2D(
                    GLES20.GL_TEXTURE_2D,
                    0,
                    bitmap,
                    0
                )
                bitmap.recycle()
                return texId
            }
        } catch (e: Exception) {
            Log.e(tag, "Failed to load LUT texture: $assetPath", e)
            return -1
        }
    }

    fun release() {
        val handler = renderHandler
        handler.post {
            cameraSurfaceTexture?.setOnFrameAvailableListener(null)
            cameraSurfaceTexture?.release()
            cameraSurfaceTexture = null

            if (oesTextureId != -1) {
                val textures = intArrayOf(oesTextureId)
                GLES20.glDeleteTextures(1, textures, 0)
                oesTextureId = -1
            }

            for (texId in lutTextureCache.values) {
                if (texId != -1) {
                    GLES20.glDeleteTextures(1, intArrayOf(texId), 0)
                }
            }
            lutTextureCache.clear()
            activeLutTextureId = -1
            activeLutPath = null

            if (programId != -1) {
                GLES20.glDeleteProgram(programId)
                programId = -1
            }

            if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT
                )
                if (eglSurface != EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(eglDisplay, eglSurface)
                    eglSurface = EGL14.EGL_NO_SURFACE
                }
                if (eglContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(eglDisplay, eglContext)
                    eglContext = EGL14.EGL_NO_CONTEXT
                }
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(eglDisplay)
                eglDisplay = EGL14.EGL_NO_DISPLAY
            }

            renderThread.quitSafely()
        }
    }
}
