#!/usr/bin/env bash
# Test inference routing through Clawd Box gateway (local vLLM / Ollama)
echo '{"model":"nvidia/nemotron-3-nano-30b-a3b","messages":[{"role":"user","content":"say hello"}]}' > /tmp/req.json
curl -s https://inference.clawd-box.internal/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @/tmp/req.json
