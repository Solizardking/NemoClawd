#!/usr/bin/env node
// SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import { OpenRouter } from "@openrouter/sdk";

const apiKey = process.env.OPENROUTER_API_KEY;
const model = process.env.OPENROUTER_MODEL || "z-ai/glm-5.2";
const prompt = process.argv.slice(2).join(" ") || "How many r's are in the word 'strawberry'?";

if (!apiKey) {
  console.error("OPENROUTER_API_KEY is required.");
  process.exit(1);
}

const openrouter = new OpenRouter({
  apiKey,
});

console.log(`OpenRouter model: ${model}`);

const stream = await openrouter.chat.send({
  model,
  messages: [
    {
      role: "user",
      content: prompt,
    },
  ],
  stream: true,
  streamOptions: {
    includeUsage: true,
  },
});

let response = "";
let usage = null;

for await (const chunk of stream) {
  const content = chunk.choices?.[0]?.delta?.content;
  if (content) {
    response += content;
    process.stdout.write(content);
  }

  if (chunk.usage) {
    usage = chunk.usage;
  }
}

if (!response.endsWith("\n")) {
  process.stdout.write("\n");
}

if (usage) {
  const reasoningTokens =
    usage.reasoningTokens ?? usage.completionTokensDetails?.reasoningTokens ?? 0;
  console.log(`Reasoning tokens: ${reasoningTokens}`);
  console.log(`Total tokens: ${usage.totalTokens ?? "unknown"}`);
}
