#!/usr/bin/env bash
# NemoClawd curl-pipe-bash installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Solizardking/solana-clawd/main/scripts/install.sh | bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[install]${NC} $1"; }
warn()  { echo -e "${YELLOW}[install]${NC} $1"; }
fail()  { echo -e "${RED}[install]${NC} $1"; exit 1; }

ensure_nvm_loaded() {
  if [ -z "${NVM_DIR:-}" ]; then export NVM_DIR="$HOME/.nvm"; fi
  if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; fi
}

refresh_path() {
  ensure_nvm_loaded
  local npm_bin
  npm_bin="$(npm config get prefix 2>/dev/null)/bin" || true
  if [ -n "$npm_bin" ] && [ -d "$npm_bin" ]; then
    case ":$PATH:" in *":$npm_bin:"*) ;; *) export PATH="$npm_bin:$PATH" ;; esac
  fi
}

MIN_NODE_MAJOR=20
MIN_NPM_MAJOR=10
RECOMMENDED_NODE_MAJOR=22
RUNTIME_REQUIREMENT_MSG="NemoClawd requires Node.js >=${MIN_NODE_MAJOR} and npm >=${MIN_NPM_MAJOR} (recommended Node.js ${RECOMMENDED_NODE_MAJOR})."

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) OS_LABEL="macOS" ;;
  Linux)  OS_LABEL="Linux" ;;
  *)      fail "Unsupported OS: $OS" ;;
esac

case "$ARCH" in
  x86_64|amd64)  ARCH_LABEL="x86_64" ;;
  aarch64|arm64) ARCH_LABEL="aarch64" ;;
  *)             fail "Unsupported architecture: $ARCH" ;;
esac

info "Detected $OS_LABEL ($ARCH_LABEL)"

NODE_MGR="none"
NEED_RESHIM=false

if command -v asdf > /dev/null 2>&1 && asdf plugin list 2>/dev/null | grep -q nodejs; then
  NODE_MGR="asdf"
elif [ -n "${NVM_DIR:-}" ] && [ -s "${NVM_DIR}/nvm.sh" ]; then
  NODE_MGR="nvm"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"; NODE_MGR="nvm"
elif command -v fnm > /dev/null 2>&1; then
  NODE_MGR="fnm"
elif command -v brew > /dev/null 2>&1 && [ "$OS" = "Darwin" ]; then
  NODE_MGR="brew"
elif [ "$OS" = "Linux" ]; then
  NODE_MGR="nodesource"
fi

info "Node.js manager: $NODE_MGR"

version_major() { printf '%s\n' "${1#v}" | cut -d. -f1; }

ensure_supported_runtime() {
  command -v node > /dev/null 2>&1 || fail "${RUNTIME_REQUIREMENT_MSG} Node.js was not found on PATH."
  command -v npm  > /dev/null 2>&1 || fail "${RUNTIME_REQUIREMENT_MSG} npm was not found on PATH."
  local node_version npm_version node_major npm_major
  node_version="$(node -v 2>/dev/null || true)"
  npm_version="$(npm --version 2>/dev/null || true)"
  node_major="$(version_major "$node_version")"
  npm_major="$(version_major "$npm_version")"
  [[ "$node_major" =~ ^[0-9]+$ ]] || fail "Could not determine Node.js version. ${RUNTIME_REQUIREMENT_MSG}"
  [[ "$npm_major"  =~ ^[0-9]+$ ]] || fail "Could not determine npm version. ${RUNTIME_REQUIREMENT_MSG}"
  if (( node_major < MIN_NODE_MAJOR || npm_major < MIN_NPM_MAJOR )); then
    fail "Unsupported runtime detected: Node.js ${node_version:-unknown}, npm ${npm_version:-unknown}. ${RUNTIME_REQUIREMENT_MSG}"
  fi
  info "Runtime OK: Node.js ${node_version}, npm ${npm_version}"
}

install_node() {
  local current_major=""
  command -v node > /dev/null 2>&1 && current_major="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
  [ "$current_major" = "$RECOMMENDED_NODE_MAJOR" ] && { info "Node.js ${RECOMMENDED_NODE_MAJOR} already installed"; return 0; }
  info "Installing Node.js ${RECOMMENDED_NODE_MAJOR}..."
  case "$NODE_MGR" in
    asdf)
      local latest; latest="$(asdf list all nodejs 2>/dev/null | grep "^${RECOMMENDED_NODE_MAJOR}\." | tail -1)"
      [ -n "$latest" ] || fail "Could not find Node.js ${RECOMMENDED_NODE_MAJOR} in asdf"
      asdf install nodejs "$latest"; asdf global nodejs "$latest"; NEED_RESHIM=true ;;
    nvm)
      . "${NVM_DIR}/nvm.sh"; nvm install "$RECOMMENDED_NODE_MAJOR"; nvm use "$RECOMMENDED_NODE_MAJOR"; nvm alias default "$RECOMMENDED_NODE_MAJOR" ;;
    fnm)
      fnm install "$RECOMMENDED_NODE_MAJOR"; fnm use "$RECOMMENDED_NODE_MAJOR"; fnm default "$RECOMMENDED_NODE_MAJOR" ;;
    brew)
      brew install "node@${RECOMMENDED_NODE_MAJOR}"; brew link --overwrite "node@${RECOMMENDED_NODE_MAJOR}" 2>/dev/null || true ;;
    nodesource)
      curl -fsSL "https://deb.nodesource.com/setup_${RECOMMENDED_NODE_MAJOR}.x" | sudo -E bash - > /dev/null 2>&1
      sudo apt-get install -y -qq nodejs > /dev/null 2>&1 ;;
    none) fail "No Node.js version manager found. Install Node.js ${RECOMMENDED_NODE_MAJOR} manually." ;;
  esac
  info "Node.js $(node -v) installed"
}

install_docker() {
  if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    info "Docker already running"; return 0
  fi
  info "Installing Docker..."
  case "$OS" in
    Darwin)
      command -v brew > /dev/null 2>&1 || fail "Homebrew required to install Docker on macOS."
      brew install colima docker; colima start ;;
    Linux)
      sudo apt-get update -qq > /dev/null 2>&1
      sudo apt-get install -y -qq docker.io > /dev/null 2>&1
      sudo usermod -aG docker "$(whoami)"
      info "Docker installed. You may need to log out and back in." ;;
  esac
  docker info > /dev/null 2>&1 || fail "Docker installed but not running."
  info "Docker is running"
}

install_clawd_box() {
  if command -v clawd-box > /dev/null 2>&1; then
    info "clawd-box already installed: $(clawd-box --version 2>&1 || echo 'unknown')"; return 0
  fi
  info "Installing Clawd Box CLI..."
  case "$OS" in
    Darwin)
      case "$ARCH_LABEL" in
        x86_64)  ASSET="clawd-box-x86_64-apple-darwin.tar.gz" ;;
        aarch64) ASSET="clawd-box-aarch64-apple-darwin.tar.gz" ;;
      esac ;;
    Linux)
      case "$ARCH_LABEL" in
        x86_64)  ASSET="clawd-box-x86_64-unknown-linux-musl.tar.gz" ;;
        aarch64) ASSET="clawd-box-aarch64-unknown-linux-musl.tar.gz" ;;
      esac ;;
  esac
  local tmpdir; tmpdir="$(mktemp -d)"
  if command -v gh > /dev/null 2>&1; then
    GH_TOKEN="${GITHUB_TOKEN:-}" gh release download --repo 8bitlabs/clawd-box \
      --pattern "$ASSET" --dir "$tmpdir"
  else
    curl -fsSL "https://github.com/8bitlabs/clawd-box/releases/latest/download/$ASSET" -o "$tmpdir/$ASSET"
  fi
  tar xzf "$tmpdir/$ASSET" -C "$tmpdir"
  if [ -w /usr/local/bin ]; then
    install -m 755 "$tmpdir/clawd-box" /usr/local/bin/clawd-box
  else
    sudo install -m 755 "$tmpdir/clawd-box" /usr/local/bin/clawd-box
  fi
  rm -rf "$tmpdir"
  info "clawd-box $(clawd-box --version 2>&1 || echo '') installed"
}

install_node
ensure_supported_runtime
install_docker
install_clawd_box

NPM_PACKAGE="@8bitlabs/nemoclawd"
info "Installing ${NPM_PACKAGE}..."
if [ "$NODE_MGR" = "nodesource" ]; then
  sudo npm install -g "$NPM_PACKAGE"
else
  npm install -g "$NPM_PACKAGE"
fi

[ "$NEED_RESHIM" = true ] && { info "Reshimming asdf..."; asdf reshim nodejs; }
refresh_path

if ! command -v nemoclawd > /dev/null 2>&1; then refresh_path; fi

if ! command -v nemoclawd > /dev/null 2>&1; then
  npm_bin="$(npm config get prefix 2>/dev/null)/bin" || true
  if [ -n "$npm_bin" ] && [ -x "$npm_bin/nemoclawd" ]; then
    warn "nemoclawd installed at $npm_bin/nemoclawd but not on current PATH."
    warn "Add to your shell profile:  export PATH=\"$npm_bin:\$PATH\""
  else
    fail "nemoclawd installation failed. Binary not found."
  fi
fi

echo ""
info "Installation complete!"
info "nemoclawd $(nemoclawd --version 2>/dev/null || echo 'v0.1.0') is ready."
echo ""
echo "  Run \`nemoclawd onboard\` to get started"
echo ""
