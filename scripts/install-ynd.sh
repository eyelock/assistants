#!/usr/bin/env bash
# Install the `ynd` (and `ynh`) binaries from a pinned eyelock/ynh GitHub
# release into $BIN_DIR (default: /usr/local/bin), after checking the archive
# against the release's checksums.txt. Requires `curl` and `sha256sum` or
# `shasum`.
#
# The version is pinned below (DEFAULT_YND_VERSION) and moves only by a
# reviewed change to this file, never by "latest".
#
# Usage:
#   scripts/install-ynd.sh                    # pinned release, /usr/local/bin
#   BIN_DIR=$HOME/.local/bin scripts/install-ynd.sh
#   YND_VERSION=v0.1.2 scripts/install-ynd.sh # another release, still verified
#   YND_BASE_URL=file:///dir scripts/install-ynd.sh  # test seam: a directory
#                                             # laid out as <base>/<tag>/<asset>

set -euo pipefail

DEFAULT_YND_VERSION="v0.17.0"

REPO="eyelock/ynh"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
VERSION="${YND_VERSION:-$DEFAULT_YND_VERSION}"
BASE_URL="${YND_BASE_URL:-https://github.com/$REPO/releases/download}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "unsupported arch: $arch" >&2; exit 1 ;;
esac

ver_no_v="${VERSION#v}"
asset="ynh_${ver_no_v}_${os}_${arch}.tar.gz"
url="$BASE_URL/$VERSION/$asset"
sums_url="$BASE_URL/$VERSION/checksums.txt"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "downloading $asset ($VERSION)"
curl -fsSL "$url" -o "$tmp/$asset"
curl -fsSL "$sums_url" -o "$tmp/checksums.txt"

expected=$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1; exit }' "$tmp/checksums.txt")
if [ -z "$expected" ]; then
  echo "no checksum for $asset in checksums.txt ($VERSION)" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$tmp/$asset" | awk '{print $1}')
else
  actual=$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')
fi
if [ "$actual" != "$expected" ]; then
  echo "checksum mismatch for $asset: expected $expected, got $actual" >&2
  exit 1
fi
echo "checksum ok ($asset)"
tar -xzf "$tmp/$asset" -C "$tmp"

mkdir -p "$BIN_DIR"
for bin in ynd ynh; do
  if [ -f "$tmp/$bin" ]; then
    install -m 0755 "$tmp/$bin" "$BIN_DIR/$bin"
    echo "installed $BIN_DIR/$bin"
  fi
done

"$BIN_DIR/ynd" --version || true
