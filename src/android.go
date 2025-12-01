//go:build android

package main

/*
#include <jni.h>
#include <stdlib.h>
#include <string.h>

// Duplicate a Java string into a newly-allocated C string (UTF-8)
static char* ikm_dup_jstring(JNIEnv* env, jstring js) {
    if (!js) return NULL;
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
    "fmt"
    "unsafe"
)

//export Java_com_ikemenmobile_IkemenNative_runIkemen
func Java_com_ikemenmobile_IkemenNative_runIkemen(
    env *C.JNIEnv,
    thiz C.jobject,
    basePath C.jstring,
) {
    cStr := C.ikm_dup_jstring(env, basePath)
    var goBase string
    if cStr != nil {
        goBase = C.GoString(cStr)
        C.free(unsafe.Pointer(cStr))
    }
	// Very verbose debug trace
	println("[Ikemen JNI] Java_com_ikemenmobile_IkemenNative_runIkemen: ENTER")

    fmt.Println("[Ikemen JNI] Java_com_ikemenmobile_IkemenNative_runIkemen: basePath =", goBase)

    // Hand over to the Android-specific entrypoint in Go.
    RunGameAndroid(goBase)

    println("[Ikemen JNI] Java_com_ikemenmobile_IkemenNative_runIkemen: EXIT (RunGameAndroid returned)")
}