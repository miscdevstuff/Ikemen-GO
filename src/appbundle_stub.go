//go:build !darwin

package main

// macOS-only concept; on Android (and other platforms) just return false.
func isRunningInsideAppBundle(exePath string) bool {
    return false
}
