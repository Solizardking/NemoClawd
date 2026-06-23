<p align="center">
  <strong>🦞 NemoClawd</strong><br/>
  <em>OpenClawd + NVIDIA + Solana agents, with a lobster at the controls</em>
</p>

<p align="center">
  <code>$CLAWD: 8cHzQHUS2s2h8TzCmfqPKYiM4dSt4roa3n7MyRLApump</code>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OpenClawd-blue?style=flat-square" alt="OpenClawd">
  <img src="https://img.shields.io/badge/NVIDIA-NIM%20%2B%20vLLM-76B900?style=flat-square&logo=nvidia&logoColor=white" alt="NVIDIA NIM and vLLM">
  <img src="https://img.shields.io/badge/MCP-37%20tools-blueviolet?style=flat-square" alt="37 MCP tools">
  <img src="https://img.shields.io/badge/Solana-mainnet-9945FF?style=flat-square&logo=solana&logoColor=white" alt="Solana">
  <img src="https://img.shields.io/badge/Phoenix-Perps-orange?style=flat-square" alt="Phoenix Perps">
  <img src="https://img.shields.io/badge/Hermes-Oracle-lightgrey?style=flat-square" alt="Hermes Blockchain Oracle">
</p>

---

## What This Is

NemoClawd is a Solana-native agent stack that now ties together:

- **OpenClawd/NemoClawd blueprint runtime** for sandbox planning, migration, policy, and inference routing.
- **NVIDIA inference routes** for hosted NIM, NCP, local NIM, and local vLLM profiles.
- **nemoClawd MCP** with **37 tools** across Solana data, Helius, Pump.fun, xAI Grok, and Clawd Perps.
- **Clawd Perps** safety tooling with preflight gates, paper previews, live-preview blocking, and Vulcan plan generation.
- **Hermes-style blockchain oracle** planning for read-only Solana wallet, token, transaction, NFT, whale, and network intelligence.

No private keys are stored in the blueprint. Live trading is still gated. The lobster is cheerful, but the risk engine is not.

## Lobster Boot Animation

Paste this in a terminal when you want the correct deployment mood:

```bash
for frame in "🦞  " " 🦞 " "  🦞" " 🦞 "; do
  printf "\r%s OpenClawd sandbox warming NVIDIA tensors..." "$frame"
  sleep 0.15
done
printf "\r🦞 NemoClawd online. Preflight first.              \n"
```

```text
       _.-._
     .'     '.        🦞  observe
    /  o   o  \       🦞  preflight
   |     ^     |      🦞  paper preview
    \  \___/  /       🦞  live only when explicitly armed
     '.___.'
```

## Current Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│                             NemoClawd                                │
│                                                                      │
│  🦞 CLI / MCP / Blueprint                                             │
│        │                                                             │
│        ├─ nemoclawd-mcp                                              │
│        │    ├─ 37 MCP tools                                          │
│        │    ├─ Solana + Helius + Pump.fun                            │
│        │    ├─ xAI Grok chat, vision, image, X search, research      │
│        │    └─ Clawd Perps: preflight, paper, live preview, Vulcan   │
│        │                                                             │
│        ├─ nemoclawd-blueprint                                        │
│        │    ├─ OpenClawd sandbox runner                              │
│        │    ├─ NVIDIA hosted NIM profile                             │
│        │    ├─ NVIDIA NCP profile                                    │
│        │    ├─ local NIM profile                                     │
│        │    ├─ local vLLM profile                                    │
│        │    └─ Hermes blockchain oracle MCP launch contract          │
│        │                                                             │
│        └─ Policies                                                   │
│             ├─ openclawd-sandbox.yaml                                │
│             ├─ solana-rpc.yaml                                       │
│             ├─ phoenix-perps.yaml                                    │
│             └─ hermes-blockchain-oracle.yaml                         │
└──────────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
git clone https://github.com/x402agent/NemoClawd.git
cd NemoClawd

# MCP package
cd nemoclawd-mcp
npm install
npm run build
npm test
cd ..

# Blueprint package
cd nemoclawd-blueprint
make check
OPENCLAWD_CLI=true NEMOCLAWD_BLUEPRINT_PATH=. \
  python orchestrator/runner.py plan --profile default --dry-run
```

Use `OPENCLAWD_CLI=true` only for local dry-run validation when the real `openclawd` binary is not installed. In a real sandbox flow, install OpenClawd and let the runner call `openclawd`.

## NVIDIA Integration

The blueprint has four inference profiles in `nemoclawd-blueprint/blueprint.yaml`:

| Profile | Provider | Endpoint | Model |
|---|---|---|---|
| `default` | NVIDIA hosted inference | `https://integrate.api.nvidia.com/v1` | `nvidia/nemotron-3-super-120b-a12b` |
| `ncp` | NVIDIA NCP | dynamic | `nvidia/nemotron-3-super-120b-a12b` |
| `nim-local` | OpenAI-compatible local NIM | `http://nim-service.local:8000/v1` | `nvidia/nemotron-3-super-120b-a12b` |
| `vllm` | OpenAI-compatible local vLLM | `http://localhost:8000/v1` | `nvidia/nemotron-3-nano-30b-a3b` |

Useful env:

```bash
export NVIDIA_API_KEY="..."
export NIM_API_KEY="..."
export OPENCLAWD_CLI="openclawd"
export NEMOCLAWD_BLUEPRINT_PATH="/path/to/nemoclawd-blueprint"
```

Plan a run:

```bash
cd nemoclawd-blueprint
python orchestrator/runner.py plan --profile default --dry-run
python orchestrator/runner.py plan --profile ncp --dry-run
python orchestrator/runner.py plan --profile nim-local --endpoint-url http://nim-service.local:8000/v1
```

## OpenClawd Blueprint

The blueprint was rewritten from the old OpenShell/OpenClaw naming to **OpenClawd/NemoClawd**:

- `min_openclawd_version` in `blueprint.yaml`.
- `OPENCLAWD_CLI` as the runner override.
- `~/.openclawd` migration snapshots.
- `nb-...` run IDs for NemoClawd blueprint runs.
- `policies/openclawd-sandbox.yaml` as the strict base policy.

Core commands:

```bash
cd nemoclawd-blueprint
make check
python orchestrator/runner.py plan --profile default --dry-run
python orchestrator/runner.py apply --profile default
python orchestrator/runner.py status
python orchestrator/runner.py rollback --run-id nb-YYYYMMDD-HHMMSS-xxxxxxxx
```

## MCP Server

`nemoclawd-mcp` now advertises **37 MCP tools**.

### Clawd Perps Tools

- `perps_status`
- `perps_preflight`
- `perps_paper_trade_preview`
- `perps_live_trade_preview`
- `perps_vulcan_plan`
- `perps_vulcan_catalog`

The perps runtime is intentionally preview-first:

```bash
export HELIUS_RPC_URL="https://mainnet.helius-rpc.com/?api-key=..."
export CLAWD_PERPS_WALLET="your-wallet-address"
export PERPS_ALLOWED_SYMBOLS="SOL,ETH,BTC"
export PERPS_MAX_NOTIONAL_USD="250"
export PERPS_MAX_LEVERAGE="3"
export PERPS_MAX_SPREAD_BPS="40"

# Required together before a live preview can pass preflight
export LIVE_TRADING="true"
export OPERATOR_CONFIRMED="true"
export PERPS_SIM_ONLY="false"
```

Live tools still return previews. The MCP server does not sign or submit orders.

### MCP Build Checks

```bash
cd nemoclawd-mcp
npm run build
npm run lint
npm test
```

## Hermes Blockchain Oracle

The blueprint now includes a Hermes-style blockchain oracle component. It is modeled as a read-only MCP launch contract, not a vendored virtualenv:

```yaml
blockchain_oracle:
  enabled: true
  package: hermes-blockchain-oracle
  command: python
  args: ["-m", "hermes_blockchain_oracle"]
```

Planned tools:

- `solana_wallet_info`
- `solana_transaction`
- `solana_token_info`
- `solana_recent_activity`
- `solana_nft_portfolio`
- `whale_detector`
- `solana_network_stats`

Policy presets:

- `policies/presets/solana-rpc.yaml`
- `policies/presets/hermes-blockchain-oracle.yaml`

Useful env:

```bash
export SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
export RPC_URL="$SOLANA_RPC_URL"
export HELIUS_API_KEY="..."
export CLAWD_TOKEN="8cHzQHUS2s2h8TzCmfqPKYiM4dSt4roa3n7MyRLApump"
export WHALE_THRESHOLD_SOL="1000"
```

## Policy Posture

NemoClawd keeps the sandbox strict:

- Deny by default.
- Allow OpenClawd, NVIDIA, Solana RPC, Helius, Phoenix Perps, npm, Telegram, and explicit presets.
- Store secrets in environment variables, not YAML.
- Keep the oracle read-only.
- Keep perps live flow blocked unless `LIVE_TRADING=true`, `OPERATOR_CONFIRMED=true`, and `PERPS_SIM_ONLY=false`.

## What Changed In This Round

- Integrated Clawd Perps behavior into `nemoclawd-mcp`.
- Added six perps MCP tools and focused tests.
- Rewrote `nemoclawd-blueprint` from OpenShell/OpenClaw naming to OpenClawd/NemoClawd.
- Added NVIDIA NIM/NCP/local NIM/vLLM blueprint profiles.
- Added OpenClawd sandbox policy rename and updated policy hosts/binaries.
- Added Hermes blockchain oracle planning, policy, and unit tests.
- Updated build checks so the blueprint verifies the new oracle helper.

## Verification

These are the checks used for the current tree:

```bash
cd nemoclawd-mcp
npm run build
npm run lint
npm test

cd ../nemoclawd-blueprint
make check
make test
OPENCLAWD_CLI=true NEMOCLAWD_BLUEPRINT_PATH=. \
  python orchestrator/runner.py plan --profile default --dry-run
```

## License

Licensed under [Apache 2.0](LICENSE).

Powered by **Solana**, **OpenClawd**, **xAI Grok**, and **NVIDIA NIM/vLLM**.

The lobster does not bypass preflight.
