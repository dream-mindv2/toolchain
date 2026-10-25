#!/bin/sh
# One Linux toolchain tarball, built in an AlmaLinux 9 container: glibc 2.34,
# as old as any distribution still supported that is worth building for --
# RHEL, Rocky and Alma 9 -- so the VM it builds runs on every newer one too
# (Ubuntu 22.04 on, Debian 12 on, Fedora, Arch, NixOS): a program built
# against an older glibc runs on a newer one, never the reverse. Debian 11,
# which was older still, has left security support.
#
# Everything the VM uses but the C library is linked in
# (DREAM_SELF_CONTAINED): libffi and OpenSSL built here from source as
# position-independent archives, LLVM's static archives for the JIT, zlib and
# zstd under them, and the C++ runtime. The last step checks that nothing
# else crept in, since a shared library a user's system lacks is a VM that
# will not start.
#
#   sh ci/linux.sh VERSION        from a checkout with its submodules
#
# Writes dist/dream-VERSION-linux-MACHINE.tar.gz.
set -eu
version=$1
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
jobs=${JOBS:-$(nproc)}
deps=$root/build/deps
mkdir -p "$deps" build/src

dnf install -y -q dnf-plugins-core epel-release >/dev/null
dnf config-manager --set-enabled crb
dnf install -y -q gcc-c++ make cmake ninja-build perl git python3 file which \
    zlib-devel zlib-static libstdc++-static llvm-devel llvm-static gcc-toolset-14 >/dev/null
# AlmaLinux builds its LLVM with a newer GCC than its own (which the static
# archives show, needing that GCC's libstdc++), so the VM is built with the
# same toolset: newer C++ features from its libstdc++_nonshared.a, the rest
# from the system's, and still only glibc 2.34 at run time.
. /opt/rh/gcc-toolset-14/enable

fetch() { # URL SHA256 FILE
    curl -fsSL "$1" -o "build/src/$3"
    echo "$2  build/src/$3" | sha256sum -c - >/dev/null
}
# OpenSSL 3.5 is the long-term release; its sum, and zstd's, are the ones they publish.
fetch https://github.com/libffi/libffi/releases/download/v3.8.0/libffi-3.8.0.tar.gz \
    7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4 libffi.tar.gz
fetch https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz \
    603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a openssl.tar.gz
# LLVM is built with zstd, and AlmaLinux packages no archive of it.
fetch https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz \
    eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3 zstd.tar.gz

(cd build/src && tar -xzf libffi.tar.gz && cd libffi-3.8.0 \
    && ./configure --prefix="$deps" --libdir="$deps/lib" --disable-multi-os-directory --disable-shared --enable-static --with-pic --disable-docs >/dev/null \
    && make -j"$jobs" >/dev/null && make install >/dev/null)
(cd build/src && tar -xzf openssl.tar.gz && cd openssl-3.5.9 \
    && ./Configure --prefix="$deps" --libdir=lib no-shared no-tests no-module no-docs -fPIC >/dev/null \
    && make -j"$jobs" >/dev/null && make install_sw >/dev/null)

(cd build/src && tar -xzf zstd.tar.gz && cd zstd-1.5.7/lib \
    && make -j"$jobs" libzstd.a CFLAGS='-O2 -fPIC' >/dev/null && make install-static install-includes PREFIX="$deps" >/dev/null)

cmake -S . -B build/vm -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib \
    -DDREAM_SELF_CONTAINED=ON -DDREAM_ENABLE_JIT=ON -DDREAM_LLVM_CONFIG=/usr/bin/llvm-config \
    -DDREAM_FFI_INCLUDE="$deps/include" -DDREAM_FFI_LIB="$deps/lib/libffi.a" \
    -DOPENSSL_ROOT_DIR="$deps" -DOPENSSL_USE_STATIC_LIBS=TRUE -DCMAKE_PREFIX_PATH="$deps" -DDREAM_BUILD_TESTS=OFF
cmake --build build/vm --parallel "$jobs"
cmake --install build/vm --prefix build/stage

# Only the C library: anything else is a library the user's system may lack.
for f in build/stage/bin/dream build/stage/lib/libdream.so.0.1; do
    extra=$(ldd "$f" | awk '{print $1}' | grep -v -E '^(linux-vdso|linux-gate)\.so|^lib(c|m|dl|pthread|rt)\.so\.[0-9]+$|^/lib.*/ld-linux|^libdream\.so' || true)
    if [ -n "$extra" ]; then
        echo "$f needs libraries a user's system may not have:" >&2
        echo "$extra" >&2
        exit 1
    fi
done

sh ci/images.sh "$version" build/stage/bin/dream
DREAM=$root/build/stage/bin/dream build/stage/bin/dream build/mind pack tarball --package-version "$version"
