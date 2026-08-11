#!/usr/bin/env bash
set -e

# build-rizin.sh — Linux version of build-rizin.ps1
# Cross-compiles Rizin static archives for one Android ABI using meson.

ABI="${1:-arm64-v8a}"
RIZIN_SRC="${2:-third_party/rizin-src}"
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_HOME}/ndk/29.0.14206865}"

if [ ! -d "$RIZIN_SRC/librz/include" ]; then
    echo "[build-rizin] Rizin source not found at '$RIZIN_SRC'. Cloning v0.10.0..."
    rm -rf "$RIZIN_SRC"
    git clone --depth 1 --branch v0.10.0 https://github.com/rizinorg/rizin.git "$RIZIN_SRC"
fi

if [ ! -d "$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin" ]; then
    echo "[build-rizin] ERROR: NDK root '$NDK_ROOT' has no linux-x86_64 llvm toolchain."
    exit 1
fi

NDK_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"

# Map ABI to compiler prefix
case "$ABI" in
    arm64-v8a)      TRIPLE="aarch64-linux-android"      ;;
    armeabi-v7a)    TRIPLE="armv7a-linux-androideabi"    ;;
    x86)            TRIPLE="i686-linux-android"          ;;
    x86_64)         TRIPLE="x86_64-linux-android"         ;;
    *)              echo "[build-rizin] Unknown ABI '$ABI'" ; exit 1 ;;
esac

BUILD_DIR="rizin-build/$ABI"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Generate meson cross file
cat > "$BUILD_DIR/cross-$ABI.ini" <<EOF
[binaries]
c = '$NDK_BIN/${TRIPLE}26-clang'
cpp = '$NDK_BIN/${TRIPLE}26-clang++'
ar = '$NDK_BIN/llvm-ar'
strip = '$NDK_BIN/llvm-strip'
ranlib = '$NDK_BIN/llvm-ranlib'
ld = '$NDK_BIN/ld.lld'
pkg-config = 'false'

[host_machine]
system = 'android'
cpu_family = '$([ "$ABI" = arm64-v8a ] && echo aarch64 || echo ${TRIPLE%%-*})'
cpu = '$([ "$ABI" = arm64-v8a ] && echo aarch64 || echo ${TRIPLE%%-*})'
endian = 'little'

[built-in options]
c_args = ['-fPIC', '-O2', '-fvisibility=hidden', '-ffunction-sections', '-fdata-sections']
cpp_args = ['-fPIC', '-O2', '-fvisibility=hidden', '-ffunction-sections', '-fdata-sections', '-std=c++17', '-fexceptions', '-frtti']
c_link_args = ['-Wl,--gc-sections', '-Wl,--icf=safe']
cpp_link_args = ['-Wl,--gc-sections', '-Wl,--icf=safe']
EOF

# Generate meson native file (Use host gcc/g++)
cat > "$BUILD_DIR/native-$ABI.ini" <<EOF
[binaries]
c = '/usr/bin/gcc'
cpp = '/usr/bin/g++'
ar = '/usr/bin/ar'
ld = '/usr/bin/ld'
pkg-config = 'false'

[built-in options]
c_args = ['-O2']
cpp_args = ['-O2', '-std=c++17']
c_std = 'c11'
cpp_std = 'c++17'
EOF

echo "[build-rizin] meson setup $BUILD_DIR ..."
meson setup "$BUILD_DIR" "$RIZIN_SRC" \
    --cross-file "$BUILD_DIR/cross-$ABI.ini" \
    --native-file "$BUILD_DIR/native-$ABI.ini" \
    -Dblob=true \
    -Dstatic_runtime=true \
    --default-library static \
    -Duse_sys_capstone=disabled \
    -Ddebugger=false \
    -Dsubprojects_check=false

echo "[build-rizin] meson compile ..."
meson compile -C "$BUILD_DIR"

echo "[build-rizin] DONE - $ABI archives at $BUILD_DIR"
