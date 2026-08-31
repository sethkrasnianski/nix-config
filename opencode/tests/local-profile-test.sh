#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LOCAL_CONFIG="$TMP/local.nix"

write_config() {
  local build_model="$1"
  printf '%s\n' \
    '{ ... }:' \
    '{' \
    '  local.opencode.build = {' \
    "    model = \"$build_model\";" \
    '    reasoningEffort = "high";' \
    '  };' \
    '  local.opencode.plan = {' \
    '    model = "test/plan";' \
    '  };' \
    '  local.opencode.agents = {' \
    '    provider = "test-profile";' \
    '    providers."test-profile".selected = {' \
    '      model = "test/custom";' \
    '    };' \
    '  };' \
    '}' >"$LOCAL_CONFIG"
}

run_plugin() {
  local expected_build="$1"
  local expected_reasoning="$2"
  local expected_plan="$3"
  local expected_custom="$4"
  EXPECTED_BUILD="$expected_build" \
    EXPECTED_REASONING="$expected_reasoning" \
    EXPECTED_PLAN="$expected_plan" \
    EXPECTED_CUSTOM="$expected_custom" \
    OPENCODE_LOCAL_CONFIG="$LOCAL_CONFIG" \
    OPENCODE_LOCAL_PROFILE_EVALUATOR="$ROOT/local-profile.nix" \
    OPENCODE_LOCAL_LLM_PROFILE= \
    node - "$ROOT/plugins/local-llm-routing.js" <<'NODE'
(async () => {
  const { default: plugin } = await import(process.argv[2]);
  const hooks = await plugin({});
  const config = {
    model: "github-copilot/gpt-5.6-luna",
    provider: { cloud: { name: "Cloud" } },
    agent: {
      build: { model: "cloud/build", variant: "medium", options: {} },
      plan: { model: "cloud/plan", variant: "medium", options: {} },
      selected: { options: {} },
    },
  };

  hooks.config(config);

  if (config.agent.build.model !== process.env.EXPECTED_BUILD) {
    throw new Error(`unexpected Build model: ${config.agent.build.model}`);
  }
  if (process.env.EXPECTED_REASONING) {
    if (config.agent.build.options.reasoningEffort !== process.env.EXPECTED_REASONING) {
      throw new Error("Build reasoning effort was not applied");
    }
  } else if (config.agent.build.options.reasoningEffort) {
    throw new Error("Build reasoning effort was applied unexpectedly");
  }
  if (config.agent.plan.model !== process.env.EXPECTED_PLAN) {
    throw new Error(`unexpected Plan model: ${config.agent.plan.model}`);
  }
  if (process.env.EXPECTED_CUSTOM) {
    if (config.agent.selected.model !== process.env.EXPECTED_CUSTOM) {
      throw new Error(`unexpected custom model: ${config.agent.selected.model}`);
    }
  } else if (config.agent.selected.model) {
    throw new Error("custom model was applied unexpectedly");
  }
  if (config.model !== "github-copilot/gpt-5.6-luna") {
    throw new Error("the top-level model was changed");
  }
  if (config.provider.ollama) {
    throw new Error("Ollama was enabled unexpectedly");
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
}

write_config "test/build-v1"
run_plugin "test/build-v1" "high" "test/plan" "test/custom"

write_config "test/build-v2"
run_plugin "test/build-v2" "high" "test/plan" "test/custom"

rm "$LOCAL_CONFIG"
run_plugin "cloud/build" "" "cloud/plan" ""

printf 'local profile startup tests passed\n'
