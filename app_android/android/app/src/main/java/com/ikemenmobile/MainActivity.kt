package com.ikemenmobile

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.PopupMenu
import android.widget.Toast
import org.libsdl.app.SDLActivity

class MainActivity : SDLActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Force landscape once on startup
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        // Extract game assets before Go/SDL touches basePath
        AssetsExtractor.ensureAssetsExtracted(this)

        // Root view is a FrameLayout
        val root = window.decorView.findViewById<FrameLayout>(android.R.id.content)

        // 1) Virtual gamepad overlay (initially visible)
        val pad = VirtualGamepadView(this)
        root.addView(
            pad,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // 2) Menu button that is NEVER hidden by gamepad toggle
        val menuButton = Button(this).apply {
            text = "☰"
            alpha = 0.85f
        }

        val menuSize = (48 * resources.displayMetrics.density).toInt()
        val menuLp = FrameLayout.LayoutParams(menuSize, menuSize).apply {
            gravity = Gravity.START or Gravity.TOP
            marginStart = (8 * resources.displayMetrics.density).toInt()
            topMargin = (8 * resources.displayMetrics.density).toInt()
        }
        root.addView(menuButton, menuLp)

        // Menu hierarchy
        menuButton.setOnClickListener {
            showRootMenu(menuButton, pad)
        }

        Log.d("MainActivity", "VirtualGamepadView + menu button attached")
    }

    private fun showRootMenu(anchor: View, pad: View) {
        val pm = PopupMenu(this, anchor)
        pm.menu.add("Gamepad")

        pm.setOnMenuItemClickListener { item ->
            when (item.title.toString()) {
                "Gamepad" -> {
                    showGamepadMenu(anchor, pad)
                    true
                }
                else -> false
            }
        }
        pm.show()
    }

    private fun showGamepadMenu(anchor: View, pad: View) {
        val pm = PopupMenu(this, anchor)
        pm.menu.add("Toggle gamepad")
        pm.menu.add("Import gamepad layout")

        pm.setOnMenuItemClickListener { item ->
            when (item.title.toString()) {
                "Toggle gamepad" -> {
                    pad.visibility =
                        if (pad.visibility == View.VISIBLE) View.GONE else View.VISIBLE
                    true
                }
                "Import gamepad layout" -> {
                    // Stub – later we’ll open a proper UI / file picker
                    Toast.makeText(
                        this,
                        "Import layout: not implemented yet",
                        Toast.LENGTH_SHORT
                    ).show()
                    Log.d("MainActivity", "Import gamepad layout requested (stub)")
                    true
                }
                else -> false
            }
        }
        pm.show()
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
        return arrayOf("ikemen") // Loads libikemen.so
    }

    // This becomes argv[1] in SDL_main
    override fun getArguments(): Array<String> {
        val base = getExternalFilesDir(null)?.absolutePath
            ?: filesDir.absolutePath
        return arrayOf(base)
    }
}