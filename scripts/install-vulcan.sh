#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Install the official Vulcan CLI for Phoenix perpetual futures.

set -euo pipefail

INSTALL_DIR="${VULCAN_INSTALL_DIR:-$HOME/.local/bin}"

mkdir -p "$INSTALL_DIR"

if command -v vulcan >/dev/null 2>&1; then
  echo "[vulcan] already installed: $(vulcan version 2>&1 || echo unknown)"
  exit 0
fi

echo "[vulcan] installing to $INSTALL_DIR"
VULCAN_INSTALL_DIR="$INSTALL_DIR" \
  sh -c "$(curl -fsSL https://github.com/Ellipsis-Labs/vulcan-cli/releases/latest/download/install.sh)"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) export PATH="$INSTALL_DIR:$PATH" ;;
esac

command -v vulcan >/dev/null 2>&1 || {
  echo "[vulcan] install finished but vulcan is not on PATH" >&2
  echo "[vulcan] add this to your shell: export PATH=\"$INSTALL_DIR:\$PATH\"" >&2
  exit 1
}

vulcan version
