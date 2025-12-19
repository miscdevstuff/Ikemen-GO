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
	"os"
	"unsafe"
)

//export SDL_main
func SDL_main(argc C.int, argv **C.char) C.int {
	// 1. Get Base Path from Env (Set by MainActivity)
	base := os.Getenv("IKEMEN_PATH")
	
	if base == "" {
		// Fallback hardcoded just in case
		base = "/storage/emulated/0/IkemenMobile"
	}

	// 2. Logging
	msg := C.CString(fmt.Sprintf("SDL_main(): Starting. CWD: %s", base))
	C.ikm_log(msg)
	C.free(unsafe.Pointer(msg))

	// 3. Switch Working Directory
	// This ensures all file operations happen inside IkemenMobile/
	if err := os.Chdir(base); err != nil {
         msgErr := C.CString(fmt.Sprintf("SDL_main(): Failed to Chdir: %v", err))
         C.ikm_log(msgErr)
         C.free(unsafe.Pointer(msgErr))
    }
    
    // 4. Ensure TMPDIR exists on Go side (Safety)
    if tmp := os.Getenv("TMPDIR"); tmp != "" {
        os.MkdirAll(tmp, 0755)
    }

	// 5. Start Engine
	RunGameAndroid(base)

	return 0
}