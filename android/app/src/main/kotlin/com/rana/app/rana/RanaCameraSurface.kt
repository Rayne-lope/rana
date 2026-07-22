package com.rana.app.rana

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView

/** Owns the Android preview view hierarchy and TextureView lifecycle. */
internal class RanaCameraSurface(
    context: Context,
    onAvailable: (SurfaceTexture, Int, Int) -> Unit,
    onSizeChanged: (Int, Int) -> Unit,
    onDestroyed: () -> Unit
) {
    val root = FrameLayout(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    val texture = TextureView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }
    val lensSwitchOverlay = ImageView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        scaleType = ImageView.ScaleType.CENTER_CROP
        visibility = View.GONE
    }

    init {
        root.addView(texture)
        root.addView(lensSwitchOverlay)
        texture.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(
                surfaceTexture: SurfaceTexture,
                width: Int,
                height: Int
            ) = onAvailable(surfaceTexture, width, height)

            override fun onSurfaceTextureSizeChanged(
                surfaceTexture: SurfaceTexture,
                width: Int,
                height: Int
            ) = onSizeChanged(width, height)

            override fun onSurfaceTextureDestroyed(surfaceTexture: SurfaceTexture): Boolean {
                onDestroyed()
                return true
            }

            override fun onSurfaceTextureUpdated(surfaceTexture: SurfaceTexture) = Unit
        }
    }
}
