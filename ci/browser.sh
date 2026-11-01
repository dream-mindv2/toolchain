#!/bin/sh
# The browser VM: the VM compiled to WebAssembly, which every std.graphics
# application carries as its page's runtime. It is one build for every
# platform -- a wasm file runs wherever a browser does, and Emscripten is not
# something a user should need to make a window -- so the release builds it
# once and each tarball ships the same two files at lib/dream/browser/, where
# `mind build` looks for them (`runtime!` in mind/tool/src/graphics.dr).
#
# Emscripten is pinned, as the other dependencies are, because a new one can
# change what the VM's C++ compiles to with nothing here having moved. An
# `emcmake` already on the PATH is used instead, for a machine that has its
# own: `nix-shell -p emscripten cmake --run 'sh ci/browser.sh'`.
#
#   sh ci/browser.sh
#
# Writes build/browser/dream-browser.mjs and dream-browser.wasm.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
emscripten=5.0.6
mkdir -p build
if ! command -v emcmake >/dev/null 2>&1; then
    git clone -q --depth 1 --branch "$emscripten" https://github.com/emscripten-core/emsdk build/emsdk
    build/emsdk/emsdk install "$emscripten" >/dev/null
    build/emsdk/emsdk activate "$emscripten" >/dev/null
    # Sourced from its own directory: under dash, the runners' sh, the script
    # has no other way to learn where it is.
    cd build/emsdk
    EMSDK_QUIET=1 . ./emsdk_env.sh
    cd "$root"
fi
jobs=${JOBS:-$(nproc)}
emcmake cmake -S dream/browser -B build/browser-vm -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build/browser-vm --parallel "$jobs"
mkdir -p build/browser
cp build/browser-vm/dream-browser.mjs build/browser-vm/dream-browser.wasm build/browser/

# That it instantiates, and has the entry points the page's worker calls: a
# link that lost an export still writes both files.
node --input-type=module -e '
    import { pathToFileURL } from "node:url";
    const { default: create } = await import(pathToFileURL(process.argv[1]));
    const vm = await create({ print: () => {}, printErr: () => {} });
    for (const name of ["load", "tick", "delay", "event", "exit_code", "dispose"])
        if (typeof vm[`_dream_browser_${name}`] !== "function") throw new Error(`no export: ${name}`);
' "$PWD/build/browser/dream-browser.mjs"
