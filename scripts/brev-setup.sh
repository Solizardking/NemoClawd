#!/usr/bin/env bash
# Brev VM bootstrap — installs prerequisites then runs setup.sh.
#
# Run on a fresh Brev VM:
#   export OPENROUTER_API_KEY=sk-or-...
#   export OPENROUTER_MODEL=z-ai/glm-5.2
#   ./scripts/brev-setup.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[brev]${NC} $1"; }
warn() { echo -e "${YELLOW}[brev]${NC} $1"; }
fail() { echo -e "${RED}[brev]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -n "${OPENROUTER_API_KEY:-}" ] || fail "OPENROUTER_API_KEY not set"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-z-ai/glm-5.2}"
SOLANA_RPC_URL="${SOLANA_RPC_URL:-${RPC_URL:-https://rpc.solanatracker.io/public}}"
RPC_URL="${RPC_URL:-$SOLANA_RPC_URL}"
PHOENIX_API_URL="${PHOENIX_API_URL:-https://perp-api.phoenix.trade}"

export NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive

# --- 0. Node.js ---
if ! command -v node > /dev/null 2>&1; then
  info "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - > /dev/null 2>&1
  sudo apt-get install -y -qq nodejs > /dev/null 2>&1
  info "Node.js $(node --version) installed"
else
  info "Node.js already installed: $(node --version)"
fi

# --- 1. Docker ---
if ! command -v docker > /dev/null 2>&1; then
  info "Installing Docker..."
  sudo apt-get update -qq > /dev/null 2>&1
  sudo apt-get install -y -qq docker.io > /dev/null 2>&1
  sudo usermod -aG docker "$(whoami)"
  info "Docker installed"
else
  info "Docker already installed"
fi

# --- 2. NVIDIA Container Toolkit (if GPU present) ---
if command -v nvidia-smi > /dev/null 2>&1; then
  if ! dpkg -s nvidia-container-toolkit > /dev/null 2>&1; then
    info "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    sudo apt-get update -qq > /dev/null 2>&1
    sudo apt-get install -y -qq nvidia-container-toolkit > /dev/null 2>&1
    sudo nvidia-ctk runtime configure --runtime=docker > /dev/null 2>&1
    sudo systemctl restart docker
    info "NVIDIA Container Toolkit installed"
  else
    info "NVIDIA Container Toolkit already installed"
  fi
fi

# --- 3. OpenShell CLI ---
if ! command -v openshell > /dev/null 2>&1; then
  info "Installing NVIDIA OpenShell CLI..."
  bash "$SCRIPT_DIR/install-openshell.sh"
  info "OpenShell $(openshell --version 2>&1 || echo 'installed')"
else
  info "OpenShell already installed: $(openshell --version 2>&1 || echo 'unknown')"
fi

# --- 3b. cloudflared ---
if ! command -v cloudflared > /dev/null 2>&1; then
  info "Installing cloudflared..."
  CF_ARCH="$(uname -m)"
  case "$CF_ARCH" in
    x86_64|amd64)  CF_ARCH="amd64" ;;
    aarch64|arm64) CF_ARCH="arm64" ;;
    *)             fail "Unsupported arch for cloudflared: $CF_ARCH" ;;
  esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o /tmp/cloudflared
  sudo install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
  rm -f /tmp/cloudflared
  info "cloudflared installed"
else
  info "cloudflared already installed"
fi

# --- 4. vLLM (GPU only) ---
if command -v nvidia-smi > /dev/null 2>&1; then
  if ! python3 -c "import vllm" 2>/dev/null; then
    info "Installing vLLM..."
    ! command -v pip3 > /dev/null 2>&1 && sudo apt-get install -y -qq python3-pip > /dev/null 2>&1
    pip3 install --break-system-packages vllm 2>/dev/null || pip3 install vllm
    info "vLLM installed"
  fi
  VLLM_MODEL="nvidia/nemotron-3-nano-30b-a3b"
  if ! curl -s http://localhost:8000/v1/models > /dev/null 2>&1 && python3 -c "import vllm" 2>/dev/null; then
    info "Starting vLLM with $VLLM_MODEL..."
    nohup python3 -m vllm.entrypoints.openai.api_server \
      --model "$VLLM_MODEL" --port 8000 --host 0.0.0.0 > /tmp/vllm-server.log 2>&1 &
    VLLM_PID=$!
    info "Waiting for vLLM to load model..."
    for _ in $(seq 1 120); do
      curl -s http://localhost:8000/v1/models > /dev/null 2>&1 && { info "vLLM ready (PID $VLLM_PID)"; break; }
      kill -0 "$VLLM_PID" 2>/dev/null || { warn "vLLM exited. Check /tmp/vllm-server.log"; break; }
      sleep 2
    done
  fi
fi

# --- 5. Run setup.sh ---
info "Running setup.sh..."
export OPENROUTER_API_KEY OPENROUTER_MODEL
export RPC_URL SOLANA_RPC_URL PHOENIX_API_URL
[ -n "${VULCAN_WALLET_NAME:-}" ] && export VULCAN_WALLET_NAME
[ -n "${VULCAN_WALLET_PASSWORD:-}" ] && export VULCAN_WALLET_PASSWORD
[ -n "${NVIDIA_API_KEY:-}" ] && export NVIDIA_API_KEY
exec sg docker -c "bash $SCRIPT_DIR/setup.sh"
