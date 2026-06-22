#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Install the NVIDIA OpenShell CLI using the upstream installer.
# Set OPENSHELL_VERSION to pin a release or use the upstream dev channel.

set -euo pipefail

if command -v openshell >/dev/null 2>&1; then
  echo "openshell $(openshell --version 2>&1 || echo 'installed')"
  exit 0
fi

curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh

if ! command -v openshell >/dev/null 2>&1; then
  npm_bin="$(npm config get prefix 2>/dev/null)/bin" || true
  if [ -n "${npm_bin:-}" ] && [ -x "$npm_bin/openshell" ]; then
    export PATH="$npm_bin:$PATH"
  fi
fi

command -v openshell >/dev/null 2>&1 || {
  echo "openshell installer completed, but openshell is not on PATH" >&2
  exit 1
}

echo "openshell $(openshell --version 2>&1 || echo 'installed')"
