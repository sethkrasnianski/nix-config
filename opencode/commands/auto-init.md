---
description: Scaffold a commented .opencode/opencode.jsonc override template in the current repo, for tuning auto-agent models/reasoning/prompts per-project without modifying the global harness install.
---
Scaffold per-project auto-agent overrides for the repo at the current working directory.

1. Check whether `.opencode/opencode.jsonc` already exists. If it does, show its current contents and ask before overwriting or merging — never clobber existing project config silently.
2. If it doesn't exist (or the user confirms), create `.opencode/opencode.jsonc` with the following commented template, adjusted only if the user gave specific overrides to apply as part of `$ARGUMENTS`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  // Per-project overrides for the auto-agent harness. Anything set here
  // wins over the globally-installed agent defaults from the auto-agent
  // repo (~/.config/opencode/agents/*.md) — OpenCode merges project config
  // over global config, keying by agent name. Delete any block below you
  // don't need; omitted fields simply inherit the global default.
  "agent": {
    // Example: pin the planner to a different model or reasoning depth
    // for this repo specifically.
    // "auto-planner": {
    //   "model": "github-copilot/gpt-5.6-sol",
    //   "reasoningEffort": "xhigh"
    // },

    // Example: this repo's tests are slow/flaky enough to warrant a
    // larger test-fixer retry budget than the harness default of 5.
    // Note: the attempt limit itself is documented in the tdd-loop skill
    // and enforced by agent instructions, not a config field — override
    // it by forking skills/tdd-loop (see below) if you need a different
    // number, not by editing this file alone.

    // Example: disable the rebase watcher prompt entirely for this repo
    // by pre-empting the question — not directly supported as a config
    // field; instead, tell the orchestrator your preference in the goal
    // prompt itself (e.g. "don't offer the PR watcher").
  }

  // Example: enable a ticket-lookup MCP for this repo only (leave disabled
  // globally, enable here if only this repo's tickets should be fetched
  // this way).
  // "mcp": {
  //   "github": { "type": "local", "command": ["gh", "mcp"], "enabled": true }
  // }
}
```

3. If the user wants to override a skill's *content* (not just an agent's model/prompt) for this repo specifically — e.g. a repo-specific twist on `tdd-loop` — remind them that skill names must stay unique across all discovery locations (project `.opencode/skills/`, global `~/.config/opencode/skills/`, and the Claude/agent-compatible mirrors). A project-local fork must use a **different name** (e.g. `tdd-loop-<reponame>`) and won't be picked up automatically by agent prompts that reference `tdd-loop` by name — only do this if truly necessary, and update the referencing agent's prompt (via an `.opencode/agents/<name>.md` override) to point at the forked skill name explicitly.

4. Report what was created/changed and remind the user this file is safe to commit — project-level auto-agent config is meant to be shared with the team, unlike `.auto/` scratch state which never gets committed (see `worktree-workflow` skill).

Additional specific overrides to apply, if any:
$ARGUMENTS
