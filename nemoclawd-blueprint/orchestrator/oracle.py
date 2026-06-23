"""NemoClawd blockchain oracle blueprint helpers."""

from __future__ import annotations

from typing import Any

ORACLE_TOOLS = [
    "solana_wallet_info",
    "solana_transaction",
    "solana_token_info",
    "solana_recent_activity",
    "solana_nft_portfolio",
    "whale_detector",
    "solana_network_stats",
]

DEFAULT_ORACLE_ENV = {
    "SOLANA_RPC_URL": "${SOLANA_RPC_URL:-https://api.mainnet-beta.solana.com}",
    "RPC_URL": "${RPC_URL:-}",
    "HELIUS_API_KEY": "${HELIUS_API_KEY:-}",
    "CLAWD_TOKEN": "8cHzQHUS2s2h8TzCmfqPKYiM4dSt4roa3n7MyRLApump",
    "WHALE_THRESHOLD_SOL": "1000",
    "CACHE_TTL_SECONDS": "30",
}

DEFAULT_POLICY_PRESETS = [
    "policies/presets/solana-rpc.yaml",
    "policies/presets/hermes-blockchain-oracle.yaml",
]


def _as_string_list(value: Any, *, field: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"blockchain_oracle.{field} must be a list of strings")
    return value


def build_oracle_plan(blueprint: dict[str, Any]) -> dict[str, Any]:
    """Build the safe MCP launch contract for the blockchain oracle component."""
    component = blueprint.get("components", {}).get("blockchain_oracle", {})
    if not isinstance(component, dict):
        raise ValueError("components.blockchain_oracle must be a mapping")

    enabled = component.get("enabled", True)
    if enabled is False:
        return {"enabled": False}
    if enabled is not True:
        raise ValueError("blockchain_oracle.enabled must be true or false")

    tools = _as_string_list(component.get("tools", ORACLE_TOOLS), field="tools")
    missing_tools = sorted(set(ORACLE_TOOLS) - set(tools))
    if missing_tools:
        raise ValueError(f"blockchain_oracle.tools missing required tools: {missing_tools}")

    args = _as_string_list(component.get("args", ["-m", "hermes_blockchain_oracle"]), field="args")
    policy_presets = _as_string_list(
        component.get("policy_presets", DEFAULT_POLICY_PRESETS),
        field="policy_presets",
    )
    env = component.get("env", {})
    if not isinstance(env, dict):
        raise ValueError("blockchain_oracle.env must be a mapping")

    return {
        "enabled": True,
        "name": component.get("name", "nemoclawd-blockchain-oracle"),
        "upstream": component.get("upstream", "hermes-blockchain-oracle"),
        "description": component.get(
            "description",
            "Solana blockchain oracle MCP server for NemoClawd.",
        ),
        "transport": component.get("transport", "stdio"),
        "package": component.get("package", "hermes-blockchain-oracle"),
        "command": component.get("command", "python"),
        "args": args,
        "env": {**DEFAULT_ORACLE_ENV, **env},
        "tools": tools,
        "policy_presets": policy_presets,
        "safety": {
            "signing": "disabled",
            "mode": "read-only Solana RPC/DAS queries",
            "secrets": "env-only; blueprint stores variable names and defaults, not private keys",
        },
    }
