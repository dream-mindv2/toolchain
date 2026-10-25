#!/bin/sh
# The toolchain's site, as GitHub Pages serves it: install.sh, the latest
# release's -- the one-line install -- and channel.json, which `mind
# toolchain` reads for the versions there are, the latest, and where each
# file of a release is downloaded from. Every release is listed, newest
# first, from the releases this repository has.
#
#   sh ci/site.sh VERSION       after the release VERSION exists
set -eu
version=$1
repo=${GITHUB_REPOSITORY:-dream-mindv2/toolchain}
mkdir -p site
cp dist/install.sh site/install.sh
versions=$(gh release list -R "$repo" --limit 1000 --json tagName -q '.[].tagName' \
    | sed -n 's/^v//p' | sort -t . -k 1,1nr -k 2,2nr -k 3,3nr)
latest=$(printf '%s\n' "$versions" | head -n 1)
list=$(printf '%s\n' "$versions" | sed 's/.*/"&"/' | paste -sd , -)
cat > site/channel.json <<EOF
{
  "latest": "$latest",
  "versions": [$list],
  "download": "https://github.com/$repo/releases/download/v{version}/{file}"
}
EOF
cat > site/index.html <<EOF
<!doctype html>
<meta charset="utf-8">
<title>Dream toolchain</title>
<p>Install Dream $latest:</p>
<pre>curl -fsSL https://dream-mindv2.github.io/toolchain/install.sh | sh</pre>
<p>Then <code>mind toolchain list --available</code>, <code>install</code>, <code>use</code> and <code>update</code>.
See <a href="https://github.com/$repo">github.com/$repo</a>.</p>
EOF
echo "site for $version: latest $latest"
