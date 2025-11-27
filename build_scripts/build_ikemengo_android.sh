#!/bin/bash
set -e

NDK_VER="27.1.12297006"
if [ -z "$ANDROID_NDK_HOME" ]; then
	export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi

API_LEVEL=24
ARCH=aarch64
ABI=arm64-v8a
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
JNI_DIR="$(pwd)/app_android/android/app/src/main/jniLibs/$ABI"
mkdir -p "$JNI_DIR"

echo "=== Building Ikemen GO Core ==="

# Setup Cross-Compiler
export CC="$TOOLCHAIN/bin/${ARCH}-linux-android${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${ARCH}-linux-android${API_LEVEL}-clang++"
export CGO_ENABLED=1
export GOOS=android
export GOARCH=arm64

# Link against dependencies
export CGO_CFLAGS="-I$(pwd)/external/gl4es/include -I$(pwd)/external/glu/include -DANDROID -O3"
export CGO_LDFLAGS="-L$JNI_DIR -lGL_es4 -lGLU -landroid -llog"

# Build Shared Library
go build -tags android \
	-buildmode=c-shared \
	-trimpath \
	-ldflags="-s -w -X 'main.Version=Android-CI'" \
	-o "$JNI_DIR/libikemen.so" \
	./src

echo "Success: libikemen.so created."
ls -lh "$JNI_DIR"
