//go:build android

package main

/*
#include <jni.h>
*/
import "C"

// Java side:
//   package com.ikemenmobile
//   object IkemenNative {
//       init { System.loadLibrary("ikemen") }
//       external fun runIkemen(basePath: String)
//   }
//
// JNI signature: void com.ikemenmobile.IkemenNative.runIkemen(String)
//
// C-side name that the JVM looks for:
//   Java_com_ikemenmobile_IkemenNative_runIkemen
//
// C signature:
//   void Java_com_ikemenmobile_IkemenNative_runIkemen(
//       JNIEnv* env,
//       jobject thiz,
//       jstring basePath
//   );

//export Java_com_ikemenmobile_IkemenNative_runIkemen
func Java_com_ikemenmobile_IkemenNative_runIkemen(
	env *C.JNIEnv,
	thiz C.jobject,
	basePath C.jstring,
) {
	// For now we ignore basePath here; RunGame() uses its own logic.
	// If we want to wire it through later, we can add a small C helper
	// to convert jstring -> Go string and store it into sys.xxxx.
	RunGame()
}