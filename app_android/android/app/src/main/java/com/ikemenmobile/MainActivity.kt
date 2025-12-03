package com.ikemenmobile

import org.libsdl.app.SDLActivity

class MainActivity : SDLActivity() {
    // SDL handles native main + GL + input
    // Already renamed main to ikemen in sdl code itself
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