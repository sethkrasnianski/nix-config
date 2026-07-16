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
disabled="$(run_plugin)"
[[ "$disabled" == *'"model":"github-copilot/gpt-5.6-luna"'* ]]
[[ "$disabled" != *'"ollama"'* ]]

printf '{"ollama":{"enable":true,"model":"qwen3-coder:30b","contextLength":65536},"agents":{"selected":{"model":"ollama/qwen3-coder:30b"}}}\n' >"$PROFILE"
enabled="$(run_plugin)"
[[ "$enabled" == *'"ollama"'* ]]
[[ "$enabled" == *'"model":"ollama/qwen3-coder:30b"'* ]]
[[ "$enabled" == *'"context":65536'* ]]
[[ "$enabled" == *'"selected":{"options":{},"description":"keep","model":"ollama/qwen3-coder:30b"'* ]]
[[ "$enabled" == *'"untouched":{"model":"cloud/model"'* ]]
[[ "$enabled" == *'"untouched":{"model":"cloud/model","options":{"reasoningEffort":"max"}}'* ]]

first="$(run_plugin)"
second="$(run_plugin)"
[[ "$first" == "$second" ]]
printf 'local LLM routing tests passed\n'
