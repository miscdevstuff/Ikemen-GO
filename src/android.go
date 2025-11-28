//go:build android

package main

/*
#include <jni.h>
*/
import "C"

// Java signature: public static native void runIkemen();

//export Java_com_ikemenmobile_MainActivity_runIkemen
func Java_com_ikemenmobile_MainActivity_runIkemen(env *C.JNIEnv, clazz C.jclass) {
	// We ignore env and clazz for now: all game logic is internal to Ikemen GO.
	// Just start the engine. You already made main() skip RunGame() on Android.
	go RunGame()
}
