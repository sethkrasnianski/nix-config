#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require() {
  local file="$1" text="$2"
  grep -qF "$text" "$ROOT/$file" || { printf 'missing %s in %s\n' "$text" "$file" >&2; exit 1; }
}

require agents/auto-history-finalizer.md 'model: github-copilot/gpt-5.6-terra'
require agents/auto-history-finalizer.md 'edit: deny'
require agents/auto-history-finalizer.md '"auto-history-finalize prepare *": allow'
require agents/auto-committer.md 'model: github-copilot/gpt-5.6-luna'
require agents/auto-implementer.md 'model: github-copilot/gpt-5.3-codex'
require agents/auto-implementer.md 'reasoningEffort: high'
if grep -q '"git \(rebase\|push\|fetch\)' "$ROOT/agents/auto-committer.md"; then
  printf 'committer must not have rewrite, push, or fetch permission\n' >&2
  exit 1
fi
require agents/auto.md 'post-plan-autonomy'
require agents/auto.md 'auto-history-finalizer'
require agents/auto-test-fixer.md 'question: deny'
require agents/auto-reviewer.md 'question: deny'
require skills/post-plan-autonomy/SKILL.md 'OUTCOME: continue | plan-delta | needs-context | safety-decision'
require install.sh 'auto-history-finalize'
require install.sh 'plugins/*.js'
require ../modules/local-llm-nixos.nix 'OLLAMA_NO_CLOUD'
require ../flake.nix 'local-config'

printf 'config contracts passed\n'
