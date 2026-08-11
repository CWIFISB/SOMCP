#!/usr/bin/env bash
set -e

# build-lief.sh — Linux version of build-lief.ps1
# Cross-compiles LIEF static archive for one Android ABI with CMake.

ABI="${1:-arm64-v8a}"
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_HOME}/ndk/29.0.14206865}"
SRC_DIR="third_party/lief-src"
BUILD_DIR="third_party/lief-build/$ABI"

if [ ! -d "$SRC_DIR" ]; then
    echo "[build-lief] LIEF source not found at '$SRC_DIR' — run 'git submodule update --init third_party/lief-src'"
    exit 1
fi

if [ ! -f "$NDK_ROOT/build/cmake/android.toolchain.cmake" ]; then
    echo "[build-lief] NDK toolchain not found at $NDK_ROOT/build/cmake/android.toolchain.cmake"
    exit 1
fi

TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[build-lief] CMake configure for $ABI ..."
cmake -G "Ninja" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-26 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLIEF_TESTS=OFF \
    -DLIEF_EXAMPLES=OFF \
    -DLIEF_DOC=OFF \
    -DLIEF_PYTHON_API=OFF \
    -DLIEF_RUST_API=OFF \
    -DLIEF_C_API=ON \
    -DLIEF_ELF=ON \
    -DLIEF_PE=ON \
    -DLIEF_MACHO=ON \
    -DLIEF_DEX=ON \
    -DLIEF_ART=ON \
    -DLIEF_OAT=ON \
    -DLIEF_VDEX=ON \
    -DLIEF_DEBUG_INFO=OFF \
    -DLIEF_OBJC=OFF \
    -DLIEF_DYLD_SHARED_CACHE=OFF \
    -DLIEF_ASM=OFF \
    -DLIEF_LOGGING=ON \
    -DLIEF_ENABLE_JSON=ON \
    -DLIEF_USE_CCACHE=OFF \
    -DLIEF_DISABLE_FROZEN=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR" \
    -B "$BUILD_DIR" \
    -S "$SRC_DIR"

echo "[build-lief] Building LIEF for $ABI ..."
cmake --build "$BUILD_DIR" --parallel 4

echo "[build-lief] Installing LIEF for $ABI ..."
cmake --install "$BUILD_DIR"

echo "[build-lief] DONE - $ABI"
