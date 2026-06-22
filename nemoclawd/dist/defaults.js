"use strict";
// SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
Object.defineProperty(exports, "__esModule", { value: true });
exports.OPENROUTER_CREDENTIAL_ENV = exports.OPENROUTER_PROVIDER_NAME = exports.OPENROUTER_ENDPOINT_URL = exports.DEFAULT_OPENROUTER_MODEL = void 0;
exports.resolveDefaultOpenRouterModel = resolveDefaultOpenRouterModel;
exports.DEFAULT_OPENROUTER_MODEL = "z-ai/glm-5.2";
exports.OPENROUTER_ENDPOINT_URL = "https://openrouter.ai/api/v1";
exports.OPENROUTER_PROVIDER_NAME = "openrouter";
exports.OPENROUTER_CREDENTIAL_ENV = "OPENROUTER_API_KEY";
function resolveDefaultOpenRouterModel() {
    return process.env.OPENROUTER_MODEL || exports.DEFAULT_OPENROUTER_MODEL;
}
//# sourceMappingURL=defaults.js.map