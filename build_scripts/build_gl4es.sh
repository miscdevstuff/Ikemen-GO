#!/bin/bash
set -e

# --- Configuration ---
NDK_VER="27.1.12297006"
if [ -z "$ANDROID_NDK_HOME" ]; then
	export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi

API_LEVEL=24
ABI=arm64-v8a
# Output directory relative to repo root
JNI_DIR="$(pwd)/app_android/android/app/src/main/jniLibs/$ABI"
mkdir -p "$JNI_DIR"

echo "=== Building gl4es ==="
cd external/gl4es
rm -rf build_android

# Configure
cmake -B build_android \
	-DANDROID_ABI=$ABI \
	-DANDROID_PLATFORM=android-$API_LEVEL \
	-DANDROID_NDK=$ANDROID_NDK_HOME \
	-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
	-DDEFAULT_ES=2 \
	-DLIBGL_ES=2 \
	-DNO_X11=ON \
	-DNO_GBM=ON \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="-Wno-error=format-security" # Suppress format errors if any

# Build
cmake --build build_android -- -j$(nproc)

# Copy and Rename
# Note: gl4es might output libGL.so.1 or libGL.so. We grab the shared object.
echo "Copying library..."
find build_android -name "libGL.so*" -exec cp {} "$JNI_DIR/libGL_es4.so" \;

if [ -f "$JNI_DIR/libGL_es4.so" ]; then
	echo "Success: libGL_es4.so created."
else
	echo "Error: libGL_es4.so was not created. Check CMake output."
	exit 1
fi
