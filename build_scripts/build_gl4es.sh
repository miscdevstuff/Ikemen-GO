#!/bin/bash
set -e

# --- Configuration ---
NDK_VER="27.1.12297006"
if [ -z "$ANDROID_NDK_HOME" ]; then
	export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi

# Resolve repo root (one level above build_scripts)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
API_LEVEL="${ANDROID_API:-24}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
# Output directory for gl4es pkg-config module
GL4ES_PC_DIR="$REPO_ROOT/build/android/$ANDROID_ABI/gl4es"
# Output directory relative to repo root
JNI_DIR="$REPO_ROOT/app_android/android/app/src/main/jniLibs/$ANDROID_ABI"

mkdir -p "$JNI_DIR" "$GL4ES_PC_DIR"

echo "=== Building gl4es ==="
cd external/gl4es
rm -rf build_android

# Configure
cmake -B build_android \
	-DANDROID_ABI=$ANDROID_ABI \
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
find lib -name "libGL.so*" -exec cp {} "$JNI_DIR/libGL_es4.so" \;

if [ -f "$JNI_DIR/libGL_es4.so" ]; then
	echo "Success: libGL_es4.so created."
else
	echo "Error: libGL_es4.so was not created. Check CMake output."
	exit 1
fi

# Also expose this as a valid gl pkg-config module for ikemen-go android build
### Step 1: create a dummy `gl.pc` for gl4es
mkdir -p "$GL4ES_PC_DIR/lib/pkgconfig" "$GL4ES_PC_DIR/include"
cp -r include/* "$GL4ES_PC_DIR/include/"
cp "$JNI_DIR/libGL_es4.so" "$GL4ES_PC_DIR/lib/"

cat > $GL4ES_PC_DIR/lib/pkgconfig/gl.pc << 'EOF'
prefix=@GL4ES_PC_DIR@
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include

Name: gl
Description: OpenGL shim via gl4es for Ikemen GO Android
Version: 1.0.0
Libs: -L${libdir} -lGL_es4
Cflags: -I${includedir}
EOF

sed -e "s|@GL4ES_PC_DIR@|$GL4ES_PC_DIR|g" << 'EOF' > "$GL4ES_PC_DIR/lib/pkgconfig/gl.pc"
prefix=@GL4ES_PC_DIR@
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include

Name: gl
Description: OpenGL shim via gl4es for Ikemen GO Android
Version: 1.0.0
Libs: -L${libdir} -lGL_es4
Cflags: -I${includedir}
EOF

