package com.ikemenmobile

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ContextThemeWrapper
import android.widget.FrameLayout
import android.widget.PopupMenu
import androidx.appcompat.widget.AppCompatButton
import org.libsdl.app.SDLActivity

class MainActivity : SDLActivity() {

    private lateinit var virtualPad: VirtualGamepadLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Force landscape
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        // Extract Ikemen assets before Go/SDL touches basePath
        AssetsExtractor.ensureAssetsExtracted(this)

        // Root container SDL uses
        val root = window.decorView.findViewById<ViewGroup>(android.R.id.content)

        // Our overlay (XML-based virtual pad)
        virtualPad = VirtualGamepadLayout(this)
        root.addView(
            virtualPad,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        // Floating menu button (≡) – always visible
        val themedCtx = ContextThemeWrapper(this, R.style.VirtualPadMenuButton)
        val menuButton = AppCompatButton(themedCtx, null, 0).apply {
            text = "≡"
            textSize = 16f
            alpha = 0.9f

            val density = resources.displayMetrics.density
            val size = (40f * density).toInt()
            val margin = (16f * density).toInt()

            layoutParams = FrameLayout.LayoutParams(
                size,
                size,
                Gravity.TOP or Gravity.START
            ).apply {
                setMargins(margin, margin, margin, margin)
            }

            setOnClickListener { showGamepadMenu(this) }
        }

        root.addView(menuButton)

        Log.d("MainActivity", "VirtualGamepadLayout attached")
    }

    private fun showGamepadMenu(anchor: View) {
        val popup = PopupMenu(this, anchor)
        popup.menu.add(0, 1, 0, "Toggle gamepad")
        popup.menu.add(0, 2, 1, "Import gamepad layout (stub)")

        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> {
                    virtualPad.visibility =
                        if (virtualPad.visibility == View.VISIBLE) View.GONE else View.VISIBLE
                    true
                }

                2 -> {
                    // Placeholder for future in-app layout editor / importer
                    Log.d("MainActivity", "Import gamepad layout – not implemented yet")
                    true
                }

                else -> false
            }
        }
        popup.show()
    }

    override fun onResume() {
        super.onResume()
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    // SDL handles native main + GL + input
    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen")
    }

    override fun getArguments(): Array<String> {
        val base = getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath
        return arrayOf(base)
    }
}