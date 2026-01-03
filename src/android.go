//go:build android

package main

/*
#include <jni.h>
#include <stdlib.h>
#include <stdio.h>
#include <android/log.h>
#include <unistd.h>
#include <pthread.h>

static int pfd[2];
static pthread_t thr;
static const char *TAG = "IkemenGoStd";
static FILE *log_fp = NULL;

// FIX 1: Added parameter name 'arg' to fix C23 warning
static void *thread_func(void* arg) {
    ssize_t rdsz;
    char buf[2048]; // Large buffer for shader code
    while((rdsz = read(pfd[0], buf, sizeof buf - 1)) > 0) {
        if(buf[rdsz - 1] == '\n') --rdsz;
        buf[rdsz] = 0;  // Null-terminate

        // 1. Send to Logcat (Live Debugging)
        __android_log_write(ANDROID_LOG_INFO, TAG, buf);

        // 2. Write to File (Saved Debugging)
        if(log_fp) {
            fprintf(log_fp, "%s\n", buf);
            fflush(log_fp); // Ensure it saves immediately
        }
    }
    return 0;
}

// FIX 2: Added 'static' keyword to prevent "duplicate symbol" linker error
static int start_logger(const char* app_name, const char* file_path) {
    TAG = app_name;

    // Open log file if path provided
    if (file_path) {
        log_fp = fopen(file_path, "w");
    }

    // Unbuffer stdout/stderr to capture crashes
    setvbuf(stdout, 0, _IOLBF, 0);
    setvbuf(stderr, 0, _IONBF, 0);

    // Create pipe
    if(pipe(pfd) == -1) return -1;
    
    // Redirect stdout (1) and stderr (2) to pipe
    dup2(pfd[1], 1);
    dup2(pfd[1], 2);

    // Start reading thread
    if(pthread_create(&thr, 0, thread_func, 0) == -1) return -1;
    pthread_detach(thr);
    return 0;
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
	// 1. Get Base Path from Env
	base := os.Getenv("IKEMEN_PATH")
	if base == "" {
		base = "/storage/emulated/0/IkemenMobile"
	}

    // 2. Initialize Dual Logging (Logcat + File)
    // Logs will be saved to /storage/emulated/0/IkemenMobile/ikemen_go_logs.txt
    logPath := filepath.Join(base, "ikemen_go_logs.txt")
    
    cAppName := C.CString("IkemenGo")
    cLogPath := C.CString(logPath)
    
    C.start_logger(cAppName, cLogPath)
    
    C.free(unsafe.Pointer(cAppName))
    C.free(unsafe.Pointer(cLogPath))

	// 3. Log Startup
	fmt.Printf("SDL_main(): Logging started. Saving to: %s\n", logPath)

	// 4. Switch Working Directory
	if err := os.Chdir(base); err != nil {
         fmt.Printf("SDL_main(): Failed to Chdir: %v\n", err)
    }
    
    // 5. Ensure TMPDIR exists
    if tmp := os.Getenv("TMPDIR"); tmp != "" {
        os.MkdirAll(tmp, 0755)
    }

	// 6. Start Engine
	RunGameAndroid(base)

	return 0
}
