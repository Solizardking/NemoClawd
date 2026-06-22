#!/usr/bin/env bash
# Test inference routing through the OpenShell gateway
MODEL="${OPENROUTER_MODEL:-z-ai/glm-5.2}"
printf '{"model":"%s","messages":[{"role":"user","content":"say hello"}]}\n' "$MODEL" > /tmp/req.json
curl -s https://inference.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @/tmp/req.json
