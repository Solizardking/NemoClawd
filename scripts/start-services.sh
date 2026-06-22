#!/usr/bin/env bash
# Start NemoClawd auxiliary services: Telegram bridge and cloudflared tunnel.
#
# Usage:
#   TELEGRAM_BOT_TOKEN=... ./scripts/start-services.sh         # start all
#   ./scripts/start-services.sh --status                       # check status
#   ./scripts/start-services.sh --stop                         # stop all
#   ./scripts/start-services.sh --sandbox mybox                # specific sandbox

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARD_PORT="${DASHBOARD_PORT:-18789}"

SANDBOX_NAME="${NEMOCLAWD_SANDBOX:-default}"
ACTION="start"

while [ $# -gt 0 ]; do
  case "$1" in
    --sandbox) SANDBOX_NAME="${2:?--sandbox requires a name}"; shift 2 ;;
    --stop)    ACTION="stop";   shift ;;
    --status)  ACTION="status"; shift ;;
    *)         shift ;;
  esac
done

PIDDIR="/tmp/nemoclawd-services-${SANDBOX_NAME}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[services]${NC} $1"; }
warn() { echo -e "${YELLOW}[services]${NC} $1"; }
fail() { echo -e "${RED}[services]${NC} $1"; exit 1; }

is_running() {
  local pidfile="$PIDDIR/$1.pid"
  [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

start_service() {
  local name="$1"; shift
  is_running "$name" && { info "$name already running (PID $(cat "$PIDDIR/$name.pid"))"; return 0; }
  nohup "$@" > "$PIDDIR/$name.log" 2>&1 &
  echo $! > "$PIDDIR/$name.pid"
  info "$name started (PID $!)"
}

stop_service() {
  local name="$1" pidfile="$PIDDIR/$1.pid"
  if [ -f "$pidfile" ]; then
    local pid; pid="$(cat "$pidfile")"
    kill "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
    info "$name stopped (PID $pid)"
    rm -f "$pidfile"
  else
    info "$name was not running"
  fi
}

show_status() {
  mkdir -p "$PIDDIR"; echo ""
  for svc in telegram-bridge cloudflared; do
    if is_running "$svc"; then
      echo -e "  ${GREEN}●${NC} $svc  (PID $(cat "$PIDDIR/$svc.pid"))"
    else
      echo -e "  ${RED}●${NC} $svc  (stopped)"
    fi
  done
  echo ""
  local url=""
  [ -f "$PIDDIR/cloudflared.log" ] && url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$PIDDIR/cloudflared.log" 2>/dev/null | head -1 || true)"
  [ -n "$url" ] && info "Public URL: $url"
}

do_stop() {
  mkdir -p "$PIDDIR"
  stop_service cloudflared
  stop_service telegram-bridge
  info "All services stopped."
}

do_start() {
  [ -n "${NVIDIA_API_KEY:-}" ] || fail "NVIDIA_API_KEY required"
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && warn "TELEGRAM_BOT_TOKEN not set — Telegram bridge will not start."
  command -v node > /dev/null || fail "node not found. Install Node.js first."

  if command -v clawd-box > /dev/null 2>&1; then
    clawd-box sandbox list 2>&1 | grep -q "Ready" || warn "No sandbox in Ready state."
  fi

  mkdir -p "$PIDDIR"

  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && start_service telegram-bridge node "$REPO_DIR/scripts/telegram-bridge.js"

  command -v cloudflared > /dev/null 2>&1 && \
    start_service cloudflared cloudflared tunnel --url "http://localhost:$DASHBOARD_PORT" || \
    warn "cloudflared not found — no public URL. Install via brev-setup.sh."

  if is_running cloudflared; then
    info "Waiting for tunnel URL..."
    for _ in $(seq 1 15); do
      local url=""
      url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$PIDDIR/cloudflared.log" 2>/dev/null | head -1 || true)"
      [ -n "$url" ] && break
      sleep 1
    done
  fi

  local tunnel_url=""
  [ -f "$PIDDIR/cloudflared.log" ] && tunnel_url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$PIDDIR/cloudflared.log" 2>/dev/null | head -1 || true)"

  echo ""
  echo "  ┌─────────────────────────────────────────────────────┐"
  echo "  │  NemoClawd Services                                 │"
  echo "  │                                                     │"
  [ -n "$tunnel_url" ] && printf "  │  Public URL:  %-40s│\n" "$tunnel_url"
  is_running telegram-bridge && echo "  │  Telegram:    bridge running                        │" || echo "  │  Telegram:    not started (no token)                │"
  echo "  │                                                     │"
  echo "  │  Run 'clawd-box term' to monitor egress approvals   │"
  echo "  └─────────────────────────────────────────────────────┘"
  echo ""
}

case "$ACTION" in
  stop)   do_stop ;;
  status) show_status ;;
  start)  do_start ;;
esac
