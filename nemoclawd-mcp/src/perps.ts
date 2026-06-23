import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

export type TradingMode = "observe" | "paper" | "live";
export type PerpsExecution = "observe" | "paper" | "vulcan-live" | "rise-live";
export type PerpsSide = "buy" | "sell";

export interface PerpsRiskLimits {
  allowedSymbols: string[];
  maxNotionalUsd: number;
  maxLeverage: number;
  maxSpreadBps: number;
  requireWallet: boolean;
}

export interface PerpsRuntimeConfig {
  rpcUrl: string;
  apiUrl: string;
  walletConfigured: boolean;
  liveTrading: boolean;
  operatorConfirmed: boolean;
  simOnly: boolean;
  risk: PerpsRiskLimits;
  integrations: {
    xaiConfigured: boolean;
    deepseekConfigured: boolean;
    heliusConfigured: boolean;
    vulcanCatalogPath?: string;
  };
}

export interface PreflightRequest {
  symbol: string;
  notionalUsd: number;
  leverage?: number;
  expectedSpreadBps?: number;
  execution: PerpsExecution;
}

export interface PreflightReport {
  ok: boolean;
  mode: TradingMode;
  blocking: string[];
  warnings: string[];
}

export interface VulcanExecutionIntent {
  action:
    | "market-list"
    | "ticker"
    | "positions"
    | "paper-buy"
    | "paper-sell"
    | "live-buy"
    | "live-sell";
  symbol?: string;
  notionalUsd?: number;
}

export interface VulcanBridgeCommand {
  command: string;
  args: string[];
  cwd?: string;
  env: Record<string, string>;
}

export interface VulcanExecutionPlan {
  transport: "cli";
  mode: TradingMode;
  preflight: PreflightReport;
  command: VulcanBridgeCommand;
  blocked: boolean;
}

export interface TraderActionPreview {
  symbol: string;
  side: PerpsSide;
  notionalUsd: number;
  execution: PerpsExecution;
  preflight: PreflightReport;
  route: {
    adapter: "rise" | "vulcan";
    action: string;
    payload: unknown;
  };
}

export interface PerpsStatusCard {
  title: string;
  value: string;
  hint: string;
  tone: "live" | "safe" | "watch" | "infra";
}

export interface PerpsRuntimeStatus {
  name: "Clawd Perps";
  armed: boolean;
  mode: TradingMode;
  walletConfigured: boolean;
  allowedSymbols: string[];
  risk: PerpsRiskLimits;
  apiUrl: string;
  rpcConfigured: boolean;
  integrations: PerpsRuntimeConfig["integrations"];
  notes: string[];
  cards: PerpsStatusCard[];
}

export interface VulcanCatalogSummary {
  ok: boolean;
  path?: string;
  cliVersion?: string;
  groupCount?: number;
  commandCount?: number;
  dangerousCommands?: number;
  groups?: Array<{ name: string; description: string; commandCount: number }>;
  error?: string;
}

interface VulcanToolCatalog {
  cli_version?: string;
  groups?: Record<string, string>;
  commands?: Array<{
    name?: string;
    group?: string;
    dangerous?: boolean;
  }>;
}

function parseCsv(value: string | undefined): string[] {
  if (!value) {
    return [];
  }
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function normalizeSymbols(symbols: string[]): string[] {
  return symbols.map((symbol) => normalizeSymbol(symbol));
}

function firstNonEmpty(...values: Array<string | undefined>): string | undefined {
  return values.find((value) => value !== undefined && value.trim().length > 0);
}

function buildHeliusRpcUrl(apiKey?: string): string | undefined {
  if (!apiKey) {
    return undefined;
  }
  return `https://mainnet.helius-rpc.com/?api-key=${apiKey}`;
}

function parseNumber(value: string | undefined, fallback: number): number {
  if (value === undefined || value.trim() === "") {
    return fallback;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeSymbol(symbol: string): string {
  return symbol.trim().toUpperCase();
}

function hasVulcanCatalog(root: string): boolean {
  return existsSync(join(root, "vulcan-cli-master", "agents", "tool-catalog.json"));
}

function walkUpForVulcanCatalog(startPath: string): string | undefined {
  let current = resolve(startPath);

  while (true) {
    if (hasVulcanCatalog(current)) {
      return join(current, "vulcan-cli-master", "agents", "tool-catalog.json");
    }

    const parent = dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

export function resolveVulcanCatalogPath(
  env: NodeJS.ProcessEnv = process.env,
  startPath = process.cwd(),
): string | undefined {
  const explicit = firstNonEmpty(env.VULCAN_CATALOG_PATH, env.CLAWD_VULCAN_CATALOG_PATH);
  if (explicit) {
    return resolve(explicit);
  }

  const vulcanRoot = firstNonEmpty(env.VULCAN_ROOT, env.CLAWD_VULCAN_ROOT, env.CLAWD_REPO_ROOT);
  if (vulcanRoot) {
    return join(resolve(vulcanRoot), "vulcan-cli-master", "agents", "tool-catalog.json");
  }

  return walkUpForVulcanCatalog(startPath);
}

export function loadPerpsRuntimeConfig(env: NodeJS.ProcessEnv = process.env): PerpsRuntimeConfig {
  const wallet = firstNonEmpty(
    env.CLAWD_PERPS_WALLET,
    env.LOCK_WALLET_ADDRESS,
    env.CLAWD_LOCK_WALLET_ADDRESS,
  );

  return {
    rpcUrl:
      firstNonEmpty(
        env.HELIUS_RPC_URL,
        env.SOLANA_RPC_URL,
        env.RPC_URL,
        buildHeliusRpcUrl(env.HELIUS_API_KEY),
      ) ?? "",
    apiUrl: firstNonEmpty(env.CLAWD_PERPS_API_URL) ?? "https://perp-api.phoenix.trade",
    walletConfigured: Boolean(wallet),
    liveTrading: env.LIVE_TRADING === "true",
    operatorConfirmed: env.OPERATOR_CONFIRMED === "true",
    simOnly: env.PERPS_SIM_ONLY !== "false",
    risk: {
      allowedSymbols: normalizeSymbols(parseCsv(env.PERPS_ALLOWED_SYMBOLS ?? "SOL,ETH,BTC")),
      maxNotionalUsd: parseNumber(env.PERPS_MAX_NOTIONAL_USD, 250),
      maxLeverage: parseNumber(env.PERPS_MAX_LEVERAGE, 3),
      maxSpreadBps: parseNumber(env.PERPS_MAX_SPREAD_BPS, 40),
      requireWallet: env.PERPS_REQUIRE_WALLET !== "false",
    },
    integrations: {
      xaiConfigured: Boolean(env.XAI_API_KEY),
      deepseekConfigured: Boolean(env.DEEPSEEK_API_KEY),
      heliusConfigured: Boolean(env.HELIUS_API_KEY || env.HELIUS_RPC_URL || env.SOLANA_RPC_URL),
      vulcanCatalogPath: resolveVulcanCatalogPath(env),
    },
  };
}

export function resolveTradingMode(config: PerpsRuntimeConfig): TradingMode {
  if (config.liveTrading && config.operatorConfirmed && !config.simOnly) {
    return "live";
  }
  if (!config.simOnly) {
    return "paper";
  }
  return "observe";
}

export function buildPreflightReport(
  config: PerpsRuntimeConfig,
  request: PreflightRequest,
): PreflightReport {
  const blocking: string[] = [];
  const warnings: string[] = [];
  const mode = resolveTradingMode(config);
  const symbol = normalizeSymbol(request.symbol);

  if (!config.rpcUrl) {
    blocking.push("Missing HELIUS_RPC_URL, SOLANA_RPC_URL, RPC_URL, or HELIUS_API_KEY.");
  }
  if (config.risk.requireWallet && !config.walletConfigured) {
    blocking.push("Missing CLAWD_PERPS_WALLET, LOCK_WALLET_ADDRESS, or CLAWD_LOCK_WALLET_ADDRESS.");
  }
  if (!config.risk.allowedSymbols.includes(symbol)) {
    blocking.push(`Symbol ${symbol} is outside PERPS_ALLOWED_SYMBOLS.`);
  }
  if (!Number.isFinite(request.notionalUsd) || request.notionalUsd <= 0) {
    blocking.push("Notional must be positive.");
  }
  if (request.notionalUsd > config.risk.maxNotionalUsd) {
    blocking.push(
      `Notional ${request.notionalUsd} exceeds PERPS_MAX_NOTIONAL_USD=${config.risk.maxNotionalUsd}.`,
    );
  }
  if (request.leverage !== undefined && request.leverage > config.risk.maxLeverage) {
    blocking.push(
      `Leverage ${request.leverage} exceeds PERPS_MAX_LEVERAGE=${config.risk.maxLeverage}.`,
    );
  }
  if (
    request.expectedSpreadBps !== undefined &&
    request.expectedSpreadBps > config.risk.maxSpreadBps
  ) {
    blocking.push(
      `Spread ${request.expectedSpreadBps}bps exceeds PERPS_MAX_SPREAD_BPS=${config.risk.maxSpreadBps}.`,
    );
  }
  if (request.execution === "rise-live" || request.execution === "vulcan-live") {
    if (mode !== "live") {
      blocking.push(
        "Live execution disabled. Require LIVE_TRADING=true, OPERATOR_CONFIRMED=true, and PERPS_SIM_ONLY=false.",
      );
    }
    warnings.push("Live execution is preview-only in this MCP; signing and submission stay outside the server.");
  }
  if (!config.integrations.deepseekConfigured && !config.integrations.xaiConfigured) {
    warnings.push("No XAI_API_KEY or DEEPSEEK_API_KEY configured for agent reasoning.");
  }
  if (!config.integrations.vulcanCatalogPath) {
    warnings.push("Vulcan catalog not discovered; set VULCAN_CATALOG_PATH or VULCAN_ROOT for catalog posture.");
  }
  if (mode !== "live") {
    warnings.push(`Runtime mode is ${mode}; execution should remain observe/paper.`);
  }

  return {
    ok: blocking.length === 0,
    mode,
    blocking,
    warnings,
  };
}

function resolveVulcanCwd(config: PerpsRuntimeConfig): string | undefined {
  const catalogPath = config.integrations.vulcanCatalogPath;
  if (!catalogPath) {
    return undefined;
  }
  return dirname(dirname(catalogPath));
}

export function buildVulcanExecutionPlan(
  config: PerpsRuntimeConfig,
  input: VulcanExecutionIntent,
  preflight: PreflightReport,
): VulcanExecutionPlan {
  const symbol = normalizeSymbol(input.symbol ?? "SOL");
  const notional = String(input.notionalUsd ?? 100);
  const mode: TradingMode = input.action.startsWith("live")
    ? "live"
    : input.action.startsWith("paper")
      ? "paper"
      : "observe";
  const globalArgs = [
    ...(config.rpcUrl ? ["--rpc-url", config.rpcUrl] : []),
    ...(config.apiUrl ? ["--api-url", config.apiUrl] : []),
  ];
  let args: string[];

  switch (input.action) {
    case "market-list":
      args = ["market", "list", "-o", "json"];
      break;
    case "ticker":
      args = ["market", "ticker", symbol, "-o", "json"];
      break;
    case "positions":
      args = ["position", "list", "-o", "json"];
      break;
    case "paper-buy":
    case "paper-sell":
      args = [
        "paper",
        input.action === "paper-buy" ? "buy" : "sell",
        symbol,
        "--notional-usdc",
        notional,
        "--type",
        "market",
        "-o",
        "json",
      ];
      break;
    case "live-buy":
    case "live-sell":
      args = [
        "trade",
        input.action === "live-buy" ? "buy" : "sell",
        symbol,
        "--notional-usdc",
        notional,
        "--type",
        "market",
        "-o",
        "json",
      ];
      break;
  }

  return {
    transport: "cli",
    mode,
    preflight,
    command: {
      command: "vulcan",
      args: [...globalArgs, ...args],
      cwd: resolveVulcanCwd(config),
      env: { NO_COLOR: "1" },
    },
    blocked: !preflight.ok,
  };
}

export function createPaperTradePreview(
  config: PerpsRuntimeConfig,
  symbol: string,
  side: PerpsSide,
  notionalUsd: number,
  expectedSpreadBps?: number,
): TraderActionPreview {
  const preflight = buildPreflightReport(config, {
    symbol,
    notionalUsd,
    expectedSpreadBps,
    execution: "paper",
  });
  const action = side === "buy" ? "paper-buy" : "paper-sell";

  return {
    symbol: normalizeSymbol(symbol),
    side,
    notionalUsd,
    execution: "paper",
    preflight,
    route: {
      adapter: "vulcan",
      action,
      payload: buildVulcanExecutionPlan(
        config,
        {
          action,
          symbol,
          notionalUsd,
        },
        preflight,
      ),
    },
  };
}

export function createLiveTradePreview(
  config: PerpsRuntimeConfig,
  symbol: string,
  side: PerpsSide,
  notionalUsd: number,
  leverage?: number,
  expectedSpreadBps?: number,
  execution: Extract<PerpsExecution, "rise-live" | "vulcan-live"> = "rise-live",
): TraderActionPreview {
  const preflight = buildPreflightReport(config, {
    symbol,
    notionalUsd,
    leverage,
    expectedSpreadBps,
    execution,
  });
  const action = side === "buy" ? "live-buy" : "live-sell";

  return {
    symbol: normalizeSymbol(symbol),
    side,
    notionalUsd,
    execution,
    preflight,
    route:
      execution === "vulcan-live"
        ? {
            adapter: "vulcan",
            action,
            payload: buildVulcanExecutionPlan(
              config,
              {
                action,
                symbol,
                notionalUsd,
              },
              preflight,
            ),
          }
        : {
            adapter: "rise",
            action: "order.place.preview",
            payload: {
              symbol: normalizeSymbol(symbol),
              side,
              notionalUsd,
              leverage,
              expectedSpreadBps,
              blocked: !preflight.ok,
            },
          },
  };
}

function buildStatusCards(config: PerpsRuntimeConfig): PerpsStatusCard[] {
  const mode = resolveTradingMode(config);
  return [
    {
      title: "Execution Mode",
      value: mode,
      hint: "Observe and paper are default; live requires all operator gates.",
      tone: mode === "live" ? "live" : "safe",
    },
    {
      title: "Risk Envelope",
      value: `${config.risk.maxNotionalUsd} USD cap`,
      hint: `Allowed symbols: ${config.risk.allowedSymbols.join(", ")}`,
      tone: "watch",
    },
    {
      title: "Wallet Gate",
      value: config.walletConfigured ? "configured" : "missing",
      hint: "Live previews remain blocked when wallet presence is required and missing.",
      tone: config.walletConfigured ? "live" : "safe",
    },
    {
      title: "Vulcan Bridge",
      value: config.integrations.vulcanCatalogPath ? "catalog discovered" : "plan-only",
      hint: "MCP returns CLI-compatible Vulcan plans without executing trades.",
      tone: "infra",
    },
    {
      title: "Reasoning Backend",
      value: config.integrations.xaiConfigured
        ? "xAI configured"
        : config.integrations.deepseekConfigured
          ? "DeepSeek configured"
          : "missing",
      hint: "Agent reasoning can use configured model keys; risk gates do not depend on them.",
      tone: "infra",
    },
  ];
}

export function createPerpsStatus(config: PerpsRuntimeConfig = loadPerpsRuntimeConfig()): PerpsRuntimeStatus {
  const mode = resolveTradingMode(config);
  return {
    name: "Clawd Perps",
    armed: mode === "live",
    mode,
    walletConfigured: config.walletConfigured,
    allowedSymbols: config.risk.allowedSymbols,
    risk: config.risk,
    apiUrl: config.apiUrl,
    rpcConfigured: Boolean(config.rpcUrl),
    integrations: config.integrations,
    notes: [
      "Every trade preview runs preflight before building an order shape.",
      "Live tools return previews only; this MCP never signs or submits orders.",
      "Vulcan plans are CLI-compatible and blocked when preflight fails.",
    ],
    cards: buildStatusCards(config),
  };
}

export async function summarizeVulcanCatalog(
  config: PerpsRuntimeConfig = loadPerpsRuntimeConfig(),
): Promise<VulcanCatalogSummary> {
  const path = config.integrations.vulcanCatalogPath;
  if (!path || !existsSync(path)) {
    return {
      ok: false,
      path,
      error: "Vulcan tool catalog not found. Set VULCAN_CATALOG_PATH or VULCAN_ROOT.",
    };
  }

  try {
    const catalog = JSON.parse(await readFile(path, "utf8")) as VulcanToolCatalog;
    const groups = Object.entries(catalog.groups ?? {}).map(([name, description]) => ({
      name,
      description,
      commandCount: (catalog.commands ?? []).filter((command) => command.group === name).length,
    }));

    return {
      ok: true,
      path,
      cliVersion: catalog.cli_version ?? "unknown",
      groupCount: groups.length,
      commandCount: catalog.commands?.length ?? 0,
      dangerousCommands: (catalog.commands ?? []).filter((command) => command.dangerous).length,
      groups,
    };
  } catch (error) {
    return {
      ok: false,
      path,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
