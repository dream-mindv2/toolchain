#!/bin/sh
# A toolchain tarball, used as someone who has just downloaded it would use
# it, on a machine that has nothing else of Dream's:
#
#     sh ci/smoke.sh dist/dream-0.3.8-linux-x86_64.tar.gz
#
# Run in clean containers of several distributions by the release workflow,
# before anything is published, so that a tarball which unpacks but cannot
# compile -- a missing standard library, a VM that will not start against an
# older C library, a compiler it cannot find -- never becomes a release. Each
# step is one a person takes: the VM says what it is, `mind doctor` finds
# nothing broken, and a new project builds and runs.
set -eu
tarball=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/dream" "$work/home"
tar -xzf "$tarball" -C "$work/dream" --strip-components 1
export HOME="$work/home" PATH="$work/dream/bin:$PATH"
unset MINDV2_PATH DREAM DREAMS 2>/dev/null || true

step() { printf '\n== %s\n' "$*"; }

step "dream --version"
version=$(dream --version)
printf '%s\n' "$version"
case "$version" in *"jit      LLVM"*) ;; *) echo "no JIT in this VM" >&2; exit 1 ;; esac
case "$(uname -s)" in
    Linux) case "$version" in *"self-contained"*) ;; *) echo "this VM is not self-contained" >&2; exit 1 ;; esac ;;
esac

step "mind doctor"
mind doctor

step "a new project"
cd "$work" && mind new hello >/dev/null && cd hello
out=$(mind run 2>&1)
printf '%s\n' "$out"
case "$out" in *"Hello from hello"*) ;; *) echo "the new project did not run" >&2; exit 1 ;; esac

step "passed"
