#!/usr/bin/env python3
"""Write NVIDIA auth profile into the Clawd agent config directory."""
import json
import os

path = os.path.expanduser("~/.clawd/agents/main/agent/auth-profiles.json")
os.makedirs(os.path.dirname(path), exist_ok=True)

profile = {
    "nvidia:manual": {
        "type": "api_key",
        "provider": "nvidia",
        "keyRef": {"source": "env", "id": "NVIDIA_API_KEY"},
        "profileId": "nvidia:manual",
    }
}
with open(path, "w") as f:
    json.dump(profile, f, indent=2)
os.chmod(path, 0o600)
print(f"Wrote auth profile to {path}")
