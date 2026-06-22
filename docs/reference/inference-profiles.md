---
title:
  page: "NemoClawd Inference Profiles"
  nav: "Inference Profiles"
description: "Configuration reference for inference profiles — OpenRouter, Ollama (DeepSolana), NVIDIA Cloud, vLLM."
keywords: ["nemoclawd inference profiles", "nemoclawd openrouter", "nemoclawd deepsolana", "nemoclawd ollama", "nemoclawd nvidia cloud provider"]
topics: ["generative_ai", "ai_agents"]
tags: ["openclaw", "openshell", "inference_routing", "llms", "openrouter", "ollama", "deepsolana"]
content:
  type: reference
  difficulty: intermediate
  audience: ["developer", "engineer"]
status: published
---

<!--
  SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
  SPDX-License-Identifier: Apache-2.0
-->

# Inference Profiles

NemoClawd ships with an inference profile defined in `blueprint.yaml`.
The profile configures an OpenShell inference provider and model route.
The agent inside the sandbox uses whichever model is active.
Inference requests are routed transparently through the OpenShell gateway.

## Default: OpenRouter + `z-ai/glm-5.2`

NemoClawd defaults to the OpenRouter provider and `OPENROUTER_MODEL`, which falls back to `z-ai/glm-5.2`.

Set `OPENROUTER_API_KEY` in the host environment before running `nemoclawd onboard`, `nemoclawd setup`, or `scripts/setup.sh`.

```console
$ export OPENROUTER_API_KEY=sk-or-...
$ export OPENROUTER_MODEL=z-ai/glm-5.2

$ openshell provider create --name openrouter --type openai \
    --credential "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" \
    --config "OPENAI_BASE_URL=https://openrouter.ai/api/v1"

$ openshell inference set --no-verify --provider openrouter --model "$OPENROUTER_MODEL"
```

## Profile Summary

| Profile | Provider | Model | Endpoint | Use Case |
|---|---|---|---|---|
| `openrouter` (default) | OpenRouter | `z-ai/glm-5.2` | `openrouter.ai` | Default cloud route. Requires `OPENROUTER_API_KEY`. |
| `ollama-local` | Ollama | `8bit/DeepSolana` | `localhost:11434` | Local inference. No API key required. |
| `nvidia-nim` | NVIDIA Cloud | `nvidia/nemotron-3-super-120b-a12b` | `integrate.api.nvidia.com` | Production. Requires NVIDIA API key. |

## Available NVIDIA Cloud Models

The `nvidia-nim` provider registers the following models from [build.nvidia.com](https://build.nvidia.com):

| Model ID | Label | Context Window | Max Output |
|---|---|---|---|
| `nvidia/nemotron-3-super-120b-a12b` | Nemotron 3 Super 120B | 131,072 | 8,192 |
| `nvidia/llama-3.1-nemotron-ultra-253b-v1` | Nemotron Ultra 253B | 131,072 | 4,096 |
| `nvidia/llama-3.3-nemotron-super-49b-v1.5` | Nemotron Super 49B v1.5 | 131,072 | 4,096 |
| `nvidia/nemotron-3-nano-30b-a3b` | Nemotron 3 Nano 30B | 131,072 | 4,096 |

## Switching Models at Runtime

After the sandbox is running, switch models with the OpenShell CLI:

```console
# Switch to a different Ollama model
$ ollama pull llama3
$ openshell inference set --no-verify --provider ollama-local --model llama3

# Switch to OpenRouter
$ openshell inference set --provider openrouter --model z-ai/glm-5.2

# Switch to NVIDIA Cloud
$ openshell inference set --provider nvidia-nim --model nvidia/nemotron-3-super-120b-a12b
```

The change takes effect immediately.
No sandbox restart is needed.

## `openrouter` — Default

- **Provider type:** `openai` (OpenAI-compatible)
- **Endpoint:** `https://openrouter.ai/api/v1`
- **Model:** `z-ai/glm-5.2` unless `OPENROUTER_MODEL` overrides it
- **Credential:** `OPENROUTER_API_KEY` environment variable

Get an API key from [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys).

## `ollama-local` — Local DeepSolana

- **Provider type:** `openai` (OpenAI-compatible)
- **Endpoint:** `http://host.openshell.internal:11434/v1`
- **Model:** `8bit/DeepSolana`
- **Credential:** `OPENAI_API_KEY=ollama` (placeholder, Ollama doesn't require auth)
- **Install:** `brew install ollama` (macOS) or [ollama.ai](https://ollama.ai)

## `nvidia-nim` — NVIDIA Cloud

- **Provider type:** `nvidia`
- **Endpoint:** `https://integrate.api.nvidia.com/v1`
- **Model:** `nvidia/nemotron-3-super-120b-a12b`
- **Credential:** `NVIDIA_API_KEY` environment variable

Get an API key from [build.nvidia.com](https://build.nvidia.com).
The `nemoclawd onboard` command prompts for this key and stores it in `~/.nemoclawd/credentials.json`.
