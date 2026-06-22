// SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

export const DEFAULT_OPENROUTER_MODEL = "z-ai/glm-5.2";
export const OPENROUTER_ENDPOINT_URL = "https://openrouter.ai/api/v1";
export const OPENROUTER_PROVIDER_NAME = "openrouter";
export const OPENROUTER_CREDENTIAL_ENV = "OPENROUTER_API_KEY";

export function resolveDefaultOpenRouterModel(): string {
  return process.env.OPENROUTER_MODEL || DEFAULT_OPENROUTER_MODEL;
}
