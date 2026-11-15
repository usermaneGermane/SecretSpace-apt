#!/usr/bin/env bash
# fetch.sh DIR - download the .deb of the Latest release of every repository
# in repos.txt into DIR, and check each against that release's SHA256SUMS.txt.
# Needs gh (GH_TOKEN set) and sha256sum.
set -euo pipefail
out=$1
here=$(cd "$(dirname "$0")" && pwd)
rm -rf "$out"; mkdir -p "$out"

grep -v '^\s*#' "$here/repos.txt" | grep . | while read -r repo; do
    tag=$(gh release view -R "$repo" --json tagName -q .tagName)
    tmp=$(mktemp -d)
    gh release download "$tag" -R "$repo" -p '*.deb' -p 'SHA256SUMS.txt' -D "$tmp"
    ls "$tmp"/*.deb > /dev/null            # a Latest release with no .deb fails
    (cd "$tmp" && sha256sum -c --ignore-missing SHA256SUMS.txt)
    mv "$tmp"/*.deb "$out/"
    echo "$repo $tag"
done
ls -l "$out"
