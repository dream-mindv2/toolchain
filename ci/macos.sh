#!/bin/sh
# One macOS toolchain tarball, on Apple silicon. Homebrew's LLVM, libffi and
# OpenSSL are linked in from their archives (DREAM_SELF_CONTAINED), so the VM
# needs nothing a Mac does not have; the last step checks that, as the Linux
# build does, by what `otool -L` says it loads.
#
#   sh ci/macos.sh VERSION
set -eu
version=$1
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
jobs=${JOBS:-$(sysctl -n hw.ncpu)}
brew install llvm libffi openssl@3 ninja >/dev/null
llvm=$(brew --prefix llvm)
ffi=$(brew --prefix libffi)
ssl=$(brew --prefix openssl@3)

cmake -S . -B build/vm -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib -DDREAM_VERSION="$version" \
    -DDREAM_SELF_CONTAINED=ON -DDREAM_ENABLE_JIT=ON -DDREAM_LLVM_CONFIG="$llvm/bin/llvm-config" \
    -DDREAM_FFI_INCLUDE="$ffi/include" -DDREAM_FFI_LIB="$ffi/lib/libffi.a" \
    -DOPENSSL_ROOT_DIR="$ssl" -DOPENSSL_USE_STATIC_LIBS=TRUE -DDREAM_BUILD_TESTS=OFF
cmake --build build/vm --parallel "$jobs"
cmake --install build/vm --prefix build/stage

for f in build/stage/bin/dream build/stage/lib/libdream.0.1.dylib; do
    extra=$(otool -L "$f" | tail -n +2 | awk '{print $1}' | grep -v -E '^(/usr/lib/|/System/)|libdream' || true)
    if [ -n "$extra" ]; then
        echo "$f needs libraries a Mac may not have:" >&2
        echo "$extra" >&2
        exit 1
    fi
done

sh ci/images.sh "$version" build/stage/bin/dream
DREAM=$root/build/stage/bin/dream build/stage/bin/dream build/mind pack tarball --package-version "$version"
