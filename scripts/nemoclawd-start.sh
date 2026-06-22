#!/usr/bin/env bash
# NemoClawd sandbox entrypoint. Configures Clawd and starts the dashboard
# gateway inside the sandbox so the forwarded host port has a live upstream.
#
# Optional env:
#   NVIDIA_API_KEY      API key for NVIDIA-hosted inference
#   CLAWD_ROUTER_KEY    API key for ClawdRouter free-tier inference
#   CHAT_UI_URL         Browser origin that will access the forwarded dashboard

set -euo pipefail

NEMOCLAWD_CMD=("$@")
CHAT_UI_URL="${CHAT_UI_URL:-http://127.0.0.1:18789}"
PUBLIC_PORT=18789
WORKSPACE_ROOT="${HOME:-/sandbox}/.clawd/workspace"
PUMPFUN_ROOT="/opt/pump-fun"
SOLANA_RPC_URL="${SOLANA_RPC_URL:-https://rpc.solanatracker.io/public}"

write_workspace_prompts() {
  mkdir -p "${WORKSPACE_ROOT}/pumpfun"

  ln -snf "${PUMPFUN_ROOT}/docs"                    "${WORKSPACE_ROOT}/pumpfun/docs"
  ln -snf "${PUMPFUN_ROOT}/agent-prompts"           "${WORKSPACE_ROOT}/pumpfun/agent-prompts"
  ln -snf "${PUMPFUN_ROOT}/agent-tasks"             "${WORKSPACE_ROOT}/pumpfun/agent-tasks"
  ln -snf "${PUMPFUN_ROOT}/agent-app"               "${WORKSPACE_ROOT}/pumpfun/agent-app"
  ln -snf "${PUMPFUN_ROOT}/defi-agents"             "${WORKSPACE_ROOT}/pumpfun/defi-agents"
  ln -snf "${PUMPFUN_ROOT}/telegram-bot"            "${WORKSPACE_ROOT}/pumpfun/telegram-bot"
  ln -snf "${PUMPFUN_ROOT}/swarm-bot"               "${WORKSPACE_ROOT}/pumpfun/swarm-bot"
  ln -snf "${PUMPFUN_ROOT}/websocket-server"        "${WORKSPACE_ROOT}/pumpfun/websocket-server"
  ln -snf "${PUMPFUN_ROOT}/x402"                    "${WORKSPACE_ROOT}/pumpfun/x402"
  ln -snf "${PUMPFUN_ROOT}/tools"                   "${WORKSPACE_ROOT}/pumpfun/tools"
  ln -snf "${PUMPFUN_ROOT}/sdk"                     "${WORKSPACE_ROOT}/pumpfun/sdk"
  ln -snf "${PUMPFUN_ROOT}/tokenized-agents-skill"  "${WORKSPACE_ROOT}/pumpfun/tokenized-agents-skill"
  ln -snf "${PUMPFUN_ROOT}/pumpkit"                 "${WORKSPACE_ROOT}/pumpfun/pumpkit"

  cat > "${WORKSPACE_ROOT}/AGENTS.md" <<'EOF'
# Pump-Fun Solana Agent Workspace

This Clawd workspace is a **Solana autonomous developer agent** with built-in
Pump.fun SDK, tokenized agent payments, the Pump-Fun Telegram/runtime stack,
44 DeFi agent personas, and an encrypted Privy agentic wallet.

Inference is routed through the Clawd Box — use `clawd-router` for free-tier
models or `nvidia` for Nemotron via NVIDIA NIM.

Core behavior:
- Treat `pumpfun/docs/` as the primary local documentation corpus.
- Use `pumpfun/telegram-bot/src/` for the Pump-Fun Telegram bot runtime.
- Use `pumpfun/agent-app/src/` for payment-gated app flows.
- Pull persona definitions from `pumpfun/defi-agents/src/*.json`.
- Use `pumpfun/x402/` for HTTP 402 Solana USDC micropayment patterns.
- Use `pumpfun/sdk/` for Pump-Fun SDK source.
- NemoClawd vault at `~/.clawd-box/vault/` for JSONL logs.
EOF
}

fix_clawd_config() {
  python3 - <<'PYCFG'
import json
import os
from urllib.parse import urlparse

home = os.environ.get('HOME', '/sandbox')
config_path = os.path.join(home, '.clawd', 'clawd.json')
os.makedirs(os.path.dirname(config_path), exist_ok=True)

cfg = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        cfg = json.load(f)

cfg.setdefault('agents', {}).setdefault('defaults', {}).setdefault('model', {})['primary'] = 'nvidia/nemotron-3-super-120b-a12b'

chat_ui_url = os.environ.get('CHAT_UI_URL', 'http://127.0.0.1:18789')
parsed = urlparse(chat_ui_url)
chat_origin = f"{parsed.scheme}://{parsed.netloc}" if parsed.scheme and parsed.netloc else 'http://127.0.0.1:18789'
local_origin = f'http://127.0.0.1:{os.environ.get("PUBLIC_PORT", "18789")}'
origins = [local_origin]
if chat_origin not in origins:
    origins.append(chat_origin)

gateway = cfg.setdefault('gateway', {})
gateway['mode'] = 'local'
gateway['controlUi'] = {
    'allowInsecureAuth': True,
    'dangerouslyDisableDeviceAuth': True,
    'allowedOrigins': origins,
}
gateway['trustedProxies'] = ['127.0.0.1', '::1']

with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)
os.chmod(config_path, 0o600)
PYCFG
}

write_auth_profile() {
  if [ -z "${NVIDIA_API_KEY:-}" ]; then
    return
  fi

  python3 - <<'PYAUTH'
import json
import os
path = os.path.expanduser('~/.clawd/agents/main/agent/auth-profiles.json')
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump({
    'nvidia:manual': {
        'type': 'api_key',
        'provider': 'nvidia',
        'keyRef': {'source': 'env', 'id': 'NVIDIA_API_KEY'},
        'profileId': 'nvidia:manual',
    }
}, open(path, 'w'))
os.chmod(path, 0o600)
PYAUTH
}

print_dashboard_urls() {
  local token chat_ui_base local_url remote_url

  token="$(python3 - <<'PYTOKEN'
import json
import os
path = os.path.expanduser('~/.clawd/clawd.json')
try:
    cfg = json.load(open(path))
except Exception:
    print('')
else:
    print(cfg.get('gateway', {}).get('auth', {}).get('token', ''))
PYTOKEN
)"

  chat_ui_base="${CHAT_UI_URL%/}"
  local_url="http://127.0.0.1:${PUBLIC_PORT}/"
  remote_url="${chat_ui_base}/"
  if [ -n "$token" ]; then
    local_url="${local_url}#token=${token}"
    remote_url="${remote_url}#token=${token}"
  fi

  echo "[gateway] Local UI:  ${local_url}"
  echo "[gateway] Remote UI: ${remote_url}"
}

echo 'Setting up NemoClawd...'
clawd doctor --fix > /dev/null 2>&1 || true
clawd models set nvidia/nemotron-3-super-120b-a12b > /dev/null 2>&1 || true
write_auth_profile
export CHAT_UI_URL PUBLIC_PORT
fix_clawd_config
write_workspace_prompts

# ── Solana CLI configuration ──────────────────────────────────────
if command -v solana &>/dev/null; then
  echo "[solana] Configuring Solana CLI..."
  solana config set --url "${SOLANA_RPC_URL}" 2>/dev/null || true
  echo "[solana] RPC: ${SOLANA_RPC_URL}"

  ln -snf "${PUMPFUN_ROOT}/sdk"                    "${WORKSPACE_ROOT}/pumpfun/sdk"
  ln -snf "${PUMPFUN_ROOT}/defi-agents"            "${WORKSPACE_ROOT}/pumpfun/defi-agents"
  ln -snf "${PUMPFUN_ROOT}/tokenized-agents-skill" "${WORKSPACE_ROOT}/pumpfun/tokenized-agents-skill"
  ln -snf "${PUMPFUN_ROOT}/pumpkit"                "${WORKSPACE_ROOT}/pumpfun/pumpkit"
  if command -v helius &>/dev/null; then
    echo "[solana] Helius CLI: $(helius --version 2>/dev/null || echo 'available')"
  fi
fi

# ── Privy wallet credentials ──────────────────────────────────────
if [ -n "${PRIVY_APP_ID:-}" ] && [ -n "${PRIVY_APP_SECRET:-}" ]; then
  echo "[privy] Injecting Privy wallet credentials into Clawd config..."
  python3 - <<'PYPRIVY'
import json, os
home = os.environ.get('HOME', '/sandbox')
config_path = os.path.join(home, '.clawd', 'clawd.json')
cfg = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        cfg = json.load(f)
cfg.setdefault('env', {}).setdefault('vars', {}).update({
    'PRIVY_APP_ID': os.environ['PRIVY_APP_ID'],
    'PRIVY_APP_SECRET': os.environ['PRIVY_APP_SECRET'],
    'SOLANA_RPC_URL': os.environ.get('SOLANA_RPC_URL', ''),
})
with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)
os.chmod(config_path, 0o600)
PYPRIVY
  echo "[privy] Privy credentials configured"
fi

clawd plugins install /opt/nemoclawd > /dev/null 2>&1 || true

if [ ${#NEMOCLAWD_CMD[@]} -gt 0 ]; then
  exec "${NEMOCLAWD_CMD[@]}"
fi

nohup clawd-box gateway run > /tmp/gateway.log 2>&1 &
echo "[gateway] clawd-box gateway launched (pid $!)"
print_dashboard_urls
