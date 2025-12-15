package com.ikemenmobile

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import android.system.Os
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ContextThemeWrapper
import android.widget.FrameLayout
import android.widget.PopupMenu
import androidx.appcompat.widget.AppCompatButton
import org.libsdl.app.SDLActivity
import java.io.File

class MainActivity : SDLActivity() {

    private lateinit var virtualPad: VirtualGamepadLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        // ---------------------------------------------------------
        // CRITICAL FIX: Environment Setup BEFORE Native Init
        // ---------------------------------------------------------
        try {
            // 1. Define Paths
            val filesDirObj = getExternalFilesDir(null) ?: filesDir
            // Use 'tmp' directory INSIDE the game files directory
            val tmpDirObj = File(filesDirObj, "tmp")

            // 2. Ensure Directories Exist
            if (!tmpDirObj.exists()) {
                tmpDirObj.mkdirs()
            }

            // 3. Set Environment Variables for Go
            // IKEMEN_PATH: Game root
            Os.setenv("IKEMEN_PATH", filesDirObj.absolutePath, true)
            
            // TMPDIR: Point to basepath/tmp so all temp files go there
            Os.setenv("TMPDIR", tmpDirObj.absolutePath, true)

            // GOGC: PERFORMANCE FIX FOR AUDIO
            // Default is 100. Setting to 200 or 400 reduces the frequency of 
            // Garbage Collection pauses, which prevents audio stutter/pops.
            Os.setenv("GOGC", "200", true)

            Log.v("Ikemen", "Native Env Init: IKEMEN_PATH=${filesDirObj.absolutePath} TMPDIR=${tmpDirObj.absolutePath} GOGC=200")
        } catch (e: Exception) {
            Log.e("Ikemen", "Failed to set native environment variables", e)
        }
        // ---------------------------------------------------------

        super.onCreate(savedInstanceState)

        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        AssetsExtractor.ensureAssetsExtracted(this)

        val root = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        virtualPad = VirtualGamepadLayout(this)
        root.addView(virtualPad, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        
        setupMenuButton(root)
        Log.d("MainActivity", "VirtualGamepadLayout attached")
    }

    private fun setupMenuButton(root: ViewGroup) {
        val themedCtx = ContextThemeWrapper(this, R.style.VirtualPadMenuButton)
        val menuButton = AppCompatButton(themedCtx, null, 0).apply {
            text = "≡"
            textSize = 16f
            alpha = 0.9f
            val density = resources.displayMetrics.density
            val size = (40f * density).toInt()
            val margin = (16f * density).toInt()
            layoutParams = FrameLayout.LayoutParams(size, size, Gravity.TOP or Gravity.START).apply {
                setMargins(margin, margin, margin, margin)
            }
            setOnClickListener { showGamepadMenu(this) }
        }
        root.addView(menuButton)
    }

    private fun showGamepadMenu(anchor: View) {
        val popup = PopupMenu(this, anchor)
        popup.menu.add(0, 1, 0, "Toggle gamepad")
        popup.menu.add(0, 2, 1, "Import gamepad layout (stub)")
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> {
                    virtualPad.visibility = if (virtualPad.visibility == View.VISIBLE) View.GONE else View.VISIBLE
                    true
                }
                2 -> {
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

    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen")
    }

    override fun getArguments(): Array<String> {
        val base = getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath
        return arrayOf(base)
    }
}