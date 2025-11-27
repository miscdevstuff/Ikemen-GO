#!/bin/bash
set -e

NDK_VER="27.1.12297006"
if [ -z "$ANDROID_NDK_HOME" ]; then
	export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi
API_LEVEL=24
ABI=arm64-v8a
JNI_DIR="$(pwd)/app_android/android/app/src/main/jniLibs/$ABI"
mkdir -p "$JNI_DIR"

echo "=== Building GLU ==="
cd external/glu
rm -rf build_android

# Configure (Linking against the gl4es we just built)
cmake -B build_android \
	-DANDROID_ABI=$ABI \
	-DANDROID_PLATFORM=android-$API_LEVEL \
	-DANDROID_NDK=$ANDROID_NDK_HOME \
	-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
	-DGL_LIBRARY="$JNI_DIR/libGL_es4.so" \
	-DGL_INCLUDE_DIR="$(pwd)/../gl4es/include" \
	-DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build_android -- -j$(nproc)

# Copy
cp build_android/libGLU.so "$JNI_DIR/"
echo "Success: libGLU.so created."
