package com.ikemenmobile

import org.libsdl.app.SDLActivityDebug

class MainActivity : SDLActivityDebug() {
    // SDL handles native main + GL + input
    // Already renamed main to ikemen in sdl code itself
    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen") // Loads libikemen.so
    }
}