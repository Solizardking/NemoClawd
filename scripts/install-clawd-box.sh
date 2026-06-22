#!/usr/bin/env bash
# Install the clawd-box CLI binary. Supports Linux and macOS (x86_64 and aarch64).

set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS/$ARCH" in
  Darwin/x86_64|Darwin/amd64)   ASSET="clawd-box-x86_64-apple-darwin.tar.gz" ;;
  Darwin/aarch64|Darwin/arm64)  ASSET="clawd-box-aarch64-apple-darwin.tar.gz" ;;
  Linux/x86_64|Linux/amd64)     ASSET="clawd-box-x86_64-unknown-linux-musl.tar.gz" ;;
  Linux/aarch64|Linux/arm64)    ASSET="clawd-box-aarch64-unknown-linux-musl.tar.gz" ;;
  *) echo "Unsupported platform: $OS/$ARCH"; exit 1 ;;
esac

tmpdir="$(mktemp -d)"
curl -fsSL "https://github.com/8bitlabs/clawd-box/releases/latest/download/$ASSET" \
  -o "$tmpdir/clawd-box.tar.gz"
tar xzf "$tmpdir/clawd-box.tar.gz" -C "$tmpdir"

if [ -w /usr/local/bin ]; then
  install -m 755 "$tmpdir/clawd-box" /usr/local/bin/clawd-box
else
  sudo install -m 755 "$tmpdir/clawd-box" /usr/local/bin/clawd-box
fi

rm -rf "$tmpdir"
echo "clawd-box $(clawd-box --version 2>&1 || echo 'installed')"
