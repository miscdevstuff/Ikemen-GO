//go:build android

package main

/*
#include <jni.h>
#include <stdlib.h>
#include <android/log.h>

static void ikm_log(const char* msg) {
    __android_log_write(ANDROID_LOG_INFO, "Ikemen", msg);
}
*/
import "C"

import (
    "fmt"
    "unsafe"
)

//export SDL_main
// SDL calls this instead of main() on Android.
// It runs on the dedicated SDL thread created by SDLActivity.
func SDL_main(argc C.int, argv **C.char) C.int {
    // For now: hardcoded base path in app-private storage.
    // Later we can switch to a user-modifiable /sdcard/IkemenMobile, etc.
    base := "/storage/emulated/0/Android/data/com.ikemenmobile/files"

    // Log via Android logcat
    {
        msg := C.CString("SDL_main(): entering Go, calling RunGameAndroid")
        C.ikm_log(msg)
        C.free(unsafe.Pointer(msg))
    }

    // Optional: also log to stdout (often ends up in logcat too)
    fmt.Println("[Ikemen] SDL_main(): base path =", base)

    // Let the Go-side Android entrypoint handle:
    //   - LockOSThread
    //   - chdir(base)
    //   - RunGame()
    RunGameAndroid(base)

    {
        msg := C.CString("SDL_main(): RunGameAndroid returned, exiting")
        C.ikm_log(msg)
        C.free(unsafe.Pointer(msg))
    }

    // SDL thread will terminate after this.
    return 0
}