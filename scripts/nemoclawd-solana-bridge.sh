#!/usr/bin/env bash
# Solana-Telegram Bridge: real-time wallet and trade narration.

set -euo pipefail

APP_DIR="/opt/pump-fun/agent-app"
SOLANA_RPC_URL="${SOLANA_RPC_URL:-https://rpc.solanatracker.io/public}"
SOLANA_WS_URL="${SOLANA_WS_URL:-$SOLANA_RPC_URL}"
BRIDGE_MODE="${BRIDGE_MODE:-natural-language}"
POLL_MS="${POLL_MS:-15000}"
CLAWD_BOX_HOME="${HOME:-/sandbox}/.clawd-box"
CLAWD_BOX_VAULT_DIR="${CLAWD_BOX_VAULT_DIR:-${CLAWD_BOX_HOME}/vault}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-60}"
MIN_WALLET_SOL="${MIN_WALLET_SOL:-0.01}"
STOP_BALANCE_SOL="${STOP_BALANCE_SOL:-0.002}"

mkdir -p "${CLAWD_BOX_VAULT_DIR}"
export CLAWD_BOX_VAULT_DIR HEARTBEAT_SECONDS MIN_WALLET_SOL STOP_BALANCE_SOL

require_env() {
  local key="$1"
  if [ -z "${!key:-}" ]; then
    echo "[solana-bridge] Missing required env: $key" >&2
    exit 1
  fi
}

require_env TELEGRAM_BOT_TOKEN

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[solana-bridge] NemoClawd Solana ↔ Telegram Bridge"
echo "[solana-bridge] Mode: ${BRIDGE_MODE}"
echo "[solana-bridge] RPC:  ${SOLANA_RPC_URL:0:70}"
echo "[solana-bridge] Vault: ${CLAWD_BOX_VAULT_DIR}"
echo "[solana-bridge] Heartbeat: every ${HEARTBEAT_SECONDS}s"
[ -n "${HELIUS_API_KEY:-}" ]              && echo "[solana-bridge] Helius: configured"
[ -n "${DEVELOPER_WALLET:-}" ]           && echo "[solana-bridge] Wallet: ${DEVELOPER_WALLET}"
[ -n "${AGENT_TOKEN_MINT_ADDRESS:-}" ]   && echo "[solana-bridge] Mint:   ${AGENT_TOKEN_MINT_ADDRESS}"
[ -n "${PRIVY_APP_ID:-}" ]               && echo "[solana-bridge] Privy:  configured"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "${APP_DIR}"

# Inline Node bridge — reads env vars set above
VAULT_DIR="${CLAWD_BOX_VAULT_DIR}" node <<'NODE'
const fs = require("fs");
const path = require("path");
const { Bot } = require("grammy");
const { Connection, PublicKey, LAMPORTS_PER_SOL } = require("@solana/web3.js");

const RPC = process.env.SOLANA_RPC_URL;
const WALLET = process.env.DEVELOPER_WALLET || "";
const TARGET_MINT = process.env.AGENT_TOKEN_MINT_ADDRESS || "";
const CHAT_IDS = (process.env.TELEGRAM_NOTIFY_CHAT_IDS || "")
  .split(",").map((v) => Number(v.trim())).filter(Boolean);
const POLL_MS = Number.parseInt(process.env.POLL_MS || "15000", 10);
const HEARTBEAT_SECONDS = Number.parseInt(process.env.HEARTBEAT_SECONDS || "60", 10);
const MIN_WALLET_SOL = Number.parseFloat(process.env.MIN_WALLET_SOL || "0.01");
const STOP_BALANCE_SOL = Number.parseFloat(process.env.STOP_BALANCE_SOL || "0.002");
const HELIUS_API_KEY = process.env.HELIUS_API_KEY || "";
const VAULT_DIR = process.env.VAULT_DIR || path.join(process.env.HOME || "/sandbox", ".clawd-box", "vault");
const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN);
const conn = new Connection(RPC, "confirmed");
const RUN_ID = `${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
const DAY = new Date().toISOString().slice(0, 10);
const EVENTS_FILE   = path.join(VAULT_DIR, `events-${DAY}.jsonl`);
const HEARTBEAT_FILE = path.join(VAULT_DIR, `heartbeats-${DAY}.jsonl`);
const SESSION_FILE  = path.join(VAULT_DIR, `sessions-${DAY}.jsonl`);

let lastSeen = new Set();
let started = Date.now();
let txCount = 0;
let lastProtectionState = null;
let lastFundingState = null;

fs.mkdirSync(VAULT_DIR, { recursive: true });

function appendJsonl(file, payload) {
  fs.appendFileSync(file, `${JSON.stringify({ timestamp: new Date().toISOString(), runId: RUN_ID, ...payload })}\n`, "utf8");
}

function logSession(kind, extra = {}) {
  appendJsonl(SESSION_FILE, { kind, wallet: WALLET || null, rpc: RPC, ...extra });
}

function logEvent(kind, extra = {}) {
  appendJsonl(EVENTS_FILE, { kind, wallet: WALLET || null, targetMint: TARGET_MINT || null, ...extra });
}

function logHeartbeat(extra = {}) {
  appendJsonl(HEARTBEAT_FILE, { kind: "heartbeat", wallet: WALLET || null, ...extra });
}

function shortAddr(v) { return v ? `${v.slice(0, 4)}...${v.slice(-4)}` : "unknown"; }
function formatAmt(v) { const n = Number(v || 0); return Math.abs(n) >= 1000 ? n.toLocaleString(undefined, { maximumFractionDigits: 2 }) : n.toLocaleString(undefined, { maximumFractionDigits: 6 }); }
function solscanLink(sig) { return `https://solscan.io/tx/${sig}`; }

function extractTokenChanges(meta, owner) {
  const pre = new Map(), post = new Map();
  for (const e of meta.preTokenBalances  || []) { if (e.owner !== owner) continue; pre.set(e.mint,  Number(e.uiTokenAmount?.uiAmountString || 0)); }
  for (const e of meta.postTokenBalances || []) { if (e.owner !== owner) continue; post.set(e.mint, Number(e.uiTokenAmount?.uiAmountString || 0)); }
  const mints = new Set([...pre.keys(), ...post.keys()]);
  return [...mints].map((m) => ({ mint: m, delta: (post.get(m) || 0) - (pre.get(m) || 0) })).filter((i) => i.delta !== 0);
}

function classifyEvent(sig, tx) {
  const keys = tx.transaction.message.accountKeys || [];
  const walletIdx = keys.findIndex((e) => e.pubkey.toBase58() === WALLET);
  if (walletIdx < 0) return null;
  const pre = tx.meta.preBalances[walletIdx] || 0;
  const post = tx.meta.postBalances[walletIdx] || 0;
  const lamports = post - pre;
  const signer = keys[0] ? keys[0].pubkey.toBase58() : "";
  const tokenChanges = extractTokenChanges(tx.meta, WALLET);
  const focusToken = tokenChanges.find((e) => e.mint === TARGET_MINT) || tokenChanges[0] || null;
  let type = "activity", counterpart = null;
  if (focusToken) {
    type = focusToken.delta > 0 && lamports < 0 ? "buy" : focusToken.delta < 0 && lamports > 0 ? "sell" : "token";
  } else if (lamports > 0 && signer !== WALLET) { type = "received"; counterpart = signer; }
  else if (lamports < 0 && signer === WALLET)   { type = "sent";     counterpart = (keys[1] || {}).pubkey?.toBase58() || null; }
  else if ((tx.meta.logMessages || []).some((l) => l.includes("Program") && l.includes("invoke"))) { type = "program"; }
  return { type, sig, lamports, counterpart, token: focusToken, tokenChanges, isTrade: type === "buy" || type === "sell" };
}

function narrate(event) {
  const sol = Math.abs(event.lamports / LAMPORTS_PER_SOL).toFixed(4);
  const tl = event.token ? `\nToken: <code>${shortAddr(event.token.mint)}</code>\nAmount: <b>${formatAmt(Math.abs(event.token.delta))}</b>` : "";
  const link = solscanLink(event.sig);
  const prov = HELIUS_API_KEY ? "<b>Helius RPC</b>" : "<b>Configured RPC</b>";
  switch (event.type) {
    case "buy":      return `🟢 <b>Buy Detected</b>\n\nSpent <b>${sol} SOL</b>${tl}\nWallet: <code>${shortAddr(WALLET)}</code>\nProvider: ${prov}\n<a href="${link}">Solscan</a>`;
    case "sell":     return `🔴 <b>Sell Detected</b>\n\nRealized <b>${sol} SOL</b>${tl}\nWallet: <code>${shortAddr(WALLET)}</code>\nProvider: ${prov}\n<a href="${link}">Solscan</a>`;
    case "received": return `💰 <b>Incoming Transfer</b>\n\nReceived <b>${sol} SOL</b>\nFrom: <code>${shortAddr(event.counterpart)}</code>\n<a href="${link}">Solscan</a>`;
    case "sent":     return `📤 <b>Outgoing Transfer</b>\n\nSent <b>${sol} SOL</b>\nTo: <code>${shortAddr(event.counterpart)}</code>\n<a href="${link}">Solscan</a>`;
    default:         return `📋 <b>Wallet Activity</b>\n\nSOL delta: <b>${sol}</b>${tl}\n<a href="${link}">Solscan</a>`;
  }
}

async function broadcast(msg) {
  for (const chatId of CHAT_IDS) {
    try { await bot.api.sendMessage(chatId, msg, { parse_mode: "HTML", link_preview_options: { is_disabled: true } }); }
    catch (e) { console.error("[bridge] send failed", chatId, e.message || e); }
  }
}

async function getWalletSnapshot() {
  if (!WALLET) return { funded: false, protectMode: true, solBalance: 0, txCount, uptimeSeconds: Math.round((Date.now() - started) / 1000) };
  const lamports = await conn.getBalance(new PublicKey(WALLET), "confirmed");
  const solBalance = lamports / LAMPORTS_PER_SOL;
  return { funded: solBalance >= MIN_WALLET_SOL, protectMode: solBalance <= STOP_BALANCE_SOL, solBalance: Number(solBalance.toFixed(6)), txCount, uptimeSeconds: Math.round((Date.now() - started) / 1000) };
}

async function heartbeat() {
  try {
    const snap = await getWalletSnapshot();
    logHeartbeat({ ...snap, mode: process.env.BRIDGE_MODE || "natural-language" });
    console.log(`[bridge] heartbeat: balance=${snap.solBalance} funded=${snap.funded} protect=${snap.protectMode} tx=${snap.txCount}`);
    if (snap.protectMode !== lastProtectionState || snap.funded !== lastFundingState) {
      logEvent("wallet_state_changed", snap);
      if (CHAT_IDS.length > 0) {
        const mode = snap.protectMode ? "🛑 <b>Protect Mode</b> — below floor." : snap.funded ? "🟢 <b>Funded</b>" : "🟡 <b>Standby</b>";
        await broadcast(`💓 <b>NemoClawd Wallet Heartbeat</b>\n\n${mode}\nBalance: <b>${snap.solBalance} SOL</b>\nVault: <code>${VAULT_DIR}</code>`);
      }
      lastProtectionState = snap.protectMode;
      lastFundingState = snap.funded;
    }
  } catch (e) { logEvent("heartbeat_error", { error: e.message || String(e) }); }
}

async function pollWallet() {
  if (!WALLET) return;
  try {
    const sigs = await conn.getSignaturesForAddress(new PublicKey(WALLET), { limit: 5 }, "confirmed");
    for (const si of sigs.reverse()) {
      if (si.err || lastSeen.has(si.signature)) continue;
      const tx = await conn.getParsedTransaction(si.signature, { maxSupportedTransactionVersion: 0 });
      if (!tx?.meta) continue;
      const event = classifyEvent(si.signature, tx);
      if (!event) continue;
      lastSeen.add(si.signature);
      if (lastSeen.size > 50) { const [f] = lastSeen; lastSeen.delete(f); }
      txCount++;
      logEvent(event.isTrade ? "trade_activity" : "wallet_activity", { eventType: event.type, signature: si.signature });
      await broadcast(narrate(event));
      console.log(`[bridge] ${event.type}: ${si.signature.slice(0, 12)}...`);
    }
  } catch (e) { logEvent("poll_error", { error: e.message || String(e) }); }
}

async function main() {
  console.log("[bridge] starting...");
  logSession("bridge_started", { notifyChats: CHAT_IDS, pollMs: POLL_MS, heartbeatSeconds: HEARTBEAT_SECONDS });
  if (CHAT_IDS.length > 0) {
    await broadcast(`🌊 <b>NemoClawd Solana Bridge Online</b>\n\nWallet: <code>${WALLET || "not configured"}</code>\nRPC: ${HELIUS_API_KEY ? "<b>Helius</b>" : "<b>Configured RPC</b>"}\nVault: <code>${VAULT_DIR}</code>`);
  }
  if (WALLET) {
    setInterval(pollWallet, POLL_MS);
    setInterval(() => heartbeat().catch((e) => logEvent("heartbeat_error", { error: e.message })), HEARTBEAT_SECONDS * 1000);
    await pollWallet();
    await heartbeat();
  } else {
    logSession("bridge_started_without_wallet");
    console.log("[bridge] no wallet configured; narration disabled");
  }
  console.log(`[bridge] online, polling every ${POLL_MS}ms`);
}

main().catch((e) => { logSession("bridge_fatal", { error: e.message }); console.error("[bridge] fatal:", e); process.exit(1); });
NODE
