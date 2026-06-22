#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Phoenix perpetual futures integration through the official Vulcan CLI.

set -euo pipefail

RPC_URL="${RPC_URL:-${SOLANA_RPC_URL:-${HELIUS_RPC_URL:-https://rpc.solanatracker.io/public}}}"
SOLANA_RPC_URL="${SOLANA_RPC_URL:-$RPC_URL}"
PHOENIX_API_URL="${PHOENIX_API_URL:-https://perp-api.phoenix.trade}"
VULCAN_DEFAULT_SLIPPAGE_BPS="${VULCAN_DEFAULT_SLIPPAGE_BPS:-50}"
export RPC_URL SOLANA_RPC_URL PHOENIX_API_URL

usage() {
  cat <<'EOF'
Usage: nemoclawd-phoenix-perps <command> [args...]

Commands:
  configure                 Write ~/.vulcan/config.toml from RPC_URL/SOLANA_RPC_URL
  health                    Run Vulcan agent health checks
  markets                   List Phoenix perp markets
  market [SYMBOL]           Show ticker for SYMBOL (default SOL)
  paper-init [BALANCE]      Initialize local paper account (default 10000)
  preflight [WALLET]        Live-readiness preflight for a wallet
  live-ready                Check whether live agent execution is ready
  mcp                       Start read-only/paper-safe Vulcan MCP server
  mcp-live                  Start live-capable Vulcan MCP server
  exec -- <args...>         Run arbitrary vulcan args with generated config

Live trading requires Vulcan wallet setup, trader registration, collateral,
VULCAN_WALLET_NAME, VULCAN_WALLET_PASSWORD, and explicit confirmations.
EOF
}

require_vulcan() {
  if command -v vulcan >/dev/null 2>&1; then
    return
  fi

  echo "[phoenix] vulcan CLI not found." >&2
  echo "[phoenix] install it on the host with: scripts/install-vulcan.sh" >&2
  echo "[phoenix] or inside this sandbox with:" >&2
  echo "  VULCAN_INSTALL_DIR=\$HOME/.local/bin curl -fsSL https://github.com/Ellipsis-Labs/vulcan-cli/releases/latest/download/install.sh | sh" >&2
  exit 127
}

write_config() {
  python3 - <<'PYCFG'
import os
from pathlib import Path

def toml_quote(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

home = Path(os.environ.get("HOME", "/sandbox"))
path = home / ".vulcan" / "config.toml"
path.parent.mkdir(parents=True, exist_ok=True)

rpc_url = os.environ["RPC_URL"]
api_url = os.environ.get("PHOENIX_API_URL", "https://perp-api.phoenix.trade")
wallet_name = os.environ.get("VULCAN_WALLET_NAME", "")
slippage_bps = os.environ.get("VULCAN_DEFAULT_SLIPPAGE_BPS", "50")

lines = [
    "[network]",
    f"rpc_url = {toml_quote(rpc_url)}",
    f"api_url = {toml_quote(api_url)}",
    "",
    "[wallet]",
]
if wallet_name:
    lines.append(f"default = {toml_quote(wallet_name)}")
lines += [
    "",
    "[trading]",
    f"default_slippage_bps = {slippage_bps}",
    "confirm_trades = true",
    "",
]

path.write_text("\n".join(lines))
path.chmod(0o600)
print(path)
PYCFG
}

vulcan_args() {
  # The generated config carries rpc_url/api_url, so subcommand-specific parsing
  # does not have to accept global flags in every position.
  vulcan "$@"
}

command="${1:-status}"
shift || true

case "$command" in
  help|-h|--help)
    usage
    ;;
  configure)
    config_path="$(write_config)"
    echo "[phoenix] wrote Vulcan config: $config_path"
    echo "[phoenix] rpc_url: $RPC_URL"
    echo "[phoenix] api_url: $PHOENIX_API_URL"
    ;;
  health|status)
    require_vulcan
    write_config >/dev/null
    vulcan_args agent health -o json
    ;;
  markets)
    require_vulcan
    write_config >/dev/null
    vulcan_args market list -o json
    ;;
  market)
    require_vulcan
    write_config >/dev/null
    symbol="${1:-SOL}"
    vulcan_args market ticker "$symbol" -o json
    ;;
  paper-init)
    require_vulcan
    write_config >/dev/null
    balance="${1:-10000}"
    vulcan_args paper init --balance "$balance" -o json
    ;;
  preflight)
    require_vulcan
    write_config >/dev/null
    wallet="${1:-${VULCAN_WALLET_NAME:-}}"
    if [ -n "$wallet" ]; then
      vulcan_args strategy preflight -w "$wallet" -o json
    else
      vulcan_args strategy preflight -o json
    fi
    ;;
  live-ready)
    require_vulcan
    write_config >/dev/null
    vulcan_args agent live-ready -o json
    ;;
  mcp)
    require_vulcan
    write_config >/dev/null
    exec vulcan mcp
    ;;
  mcp-live)
    require_vulcan
    write_config >/dev/null
    if [ -z "${VULCAN_WALLET_NAME:-}" ] || [ -z "${VULCAN_WALLET_PASSWORD:-}" ]; then
      echo "[phoenix] live MCP requires VULCAN_WALLET_NAME and VULCAN_WALLET_PASSWORD." >&2
      exit 2
    fi
    echo "[phoenix] starting live-capable Vulcan MCP server; dangerous tools require acknowledged=true." >&2
    exec vulcan mcp --allow-dangerous
    ;;
  exec)
    require_vulcan
    write_config >/dev/null
    if [ "${1:-}" = "--" ]; then shift; fi
    if [ "$#" -eq 0 ]; then
      usage >&2
      exit 2
    fi
    vulcan_args "$@"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
