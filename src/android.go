//go:build android

package main

/*
#include <jni.h>
*/
import "C"

//export Java_com_ikemenmobile_IkemenNative_runIkemen
func Java_com_ikemenmobile_IkemenNative_runIkemen(
	env *C.JNIEnv,
	thiz C.jobject,
	basePath C.jstring,
) {
	// Very verbose debug trace
	println("[Ikemen JNI] Java_com_ikemenmobile_IkemenNative_runIkemen: ENTER")

	// NOTE: for now we still ignore basePath and use existing logic in RunGameAndroid.
	RunGameAndroid()

	println("[Ikemen JNI] Java_com_ikemenmobile_IkemenNative_runIkemen: EXIT (RunGameAndroid returned)")
}