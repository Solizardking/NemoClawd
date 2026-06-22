---
title:
  page: "NemoClawd Overview — What It Does and How It Fits Together"
  nav: "Overview"
description: "NemoClawd sandboxes OpenClaw with NVIDIA inference and declarative policy."
keywords: ["nemoclawd overview", "openclaw openshell sandbox plugin"]
topics: ["generative_ai", "ai_agents"]
tags: ["openclaw", "openshell", "sandboxing", "inference_routing", "blueprints"]
content:
  type: concept
  difficulty: technical_beginner
  audience: ["developer", "engineer"]
status: published
---

<!--
  SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
  SPDX-License-Identifier: Apache-2.0
-->

# Overview

NemoClawd is the [OpenClaw](https://openclaw.ai) plugin for [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell).
It moves OpenClaw into a sandboxed environment where every network request, file access, and inference call is governed by declarative policy.

| Capability              | Description                                                                                                                                          |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| Sandbox OpenClaw        | Creates an OpenShell sandbox pre-configured for OpenClaw, with strict filesystem and network policies applied from the first boot.                   |
| Route inference         | Configures OpenShell inference routing so agent traffic flows through OpenRouter by default with `z-ai/glm-5.2`. |
| Manage the lifecycle    | Handles blueprint versioning, digest verification, and sandbox setup.                                                                                |

## Challenge

Autonomous AI agents like OpenClaw can make arbitrary network requests, access the host filesystem, and call any inference endpoint. Without guardrails, this creates security, cost, and compliance risks that grow as agents run unattended.

## Benefits

NemoClawd provides the following benefits.

| Benefit                    | Description                                                                                                            |
|----------------------------|------------------------------------------------------------------------------------------------------------------------|
| Sandboxed execution        | Every agent runs inside an OpenShell sandbox with Landlock, seccomp, and network namespace isolation. No access is granted by default. |
| OpenRouter cloud inference | Agent traffic routes through OpenRouter with `OPENROUTER_MODEL`, transparent to the agent.                                                        |
| Declarative network policy | Egress rules are defined in YAML. Unknown hosts are blocked and surfaced to the operator for approval.                 |
| Single CLI                 | The `nemoclawd` command orchestrates the full stack: gateway, sandbox, inference provider, and network policy.           |
| Blueprint lifecycle        | Versioned blueprints handle sandbox creation, digest verification, and reproducible setup.                             |

## Use Cases

You can use NemoClawd for various use cases including the following.

| Use Case                  | Description                                                                                  |
|---------------------------|----------------------------------------------------------------------------------------------|
| Always-on assistant       | Run an OpenClaw assistant with controlled network access and operator-approved egress.        |
| Sandboxed testing         | Test agent behavior in a locked-down environment before granting broader permissions.         |
| Remote GPU deployment     | Deploy a sandboxed agent to a remote GPU instance for persistent operation.                   |

## Next Steps

Explore the following pages to learn more about NemoClawd.

- [How It Works](../about/how-it-works.md) to understand the key concepts behind NemoClawd.
- [Quickstart](../get-started/quickstart.md) to install NemoClawd and run your first agent.
- [Switch Inference Providers](../inference/switch-inference-providers.md) to configure the inference provider.
- [Approve or Deny Network Requests](../network-policy/approve-network-requests.md) to manage egress approvals.
- [Deploy to a Remote GPU Instance](../deployment/deploy-to-remote-gpu.md) for persistent operation.
- [Monitor Sandbox Activity](../monitoring/monitor-sandbox-activity.md) to observe agent behavior.
