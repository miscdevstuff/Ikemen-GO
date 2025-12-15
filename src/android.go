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
	// Priority: Env Var (from Java) > Argv (from SDL) > Fallback
	base = os.Getenv("IKEMEN_PATH")
	
	if base == "" && argcGo > 1 && argvSlice[1] != nil {
		base = C.GoString(argvSlice[1])
	}

	if base == "" {
		base = "/storage/emulated/0/Android/data/com.ikemenmobile/files"
	}

	// 2. Setup TMPDIR to be basepath/tmp
	// We strictly use the 'tmp' folder inside our game directory to match motif.go logic.
	tmpDir := filepath.Join(base, "tmp")
	
	// Force creation of the temp directory.
	err := os.MkdirAll(tmpDir, 0755)

	// Force the entire Go runtime to use this safe directory for any os.TempDir() calls
	os.Setenv("TMPDIR", tmpDir)

	// 3. Logging
	msg := C.CString(fmt.Sprintf("SDL_main(): Launching. Base: %s, TMPDIR: %s, MkdirErr: %v", base, tmpDir, err))
	C.ikm_log(msg)
	C.free(unsafe.Pointer(msg))

	// 4. Start Engine
	RunGameAndroid(base)

	return 0
}