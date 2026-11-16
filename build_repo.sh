#!/usr/bin/env bash
# build_repo.sh DEBS SITE - lay out a signed apt repository in SITE from the
# .deb files in DEBS. The private key comes from $APT_SIGNING_KEY (armored);
# it must be the key whose public half is secretspace.asc, or the build fails.
# Needs dpkg-deb, apt-ftparchive (apt-utils), gpg and gpgv.
set -euo pipefail
debs=$1 site=$2
here=$(cd "$(dirname "$0")" && pwd)
SUITE=stable
ARCHES="all amd64 arm64"     # the packages are Architecture: all

rm -rf "$site"; mkdir -p "$site"
site=$(cd "$site" && pwd)

# -- the packages: pool/main/<first letter>/<package>/ ---------------------
for deb in "$debs"/*.deb; do
    pkg=$(dpkg-deb -f "$deb" Package)
    mkdir -p "$site/pool/main/${pkg:0:1}/$pkg"
    cp "$deb" "$site/pool/main/${pkg:0:1}/$pkg/"
done

# -- the indexes ------------------------------------------------------------
cd "$site"
for arch in $ARCHES; do
    dir="dists/$SUITE/main/binary-$arch"
    mkdir -p "$dir"
    apt-ftparchive packages pool > "$dir/Packages"
    gzip -9kn "$dir/Packages"
done
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=SecretSpace \
    -o APT::FTPArchive::Release::Label=SecretSpace \
    -o APT::FTPArchive::Release::Suite=$SUITE \
    -o APT::FTPArchive::Release::Codename=$SUITE \
    -o "APT::FTPArchive::Release::Architectures=$ARCHES" \
    -o APT::FTPArchive::Release::Components=main \
    -o "APT::FTPArchive::Release::Description=SecretSpace packages" \
    release "dists/$SUITE" > /tmp/Release
mv /tmp/Release "dists/$SUITE/Release"

# -- the signature ----------------------------------------------------------
export GNUPGHOME=$(mktemp -d)
trap 'rm -rf "$GNUPGHOME"' EXIT
printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --quiet --import
fpr=$(gpg --batch --with-colons --show-keys "$here/secretspace.asc" |
      awk -F: '/^fpr/{print $10; exit}')
gpg --batch --yes --pinentry-mode loopback --passphrase '' --local-user "$fpr" \
    --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
gpg --batch --yes --pinentry-mode loopback --passphrase '' --local-user "$fpr" \
    --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

# Prove it with the published public key only, as apt will.
gpg --batch --dearmor -o "$site/secretspace.gpg" < "$here/secretspace.asc"
cp "$here/secretspace.asc" "$site/secretspace.asc"
gpgv --keyring "$site/secretspace.gpg" "dists/$SUITE/InRelease"
gpgv --keyring "$site/secretspace.gpg" "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

# -- a page for people who open the address in a browser --------------------
packages=$(grep -h '^Package:\|^Version:' "dists/$SUITE/main/binary-all/Packages" |
           paste - - | sed 's/Package: \(.*\)\tVersion: \(.*\)/<li><code>\1<\/code> \2<\/li>/')
touch .nojekyll
cat > index.html <<EOF
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SecretSpace apt repository</title>
<style>
:root{--bg:#fff;--fg:#1b1d22;--muted:#5d6470;--code:#f2f4f7}
@media (prefers-color-scheme:dark){:root{--bg:#15161a;--fg:#eceef2;--muted:#9aa1ad;--code:#1f2127}}
body{background:var(--bg);color:var(--fg);font:16px/1.55 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 16px}
pre,code{background:var(--code);border-radius:6px}pre{padding:12px;overflow-x:auto}code{padding:1px 4px}
p.m{color:var(--muted)}
</style></head><body>
<h1>SecretSpace apt repository</h1>
<p>Packages of <a href="https://github.com/usermaneGermane/SecretSpace-Client-Linux">SecretSpace for Linux</a>
(<code>secretspace</code>) and <a href="https://github.com/usermaneGermane/SecretSpace-Server-Linux">SecretSpace Server</a>
(<code>secretspace-server</code>) for Ubuntu 22.04 or newer and Debian 12 or newer, signed with the key below.</p>
<pre>sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://usermanegermane.github.io/SecretSpace-apt/secretspace.gpg \\
  | sudo tee /etc/apt/keyrings/secretspace.gpg &gt; /dev/null
echo "deb [signed-by=/etc/apt/keyrings/secretspace.gpg] https://usermanegermane.github.io/SecretSpace-apt stable main" \\
  | sudo tee /etc/apt/sources.list.d/secretspace.list
sudo apt update
sudo apt install secretspace          # or: secretspace-server</pre>
<p>On a fresh Ubuntu, if apt says <code>python3-tk</code>, <code>python3-argon2</code> or
<code>python3-pil.imagetk</code> is not installable: run <code>sudo apt update</code>, then
<code>sudo add-apt-repository universe</code> and <code>sudo apt update</code>, and install again.</p>
<p>Signing key fingerprint: <code>$fpr</code></p>
<h2>Packages</h2><ul>$packages</ul>
<p class="m">Built $(date -u +%Y-%m-%d) from the Latest GitHub releases.</p>
</body></html>
EOF
find "$site" -type f | sort
