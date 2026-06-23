import { describe, expect, it } from "vitest";
import {
  buildPreflightReport,
  buildVulcanExecutionPlan,
  createLiveTradePreview,
  createPaperTradePreview,
  createPerpsStatus,
  loadPerpsRuntimeConfig,
} from "../src/perps.js";

const baseEnv = {
  HELIUS_RPC_URL: "http://127.0.0.1:8899",
  CLAWD_PERPS_WALLET: "configured-wallet",
  XAI_API_KEY: "configured-xai",
  PERPS_ALLOWED_SYMBOLS: "SOL,ETH,BTC",
  PERPS_MAX_NOTIONAL_USD: "250",
  PERPS_MAX_LEVERAGE: "3",
  PERPS_MAX_SPREAD_BPS: "40",
} satisfies NodeJS.ProcessEnv;

describe("Clawd Perps runtime", () => {
  it("blocks unsafe symbols and oversized notionals before planning", () => {
    const config = loadPerpsRuntimeConfig(baseEnv);
    const report = buildPreflightReport(config, {
      symbol: "DOGE",
      notionalUsd: 500,
      leverage: 10,
      expectedSpreadBps: 100,
      execution: "paper",
    });

    expect(report.ok).toBe(false);
    expect(report.mode).toBe("observe");
    expect(report.blocking).toEqual(
      expect.arrayContaining([
        "Symbol DOGE is outside PERPS_ALLOWED_SYMBOLS.",
        "Notional 500 exceeds PERPS_MAX_NOTIONAL_USD=250.",
        "Leverage 10 exceeds PERPS_MAX_LEVERAGE=3.",
        "Spread 100bps exceeds PERPS_MAX_SPREAD_BPS=40.",
      ]),
    );
  });

  it("builds a preflighted paper trade preview without live execution", () => {
    const config = loadPerpsRuntimeConfig(baseEnv);
    const preview = createPaperTradePreview(config, "sol", "buy", 100, 15);

    expect(preview.symbol).toBe("SOL");
    expect(preview.preflight.ok).toBe(true);
    expect(preview.execution).toBe("paper");
    expect(preview.route.adapter).toBe("vulcan");
  });

  it("keeps live previews blocked until every live gate is armed", () => {
    const config = loadPerpsRuntimeConfig(baseEnv);
    const preview = createLiveTradePreview(config, "SOL", "sell", 100, 2, 10);

    expect(preview.preflight.ok).toBe(false);
    expect(preview.preflight.blocking).toContain(
      "Live execution disabled. Require LIVE_TRADING=true, OPERATOR_CONFIRMED=true, and PERPS_SIM_ONLY=false.",
    );
    expect(preview.route.payload).toMatchObject({ blocked: true });
  });

  it("allows live preview only when the operator gates are explicit", () => {
    const config = loadPerpsRuntimeConfig({
      ...baseEnv,
      LIVE_TRADING: "true",
      OPERATOR_CONFIRMED: "true",
      PERPS_SIM_ONLY: "false",
    });
    const preview = createLiveTradePreview(config, "ETH", "buy", 100, 2, 10, "vulcan-live");

    expect(preview.preflight.ok).toBe(true);
    expect(preview.preflight.mode).toBe("live");
    expect(preview.route.adapter).toBe("vulcan");
  });

  it("returns Vulcan CLI-compatible plan data", () => {
    const config = loadPerpsRuntimeConfig(baseEnv);
    const preflight = buildPreflightReport(config, {
      symbol: "BTC",
      notionalUsd: 125,
      execution: "paper",
    });
    const plan = buildVulcanExecutionPlan(
      config,
      { action: "paper-sell", symbol: "BTC", notionalUsd: 125 },
      preflight,
    );

    expect(plan.command.command).toBe("vulcan");
    expect(plan.command.args).toEqual(
      expect.arrayContaining(["paper", "sell", "BTC", "--notional-usdc", "125"]),
    );
    expect(plan.blocked).toBe(false);
  });

  it("summarizes status without exposing wallet material", () => {
    const status = createPerpsStatus(loadPerpsRuntimeConfig(baseEnv));

    expect(status.walletConfigured).toBe(true);
    expect(JSON.stringify(status)).not.toContain("configured-wallet");
    expect(status.allowedSymbols).toEqual(["SOL", "ETH", "BTC"]);
  });
});
