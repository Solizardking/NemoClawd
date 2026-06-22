#!/usr/bin/env bash
# Run the bundled Pump-Fun Solana tracker bot inside the sandbox.

set -euo pipefail

APP_DIR="/opt/pump-fun/agent-app"
export SOLANA_RPC_URL="${SOLANA_RPC_URL:-https://rpc.solanatracker.io/public}"
export NEXT_PUBLIC_SOLANA_RPC_URL="${NEXT_PUBLIC_SOLANA_RPC_URL:-$SOLANA_RPC_URL}"
export SOLANA_WS_URL="${SOLANA_WS_URL:-$SOLANA_RPC_URL}"
export CLAWD_BOX_VAULT_DIR="${CLAWD_BOX_VAULT_DIR:-${HOME:-/sandbox}/.clawd-box/vault}"

mkdir -p "${CLAWD_BOX_VAULT_DIR}"

require_env() {
  local key="$1"
  if [ -z "${!key:-}" ]; then
    echo "[solana-agent] Missing required environment variable: $key" >&2; exit 1
  fi
}

MODE="${1:-bot}"

case "$MODE" in
  bot)
    require_env AGENT_TOKEN_MINT_ADDRESS
    require_env DEVELOPER_WALLET
    require_env TELEGRAM_BOT_TOKEN

    cd "$APP_DIR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[solana-agent] Starting Pump-Fun tracker bot"
    echo "[solana-agent] RPC: ${SOLANA_RPC_URL}"
    echo "[solana-agent] Mint: ${AGENT_TOKEN_MINT_ADDRESS}"
    echo "[solana-agent] Vault: ${CLAWD_BOX_VAULT_DIR}"
    [ -n "${PRIVY_APP_ID:-}" ] && echo "[solana-agent] Privy: configured" || echo "[solana-agent] Privy: not configured"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exec npm run bot
    ;;

  test-validator)
    echo "[solana-agent] Starting solana-test-validator..."
    command -v solana-test-validator &>/dev/null || { echo "[solana-agent] ERROR: solana-test-validator not found" >&2; exit 1; }
    exec solana-test-validator --rpc-port 8899 \
      --clone 6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P \
      --clone pAMMBay6oceH9fJKBRHGP5D4bD4sWpmSwMn52FMfXEA \
      --clone pfeeUxB6jkeY1Hxd7CsFCAjcbHA9rWtchMGdZ6VojVZ \
      --clone AgenTMiC2hvxGebTsgmsD4HHBa8WEcqGFf87iwRRxLo7 \
      --url https://api.mainnet-beta.solana.com
    ;;

  status)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[solana-agent] Status Report"
    echo "[solana-agent] RPC: ${SOLANA_RPC_URL}"
    echo "[solana-agent] Vault: ${CLAWD_BOX_VAULT_DIR}"
    curl -sf -X POST "${SOLANA_RPC_URL}" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' 2>/dev/null || echo "  unreachable"
    command -v solana &>/dev/null && { echo ""; solana config get 2>/dev/null || true; }
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ;;

  *)
    echo "Usage: nemoclawd-solana-agent [bot|test-validator|status]"
    exit 0
    ;;
esac
