import unittest

from orchestrator.oracle import ORACLE_TOOLS, build_oracle_plan


class OraclePlanTests(unittest.TestCase):
    def test_builds_default_oracle_plan(self) -> None:
        plan = build_oracle_plan({"components": {"blockchain_oracle": {}}})

        self.assertTrue(plan["enabled"])
        self.assertEqual(plan["command"], "python")
        self.assertEqual(plan["args"], ["-m", "hermes_blockchain_oracle"])
        self.assertEqual(plan["tools"], ORACLE_TOOLS)
        self.assertIn("SOLANA_RPC_URL", plan["env"])
        self.assertEqual(plan["safety"]["signing"], "disabled")

    def test_disabled_oracle_plan(self) -> None:
        plan = build_oracle_plan({"components": {"blockchain_oracle": {"enabled": False}}})

        self.assertEqual(plan, {"enabled": False})

    def test_rejects_missing_required_tools(self) -> None:
        with self.assertRaises(ValueError):
            build_oracle_plan(
                {
                    "components": {
                        "blockchain_oracle": {
                            "tools": ["solana_wallet_info"],
                        }
                    }
                }
            )
