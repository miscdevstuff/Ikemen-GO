//go:build android

package main

/*
#include <jni.h>
#include <stdlib.h>
#include <string.h>

// Check if a jstring is NULL-equivalent
static int jstr_is_null(JNIEnv* env, jstring js) {
    return (*env)->IsSameObject(env, js, NULL);
}

// Duplicate a Java string into malloc'd C string (UTF-8)
static char* jstr_dup(JNIEnv* env, jstring js) {
    if (jstr_is_null(env, js)) return NULL;
    const char* utf = (*env)->GetStringUTFChars(env, js, 0);
    if (!utf) return NULL;
    size_t len = strlen(utf);
    char* out = (char*)malloc(len + 1);
    if (!out) {
        (*env)->ReleaseStringUTFChars(env, js, utf);
        return NULL;
    }
    memcpy(out, utf, len + 1);
    (*env)->ReleaseStringUTFChars(env, js, utf);
    return out;
}
*/
import "C"

import (
    "log"
    "os"
    "runtime"
    "unsafe"
)

var androidBasePath string

//export Java_com_ikemenmobile_IkemenNative_runIkemen
func Java_com_ikemenmobile_IkemenNative_runIkemen(
    env *C.JNIEnv,
    thiz C.jobject,
    basePath C.jstring,
) {
    runtime.LockOSThread()
    defer runtime.UnlockOSThread()

    // Convert jstring → Go string safely
    cpath := C.jstr_dup(env, basePath)
    if cpath != nil {
        androidBasePath = C.GoString(cpath)
        C.free(unsafe.Pointer(cpath))
        log.Printf("[Ikemen] basePath = %s", androidBasePath)
    } else {
        log.Printf("[Ikemen] basePath is NULL; using default")
    }

    if androidBasePath != "" {
        if err := os.Chdir(androidBasePath); err != nil {
            log.Printf("[Ikemen] chdir failed: %v", err)
        } else {
            log.Printf("[Ikemen] chdir OK → %s", androidBasePath)
        }
    }

    log.Printf("[Ikemen] RunGame() starting…")
    RunGame()
    log.Printf("[Ikemen] RunGame() finished")
}