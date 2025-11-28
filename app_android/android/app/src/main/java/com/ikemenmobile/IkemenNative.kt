package com.ikemenmobile

object IkemenNative {

    init {
        // Loads /lib/arm64-v8a/libikemen.so from your APK
        System.loadLibrary("ikemen")
    }

    /**
     * Native entrypoint exported by your Go/CGO code.
     *
     * We’ll assume you have something like:
     *   //export RunIkemen
     *   func RunIkemen(basePath *C.char)
     *
     * in your Go side and that build script generated libikemen.h accordingly.
     */
    external fun runIkemen(basePath: String)
}
