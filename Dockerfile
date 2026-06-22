# NemoClawd sandbox image — OpenClaw + NemoClawd plugin inside OpenShell
# Uses Alpine for minimal attack surface

FROM node:22-alpine

# Patch OS-level packages; Node.js-bundled CVEs require a Node.js release update
RUN apk upgrade --no-cache

RUN apk add --no-cache \
        build-base \
        python3 py3-pip \
        curl git ca-certificates \
        iproute2 bzip2 bash

# Install Solana CLI tools via an explicit Agave release.
# Anza publishes installers for x86_64 Linux only.
# Linux/arm64 (Orin Nano builds) skip the CLI and use the Orin-specific image.
ARG SOLANA_VERSION=v3.1.9
RUN set -eux; \
    arch="$(uname -m)"; \
    if [ "${arch}" = "aarch64" ]; then \
      echo 'WARN: Agave does not publish Linux arm64 CLI installers; skipping Solana CLI. Use Dockerfile.orin-nano for Jetson Orin Nano.'; \
    else \
      sh -c "$(curl -sSfL https://release.anza.xyz/${SOLANA_VERSION}/install)"; \
      SOLANA_BIN_DIR="/root/.local/share/solana/install/active_release/bin"; \
      ln -sf "${SOLANA_BIN_DIR}/solana" /usr/local/bin/solana; \
      ln -sf "${SOLANA_BIN_DIR}/solana-test-validator" /usr/local/bin/solana-test-validator; \
      ln -sf "${SOLANA_BIN_DIR}/solana-keygen" /usr/local/bin/solana-keygen; \
      if [ -x "${SOLANA_BIN_DIR}/spl-token" ]; then \
        ln -sf "${SOLANA_BIN_DIR}/spl-token" /usr/local/bin/spl-token; \
      else \
        echo 'WARN: spl-token is not bundled in this Agave release'; \
      fi; \
    fi

# Create sandbox user used by OpenShell sandbox images
RUN addgroup -S sandbox && adduser -S -G sandbox -h /sandbox sandbox \
    && mkdir -p /sandbox/.openclaw /sandbox/.nemoclawd \
    && chown -R sandbox:sandbox /sandbox

# Install OpenClaw CLI
RUN npm install -g openclaw@2026.6.9

# Install PyYAML for blueprint runner
RUN pip3 install --break-system-packages pyyaml

# Copy our plugin and blueprint into the sandbox
COPY nemoclawd/dist/ /opt/nemoclawd/dist/
COPY nemoclawd/openclaw.plugin.json /opt/nemoclawd/
COPY nemoclawd/package.json /opt/nemoclawd/
COPY nemoclawd-blueprint/ /opt/nemoclawd-blueprint/
COPY Pump-Fun/agent-app/ /opt/pump-fun/agent-app/
COPY Pump-Fun/agent-tasks/ /opt/pump-fun/agent-tasks/
COPY Pump-Fun/docs/ /opt/pump-fun/docs/
COPY Pump-Fun/packages/defi-agents/agents-manifest.json /opt/pump-fun/defi-agents/agents-manifest.json
COPY Pump-Fun/packages/defi-agents/locales/ /opt/pump-fun/defi-agents/locales/
COPY Pump-Fun/packages/defi-agents/docs/ /opt/pump-fun/defi-agents/docs/
COPY Pump-Fun/packages/defi-agents/README.md /opt/pump-fun/defi-agents/README.md
COPY Pump-Fun/packages/defi-agents/llms.txt /opt/pump-fun/defi-agents/llms.txt
COPY Pump-Fun/packages/defi-agents/llms-full.txt /opt/pump-fun/defi-agents/llms-full.txt
COPY Pump-Fun/packages/defi-agents/src/ /opt/pump-fun/defi-agents/src/
COPY Pump-Fun/pumpkit/ /opt/pump-fun/pumpkit/
COPY Pump-Fun/pumpkit/agent-prompts/ /opt/pump-fun/agent-prompts/
COPY Pump-Fun/telegram-bot/ /opt/pump-fun/telegram-bot/
COPY Pump-Fun/swarm-bot/ /opt/pump-fun/swarm-bot/
COPY Pump-Fun/websocket-server/ /opt/pump-fun/websocket-server/
COPY Pump-Fun/tools/ /opt/pump-fun/tools/
COPY Pump-Fun/x402/ /opt/pump-fun/x402/
COPY Pump-Fun/src/ /opt/pump-fun/sdk/src/
COPY pump-fun-skills-main/tokenized-agents/ /opt/pump-fun/tokenized-agents-skill/

# Install runtime dependencies only
WORKDIR /opt/nemoclawd
RUN npm install --omit=dev

WORKDIR /opt/pump-fun/agent-app
RUN npm install

WORKDIR /opt/pump-fun/telegram-bot
RUN npm install

WORKDIR /opt/pump-fun/swarm-bot
RUN npm install

WORKDIR /opt/pump-fun/websocket-server
RUN npm install

WORKDIR /opt/pump-fun/x402
RUN npm install

# Set up blueprint for local resolution
RUN mkdir -p /sandbox/.nemoclawd/blueprints/0.1.0 \
    && cp -r /opt/nemoclawd-blueprint/* /sandbox/.nemoclawd/blueprints/0.1.0/

# Copy startup scripts
COPY scripts/nemoclawd-start.sh       /usr/local/bin/nemoclawd-start
COPY scripts/nemoclawd-solana-agent.sh    /usr/local/bin/nemoclawd-solana-agent
COPY scripts/nemoclawd-payment-app.sh    /usr/local/bin/nemoclawd-payment-app
COPY scripts/nemoclawd-telegram-bot.sh   /usr/local/bin/nemoclawd-telegram-bot
COPY scripts/nemoclawd-swarm-bot.sh      /usr/local/bin/nemoclawd-swarm-bot
COPY scripts/nemoclawd-websocket-server.sh /usr/local/bin/nemoclawd-websocket-server
COPY scripts/nemoclawd-solana-bridge.sh  /usr/local/bin/nemoclawd-solana-bridge
COPY scripts/nemoclawd-solana-stack.sh   /usr/local/bin/nemoclawd-solana-stack
RUN chmod +x \
    /usr/local/bin/nemoclawd-start \
    /usr/local/bin/nemoclawd-solana-agent \
    /usr/local/bin/nemoclawd-payment-app \
    /usr/local/bin/nemoclawd-telegram-bot \
    /usr/local/bin/nemoclawd-swarm-bot \
    /usr/local/bin/nemoclawd-websocket-server \
    /usr/local/bin/nemoclawd-solana-bridge \
    /usr/local/bin/nemoclawd-solana-stack

RUN npm install -g helius-cli 2>/dev/null || echo 'WARN: helius-cli install skipped'

WORKDIR /sandbox
USER sandbox

RUN mkdir -p /sandbox/.openclaw/agents/main/agent \
    && mkdir -p /sandbox/.openclaw/workspace/skills/privy \
    && mkdir -p /sandbox/.nemoclawd/wallets \
    && chmod 700 /sandbox/.openclaw \
    && chmod 700 /sandbox/.nemoclawd/wallets

RUN cat > /sandbox/.openclaw/workspace/skills/privy/SKILL.md <<'PRIVY_SKILL'
---
name: privy-agentic-wallets
description: |
  Create and manage Solana agentic wallets via Privy server wallets.
  Use when the agent needs its own wallet to sign transactions,
  send SOL/USDC, or interact with on-chain programs autonomously.
---

## Privy Agentic Wallet Skill

### Environment Variables
- `PRIVY_APP_ID` — Your Privy app ID (from dashboard.privy.io)
- `PRIVY_APP_SECRET` — Your Privy app secret

### Create a Wallet
```bash
curl -X POST https://auth.privy.io/api/v1/wallets \
  -H "Authorization: Basic $(echo -n $PRIVY_APP_ID:$PRIVY_APP_SECRET | base64)" \
  -H "privy-app-id: $PRIVY_APP_ID" \
  -H "Content-Type: application/json" \
  -d '{"chain_type": "solana"}'
```

### Security Rules
- NEVER log or expose PRIVY_APP_SECRET
- Only fund wallets with amounts you can afford to lose
PRIVY_SKILL

# Write openclaw.json: NVIDIA provider via OpenShell inference routing
RUN python3 -c "\
import json, os; \
config = { \
    'agents': {'defaults': {'model': {'primary': 'nvidia/nemotron-3-super-120b-a12b'}}}, \
    'models': {'mode': 'merge', 'providers': { \
        'nvidia': { \
            'baseUrl': 'https://integrate.api.nvidia.com/v1', \
            'apiKey': 'env:NVIDIA_API_KEY', \
            'api': 'openai-completions', \
            'models': [{'id': 'nemotron-3-super-120b-a12b', 'name': 'NVIDIA Nemotron 3 Super 120B', 'reasoning': True, 'input': ['text'], 'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0}, 'contextWindow': 131072, 'maxTokens': 8192}] \
        } \
    }} \
}; \
path = os.path.expanduser('~/.openclaw/openclaw.json'); \
json.dump(config, open(path, 'w'), indent=2); \
os.chmod(path, 0o600)"

RUN openclaw doctor --fix > /dev/null 2>&1 || true \
    && openclaw plugins install /opt/nemoclawd > /dev/null 2>&1 || true

ENTRYPOINT ["/bin/bash"]
CMD []
