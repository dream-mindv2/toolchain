# The Dream toolchain

One release of the whole of [Dream](https://github.com/Custards1/dream) -- the
VM, the compiler, `mind`, the language server and the standard library -- at
versions that belong together.

## Install

```sh
curl -fsSL https://dream-mindv2.github.io/toolchain/install.sh | sh
```

It installs the latest toolchain into `~/.mindv2/toolchains/VERSION` (or
`$MINDV2_HOME`), makes it the one in use, and links `dream` and `mind` into
`~/.local/bin` (`$XDG_BIN_HOME`; `$PREFIX/bin` on Termux), the standard
place for a user's programs, which most Linux distributions already have on
`PATH`. Only where it is not -- macOS, NixOS by default -- does it add it,
through `~/.mindv2/env` sourced from your shell's startup files (and fish's
`conf.d`); `MIND_NO_MODIFY_PATH=1` leaves those alone and says what to add.
The tarball is checked against the SHA-256 written into the script before
anything is unpacked.

There are toolchains for **Linux** (x86_64 and aarch64, any distribution with
glibc 2.34 or newer: RHEL 9, Ubuntu 22.04, Debian 12 and on), **macOS** (Apple
silicon) and **Android** (aarch64, under Termux). The VM depends on nothing
but the system's C library, and the JIT is on everywhere but Android: `dream
--no-jit` runs a program interpreted.

**NixOS**, and any Linux without the usual `/lib64/ld-linux-x86-64.so.2`: the
installer runs the VM through the loader the system's own programs use, so it
works with or without nix-ld. Or use the flake:

```sh
nix profile install github:dream-mindv2/toolchain   # or: nix run github:dream-mindv2/toolchain
```

## Versions

```sh
mind toolchain list                # what is installed, and which is in use
mind toolchain list --available    # every release
mind toolchain install 0.3.0       # another version, beside the others
mind toolchain use 0.2.0           # switch, installing it first if need be
mind toolchain update              # the latest, and use it
mind toolchain remove 0.2.0
mind toolchain which
```

A project can pin the toolchain it is built with, in its `mind.toml`:

```toml
[toolchain]
version = "0.3.0"
```

and `mind`, run in that project, hands the command to that toolchain --
installing it if it is not here. Every toolchain `mind` installs is checked
against `SHA256SUMS` and the release's signature (`toolchain.sig`) by a key
`mind` was built trusting; the design is at the head of
[mind/tool/src/toolchain.dr](https://github.com/dream-mindv2/mind/blob/main/src/toolchain.dr).

## Building it

The components are submodules here, at the paths the Dream workspace has
them:

```sh
git clone --recurse-submodules https://github.com/dream-mindv2/toolchain
```

`ci/linux.sh`, `ci/macos.sh` and `ci/android.sh` each build one platform's
tarball, as the release does; `nix build` builds the flake's.

## Releasing

Move the submodules to the commits the release is of, commit, and push a tag
`vX.Y.Z`. The release workflow builds every platform, publishes the release,
and updates the site: `install.sh` and `channel.json`, the versions `mind
toolchain` offers. Pages deploys from GitHub Actions.

`mind toolchain` installs only a release whose `SHA256SUMS` is signed by the
key it trusts. With that key as the `TOOLCHAIN_SIGNING_KEY` secret (a hex
seed, as `mind keygen` writes one) the workflow signs; without it, sign the
published sums where the key is. `ci/sign-release.sh` does that: it waits for
the tag's build to finish, refuses unless it succeeded, then downloads
`SHA256SUMS`, signs it and uploads `toolchain.sig`:

```sh
git tag -a vX.Y.Z -m "Dream X.Y.Z" && git push origin main vX.Y.Z
sh ci/sign-release.sh vX.Y.Z
```
