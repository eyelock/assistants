#!/usr/bin/env bash
# Install the `ynd` (and `ynh`) binaries from the latest eyelock/ynh GitHub
# release into $BIN_DIR (default: /usr/local/bin). Requires `gh` or `curl`.
#
# Usage:
#   scripts/install-ynd.sh                    # latest release, /usr/local/bin
#   BIN_DIR=$HOME/.local/bin scripts/install-ynd.sh
#   YND_VERSION=v0.1.2 scripts/install-ynd.sh

set -euo pipefail

REPO="eyelock/ynh"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
VERSION="${YND_VERSION:-}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "unsupported arch: $arch" >&2; exit 1 ;;
esac

if [ -z "$VERSION" ]; then
  if command -v gh >/dev/null 2>&1; then
    VERSION=$(gh release view -R "$REPO" --json tagName --jq .tagName)
  else
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  fi
fi

ver_no_v="${VERSION#v}"
asset="ynh_${ver_no_v}_${os}_${arch}.tar.gz"
url="https://github.com/$REPO/releases/download/$VERSION/$asset"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "downloading $asset ($VERSION)"
curl -fsSL "$url" -o "$tmp/$asset"
tar -xzf "$tmp/$asset" -C "$tmp"

mkdir -p "$BIN_DIR"
for bin in ynd ynh; do
  if [ -f "$tmp/$bin" ]; then
    install -m 0755 "$tmp/$bin" "$BIN_DIR/$bin"
    echo "installed $BIN_DIR/$bin"
  fi
done

"$BIN_DIR/ynd" --version || true
