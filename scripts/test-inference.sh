#!/usr/bin/env bash
# Test inference routing through Clawd Box gateway
echo '{"model":"nvidia/nemotron-3-super-120b-a12b","messages":[{"role":"user","content":"say hello"}]}' > /tmp/req.json
curl -s https://inference.clawd-box.internal/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @/tmp/req.json
