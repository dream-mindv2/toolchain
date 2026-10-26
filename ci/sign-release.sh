#!/bin/sh
# Sign a toolchain release once its build has published it:
#
#     sh ci/sign-release.sh v0.3.8
#
# The signing key is not a secret of this repository (README, "Releasing"),
# so this runs where the key is: it waits for the release workflow of the tag
# to finish, refuses unless it succeeded, downloads SHA256SUMS, signs it with
# `mind toolchain sign` and uploads toolchain.sig, without which `mind
# toolchain install` will not take the release.
set -eu
tag=${1:?usage: sh ci/sign-release.sh vX.Y.Z}
repo=dream-mindv2/toolchain
run=$(gh run list -R "$repo" --workflow release.yml --json databaseId,headBranch \
      -q "[.[] | select(.headBranch == \"$tag\")][0].databaseId")
[ -n "$run" ] || { echo "no release run for $tag" >&2; exit 1; }
echo "waiting for run $run ($tag)"
gh run watch "$run" -R "$repo" --exit-status >/dev/null || { echo "the $tag build did not succeed" >&2; exit 1; }
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
gh release download "$tag" -R "$repo" -p SHA256SUMS -D "$dir"
mind toolchain sign "$tag" "$dir/SHA256SUMS"
gh release upload "$tag" -R "$repo" "$dir/toolchain.sig" --clobber
echo "signed $tag"
