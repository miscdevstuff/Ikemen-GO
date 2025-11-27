//go:build android

package main

import "C"

//export Java_com_ikemenmobile_MainActivity_runIkemen
func Java_com_ikemenmobile_MainActivity_runIkemen(env *C.void, clazz *C.void) {
    // We run the game loop in a new goroutine to avoid blocking the JNI thread permanently
    // (though for a game loop, blocking might be intended depending on the threading model, 
    // usually SDL handles its own thread).
    go RunGame()
}
