package com.ikemenmobile

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import org.libsdl.app.SDLActivity

class MainActivity : SDLActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Force landscape once on startup
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        // Before SDL / Go touches basePath, make sure assets are extracted there.
        AssetsExtractor.ensureAssetsExtracted(this)
    }

    override fun onResume() {
        super.onResume()
        // Re-assert landscape when returning to the app
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)

        // If the system tries to flip us, push back to landscape
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    // SDL handles native main + GL + input
    // Already renamed main to ikemen in SDL code itself
    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen") // Loads libikemen.so
    }

    // This becomes argv[1] in SDL_main
    override fun getArguments(): Array<String> {
        val base = getExternalFilesDir(null)?.absolutePath
            ?: filesDir.absolutePath   // fallback, but should normally be /storage/emulated/0/Android/data/com.ikemenmobile/files
        return arrayOf(base)
    }
}