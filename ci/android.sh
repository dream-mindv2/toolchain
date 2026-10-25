#!/bin/sh
# The Android (aarch64) toolchain tarball, for Termux, cross-built with the
# NDK so a phone need not build the language itself.
#
# The VM is built by dream/android/build.sh -- libffi and OpenSSL as archives,
# the interpreter (Android has no JIT yet) -- and installed, which gives it the
# `$ORIGIN/../lib` it finds `libdream.so` and the NDK's C++ runtime by
# (checked below). The
# images are portable bytecode, so they are made by a VM built for this
# machine, which then packs the tarball for the phone.
#
#   ANDROID_NDK_ROOT=... sh ci/android.sh VERSION
set -eu
version=$1
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
jobs=${JOBS:-$(nproc)}
: "${ANDROID_NDK_ROOT:?set ANDROID_NDK_ROOT to an NDK r28 or newer}"
mkdir -p build/src

# A VM for this machine, to make the images and run the packager.
sudo apt-get install -y -q libffi-dev libssl-dev ninja-build >/dev/null
cmake -S . -B build/host -G Ninja -DCMAKE_BUILD_TYPE=Release -DDREAM_ENABLE_JIT=OFF -DDREAM_BUILD_TESTS=OFF
cmake --build build/host --parallel "$jobs"
sh ci/images.sh "$version" build/host/bin/dream

# The phone's VM.
curl -fsSL https://github.com/libffi/libffi/releases/download/v3.8.0/libffi-3.8.0.tar.gz -o build/src/libffi.tar.gz
echo "7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4  build/src/libffi.tar.gz" | sha256sum -c - >/dev/null
curl -fsSL https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz -o build/src/openssl.tar.gz
echo "603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a  build/src/openssl.tar.gz" | sha256sum -c - >/dev/null
(cd build/src && tar -xzf libffi.tar.gz && tar -xzf openssl.tar.gz)
JOBS=$jobs bash dream/android/build.sh arm64-v8a build/android build/src/libffi-3.8.0 build/src/openssl-3.5.9
cmake --install build/android/vm --prefix build/stage
cp build/android/dist/libc++_shared.so build/stage/lib/
# Bionic searches only its system directories and LD_LIBRARY_PATH unless the
# binary says otherwise, and CMake's Android module once dropped the runpath
# without a word: a phone then said `library "libdream.so" not found`.
for f in bin/dream:'$ORIGIN/../lib' lib/libdream.so:'$ORIGIN'; do
    readelf -d "build/stage/${f%%:*}" | grep -q "RUNPATH.*\[${f#*:}\]" ||
        { echo "build/stage/${f%%:*} has no RUNPATH ${f#*:}" >&2; exit 1; }
done

DREAM=$root/build/host/bin/dream build/host/bin/dream build/mind pack tarball \
    --package-version "$version" --os android --arch aarch64
