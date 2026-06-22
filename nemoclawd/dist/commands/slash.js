"use strict";
// SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleSlashCommand = handleSlashCommand;
const state_js_1 = require("../blueprint/state.js");
const config_js_1 = require("../onboard/config.js");
function handleSlashCommand(ctx, _api) {
    const subcommand = ctx.args?.trim().split(/\s+/)[0] ?? "";
    switch (subcommand) {
        case "status":
            return slashStatus();
        case "eject":
            return slashEject();
        case "onboard":
            return slashOnboard();
        default:
            return slashHelp();
    }
}
function slashHelp() {
    return {
        text: [
            "**NemoClawd**",
            "",
            "Usage: `/nemoclawd <subcommand>`",
            "",
            "Subcommands:",
            "  `status`  - Show sandbox, blueprint, and inference state",
            "  `eject`   - Show rollback instructions",
            "  `onboard` - Show onboarding status and instructions",
            "",
            "For full management use the CLI:",
            "  `openclaw nemoclawd status`",
            "  `openclaw nemoclawd migrate`",
            "  `openclaw nemoclawd launch`",
            "  `openclaw nemoclawd connect`",
            "  `openclaw nemoclawd eject --confirm`",
        ].join("\n"),
    };
}
function slashStatus() {
    const state = (0, state_js_1.loadState)();
    if (!state.lastAction) {
        return {
            text: "**NemoClawd**: No operations performed yet. Run `openclaw nemoclawd launch` or `openclaw nemoclawd migrate` to get started.",
        };
    }
    const lines = [
        "**NemoClawd Status**",
        "",
        `Last action: ${state.lastAction}`,
        `Blueprint: ${state.blueprintVersion ?? "unknown"}`,
        `Run ID: ${state.lastRunId ?? "none"}`,
        `Sandbox: ${state.sandboxName ?? "none"}`,
        `Updated: ${state.updatedAt}`,
    ];
    if (state.migrationSnapshot) {
        lines.push("", `Rollback snapshot: ${state.migrationSnapshot}`);
    }
    return { text: lines.join("\n") };
}
function slashOnboard() {
    const config = (0, config_js_1.loadOnboardConfig)();
    if (config) {
        return {
            text: [
                "**NemoClawd Onboard Status**",
                "",
                `Endpoint: ${config.endpointType} (${config.endpointUrl})`,
                config.ncpPartner ? `NCP Partner: ${config.ncpPartner}` : null,
                `Model: ${config.model}`,
                `Credential: $${config.credentialEnv}`,
                `Profile: ${config.profile}`,
                `Onboarded: ${config.onboardedAt}`,
                "",
                "To reconfigure, run: `openclaw nemoclawd onboard`",
            ]
                .filter(Boolean)
                .join("\n"),
        };
    }
    return {
        text: [
            "**NemoClawd Onboarding**",
            "",
            "No configuration found. Run the onboard command to set up inference:",
            "",
            "```",
            "openclaw nemoclawd onboard",
            "```",
            "",
            "Or non-interactively:",
            "```",
            'openclaw nemoclawd onboard --api-key "$NVIDIA_API_KEY" --endpoint build --model nvidia/nemotron-3-super-120b-a12b',
            "```",
        ].join("\n"),
    };
}
function slashEject() {
    const state = (0, state_js_1.loadState)();
    if (!state.lastAction) {
        return { text: "No NemoClawd deployment found. Nothing to eject from." };
    }
    if (!state.migrationSnapshot && !state.hostBackupPath) {
        return {
            text: "No migration snapshot found. Manual rollback required.",
        };
    }
    return {
        text: [
            "**Eject from NemoClawd**",
            "",
            "To rollback to your host OpenClaw installation, run:",
            "",
            "```",
            "openclaw nemoclawd eject --confirm",
            "```",
            "",
            `Snapshot: ${state.migrationSnapshot ?? state.hostBackupPath ?? "none"}`,
        ].join("\n"),
    };
}
//# sourceMappingURL=slash.js.map