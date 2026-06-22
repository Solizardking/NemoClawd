#!/usr/bin/env python3
"""Write OpenRouter auth profile into the OpenClaw agent config directory."""
import json
import os

path = os.path.expanduser("~/.openclaw/agents/main/agent/auth-profiles.json")
os.makedirs(os.path.dirname(path), exist_ok=True)

profile = {
    "openrouter:manual": {
        "type": "api_key",
        "provider": "openrouter",
        "keyRef": {"source": "env", "id": "OPENROUTER_API_KEY"},
        "profileId": "openrouter:manual",
    }
}
with open(path, "w") as f:
    json.dump(profile, f, indent=2)
os.chmod(path, 0o600)
print(f"Wrote auth profile to {path}")
