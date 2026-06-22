#!/usr/bin/env bash
# NemoClawd setup — run this on the HOST to set up everything.
#
# Prerequisites:
#   - Docker running (Colima, Docker Desktop, or native)
#   - clawd-box CLI installed
#   - NVIDIA_API_KEY set in environment
#
# Usage:
#   export NVIDIA_API_KEY=nvapi-...
#   ./scripts/setup.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}>>>${NC} $1"; }
warn() { echo -e "${YELLOW}>>>${NC} $1"; }
fail() { echo -e "${RED}>>>${NC} $1"; exit 1; }

upsert_provider() {
  local name="$1" type="$2" credential="$3" config="$4"
  if clawd-box provider create --name "$name" --type "$type" \
    --credential "$credential" --config "$config" 2>&1 | grep -q "AlreadyExists"; then
    clawd-box provider update "$name" --credential "$credential" --config "$config" > /dev/null
    info "Updated $name provider"
  else
    info "Created $name provider"
  fi
}

# Resolve DOCKER_HOST for Colima if needed
if [ -z "${DOCKER_HOST:-}" ]; then
  for _sock in "$HOME/.colima/default/docker.sock" "$HOME/.config/colima/default/docker.sock"; do
    if [ -S "$_sock" ]; then
      export DOCKER_HOST="unix://$_sock"
      warn "Using Colima Docker socket: $_sock"
      break
    fi
  done
  unset _sock
fi

command -v clawd-box > /dev/null || fail "clawd-box CLI not found. Run scripts/install.sh first."
command -v docker     > /dev/null || fail "docker not found"
[ -n "${NVIDIA_API_KEY:-}" ] || fail "NVIDIA_API_KEY not set. Get one from build.nvidia.com"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Gateway
info "Starting Clawd Box gateway..."
clawd-box gateway destroy -g nemoclawd > /dev/null 2>&1 || true
GATEWAY_ARGS=(--name nemoclawd)
command -v nvidia-smi > /dev/null 2>&1 && GATEWAY_ARGS+=(--gpu)
clawd-box gateway start "${GATEWAY_ARGS[@]}" 2>&1 | grep -E "Gateway|✓|Error|error" || true

for i in 1 2 3 4 5; do
  if clawd-box status 2>&1 | grep -q "Connected"; then break; fi
  [ "$i" -eq 5 ] && fail "Gateway failed to start. Check 'clawd-box gateway info' and Docker logs."
  sleep 2
done
info "Gateway is healthy"

# 2. CoreDNS fix (Colima only)
if [ -S "$HOME/.colima/default/docker.sock" ]; then
  info "Patching CoreDNS for Colima..."
  bash "$SCRIPT_DIR/fix-coredns.sh" 2>&1 || warn "CoreDNS patch failed (may not be needed)"
fi

# 3. Providers
info "Setting up inference providers..."

upsert_provider "nvidia-nim" "openai" \
  "NVIDIA_API_KEY=$NVIDIA_API_KEY" \
  "OPENAI_BASE_URL=https://integrate.api.nvidia.com/v1"

# clawd-router free tier (always configured)
CLAWD_ROUTER_CRED="${CLAWD_ROUTER_KEY:-clawd_free_anonymous}"
upsert_provider "clawd-router" "openai" \
  "OPENAI_API_KEY=$CLAWD_ROUTER_CRED" \
  "OPENAI_BASE_URL=https://clawd-box-router.fly.dev/v1"

# vllm-local (if vLLM is running)
if curl -s http://localhost:8000/v1/models > /dev/null 2>&1 || python3 -c "import vllm" 2>/dev/null; then
  upsert_provider "vllm-local" "openai" \
    "OPENAI_API_KEY=dummy" \
    "OPENAI_BASE_URL=http://host.clawd-box.internal:8000/v1"
fi

# Ollama (macOS local inference)
if [ "$(uname -s)" = "Darwin" ]; then
  if ! command -v ollama > /dev/null 2>&1; then
    info "Installing Ollama..."
    brew install ollama 2>/dev/null || warn "Ollama install failed. Install manually: https://ollama.com"
  fi
  if command -v ollama > /dev/null 2>&1; then
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
      info "Starting Ollama service..."
      OLLAMA_HOST=0.0.0.0:11434 ollama serve > /dev/null 2>&1 &
      sleep 2
    fi
    upsert_provider "ollama-local" "openai" \
      "OPENAI_API_KEY=ollama" \
      "OPENAI_BASE_URL=http://host.clawd-box.internal:11434/v1"
  fi
fi

# 4. Inference route — default to nvidia-nim
info "Setting inference route to nvidia-nim / Nemotron 3 Super..."
clawd-box inference set --no-verify --provider nvidia-nim --model nvidia/nemotron-3-super-120b-a12b > /dev/null 2>&1

# 5. Build and create sandbox
info "Deleting old nemoclawd sandbox (if any)..."
clawd-box sandbox delete nemoclawd > /dev/null 2>&1 || true

info "Building and creating NemoClawd sandbox (takes a few minutes on first run)..."

BUILD_CTX="$(mktemp -d)"
cp "$REPO_DIR/Dockerfile" "$BUILD_CTX/"
cp -r "$REPO_DIR/nemoclawd" "$BUILD_CTX/nemoclawd"
cp -r "$REPO_DIR/nemoclawd-blueprint" "$BUILD_CTX/nemoclawd-blueprint"
cp -r "$REPO_DIR/scripts" "$BUILD_CTX/scripts"
rm -rf "$BUILD_CTX/nemoclawd/node_modules" "$BUILD_CTX/nemoclawd/src"

if [ ! -d "$BUILD_CTX/nemoclawd/dist" ] || [ -z "$(ls -A "$BUILD_CTX/nemoclawd/dist" 2>/dev/null)" ]; then
  rm -rf "$BUILD_CTX"
  fail "nemoclawd/dist/ is missing or empty. Run 'cd nemoclawd && npm install && npm run build' first."
fi

CREATE_LOG=$(mktemp /tmp/nemoclawd-create-XXXXXX.log)
set +e
clawd-box sandbox create --from "$BUILD_CTX/Dockerfile" --name nemoclawd \
  --provider nvidia-nim \
  -- env NVIDIA_API_KEY="$NVIDIA_API_KEY" > "$CREATE_LOG" 2>&1
CREATE_RC=$?
set -e
rm -rf "$BUILD_CTX"

grep -E "^  (Step |Building |Built |Created sandbox|Image )|✓" "$CREATE_LOG" || true

if [ "$CREATE_RC" != "0" ]; then
  echo ""
  warn "Last 20 lines of build output:"
  tail -20 "$CREATE_LOG" | grep -v "NVIDIA_API_KEY"
  fail "Sandbox creation failed (exit $CREATE_RC). Full log: $CREATE_LOG"
fi
rm -f "$CREATE_LOG"

SANDBOX_LINE=$(clawd-box sandbox list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep "nemoclawd")
if ! echo "$SANDBOX_LINE" | grep -q "Ready"; then
  SANDBOX_PHASE=$(echo "$SANDBOX_LINE" | awk '{print $NF}')
  fail "Sandbox created but not Ready (phase: ${SANDBOX_PHASE:-unknown}). Check 'clawd-box sandbox get nemoclawd'."
fi

echo ""
info "Setup complete!"
echo ""
echo "  clawd agent --agent main --local -m 'analyze SOL/USD market conditions' --session-id s1"
echo ""
