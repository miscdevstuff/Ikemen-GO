#!/bin/bash
# Android build script for Ikemen GO core (shared lib for JNI)
# - Cross-builds FFmpeg (configure), libxmp (cmake), SDL2 (cmake), SDL2_mixer (cmake) with NDK
# - Links them + gl4es into libikemen.so
# - Outputs to app_android/android/app/src/main/jniLibs/<ABI>

set -euo pipefail

# --------------------------------------------------------------------
# Basic config
# --------------------------------------------------------------------
NDK_VER_DEFAULT="27.1.12297006"

# You can override from the environment, eg:
#   ANDROID_ABI=arm64-v8a ANDROID_API=24 bash build_scripts/build_ikemengo_android.sh
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${ANDROID_API:-27}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

case "$ANDROID_ABI" in
	arm64-v8a)
		ANDROID_ARCH="aarch64"
		ANDROID_TRIPLE="aarch64-linux-android"
		GOARCH_ANDROID="arm64"
		;;
	armeabi-v7a)
		ANDROID_ARCH="arm"
		ANDROID_TRIPLE="armv7a-linux-androideabi"
		GOARCH_ANDROID="arm"
		;;
	*)
		echo "ERROR: Unsupported ANDROID_ABI='$ANDROID_ABI' (supported: arm64-v8a, armeabi-v7a)" >&2
		exit 1
		;;
esac

# Where we install Android-built dependencies
ANDROID_PREFIX_ROOT="$REPO_ROOT/build/android/$ANDROID_ABI"
FFMPEG_PREFIX="$ANDROID_PREFIX_ROOT/ffmpeg"
LIBXMP_PREFIX="$ANDROID_PREFIX_ROOT/libxmp"
SDL2_PREFIX="$ANDROID_PREFIX_ROOT/sdl2"
GL4ES_PREFIX="$ANDROID_PREFIX_ROOT/gl4es"

# Download cache
DL_DIR="$REPO_ROOT/build/downloads"

# Where assets need to be copied to
ASSETS_DIR="$REPO_ROOT/app_android/android/app/src/main/assets"
# Where the final .so goes (for Gradle / APK)
JNI_DIR="$REPO_ROOT/app_android/android/app/src/main/jniLibs/$ANDROID_ABI"
mkdir -p "$JNI_DIR"

APP_VERSION="${APP_VERSION:-android-dev}"
APP_BUILDTIME="${APP_BUILDTIME:-$(date '+%Y.%m.%d')}"

echo "=== Ikemen GO Android build ==="
echo "  ABI        : $ANDROID_ABI"
echo "  API Level  : $ANDROID_API"
echo "  Triple     : $ANDROID_TRIPLE"
echo "  Prefix root: $ANDROID_PREFIX_ROOT"
echo "  JNI dir    : $JNI_DIR"

# --------------------------------------------------------------------
# Helper: ensure basic host tools
# --------------------------------------------------------------------
ensure_host_deps() {
	local missing=()
	need() { command -v "$1" > /dev/null 2>&1 || missing+=("$1"); }

	need wget
	need tar
	need git
	need pkg-config
	need make
	need cmake
	need nasm
	need yasm
	need go
	need zip

	if ((${#missing[@]})); then
		echo "ERROR: Missing host tools: ${missing[*]}" >&2
		echo "Install on Debian/Ubuntu (example):" >&2
		echo "  sudo apt update && sudo apt install -y ${missing[*]}" >&2
		exit 1
	fi
}

# --------------------------------------------------------------------
# NDK / toolchain
# --------------------------------------------------------------------
setup_ndk() {
	if [[ -z ${ANDROID_NDK_HOME:-} ]]; then
		if [[ -n ${ANDROID_HOME:-} && -d "$ANDROID_HOME/ndk/$NDK_VER_DEFAULT" ]]; then
			export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER_DEFAULT"
		elif [[ -n ${ANDROID_HOME:-} && -d "$ANDROID_HOME/ndk" ]]; then
			# fallback: first NDK found
			export ANDROID_NDK_HOME="$(find "$ANDROID_HOME/ndk" -maxdepth 1 -mindepth 1 -type d | head -n1)"
		fi
	fi

	if [[ -z ${ANDROID_NDK_HOME:-} || ! -d $ANDROID_NDK_HOME ]]; then
		echo "ERROR: ANDROID_NDK_HOME not set or invalid. Set ANDROID_NDK_HOME or ANDROID_HOME with NDK installed." >&2
		exit 1
	fi

	ANDROID_TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
	if [[ ! -d $ANDROID_TOOLCHAIN ]]; then
		echo "ERROR: NDK LLVM toolchain not found at: $ANDROID_TOOLCHAIN" >&2
		exit 1
	fi

	export ANDROID_NDK_HOME
	export ANDROID_TOOLCHAIN
	export ANDROID_SYSROOT="$ANDROID_TOOLCHAIN/sysroot"

	# CMake Toolchain File (Standard NDK location)
	export CMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"

	# Compiler / binutils
	export CC="$ANDROID_TOOLCHAIN/bin/${ANDROID_TRIPLE}${ANDROID_API}-clang"
	export CXX="$ANDROID_TOOLCHAIN/bin/${ANDROID_TRIPLE}${ANDROID_API}-clang++"
	export AR="$ANDROID_TOOLCHAIN/bin/llvm-ar"
	export RANLIB="$ANDROID_TOOLCHAIN/bin/llvm-ranlib"
	export STRIP="$ANDROID_TOOLCHAIN/bin/llvm-strip"

	# Ensure toolchain bin comes first
	export PATH="$ANDROID_TOOLCHAIN/bin:$PATH"

	# Shims for tools some configure scripts expect
	local strip_shim="$ANDROID_TOOLCHAIN/bin/${ANDROID_TRIPLE}-strip"
	if [[ ! -x $strip_shim ]]; then
		cat > "$strip_shim" << EOF
#!/bin/sh
exec "$ANDROID_TOOLCHAIN/bin/llvm-strip" "\$@"
EOF
		chmod +x "$strip_shim"
	fi

	local nm_shim="$ANDROID_TOOLCHAIN/bin/${ANDROID_TRIPLE}-nm"
	if [[ ! -x $nm_shim ]]; then
		cat > "$nm_shim" << EOF
#!/bin/sh
exec "$ANDROID_TOOLCHAIN/bin/llvm-nm" "\$@"
EOF
		chmod +x "$nm_shim"
	fi

	local pc_shim="$ANDROID_TOOLCHAIN/bin/${ANDROID_TRIPLE}-pkg-config"
	if [[ ! -x $pc_shim ]]; then
		cat > "$pc_shim" << 'EOF'
#!/bin/sh
exec pkg-config "$@"
EOF
		chmod +x "$pc_shim"
	fi

	echo "Using NDK: $ANDROID_NDK_HOME"
	echo "Toolchain: $ANDROID_TOOLCHAIN"
}

# --------------------------------------------------------------------
# Download helper (with caching)
# --------------------------------------------------------------------
download_and_extract() {
	local url="$1"
	local dest_dir="$2"
	local filename
	filename="$(basename "$url")"

	mkdir -p "$DL_DIR"
	local archive="$DL_DIR/$filename"

	if [[ ! -f $archive ]]; then
		echo "==> Downloading $url"
		wget -O "$archive" "$url"
	else
		echo "==> Using cached $archive"
	fi

	rm -rf "$dest_dir"
	mkdir -p "$dest_dir"

	case "$archive" in
		*.tar.xz) tar -xJf "$archive" -C "$dest_dir" --strip-components=1 ;;
		*.tar.gz) tar -xzf "$archive" -C "$dest_dir" --strip-components=1 ;;
		*.zip) unzip -q "$archive" -d "$dest_dir" &&
			mv "$dest_dir"/*/* "$dest_dir" 2> /dev/null || true ;;
		*)
			echo "ERROR: Unknown archive type for $archive" >&2
			exit 1
			;;
	esac
}

# --------------------------------------------------------------------
# FFmpeg build (Configure - Standard)
# --------------------------------------------------------------------
build_ffmpeg_android() {
	local srcdir="$REPO_ROOT/build/ffmpeg-src"
	local url="https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz"

	echo "==> Building FFmpeg for Android (prefix=$FFMPEG_PREFIX)"
	download_and_extract "$url" "$srcdir"

	pushd "$srcdir" > /dev/null

	# NOTE: We use "$STRIP" (llvm-strip) instead of relying on toolchain path detection
	./configure \
		--prefix="$FFMPEG_PREFIX" \
		--enable-cross-compile \
		--target-os=android \
		--arch=$ANDROID_ARCH \
		--cross-prefix=${ANDROID_TRIPLE}- \
		--cc=$CC --cxx=$CXX --ar=$AR --ranlib=$RANLIB \
		--strip="$STRIP" \
		--sysroot=$ANDROID_SYSROOT \
		--enable-shared --disable-static \
		--disable-programs --disable-doc --disable-debug \
		--disable-everything --disable-autodetect \
		--enable-avformat --enable-avcodec --enable-avutil \
		--enable-swresample --enable-swscale --enable-avfilter \
		--enable-protocol=file \
		--enable-demuxer=matroska,webm \
		--enable-decoder=vp8,vp9,opus,vorbis \
		--extra-cflags="-fPIC -DANDROID -I$ANDROID_SYSROOT/usr/include" \
		--extra-ldflags="-L$ANDROID_SYSROOT/usr/lib/$ANDROID_TRIPLE/$ANDROID_API"

	make -j"$(getconf _NPROCESSORS_ONLN || echo 2)"
	make install

	echo "==> FFmpeg installed to: $FFMPEG_PREFIX"
	ls -R "$FFMPEG_PREFIX" || true
	popd > /dev/null
}

# --------------------------------------------------------------------
# libxmp build (CMake - Migrated)
# --------------------------------------------------------------------
build_libxmp_android() {
	local srcdir="$REPO_ROOT/build/libxmp-src"

	echo "==> Building libxmp for Android (CMake)"
	rm -rf "$srcdir"
	mkdir -p "$(dirname "$srcdir")"
	git clone --depth 1 --single-branch https://github.com/cmatsuoka/libxmp.git "$srcdir"

	# Important: CMAKE_POSITION_INDEPENDENT_CODE=ON is required for linking static libs into shared libs
	cmake -S "$srcdir" -B "$srcdir/build_android" \
		-DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
		-DANDROID_ABI="$ANDROID_ABI" \
		-DANDROID_PLATFORM="$ANDROID_API" \
		-DCMAKE_INSTALL_PREFIX="$LIBXMP_PREFIX" \
		-DBUILD_SHARED=OFF \
		-DBUILD_STATIC=ON \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-G "Unix Makefiles"

	cmake --build "$srcdir/build_android" --target install -- -j4

	echo "==> libxmp installed to: $LIBXMP_PREFIX"
	ls -R "$LIBXMP_PREFIX" || true
}

# --------------------------------------------------------------------
# SDL2 build (CMake - Migrated)
# --------------------------------------------------------------------
build_sdl2_android() {
	local srcdir="$REPO_ROOT/build/sdl2-src"
	local url="https://github.com/libsdl-org/SDL/releases/download/release-2.32.8/SDL2-2.32.8.tar.gz"

	echo "==> Building SDL2 for Android (CMake)"
	download_and_extract "$url" "$srcdir"

	# -DSDL_OPENSLES=OFF : Disables compilation of SDL_openslES.c
	# -DSDL_AAUDIO=ON    : Enables the AAudio driver
	cmake -S "$srcdir" -B "$srcdir/build_android" \
		-DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
		-DANDROID_ABI="$ANDROID_ABI" \
		-DANDROID_PLATFORM="$ANDROID_API" \
		-DCMAKE_INSTALL_PREFIX="$SDL2_PREFIX" \
		-DSDL_SHARED=ON \
		-DSDL_STATIC=OFF \
		-DSDL_OPENSLES=OFF \
		-DSDL_AAUDIO=ON \
		-DSDL_HIDAPI=OFF \
		-DSDL_TEST=OFF \
		-G "Unix Makefiles"

	cmake --build "$srcdir/build_android" --target install -- -j4

	# Legacy compat: copy libSDL2-2.0.so to libSDL2.so if needed
	if [[ -f "$SDL2_PREFIX/lib/libSDL2-2.0.so" && ! -f "$SDL2_PREFIX/lib/libSDL2.so" ]]; then
		cp -L "$SDL2_PREFIX/lib/libSDL2-2.0.so" "$SDL2_PREFIX/lib/libSDL2.so"
	fi

	echo "==> SDL2 installed to: $SDL2_PREFIX"
	ls -R "$SDL2_PREFIX" || true
}

# --------------------------------------------------------------------
# SDL2_mixer build (CMake - Migrated)
# --------------------------------------------------------------------
build_sdl2_mixer_android() {
	local srcdir="$REPO_ROOT/build/sdl2-mixer-src"
	local url="https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.0/SDL2_mixer-2.8.0.tar.gz"

	echo "==> Building SDL2_mixer for Android (CMake)"
	download_and_extract "$url" "$srcdir"

	# Ensure CMake can find libxmp via pkg-config
	export PKG_CONFIG_PATH="$LIBXMP_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

	# FIX: Add CMAKE_FIND_ROOT_PATH so find_package(libxmp) works in cross-compile
	# CMake defaults to searching only inside the NDK sysroot when cross-compiling.
	# We must explicitly add our build prefix to the search path.
	cmake -S "$srcdir" -B "$srcdir/build_android" \
		-DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" \
		-DANDROID_ABI="$ANDROID_ABI" \
		-DANDROID_PLATFORM="$ANDROID_API" \
		-DCMAKE_INSTALL_PREFIX="$SDL2_PREFIX" \
		-DCMAKE_FIND_ROOT_PATH="$LIBXMP_PREFIX" \
		-DSDL2MIXER_VENDORED=OFF \
		-DSDL2MIXER_OPUS=OFF \
		-DSDL2MIXER_WAVE=OFF \
		-DSDL2MIXER_WAVPACK=OFF \
		-DSDL2MIXER_FLAC_DRFLAC=ON \
		-DSDL2MIXER_MP3_DRMP3=ON \
		-DSDL2MIXER_MOD_XMP=ON \
		-DSDL2MIXER_MOD_XMP_SHARED=OFF \
		-DSDL2MIXER_MIDI=OFF \
		-DSDL2MIXER_MIDI_FLUIDSYNTH=OFF \
		-DSDL2MIXER_MIDI_TIMIDITY=OFF \
		-Dlibxmp_LIBRARY="$LIBXMP_PREFIX/lib/libxmp.a" \
		-Dlibxmp_INCLUDE_PATH="$LIBXMP_PREFIX/include" \
		-DSDL2_DIR="$SDL2_PREFIX/lib/cmake/SDL2" \
		-G "Unix Makefiles"

	cmake --build "$srcdir/build_android" --target install -- -j4
}

# --------------------------------------------------------------------
# Bundle native shared libs into jniLibs
# --------------------------------------------------------------------
bundle_shared_libs_into_jni() {
	echo "==> Copying shared librari to $JNI_DIR"
	mkdir -p "$JNI_DIR"

	if [[ -d "$FFMPEG_PREFIX/lib" ]]; then
		cp -L "$FFMPEG_PREFIX"/lib/*.so "$JNI_DIR/" 2> /dev/null || true
	fi
	if [[ -d "$SDL2_PREFIX/lib" ]]; then
		cp -L "$SDL2_PREFIX"/lib/*.so "$JNI_DIR/" 2> /dev/null || true
	fi

	ls -lh "$JNI_DIR" || true
}

prepare_ikemen_assets_zip() {
	echo "==> Preparing ikemen_assets.zip"

	local TEMP_ASSETS_ROOT="$REPO_ROOT/build/ikemen_assets_tmp"
	#local SCREENPACK_DIR="$REPO_ROOT/build/elecbyte_screenpack"
	#local SCREENPACK_REPO="https://github.com/ikemen-engine/Ikemen_GO-Elecbyte-Screenpack.git"

	# Clean old temp + assets dir
	rm -rf "$ASSETS_DIR" "$TEMP_ASSETS_ROOT"
	mkdir -p "$ASSETS_DIR" "$TEMP_ASSETS_ROOT"

	# 1) Copy engine's own assets (from this repo)
	#    This matches what a desktop build expects at runtime.
	if [[ -d "$REPO_ROOT/data" ]]; then
		echo "  - Copying engine data/ from main repo"
		cp -a "$REPO_ROOT/data" "$TEMP_ASSETS_ROOT/data"
	fi
	if [[ -d "$REPO_ROOT/external" ]]; then
		echo "  - Copying engine external/ from main repo"
		cp -a "$REPO_ROOT/external" "$TEMP_ASSETS_ROOT/external"
	fi
	if [[ -d "$REPO_ROOT/font" ]]; then
		echo "  - Copying engine font/ from main repo"
		cp -a "$REPO_ROOT/font" "$TEMP_ASSETS_ROOT/font"
	fi

	# 2) Shallow-clone Elecbyte screenpack and merge its content
	# if [[ ! -d "$SCREENPACK_DIR/.git" ]]; then
	# 		echo "  - Cloning Elecbyte screenpack (shallow)"
	# 		rm -rf "$SCREENPACK_DIR"
	# 		git clone --depth=1 "$SCREENPACK_REPO" "$SCREENPACK_DIR"
	# 	else
	# 		echo "  - Updating existing Elecbyte screenpack clone"
	# 		(cd "$SCREENPACK_DIR" && git fetch --depth=1 origin && git reset --hard origin/HEAD) || true
	# 	fi

	# 3) Copy screenpack assets on top (they may override some defaults,
	#    which is fine and matches desktop usage).
	#    We keep it simple and copy the whole tree.
	#	echo "  - Merging Elecbyte screenpack assets"
	#	cp -a "$SCREENPACK_DIR/"* "$TEMP_ASSETS_ROOT/"

	# 4) Build a single zip containing everything at TEMP_ASSETS_ROOT/.
	local ZIP_PATH="$ASSETS_DIR/assets.zip"
	echo "  - Creating ZIP at: $ZIP_PATH"
	(cd "$TEMP_ASSETS_ROOT" && zip -r "$ZIP_PATH" .)

	echo "==> assets.zip built, contents:"
	ls -lh "$ZIP_PATH"
}

android_app_prepare() {
	# ToDo: Check expected *.so exist with proper names in jniLibs

	# Remove sysmlinks from jnilibs, they are not preserved
	find "$JNI_DIR" -type l -delete

	# Remove headers from jnilibs
	find "$JNI_DIR" -name '*.h' -delete

	# Remove unnecessary/duplicate files
	# if [[ -f "$JNI_DIR/libSDL2.so" ]]; then
	#	rm "$JNI_DIR/libSDL2.so"
	# fi

	echo "==> jniLibs contents after prepare:"
	ls -l "$JNI_DIR"

	# Build assets.zip into app/src/main/assets
	prepare_ikemen_assets_zip

	echo "==> Assets copied:"
	ls -l "$ASSETS_DIR"
}

# --------------------------------------------------------------------
# Build Ikemen core as libikemen.so
# --------------------------------------------------------------------
build_ikemen_android() {
	echo "=== Building Ikemen core (Go → c-shared) ==="

	# 1) Cross-build deps
	build_ffmpeg_android
	build_libxmp_android
	build_sdl2_android
	build_sdl2_mixer_android

	# 2) Make Android-built libs visible to pkg-config
	export PKG_CONFIG_PATH="$FFMPEG_PREFIX/lib/pkgconfig:$SDL2_PREFIX/lib/pkgconfig:$GL4ES_PREFIX/lib/pkgconfig:$LIBXMP_PREFIX/lib/pkgconfig"
	local pc="${PKG_CONFIG:-pkg-config}"

	# Flags for FFmpeg + libxmp + SDL2 (same idea as build/build.sh)
	local deps_cflags
	local deps_libs
	# Fixed: Removed 'gl' (doesn't exist on Android) and added SDL2_mixer
	deps_cflags="$($pc --cflags libavformat libavcodec libavutil libswscale libswresample libavfilter SDL2_mixer sdl2)"
	deps_libs="$($pc --libs libavformat libavcodec libavutil libswscale libswresample libavfilter SDL2_mixer sdl2)"

	# 3) Go / CGO setup
	export GOOS=android
	export GOARCH="$GOARCH_ANDROID"
	export CGO_ENABLED=1
	export GOEXPERIMENT=arenas

	# C flags: deps + gl4es headers + libxmp headers + Android
	X11_Mocks="-DDisplay=void -DXVisualInfo=void -DXID=long -DWindow=long -DPixmap=long -DFont=long -DBool=int -DStatus=int -DColormap=long"
	export CGO_CFLAGS="${deps_cflags} -I$GL4ES_PREFIX/include -I$LIBXMP_PREFIX/include -DANDROID -fPIC -DNOX11 -DGLX_STUBS -DUSE_ES2 -DUSE_EGL -DNO_GBM -DOBOE_ENABLE_AAUDIO=1 $X11_Mocks"

	# C++ flags
	export CGO_CXXFLAGS="-DANDROID -fPIC -DOBOE_ENABLE_AAUDIO=1"

	# Linker flags: NO -lOpenSLES
	# We rely on SDL2 being built with -DSDL_OPENSLES=OFF via CMake.
	export CGO_LDFLAGS="${deps_libs} -L$FFMPEG_PREFIX/lib -L$SDL2_PREFIX/lib -L$GL4ES_PREFIX/lib -L$LIBXMP_PREFIX/lib $LIBXMP_PREFIX/lib/libxmp.a $GL4ES_PREFIX/lib/libGL.a -landroid -llog -lm -ldl -lEGL -lGLESv2 -lvulkan -laaudio"

	# 4) Build as c-shared for JNI, add `-s -w` in ldflags to strip debug symbols
	local out_so="$JNI_DIR/libikemen.so"
	go build -tags android \
		-buildmode=c-shared \
		-trimpath \
		-ldflags="-X 'main.Version=${APP_VERSION}' -X 'main.BuildTime=${APP_BUILDTIME}' -s -w" \
		-o "$out_so" \
		./src

	echo "==> Built: $out_so"
}

# --------------------------------------------------------------------
# main
# --------------------------------------------------------------------
main() {
	# Ensure build_gl4es.sh was run before this
	if [[ ! -f "$GL4ES_PREFIX/lib/libGL.a" ]]; then
		echo "ERROR: gl4es static lib not found at $GL4ES_PREFIX/lib/libGL.a" >&2
		echo "Run: bash build_scripts/build_gl4es.sh first." >&2
		exit 1
	fi

	ensure_host_deps
	setup_ndk
	build_ikemen_android
	bundle_shared_libs_into_jni
	android_app_prepare

	echo "=== Android core build complete ==="
	echo "  JNI libs in: $JNI_DIR"
}

main "$@"
