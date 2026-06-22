/**
 * Handler for the /nemoclawd slash command (chat interface).
 *
 * Supports subcommands:
 *   /nemoclawd status   - show sandbox/blueprint/inference state
 *   /nemoclawd eject    - rollback to host installation
 *   /nemoclawd          - show help
 */
import type { PluginCommandContext, PluginCommandResult, OpenClawPluginApi } from "../index.js";
export declare function handleSlashCommand(ctx: PluginCommandContext, _api: OpenClawPluginApi): PluginCommandResult;
//# sourceMappingURL=slash.d.ts.map