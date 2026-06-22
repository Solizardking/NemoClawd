---
title:
  page: "NemoClawd Release Notes"
  nav: "Release Notes"
description: "Changelog and feature history for NemoClawd releases."
keywords: ["nemoclawd release notes", "nemoclawd changelog"]
topics: ["generative_ai", "ai_agents"]
tags: ["nemoclawd", "releases"]
content:
  type: reference
  difficulty: technical_beginner
  audience: ["developer", "engineer"]
status: published
---

<!--
  SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
  SPDX-License-Identifier: Apache-2.0
-->

# Release Notes

NemoClawd is in active development and follows a frequent release cadence. Use the following GitHub resources directly.

## 2026-06-22

- Renamed local package, CLI, plugin, MCP server, blueprint paths, scripts, state directories, and docs to the `nemoclawd` spelling.
- Updated the OpenClaw runtime pin to `2026.6.9` and aligned OpenShell installation docs with NVIDIA's current upstream installer and `uv tool install -U openshell` path.
- Synced docs with NVIDIA upstream v0.0.64 themes: restore safety for custom policy presets, more stable OpenClaw onboarding, chat-completions fallback for NVIDIA/NIM-compatible routes, and messaging setup recovery.

| Resource | Description |
|---|---|
| [Releases](https://github.com/x402agent/NemoClawd/releases) | Versioned release notes and downloadable assets. |
| [Release comparison](https://github.com/x402agent/NemoClawd/compare) | Diff between any two tags or branches. |
| [Merged pull requests](https://github.com/x402agent/NemoClawd/pulls?q=is%3Apr+is%3Amerged) | Individual changes with review discussion. |
| [Commit history](https://github.com/x402agent/NemoClawd/commits/main) | Full commit log on `main`. |
