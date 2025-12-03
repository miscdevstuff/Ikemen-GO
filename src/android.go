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
    argcGo := int(argc)
    argvSlice := unsafe.Slice(argv, argcGo)

    // Fallback if Java didn't pass anything
    base := "/storage/emulated/0/Android/data/com.ikemenmobile/files"
    if argcGo > 1 && argvSlice[1] != nil {
        base = C.GoString(argvSlice[1])
    }

    // Log via Android logcat
    {
        msg := C.CString("SDL_main(): entering Go, base=" + base)
        C.ikm_log(msg)
        C.free(unsafe.Pointer(msg))
    }

    // Also log to stdout (shows up under "E/Go" in logcat)
    fmt.Println("[Ikemen] SDL_main(): base path =", base)

    // Hand off to Go-side Android entrypoint
    RunGameAndroid(base)

    {
        msg := C.CString("SDL_main(): RunGameAndroid returned, exiting")
        C.ikm_log(msg)
        C.free(unsafe.Pointer(msg))
    }

    return 0
}