#!/bin/bash
set -e

# --- Configuration ---
NDK_VER="27.1.12297006"
if [ -z "$ANDROID_NDK_HOME" ]; then
	export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi
NDK_BUILD="$ANDROID_NDK_HOME/ndk-build"
if [ ! -x "$NDK_BUILD" ]; then
	echo "ERROR: ndk-build not found at $NDK_BUILD" >&2
	exit 1
fi

# Resolve repo root (one level above build_scripts)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
API_LEVEL="${ANDROID_API:-24}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
# Output directory for gl4es
GL4ES_PREFIX="$REPO_ROOT/build/android/$ANDROID_ABI/gl4es"

echo "=== Building gl4es ==="
cd "$REPO_ROOT/build/gl4es-src"
rm -rf build_android
mkdir -p build_android/obj build_android/libs

# Use gl4es' Android.mk to build a static libGL.a
"$NDK_BUILD" \
	NDK_PROJECT_PATH="$PWD" \
	APP_BUILD_SCRIPT="$PWD/Android.mk" \
	APP_ABI="$ANDROID_ABI" \
	APP_PLATFORM="android-$API_LEVEL" \
	NDK_OUT="$PWD/build_android/obj" \
	NDK_LIBS_OUT="$PWD/build_android/libs"

# For a BUILD_STATIC_LIBRARY target, ndk-build drops libGL.a under obj/local/<abi>/
GL_STATIC="$(find build_android -maxdepth 6 -path '*obj/local*' -name 'libGL.a' | head -n1 || true)"
if [ -z "$GL_STATIC" ]; then
	echo "ERROR: libGL.a not produced by gl4es ndk-build" >&2
	find build_android -maxdepth 8 -type f -name 'libGL*' || true
	exit 1
fi

echo "Found static gl4es archive: $GL_STATIC"

# Install to our gl4es dir
mkdir -p "$GL4ES_PREFIX/lib"
cp -L "$GL_STATIC" "$GL4ES_PREFIX/lib/libGL.a"
cp -r "$REPO_ROOT/build/gl4es-src/include" "$GL4ES_PREFIX/include"

echo "Installed static lib to: $GL4ES_PREFIX/lib/libGL.a"
echo "Headers installed under: $GL4ES_PREFIX/include"

echo "=== gl4es static build complete ==="

# Create a pkg-config file so "pkg-config gl" works (for go-gl/gl)
mkdir -p "$GL4ES_PREFIX/lib/pkgconfig"
cat > "$GL4ES_PREFIX/lib/pkgconfig/gl.pc" << EOF
prefix=$GL4ES_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: gl
Description: OpenGL via gl4es
Version: 1.0
Libs: -L\${libdir} -lGL
Cflags: -I\${includedir}
EOF

echo "Created pkg-config file: $GL4ES_PREFIX/lib/pkgconfig/gl.pc"
