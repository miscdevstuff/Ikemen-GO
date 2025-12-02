package com.ikemenmobile

import org.libsdl.app.SDLActivity

class MainActivity : SDLActivity() {
    // SDL handles native main + GL + input
    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen") // Loads libikemen.so
    }
}