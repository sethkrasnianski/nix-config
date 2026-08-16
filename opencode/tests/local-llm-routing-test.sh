#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/local-llm-routing.js"
PROFILE="$(mktemp)"
trap 'rm -f "$PROFILE"' EXIT

run_plugin() {
  OPENCODE_LOCAL_LLM_PROFILE="$PROFILE" node - "$PLUGIN" <<'NODE'
(async () => {
  const { default: plugin } = await import(process.argv[2]);
  const hooks = await plugin({});
  const config = {
    model: "github-copilot/gpt-5.6-luna",
    provider: { cloud: { name: "Cloud" } },
    agent: {
      build: { variant: "medium", options: { reasoningEffort: "low" } },
      plan: {
        model: "cloud/plan",
        variant: "medium",
        options: { reasoningEffort: "low" },
      },
      selected: { options: { reasoningEffort: "high" }, description: "keep" },
      untouched: { model: "cloud/model", options: { reasoningEffort: "max" } },
    },
  };
  hooks.config(config);
  console.log(JSON.stringify(config));
})();
NODE
}

printf '{"ollama":{"enable":false,"model":"qwen3-coder:30b","contextLength":65536},"agents":{"selected":{"model":"ollama/qwen3-coder:30b"}}}\n' >"$PROFILE"
default="$(run_plugin)"
[[ "$default" == *'"model":"github-copilot/gpt-5.6-luna"'* ]]
[[ "$default" != *'"ollama"'* ]]
[[ "$default" == *'"build":{"variant":"medium","options":{"reasoningEffort":"low"}}'* ]]
[[ "$default" == *'"plan":{"model":"cloud/plan","variant":"medium","options":{"reasoningEffort":"low"}}'* ]]

printf '{"model":"openai/legacy-top-level","builtInAgents":{"build":{"model":"openai/build","reasoningEffort":"high"},"plan":{"model":"openai/plan","reasoningEffort":"xhigh"}},"ollama":{"enable":false,"model":"qwen3-coder:30b","contextLength":65536},"agents":{"selected":{"model":"ollama/qwen3-coder:30b"}}}\n' >"$PROFILE"
disabled="$(run_plugin)"
[[ "$disabled" == *'"model":"github-copilot/gpt-5.6-luna"'* ]]
[[ "$disabled" != *'"ollama"'* ]]
[[ "$disabled" == *'"build":{"variant":"medium","options":{"reasoningEffort":"high"},"model":"openai/build"}'* ]]
[[ "$disabled" == *'"plan":{"model":"openai/plan","variant":"medium","options":{"reasoningEffort":"xhigh"}}'* ]]
[[ "$disabled" != *'"model":"openai/legacy-top-level"'* ]]

printf '{"builtInAgents":{"build":{"model":"ollama/build","reasoningEffort":"high"},"plan":{"model":"ollama/plan","reasoningEffort":"xhigh"}},"ollama":{"enable":true,"model":"qwen3-coder:30b","contextLength":65536},"agents":{"selected":{"model":"ollama/qwen3-coder:30b"}}}\n' >"$PROFILE"
enabled="$(run_plugin)"
[[ "$enabled" == *'"ollama"'* ]]
[[ "$enabled" == *'"model":"ollama/qwen3-coder:30b"'* ]]
[[ "$enabled" == *'"context":65536'* ]]
[[ "$enabled" == *'"model":"github-copilot/gpt-5.6-luna"'* ]]
[[ "$enabled" == *'"build":{"variant":"medium","options":{},"model":"ollama/build"}'* ]]
[[ "$enabled" == *'"plan":{"model":"ollama/plan","variant":"medium","options":{}}'* ]]
[[ "$enabled" == *'"selected":{"options":{},"description":"keep","model":"ollama/qwen3-coder:30b"'* ]]
[[ "$enabled" == *'"untouched":{"model":"cloud/model"'* ]]
[[ "$enabled" == *'"untouched":{"model":"cloud/model","options":{"reasoningEffort":"max"}}'* ]]

first="$(run_plugin)"
second="$(run_plugin)"
[[ "$first" == "$second" ]]
printf 'local LLM routing tests passed\n'
