#!/bin/sh
# The toolchain's images, made by the VM it ships: the compiler from its
# seed, then `mind` and the language server by that compiler; and the
# `toolchain.toml` that says which release they are, which `mind toolchain`
# reads (mind/tool/src/toolchain.dr) and which names each component's commit.
#
#   sh ci/images.sh VERSION VM
set -eu
version=$1
vm=$2
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
mkdir -p build
"$vm" dreams/bootstrap/dreams.dream -L mind -L . -o build/dreams.dream dreams/src/main.dr
"$vm" build/dreams.dream -L mind/std mind/tool/src/main.dr --shebang -o build/mind
"$vm" build/dreams.dream lucid/src/main.dr -L mind -L . -o build/lucid.dream
{
    echo "# The Dream toolchain $version: what 'mind toolchain' reads, and the"
    echo "# commit of each component it was built from."
    echo "version = \"$version\""
    for c in dream dreams mind/std mind/tool lucid; do
        echo "\"$c\" = \"$(git -C "$c" rev-parse HEAD 2>/dev/null || echo unknown)\""
    done
} > build/toolchain.toml
