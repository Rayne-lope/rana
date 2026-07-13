package com.rana.app.rana

import android.graphics.Rect
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
import kotlin.math.roundToInt

class CameraGlRenderer(
    private val context: android.content.Context,
    private val outputSurfaceTexture: SurfaceTexture,
    private val width: Int,
    private val height: Int,
    private val onInputSurfaceReady: (SurfaceTexture) -> Unit,
    private val onFpsUpdate: (Int) -> Unit,
    private val onGlError: (String) -> Unit,
    private val onPreviewFrameRendered: (Int) -> Unit = {}
) {
    private companion object {
        private const val TAG = "CameraGlRenderer"
    }

    private data class SinglePassProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val texMatrixLoc: Int,
        val lensDistortionStrengthLoc: Int,
        val temperatureLoc: Int,
        val saturationLoc: Int,
        val contrastLoc: Int,
        val colorMatrixLoc: Int,
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
        val undertoneYLoc: Int,
        val grainSizeLoc: Int,
        val softnessLoc: Int,
        val chromaticAberrationIntensityLoc: Int,
        val fadeLoc: Int,
        val highlightRollOffLoc: Int,
        val shadowRollOffLoc: Int,
        val filmBorderStyleLoc: Int,
        val outputAspectRatioLoc: Int,
        val outputYFlipLoc: Int,
        val shadowsTintLoc: Int,
        val highlightsTintLoc: Int
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
        val colorMatrixLoc: Int,
        val lutTextureLoc: Int,
        val lutStrengthLoc: Int,
        val textureLoc: Int,
        val toneLoc: Int,
        val colorLoc: Int,
        val textureValLoc: Int,
        val styleStrengthLoc: Int,
        val undertoneXLoc: Int,
        val undertoneYLoc: Int,
        val softnessLoc: Int
    )

    private data class CompositeProgram(
        val programId: Int,
        val positionLoc: Int,
        val textureCoordLoc: Int,
        val texMatrixLoc: Int,
        val baseTextureLoc: Int,
        val bloomTextureLoc: Int,
        val halationTextureLoc: Int,
        val bloomIntensityLoc: Int,
        val halationIntensityLoc: Int,
        val halationColorLoc: Int,
        val lightLeakTextureLoc: Int,
        val lightLeakIntensityLoc: Int,
        val dustTextureLoc: Int,
        val dustIntensityLoc: Int,
        val dustUvOffsetXLoc: Int,
        val dustUvOffsetYLoc: Int,
        val grainLoc: Int,
        val vignetteLoc: Int,
        val timeLoc: Int,
        val grainSizeLoc: Int,
        val toneLoc: Int,
        val colorLoc: Int,
        val textureValLoc: Int,
        val styleStrengthLoc: Int,
        val undertoneXLoc: Int,
        val undertoneYLoc: Int,
        val chromaticAberrationIntensityLoc: Int,
        val fadeLoc: Int,
        val highlightRollOffLoc: Int,
        val shadowRollOffLoc: Int,
        val filmBorderStyleLoc: Int,
        val outputAspectRatioLoc: Int,
        val outputYFlipLoc: Int,
        val shadowsTintLoc: Int,
        val highlightsTintLoc: Int
    )

    private val renderThread = HandlerThread("CameraGLThread").apply { start() }
    private val renderHandler = Handler(renderThread.looper)

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    private var oesTextureId = 0
    var cameraSurfaceTexture: SurfaceTexture? = null
        private set

    private lateinit var singlePassProgram: SinglePassProgram
    private var basePassProgram: BasePassProgram? = null
    private var compositeProgram: CompositeProgram? = null
    private var bloomProcessor: BloomProcessor? = null
    private var halationProcessor: BloomProcessor? = null

    private var baseFramebufferId = 0
    private var baseTextureId = 0
    private var baseFramebufferWidth = 0
    private var baseFramebufferHeight = 0

    private var temperature = 0f
    private var saturation = 0f
    private var contrast = 0f
    private var colorMatrix = colorMatrixForGl(IDENTITY_COLOR_MATRIX)
    private var grain = 0f
    private var vignette = 0f
    private var lutStrength = 0f
    private var lightLeakIntensity = 0f
    private var lightLeakVariant = -1
    private var dustIntensity = 0f
    private var bloomThreshold = 0.8f
    private var bloomIntensity = 0f
    private var halationIntensity = 0f
    private var halationRadius = 1f
    private var halationColorR = 1f
    private var halationColorG = 0.35f
    private var halationColorB = 0.15f
    private var lensDistortionStrength = 0f
    private var dustUVOffsetX = 0f
    private var dustUVOffsetY = 0f
    private var tone = 0f
    private var color = 0f
    private var textureVal = 0f
    private var styleStrength = 100f
    private var undertoneX = 0f
    private var undertoneY = 0f
    private var grainSize = 1f
    private var softness = 0f
    private var chromaticAberrationIntensity = 0f
    private var fade = 0f
    private var highlightRollOff = 0f
    private var shadowRollOff = 0f
    private var filmBorderStyle = 0
    private var shadowsTintR = 0f
    private var shadowsTintG = 0f
    private var shadowsTintB = 0f
    private var highlightsTintR = 0f
    private var highlightsTintG = 0f
    private var highlightsTintB = 0f

    private var activeLutTextureId = -1
    private var activeLutPath: String? = null
    private var dustTextureId = -1
    private val lutTextureCache = mutableMapOf<String, Int>()
    private val lightLeakTextureCache = mutableMapOf<Int, Int>()

    private var bloomRuntimeDisabled = false
    private var currentBloomDivisor = 4
    private var lowFpsSamples = 0
    private var recoveredFpsSamples = 0
    private var fpsFrameCount = 0
    private var fpsWindowStartMs = System.currentTimeMillis()

    private val identityMatrix = floatArrayOf(
        1f, 0f, 0f, 0f,
        0f, 1f, 0f, 0f,
        0f, 0f, 1f, 0f,
        0f, 0f, 0f, 1f
    )
    private val startTimeMs = System.currentTimeMillis()

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

    private var viewportWidth = width
    private var viewportHeight = height

    private var previewBufferWidth = 0
    private var previewBufferHeight = 0
    private var previewCropRect = Rect(0, 0, 0, 0)
    private var previewRotationDegrees = 0
    private var previewMirrorHorizontally = false
    private var previewFallbackAspectRatio = 3f / 4f
    private var previewBindingGeneration = 0
    private var previewTransformGeneration = -1
    private var reportedPreviewFrameGeneration = -1

    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(vertexCoords.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(vertexCoords)
            position(0)
        }

    private val unscaledVertexBuffer: FloatBuffer = ByteBuffer
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

    private val dustAnimRunnable = object : Runnable {
        override fun run() {
            dustUVOffsetX = (0..1000).random() / 1000f
            dustUVOffsetY = (0..1000).random() / 1000f
            renderHandler.postDelayed(this, 1000)
        }
    }

    init {
        renderHandler.post {
            try {
                initEgl()
                setupSinglePassShader()
                setupInputSurface()
                renderHandler.post(dustAnimRunnable)
            } catch (e: Exception) {
                val errorMsg = e.message ?: "Unknown error"
                Log.e(TAG, "Initialization failed", e)
                onGlError(errorMsg)
            }
        }
    }

    fun applyPresetParams(
        temperature: Float,
        saturation: Float,
        contrast: Float,
        colorMatrix: FloatArray,
        grain: Float,
        vignette: Float,
        lutPath: String?,
        lutStrength: Float,
        lightLeakIntensity: Float,
        lightLeakVariant: Int,
        dustIntensity: Float,
        bloomThreshold: Float,
        bloomIntensity: Float,
        halationIntensity: Float,
        halationRadius: Float,
        halationColorR: Float,
        halationColorG: Float,
        halationColorB: Float,
        lensDistortionStrength: Float,
        tone: Float,
        color: Float,
        textureVal: Float,
        styleStrength: Float,
        undertoneX: Float,
        undertoneY: Float,
        grainSize: Float,
        softness: Float,
        chromaticAberrationIntensity: Float,
        fade: Float,
        highlightRollOff: Float,
        shadowRollOff: Float,
        filmBorderStyle: Int,
        shadowsTintR: Float,
        shadowsTintG: Float,
        shadowsTintB: Float,
        highlightsTintR: Float,
        highlightsTintG: Float,
        highlightsTintB: Float
    ) {
        renderHandler.post {
            this.temperature = temperature
            this.saturation = saturation
            this.contrast = contrast
            this.colorMatrix = colorMatrixForGl(colorMatrix)
            this.grain = grain
            this.vignette = vignette
            this.lutStrength = lutStrength
            this.lightLeakIntensity = lightLeakIntensity
            this.lightLeakVariant = lightLeakVariant
            this.dustIntensity = dustIntensity
            this.bloomThreshold = bloomThreshold
            this.bloomIntensity = bloomIntensity
            this.halationIntensity = halationIntensity
            this.halationRadius = normalizedHalationRadius(halationRadius)
            this.halationColorR = normalizedHalationColor(halationColorR, 1f)
            this.halationColorG = normalizedHalationColor(halationColorG, 0.35f)
            this.halationColorB = normalizedHalationColor(halationColorB, 0.15f)
            this.lensDistortionStrength = lensDistortionStrength
            this.tone = tone
            this.color = color
            this.textureVal = textureVal
            this.styleStrength = styleStrength
            this.undertoneX = undertoneX
            this.undertoneY = undertoneY
            this.grainSize = grainSize
            this.softness = softness
            this.chromaticAberrationIntensity = chromaticAberrationIntensity
            this.fade = fade
            this.highlightRollOff = highlightRollOff
            this.shadowRollOff = shadowRollOff
            this.filmBorderStyle = normalizedFilmBorderStyle(filmBorderStyle)
            this.shadowsTintR = shadowsTintR
            this.shadowsTintG = shadowsTintG
            this.shadowsTintB = shadowsTintB
            this.highlightsTintR = highlightsTintR
            this.highlightsTintG = highlightsTintG
            this.highlightsTintB = highlightsTintB

            if (lutPath != activeLutPath) {
                activeLutPath = lutPath
                activeLutTextureId = if (lutPath != null) {
                    getOrLoadTextureFromAsset(lutPath)
                } else {
                    -1
                }
            }

            if (bloomIntensity <= 0f) {
                resetBloomQualityState()
                releaseBloomTargetsOnly()
            }

            Log.i(
                "GlParams",
                "[PREVIEW] temp=$temperature sat=$saturation contrast=$contrast " +
                    "grain=$grain vignette=$vignette lut=$lutPath strength=$lutStrength " +
                    "leakIntensity=$lightLeakIntensity leakVariant=$lightLeakVariant " +
                    "dustIntensity=$dustIntensity bloomThreshold=$bloomThreshold " +
                    "bloomIntensity=$bloomIntensity halationIntensity=$halationIntensity " +
                    "lensDistortionStrength=$lensDistortionStrength " +
                    "tone=$tone color=$color textureVal=$textureVal styleStrength=$styleStrength " +
                    "undertoneX=$undertoneX undertoneY=$undertoneY " +
                    "grainSize=$grainSize softness=$softness " +
                    "chromaticAberration=$chromaticAberrationIntensity fade=$fade " +
                    "highlightRollOff=$highlightRollOff shadowRollOff=$shadowRollOff " +
                    "shadowsTint=[$shadowsTintR,$shadowsTintG,$shadowsTintB] " +
                    "highlightsTint=[$highlightsTintR,$highlightsTintG,$highlightsTintB]"
            )
        }
    }

    fun setViewportSize(w: Int, h: Int) {
        renderHandler.post {
            viewportWidth = w
            viewportHeight = h
        }
    }

    fun setPreviewFrameConfig(
        bufferWidth: Int,
        bufferHeight: Int,
        fallbackAspectRatio: Float,
        mirrorHorizontally: Boolean,
        bindingGeneration: Int
    ) {
        renderHandler.post {
            previewBufferWidth = bufferWidth
            previewBufferHeight = bufferHeight
            previewFallbackAspectRatio = fallbackAspectRatio
            previewMirrorHorizontally = mirrorHorizontally
            previewCropRect = Rect(0, 0, 0, 0)
            previewRotationDegrees = 0
            previewBindingGeneration = bindingGeneration
            previewTransformGeneration = -1
            reportedPreviewFrameGeneration = -1
        }
    }

    fun setCameraTransform(
        cropRect: Rect,
        rotationDegrees: Int,
        bindingGeneration: Int
    ) {
        renderHandler.post {
            if (bindingGeneration != previewBindingGeneration) return@post
            previewCropRect = Rect(cropRect)
            previewRotationDegrees = rotationDegrees
            previewTransformGeneration = bindingGeneration
        }
    }

    fun release() {
        renderHandler.removeCallbacks(dustAnimRunnable)
        renderHandler.post {
            cameraSurfaceTexture?.setOnFrameAvailableListener(null)
            cameraSurfaceTexture?.release()
            cameraSurfaceTexture = null

            if (oesTextureId != 0) {
                GLES20.glDeleteTextures(1, intArrayOf(oesTextureId), 0)
                oesTextureId = 0
            }

            val cachedTextureIds = buildSet {
                addAll(lutTextureCache.values.filter { it > 0 })
                addAll(lightLeakTextureCache.values.filter { it > 0 })
                if (dustTextureId > 0) {
                    add(dustTextureId)
                }
            }
            for (texId in cachedTextureIds) {
                GLES20.glDeleteTextures(1, intArrayOf(texId), 0)
            }
            lutTextureCache.clear()
            lightLeakTextureCache.clear()
            activeLutTextureId = -1
            activeLutPath = null
            dustTextureId = -1

            if (::singlePassProgram.isInitialized) {
                GLES20.glDeleteProgram(singlePassProgram.programId)
            }
            releaseBloomResources(releasePrograms = true)

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

            renderThread.quitSafely()
        }
    }

    private fun initEgl() {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
            throw RuntimeException("Unable to get EGL display")
        }

        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            throw RuntimeException("Unable to initialize EGL")
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
        EGL14.eglChooseConfig(
            eglDisplay,
            attribList,
            0,
            configs,
            0,
            configs.size,
            numConfigs,
            0
        )
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
            throw RuntimeException("Failed to create EGL context")
        }

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay,
            config,
            outputSurfaceTexture,
            surfaceAttribs,
            0
        )
        if (eglSurface == EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("Failed to create EGL window surface")
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            throw RuntimeException("eglMakeCurrent failed")
        }

        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
    }

    private fun setupSinglePassShader() {
        val programId = createProgram(
            GlShaderConstants.VERTEX_SHADER,
            GlShaderConstants.FRAGMENT_SHADER_PREVIEW
        )
        if (programId == 0) {
            throw RuntimeException("Could not create preview shader program")
        }

        singlePassProgram = SinglePassProgram(
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
            colorMatrixLoc = GLES20.glGetUniformLocation(programId, "uColorMatrix"),
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
            undertoneYLoc = GLES20.glGetUniformLocation(programId, "uUndertoneY"),
            grainSizeLoc = GLES20.glGetUniformLocation(programId, "uGrainSize"),
            softnessLoc = GLES20.glGetUniformLocation(programId, "uSoftness"),
            chromaticAberrationIntensityLoc = GLES20.glGetUniformLocation(
                programId,
                "uChromaticAberrationIntensity"
            ),
            fadeLoc = GLES20.glGetUniformLocation(programId, "uFade"),
            highlightRollOffLoc = GLES20.glGetUniformLocation(
                programId,
                "uHighlightRollOff"
            ),
            shadowRollOffLoc = GLES20.glGetUniformLocation(
                programId,
                "uShadowRollOff"
            ),
            filmBorderStyleLoc = GLES20.glGetUniformLocation(
                programId,
                "uFilmBorderStyle"
            ),
            outputAspectRatioLoc = GLES20.glGetUniformLocation(
                programId,
                "uOutputAspectRatio"
            ),
            outputYFlipLoc = GLES20.glGetUniformLocation(
                programId,
                "uOutputYFlip"
            ),
            shadowsTintLoc = GLES20.glGetUniformLocation(programId, "uShadowsTint"),
            highlightsTintLoc = GLES20.glGetUniformLocation(programId, "uHighlightsTint")
        )
    }

    private fun ensureBloomPipelineReady() {
        if (bloomRuntimeDisabled) {
            throw RuntimeException("Bloom pipeline disabled for this session")
        }

        try {
            if (basePassProgram == null) {
                val programId = createProgram(
                    GlShaderConstants.VERTEX_SHADER,
                    GlShaderConstants.FRAGMENT_SHADER_BASE_COLOR_PREVIEW
                )
                if (programId == 0) {
                    throw RuntimeException("Could not create base color shader")
                }
                basePassProgram = BasePassProgram(
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
                    colorMatrixLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uColorMatrix"
                    ),
                    lutTextureLoc = GLES20.glGetUniformLocation(programId, "uLutTexture"),
                    lutStrengthLoc = GLES20.glGetUniformLocation(programId, "uLutStrength"),
                    textureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
                    toneLoc = GLES20.glGetUniformLocation(programId, "uTone"),
                    colorLoc = GLES20.glGetUniformLocation(programId, "uColor"),
                    textureValLoc = GLES20.glGetUniformLocation(programId, "uTextureVal"),
                    styleStrengthLoc = GLES20.glGetUniformLocation(programId, "uStyleStrength"),
                    undertoneXLoc = GLES20.glGetUniformLocation(programId, "uUndertoneX"),
                    undertoneYLoc = GLES20.glGetUniformLocation(programId, "uUndertoneY"),
                    softnessLoc = GLES20.glGetUniformLocation(programId, "uSoftness")
                )
                Log.i(
                    "GlParams",
                    "basePassProgram created styleLocs tone=${basePassProgram?.toneLoc} " +
                        "color=${basePassProgram?.colorLoc} texture=${basePassProgram?.textureValLoc} " +
                        "strength=${basePassProgram?.styleStrengthLoc} " +
                        "undertoneX=${basePassProgram?.undertoneXLoc} " +
                        "undertoneY=${basePassProgram?.undertoneYLoc}"
                )
            }

            if (compositeProgram == null) {
                val programId = createProgram(
                    GlShaderConstants.VERTEX_SHADER,
                    GlShaderConstants.FRAGMENT_SHADER_BLOOM_COMPOSITE
                )
                if (programId == 0) {
                    throw RuntimeException("Could not create bloom composite shader")
                }
                compositeProgram = CompositeProgram(
                    programId = programId,
                    positionLoc = GLES20.glGetAttribLocation(programId, "aPosition"),
                    textureCoordLoc = GLES20.glGetAttribLocation(programId, "aTextureCoord"),
                    texMatrixLoc = GLES20.glGetUniformLocation(programId, "uTexMatrix"),
                    baseTextureLoc = GLES20.glGetUniformLocation(programId, "sTexture"),
                    bloomTextureLoc = GLES20.glGetUniformLocation(programId, "uBloomTexture"),
                    halationTextureLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uHalationTexture"
                    ),
                    bloomIntensityLoc = GLES20.glGetUniformLocation(programId, "uBloomIntensity"),
                    halationIntensityLoc = GLES20.glGetUniformLocation(programId, "uHalationIntensity"),
                    halationColorLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uHalationColor"
                    ),
                    lightLeakTextureLoc = GLES20.glGetUniformLocation(programId, "uLightLeakTexture"),
                    lightLeakIntensityLoc = GLES20.glGetUniformLocation(programId, "uLightLeakIntensity"),
                    dustTextureLoc = GLES20.glGetUniformLocation(programId, "uDustTexture"),
                    dustIntensityLoc = GLES20.glGetUniformLocation(programId, "uDustIntensity"),
                    dustUvOffsetXLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetX"),
                    dustUvOffsetYLoc = GLES20.glGetUniformLocation(programId, "uDustUVOffsetY"),
                    grainLoc = GLES20.glGetUniformLocation(programId, "uGrain"),
                    vignetteLoc = GLES20.glGetUniformLocation(programId, "uVignette"),
                    timeLoc = GLES20.glGetUniformLocation(programId, "uTime"),
                    grainSizeLoc = GLES20.glGetUniformLocation(programId, "uGrainSize"),
                    toneLoc = GLES20.glGetUniformLocation(programId, "uTone"),
                    colorLoc = GLES20.glGetUniformLocation(programId, "uColor"),
                    textureValLoc = GLES20.glGetUniformLocation(programId, "uTextureVal"),
                    styleStrengthLoc = GLES20.glGetUniformLocation(programId, "uStyleStrength"),
                    undertoneXLoc = GLES20.glGetUniformLocation(programId, "uUndertoneX"),
                    undertoneYLoc = GLES20.glGetUniformLocation(programId, "uUndertoneY"),
                    chromaticAberrationIntensityLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uChromaticAberrationIntensity"
                    ),
                    fadeLoc = GLES20.glGetUniformLocation(programId, "uFade"),
                    highlightRollOffLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uHighlightRollOff"
                    ),
                    shadowRollOffLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uShadowRollOff"
                    ),
                    filmBorderStyleLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uFilmBorderStyle"
                    ),
                    outputAspectRatioLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uOutputAspectRatio"
                    ),
                    outputYFlipLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uOutputYFlip"
                    ),
                    shadowsTintLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uShadowsTint"
                    ),
                    highlightsTintLoc = GLES20.glGetUniformLocation(
                        programId,
                        "uHighlightsTint"
                    )
                )
                Log.i(
                    "GlParams",
                    "compositeProgram created styleLocs tone=${compositeProgram?.toneLoc} " +
                        "color=${compositeProgram?.colorLoc} texture=${compositeProgram?.textureValLoc} " +
                        "strength=${compositeProgram?.styleStrengthLoc} " +
                        "undertoneX=${compositeProgram?.undertoneXLoc} " +
                        "undertoneY=${compositeProgram?.undertoneYLoc}"
                )
            }

            if (bloomProcessor == null) {
                bloomProcessor = BloomProcessor()
            }
        } catch (e: Exception) {
            bloomRuntimeDisabled = true
            releaseBloomResources(releasePrograms = true)
            throw e
        }
    }

    private fun setupInputSurface() {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        oesTextureId = textures[0]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE
        )

        cameraSurfaceTexture = SurfaceTexture(oesTextureId).apply {
            setOnFrameAvailableListener(
                {
                    renderHandler.post {
                        drawFrame()
                    }
                },
                renderHandler
            )
        }

        onInputSurfaceReady(cameraSurfaceTexture!!)
    }

    private fun drawFrame() {
        val surfaceTexture = cameraSurfaceTexture ?: return
        if (eglDisplay == EGL14.EGL_NO_DISPLAY || eglSurface == EGL14.EGL_NO_SURFACE) {
            return
        }

        try {
            surfaceTexture.updateTexImage()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update texture image", e)
            return
        }

        val surfaceTextureMatrix = FloatArray(16)
        surfaceTexture.getTransformMatrix(surfaceTextureMatrix)
        val texMatrix = buildPreviewTextureMatrix(
            surfaceTextureMatrix = surfaceTextureMatrix,
            bufferWidth = previewBufferWidth,
            bufferHeight = previewBufferHeight,
            cropRect = previewCropRect.takeIf { it.width() > 0 && it.height() > 0 }?.let {
                PreviewCropRect(
                    left = it.left,
                    top = it.top,
                    right = it.right,
                    bottom = it.bottom
                )
            },
            rotationDegrees = previewRotationDegrees,
            mirrorHorizontally = previewMirrorHorizontally,
            fallbackAspectRatio = previewFallbackAspectRatio
        )

        if (shouldUseBloomPath()) {
            try {
                drawBloomFrame(texMatrix)
            } catch (e: Exception) {
                Log.e(TAG, "Bloom path failed, falling back to single-pass preview", e)
                bloomRuntimeDisabled = true
                releaseBloomResources(releasePrograms = true)
                drawSinglePassFrame(texMatrix)
            }
        } else {
            drawSinglePassFrame(texMatrix)
        }

        val didSwap = EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        if (!didSwap) {
            Log.w(TAG, "eglSwapBuffers failed")
        } else if (
            previewBindingGeneration != 0 &&
            previewTransformGeneration == previewBindingGeneration &&
            reportedPreviewFrameGeneration != previewBindingGeneration
        ) {
            reportedPreviewFrameGeneration = previewBindingGeneration
            onPreviewFrameRendered(previewBindingGeneration)
        }

        updateFpsStats()
    }

    private fun shouldUseBloomPath(): Boolean =
        bloomIntensity > 0f && !bloomRuntimeDisabled

    private fun drawSinglePassFrame(texMatrix: FloatArray) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(singlePassProgram.programId)

        bindQuad(singlePassProgram.positionLoc, singlePassProgram.textureCoordLoc)

        GLES20.glUniformMatrix4fv(singlePassProgram.texMatrixLoc, 1, false, texMatrix, 0)
        GLES20.glUniform1f(
            singlePassProgram.lensDistortionStrengthLoc,
            lensDistortionStrength
        )
        GLES20.glUniform1f(singlePassProgram.temperatureLoc, temperature)
        GLES20.glUniform1f(singlePassProgram.saturationLoc, saturation)
        GLES20.glUniform1f(singlePassProgram.contrastLoc, contrast)
        GLES20.glUniformMatrix3fv(
            singlePassProgram.colorMatrixLoc,
            1,
            false,
            colorMatrix,
            0
        )
        GLES20.glUniform1f(singlePassProgram.grainLoc, grain)
        GLES20.glUniform1f(singlePassProgram.vignetteLoc, vignette)
        GLES20.glUniform1f(singlePassProgram.lutStrengthLoc, lutStrength)
        GLES20.glUniform1f(singlePassProgram.lightLeakIntensityLoc, lightLeakIntensity)
        GLES20.glUniform1f(singlePassProgram.dustIntensityLoc, dustIntensity)
        GLES20.glUniform1f(singlePassProgram.dustUvOffsetXLoc, dustUVOffsetX)
        GLES20.glUniform1f(singlePassProgram.dustUvOffsetYLoc, dustUVOffsetY)
        GLES20.glUniform1f(singlePassProgram.bloomIntensityLoc, 0f)
        GLES20.glUniform1f(singlePassProgram.halationIntensityLoc, 0f)
        GLES20.glUniform1f(
            singlePassProgram.timeLoc,
            (System.currentTimeMillis() - startTimeMs) / 1000f
        )
        GLES20.glUniform1f(singlePassProgram.toneLoc, tone)
        GLES20.glUniform1f(singlePassProgram.colorLoc, color)
        GLES20.glUniform1f(singlePassProgram.textureValLoc, textureVal)
        GLES20.glUniform1f(singlePassProgram.styleStrengthLoc, styleStrength)
        GLES20.glUniform1f(singlePassProgram.undertoneXLoc, undertoneX)
        GLES20.glUniform1f(singlePassProgram.undertoneYLoc, undertoneY)
        GLES20.glUniform1f(singlePassProgram.grainSizeLoc, grainSize)
        GLES20.glUniform1f(singlePassProgram.softnessLoc, softness)
        GLES20.glUniform1f(
            singlePassProgram.chromaticAberrationIntensityLoc,
            chromaticAberrationIntensity
        )
        GLES20.glUniform1f(singlePassProgram.fadeLoc, fade)
        GLES20.glUniform1f(singlePassProgram.highlightRollOffLoc, highlightRollOff)
        GLES20.glUniform1f(singlePassProgram.shadowRollOffLoc, shadowRollOff)
        GLES20.glUniform1f(
            singlePassProgram.filmBorderStyleLoc,
            filmBorderStyle.toFloat()
        )
        GLES20.glUniform1f(
            singlePassProgram.outputAspectRatioLoc,
            viewportWidth.toFloat() / viewportHeight.coerceAtLeast(1)
        )
        GLES20.glUniform1f(singlePassProgram.outputYFlipLoc, 1f)
        GLES20.glUniform3f(
            singlePassProgram.shadowsTintLoc,
            shadowsTintR,
            shadowsTintG,
            shadowsTintB
        )
        GLES20.glUniform3f(
            singlePassProgram.highlightsTintLoc,
            highlightsTintR,
            highlightsTintG,
            highlightsTintB
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(singlePassProgram.textureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (activeLutTextureId != -1) activeLutTextureId else 0
        )
        GLES20.glUniform1i(singlePassProgram.lutTextureLoc, 1)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            getActiveLightLeakTextureId().coerceAtLeast(0)
        )
        GLES20.glUniform1i(singlePassProgram.lightLeakTextureLoc, 2)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE3)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            getActiveDustTextureId().coerceAtLeast(0)
        )
        GLES20.glUniform1i(singlePassProgram.dustTextureLoc, 3)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE4)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glUniform1i(singlePassProgram.bloomTextureLoc, 4)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(singlePassProgram.positionLoc, singlePassProgram.textureCoordLoc)
    }

    private fun drawBloomFrame(texMatrix: FloatArray) {
        ensureBloomPipelineReady()
        ensureBaseFramebuffer()

        val baseProgram = basePassProgram
            ?: throw RuntimeException("Base pass program unavailable")
        val composite = compositeProgram
            ?: throw RuntimeException("Composite program unavailable")
        val bloom = bloomProcessor
            ?: throw RuntimeException("Bloom processor unavailable")

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, baseFramebufferId)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(baseProgram.programId)

        bindQuad(baseProgram.positionLoc, baseProgram.textureCoordLoc)
        GLES20.glUniformMatrix4fv(baseProgram.texMatrixLoc, 1, false, texMatrix, 0)
        GLES20.glUniform1f(
            baseProgram.lensDistortionStrengthLoc,
            lensDistortionStrength
        )
        GLES20.glUniform1f(baseProgram.temperatureLoc, temperature)
        GLES20.glUniform1f(baseProgram.saturationLoc, saturation)
        GLES20.glUniform1f(baseProgram.contrastLoc, contrast)
        GLES20.glUniformMatrix3fv(
            baseProgram.colorMatrixLoc,
            1,
            false,
            colorMatrix,
            0
        )
        GLES20.glUniform1f(baseProgram.lutStrengthLoc, lutStrength)
        GLES20.glUniform1f(baseProgram.toneLoc, tone)
        GLES20.glUniform1f(baseProgram.colorLoc, color)
        GLES20.glUniform1f(baseProgram.textureValLoc, textureVal)
        GLES20.glUniform1f(baseProgram.styleStrengthLoc, styleStrength)
        GLES20.glUniform1f(baseProgram.undertoneXLoc, undertoneX)
        GLES20.glUniform1f(baseProgram.undertoneYLoc, undertoneY)
        GLES20.glUniform1f(baseProgram.softnessLoc, softness)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(baseProgram.textureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            if (activeLutTextureId != -1) activeLutTextureId else 0
        )
        GLES20.glUniform1i(baseProgram.lutTextureLoc, 1)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(baseProgram.positionLoc, baseProgram.textureCoordLoc)

        val bloomResult = bloom.applyBloom(
            inputTextureId = baseTextureId,
            sourceWidth = viewportWidth,
            sourceHeight = viewportHeight,
            bloomThreshold = bloomThreshold,
            divisor = currentBloomDivisor
        )
        val halationResult = when {
            halationIntensity <= 0f -> null
            canShareHalationBlur(
                bloomIntensity,
                halationRadius
            ) -> bloomResult
            else -> {
                val processor = halationProcessor ?: BloomProcessor().also {
                    halationProcessor = it
                }
                processor.applyBloom(
                    inputTextureId = baseTextureId,
                    sourceWidth = viewportWidth,
                    sourceHeight = viewportHeight,
                    bloomThreshold = bloomThreshold,
                    divisor = currentBloomDivisor,
                    blurRadiusScale = halationRadius
                )
            }
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(composite.programId)

        bindQuad(composite.positionLoc, composite.textureCoordLoc, unscaledVertexBuffer)
        GLES20.glUniformMatrix4fv(composite.texMatrixLoc, 1, false, identityMatrix, 0)
        GLES20.glUniform1f(composite.bloomIntensityLoc, bloomIntensity)
        GLES20.glUniform1f(composite.halationIntensityLoc, halationIntensity)
        GLES20.glUniform3f(
            composite.halationColorLoc,
            halationColorR,
            halationColorG,
            halationColorB
        )
        GLES20.glUniform1f(composite.lightLeakIntensityLoc, lightLeakIntensity)
        GLES20.glUniform1f(composite.dustIntensityLoc, dustIntensity)
        GLES20.glUniform1f(composite.dustUvOffsetXLoc, dustUVOffsetX)
        GLES20.glUniform1f(composite.dustUvOffsetYLoc, dustUVOffsetY)
        GLES20.glUniform1f(composite.grainLoc, grain)
        GLES20.glUniform1f(composite.vignetteLoc, vignette)
        GLES20.glUniform1f(composite.toneLoc, tone)
        GLES20.glUniform1f(composite.colorLoc, color)
        GLES20.glUniform1f(composite.textureValLoc, textureVal)
        GLES20.glUniform1f(composite.styleStrengthLoc, styleStrength)
        GLES20.glUniform1f(composite.undertoneXLoc, undertoneX)
        GLES20.glUniform1f(composite.undertoneYLoc, undertoneY)
        GLES20.glUniform1f(
            composite.timeLoc,
            (System.currentTimeMillis() - startTimeMs) / 1000f
        )
        GLES20.glUniform1f(composite.grainSizeLoc, grainSize)
        GLES20.glUniform1f(
            composite.chromaticAberrationIntensityLoc,
            chromaticAberrationIntensity
        )
        GLES20.glUniform1f(composite.fadeLoc, fade)
        GLES20.glUniform1f(composite.highlightRollOffLoc, highlightRollOff)
        GLES20.glUniform1f(composite.shadowRollOffLoc, shadowRollOff)
        GLES20.glUniform1f(
            composite.filmBorderStyleLoc,
            filmBorderStyle.toFloat()
        )
        GLES20.glUniform1f(
            composite.outputAspectRatioLoc,
            viewportWidth.toFloat() / viewportHeight.coerceAtLeast(1)
        )
        GLES20.glUniform1f(composite.outputYFlipLoc, 1f)
        GLES20.glUniform3f(
            composite.shadowsTintLoc,
            shadowsTintR,
            shadowsTintG,
            shadowsTintB
        )
        GLES20.glUniform3f(
            composite.highlightsTintLoc,
            highlightsTintR,
            highlightsTintG,
            highlightsTintB
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, baseTextureId)
        GLES20.glUniform1i(composite.baseTextureLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            bloomResult.textureId
        )
        GLES20.glUniform1i(composite.bloomTextureLoc, 1)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            getActiveLightLeakTextureId().coerceAtLeast(0)
        )
        GLES20.glUniform1i(composite.lightLeakTextureLoc, 2)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE3)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            getActiveDustTextureId().coerceAtLeast(0)
        )
        GLES20.glUniform1i(composite.dustTextureLoc, 3)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE4)
        GLES20.glBindTexture(
            GLES20.GL_TEXTURE_2D,
            halationResult?.textureId ?: 0
        )
        GLES20.glUniform1i(composite.halationTextureLoc, 4)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        unbindQuad(composite.positionLoc, composite.textureCoordLoc)
    }

    private fun ensureBaseFramebuffer() {
        val needsRecreate =
            baseFramebufferId == 0 ||
                baseTextureId == 0 ||
                baseFramebufferWidth != viewportWidth ||
                baseFramebufferHeight != viewportHeight

        if (!needsRecreate) return

        releaseBaseFramebuffer()
        baseFramebufferWidth = viewportWidth
        baseFramebufferHeight = viewportHeight

        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        baseTextureId = textures[0]
        if (baseTextureId == 0) {
            throw RuntimeException("Failed to create base color texture")
        }

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, baseTextureId)
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
            baseFramebufferWidth,
            baseFramebufferHeight,
            0,
            GLES20.GL_RGBA,
            GLES20.GL_UNSIGNED_BYTE,
            null
        )

        val framebuffers = IntArray(1)
        GLES20.glGenFramebuffers(1, framebuffers, 0)
        baseFramebufferId = framebuffers[0]
        if (baseFramebufferId == 0) {
            releaseBaseFramebuffer()
            throw RuntimeException("Failed to create base color framebuffer")
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, baseFramebufferId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER,
            GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D,
            baseTextureId,
            0
        )
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            releaseBaseFramebuffer()
            throw RuntimeException("Base color framebuffer incomplete: $status")
        }
    }

    private fun bindQuad(
        positionLoc: Int,
        textureCoordLoc: Int,
        activeVertexBuffer: FloatBuffer = vertexBuffer
    ) {
        activeVertexBuffer.position(0)
        textureBuffer.position(0)
        GLES20.glEnableVertexAttribArray(positionLoc)
        GLES20.glVertexAttribPointer(
            positionLoc,
            3,
            GLES20.GL_FLOAT,
            false,
            12,
            activeVertexBuffer
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

    private fun updateFpsStats() {
        fpsFrameCount += 1
        val now = System.currentTimeMillis()
        val elapsedMs = now - fpsWindowStartMs
        if (elapsedMs < 1000) return

        val fps = ((fpsFrameCount * 1000f) / elapsedMs.toFloat()).roundToInt()
        fpsWindowStartMs = now
        fpsFrameCount = 0
        onFpsUpdate(fps)

        if (shouldUseBloomPath()) {
            adjustBloomQuality(fps)
        } else {
            resetBloomQualityState()
        }
    }

    private fun adjustBloomQuality(fps: Int) {
        when {
            fps < 24 -> {
                lowFpsSamples += 1
                recoveredFpsSamples = 0
                if (lowFpsSamples >= 2 && currentBloomDivisor != 8) {
                    setBloomDivisor(8, fps)
                }
            }

            fps >= 27 -> {
                recoveredFpsSamples += 1
                lowFpsSamples = 0
                if (recoveredFpsSamples >= 3 && currentBloomDivisor != 4) {
                    setBloomDivisor(4, fps)
                }
            }

            else -> {
                lowFpsSamples = 0
                recoveredFpsSamples = 0
            }
        }
    }

    private fun setBloomDivisor(divisor: Int, fps: Int) {
        currentBloomDivisor = divisor
        lowFpsSamples = 0
        recoveredFpsSamples = 0
        releaseBloomTargetsOnly()
        Log.i(TAG, "Bloom divisor switched to 1/$divisor at ${fps} FPS")
    }

    private fun resetBloomQualityState() {
        lowFpsSamples = 0
        recoveredFpsSamples = 0
        currentBloomDivisor = 4
    }

    private fun releaseBloomTargetsOnly() {
        releaseBaseFramebuffer()
        bloomProcessor?.releaseFramebuffers()
        halationProcessor?.releaseFramebuffers()
    }

    private fun releaseBaseFramebuffer() {
        if (baseFramebufferId != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(baseFramebufferId), 0)
            baseFramebufferId = 0
        }
        if (baseTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(baseTextureId), 0)
            baseTextureId = 0
        }
        baseFramebufferWidth = 0
        baseFramebufferHeight = 0
    }

    private fun releaseBloomResources(releasePrograms: Boolean) {
        releaseBloomTargetsOnly()

        if (releasePrograms) {
            basePassProgram?.let { GLES20.glDeleteProgram(it.programId) }
            compositeProgram?.let { GLES20.glDeleteProgram(it.programId) }
            bloomProcessor?.release()
            halationProcessor?.release()
            basePassProgram = null
            compositeProgram = null
            bloomProcessor = null
            halationProcessor = null
        }
    }

    private fun getActiveLightLeakTextureId(): Int {
        if (lightLeakIntensity <= 0f || lightLeakVariant !in 0..3) {
            return -1
        }
        return getOrLoadLightLeakTexture(lightLeakVariant)
    }

    private fun getActiveDustTextureId(): Int {
        if (dustIntensity <= 0f) {
            return -1
        }
        return getOrLoadDustTexture()
    }

    private fun getOrLoadDustTexture(): Int {
        if (dustTextureId != -1) {
            return dustTextureId
        }
        dustTextureId = getOrLoadTextureFromAsset("assets/textures/dust_scratches_atlas.png")
        return dustTextureId
    }

    private fun getOrLoadLightLeakTexture(variant: Int): Int {
        val cachedId = lightLeakTextureCache[variant]
        if (cachedId != null && cachedId != -1) {
            return cachedId
        }

        val assetPath = "assets/textures/light_leak_${variant + 1}.png"
        val textureId = getOrLoadTextureFromAsset(assetPath)
        if (textureId != -1) {
            lightLeakTextureCache[variant] = textureId
        }
        return textureId
    }

    private fun getOrLoadTextureFromAsset(assetPath: String): Int {
        val cachedId = lutTextureCache[assetPath]
        if (cachedId != null && cachedId != -1) {
            return cachedId
        }

        return try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { inputStream ->
                val options = android.graphics.BitmapFactory.Options().apply {
                    inScaled = false
                }
                val bitmap = android.graphics.BitmapFactory.decodeStream(
                    inputStream,
                    null,
                    options
                ) ?: return -1

                val textures = IntArray(1)
                GLES20.glGenTextures(1, textures, 0)
                val textureId = textures[0]
                if (textureId == 0) {
                    bitmap.recycle()
                    return -1
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
                android.opengl.GLUtils.texImage2D(
                    GLES20.GL_TEXTURE_2D,
                    0,
                    bitmap,
                    0
                )
                bitmap.recycle()
                lutTextureCache[assetPath] = textureId
                textureId
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load texture asset: $assetPath", e)
            -1
        }
    }

    private fun createProgram(vertexCode: String, fragmentCode: String): Int {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexCode)
        if (vertexShader == 0) return 0
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentCode)
        if (fragmentShader == 0) {
            GLES20.glDeleteShader(vertexShader)
            return 0
        }

        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)

        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0)
        GLES20.glDeleteShader(vertexShader)
        GLES20.glDeleteShader(fragmentShader)
        if (linkStatus[0] == 0) {
            Log.e(TAG, "Could not link program: ${GLES20.glGetProgramInfoLog(program)}")
            GLES20.glDeleteProgram(program)
            return 0
        }
        return program
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        if (shader == 0) return 0

        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(TAG, "Could not compile shader $type: ${GLES20.glGetShaderInfoLog(shader)}")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }
}
