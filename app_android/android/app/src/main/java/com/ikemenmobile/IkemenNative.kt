/* package com.ikemenmobile

import android.util.Log

object IkemenNative {

    private const val TAG = "IkemenNative"

    init {
        try {
            Log.d(TAG, "About to load native library 'ikemen'")
            System.loadLibrary("ikemen")
            Log.d(TAG, "Successfully loaded native library 'ikemen'")
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to load native library 'ikemen'", t)
            throw t   // rethrow so we see the real cause
        }
    }

    // Native entrypoint exported by your Go/CGO code.
    external fun runIkemen(basePath: String)
} */