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
	"path/filepath"
	"unsafe"
)

//export SDL_main
func SDL_main(argc C.int, argv **C.char) C.int {
	argcGo := int(argc)
	argvSlice := unsafe.Slice(argv, argcGo)

	// 1. Get Base Path
	var base string
	base = os.Getenv("IKEMEN_PATH")
	
	if base == "" && argcGo > 1 && argvSlice[1] != nil {
		base = C.GoString(argvSlice[1])
	}

	if base == "" {
		base = "/storage/emulated/0/Android/data/com.ikemenmobile/files"
	}

	// 2. Setup TMPDIR
	tmpDir := filepath.Join(base, "tmp")
	os.MkdirAll(tmpDir, 0755)
	os.Setenv("TMPDIR", tmpDir)

	// 3. Logging
	msg := C.CString(fmt.Sprintf("SDL_main(): Launching. Base: %s", base))
	C.ikm_log(msg)
	C.free(unsafe.Pointer(msg))

	// 4. Start Engine
	// This function will likely never return because RunGame calls os.Exit(0)
	RunGameAndroid(base)

	return 0
}