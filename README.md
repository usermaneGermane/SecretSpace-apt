# SecretSpace apt repository

The apt repository for [SecretSpace for Linux](https://github.com/usermaneGermane/SecretSpace-Client-Linux)
(package `secretspace`) and [SecretSpace Server](https://github.com/usermaneGermane/SecretSpace-Server-Linux)
(package `secretspace-server`),
published on GitHub Pages at **https://usermanegermane.github.io/SecretSpace-apt**.
With it, `sudo apt install secretspace` installs SecretSpace and `sudo apt upgrade`
keeps it up to date with everything else.

## Using it

On Ubuntu 22.04 or newer, or Debian 12 or newer:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://usermanegermane.github.io/SecretSpace-apt/secretspace.gpg \
  | sudo tee /etc/apt/keyrings/secretspace.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/secretspace.gpg] https://usermanegermane.github.io/SecretSpace-apt stable main" \
  | sudo tee /etc/apt/sources.list.d/secretspace.list
sudo apt update
sudo apt install secretspace          # the app
sudo apt install secretspace-server   # the sync server
```

The key is trusted for this repository only (`signed-by`), not for the rest of
your system's sources. Its fingerprint:

```
40CD 8C8D 27FF 73CC 5F66  2DA3 6259 A726 E44C B898
```

To stop using it: `sudo rm /etc/apt/sources.list.d/secretspace.list /etc/apt/keyrings/secretspace.gpg`.
The installed package stays until `sudo apt remove secretspace` (your vaults stay either way).

## What the signature is for

apt downloads the package list (`InRelease`) and then the packages. `InRelease`
holds the SHA-256 of every package list, which holds the SHA-256 of every
`.deb`, and it is signed with the key above. apt refuses a list whose
signature does not match that key, and a package whose checksum does not
match the list. So whoever can change the files on the web server — or sits
between you and it — still cannot get apt to install anything that was not
signed with this key. The key signs nothing else.

## How it is built

Nothing is built here: the `.deb` files are the ones published on the
*Latest* release of each repository in [`repos.txt`](repos.txt), checked
against that release's `SHA256SUMS.txt`.

[`.github/workflows/publish.yml`](.github/workflows/publish.yml) runs on a push
to `main`, by hand (*Actions → publish → Run workflow*, after a release), and
once a day, so a new release reaches apt within a day without anyone pressing
anything. It:

1. downloads the packages ([`fetch.sh`](fetch.sh));
2. lays out `pool/` and `dists/stable/`, writes the indexes with
   `apt-ftparchive`, signs `InRelease` and `Release.gpg` with the private key
   from the `APT_SIGNING_KEY` secret, and checks both signatures with the
   public key in this repository alone ([`build_repo.sh`](build_repo.sh)). A
   secret that is not the key of [`secretspace.asc`](secretspace.asc) fails
   here;
3. publishes it on GitHub Pages; the site is not kept in git;
4. in a clean `ubuntu:24.04` container, adds the repository from the
   published address exactly as above and installs `secretspace`.

A pull request runs step 1 and 2 only.

## The key

An Ed25519 signing key with no expiry and no passphrase, made for this
repository only. The private key is in the `APT_SIGNING_KEY` secret and in
an offline copy kept by the owner, with its revocation certificate.

If it is ever exposed: make a new key, replace `secretspace.asc` and the
secret, publish the revocation, and tell users to fetch the new
`secretspace.gpg` (the commands above, again).

## License

GPL-3.0, the same as SecretSpace. See [LICENSE](LICENSE).
