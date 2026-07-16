# OpenCode Auto-Agent

This is the canonical OpenCode auto-agent configuration for this NixOS
configuration. Keep OpenCode-specific agents, commands, skills, helper
scripts, and tests under this directory; do not install or modify a separate
checkout.

## Improving The Agent

1. Identify the affected pipeline phase or behavior.
2. Edit the smallest relevant file under `agents/`, `commands/`, or `skills/`.
3. Preserve the approval, TDD, review, and history-safety boundaries.
4. Run the tests under `tests/` before evaluating the NixOS outputs.

The `.auto/` directory belongs to the target repository and is scratch state;
it must not be committed here.

An autonomous SWE agent harness for [OpenCode](https://opencode.ai): give it a
goal, and it takes it from research through an approved plan, strict
test-driven implementation, review, and a linear-history pull request — with
configurable models and reasoning depth per phase, and interactive
checkpoints where they matter.

Built entirely from OpenCode-native primitives (agents, skills, commands) plus
one small background script — no separate runtime, no SDK app to maintain.

## What it does

```
/auto add rate limiting to the /api/upload endpoint
```

1. **Research** (`auto-researcher`, GPT-5.6 Sol, high reasoning) — figures
   out this repo's own conventions (test/lint/build commands, commit style,
   architecture) plus whatever the task itself requires, asking you questions
   when something's genuinely ambiguous.
2. **Plan** (`auto-planner`, Claude Fable 5, max reasoning) — turns research
   into an ordered, TDD-shaped step list, surfaces real design decisions as
   questions with a recommendation, and won't proceed without your explicit
   approval.
3. **PR gate** — asks whether to open a draft PR now (with the plan as its
   body) and whether to start a background rebase watcher, *before* any code
   is written.
4. **Implement** — a strict red/green loop per step: `auto-test-writer` writes
   a failing test and verifies it fails for the right reason, `auto-implementer`
   makes it pass, `auto-test-fixer` handles failures in a bounded retry loop
   **pinned to one model tier — it never escalates to a smarter model no
   matter how many times a test fails**, and `auto-committer` produces one
   atomic Conventional Commit per green step.
5. **Review** (`auto-reviewer`, GPT-5.6 Sol, max reasoning) — a real
   review pass (correctness, security, test coverage, commit atomicity, TDD
   compliance), routed back through the same TDD loop rather than hand-patched.
   Clear in-scope discoveries and findings are handled autonomously after plan
   approval; only semantic, security, scope, blocker, destructive, and external
   publication decisions are escalated.
6. **Finalize** — a tightly-permissioned Terra agent invokes a guarded helper
   that creates a recovery ref, locally rewrites and verifies history, then
   presents one SHA-bound publish approval. History is always linear; this
   harness never merges.

## Requirements

- [OpenCode](https://opencode.ai) (tested on 1.1.14+)
- `git`, `gh` (authenticated: `gh auth login`)
- A model provider with the five models below (or your own substitutes —
  see [Changing models](#changing-models))

## Install

```bash
git clone <this-repo-url> auto-agent
cd auto-agent
./install.sh
```

This symlinks each agent, command, and skill individually into
`~/.config/opencode/{agents,commands,skills}/` (existing unrelated content is
left alone; any real pre-existing file at one of these exact names is backed
up with a timestamp, never silently overwritten), and installs the PR-watch
daemon as `auto-pr-watch` on `~/.local/bin` (add that to your `PATH` if the
installer says it's missing).

Because this installs into your **global** OpenCode config, `/auto` and its
sibling commands become available in *every* repo you open OpenCode in —
nothing repo-specific needs to be copied around. `git pull` in this repo plus
re-running `./install.sh` updates every repo at once.

```bash
./install.sh --dry-run     # preview changes without making them
./install.sh --uninstall   # remove exactly the symlinks this script created
```

## Usage

```bash
cd ~/wherever/your/actual/project/is
opencode
```

Then, in any repo:

- `/auto <goal>` — run the full pipeline end to end.
- `/research <goal>` — just the research phase (repo conventions + task
  investigation), if you want to check its findings before planning.
- `/plan` — just the planning phase, against research already on disk.
- `/implement` — just implementation (PR gate → TDD loop → review →
  finalize), against an already-approved plan.
- `/cleanup` — audit an existing codebase for verified bugs, dead code, and
  obvious low-risk refactors, committing each coherent cleanup atomically.
- `/auto-init` — scaffold a commented `.opencode/opencode.jsonc` in the
  *current* repo for project-specific overrides (see below).

You can also `@auto-researcher`, `@auto-planner`, etc. directly, or let the
`auto` primary agent (`/agent auto` or Tab-cycle to it) drive the whole thing
conversationally instead of via slash command.

## Using this in your own repos

Nothing here is repo-specific by design:

- Worktree paths, base branch, test commands, and commit conventions are all
  **discovered per repo** at the start of every task (the "repo-adaptation
  protocol" — see `agents/auto.md` and `skills/worktree-workflow/SKILL.md`),
  never hardcoded or assumed from this harness's own development.
- Task state (research notes, the plan draft, watcher logs) lives in a
  worktree-local `.auto/` directory that's excluded via the target repo's
  **local** `.git/info/exclude` — never its tracked `.gitignore`. A target
  repo needs **zero committed changes** to work with this harness.
- The PR-watch script runs from `~/.local/bin`, not from inside any
  particular repo, so it's invocable from any worktree of any project.

So: install once (above), then just `cd` into whatever repo you're working on
and run `/auto <goal>`. No per-repo setup required.

### Per-project overrides

If a specific repo wants different models, reasoning depth, or prompts than
the global defaults — run `/auto-init` inside that repo's OpenCode session.
It scaffolds a commented `.opencode/opencode.jsonc` you can safely commit and
share with your team; OpenCode merges project config over global config, so
only the fields you actually set there override this harness's defaults.
Example: pin the planner to a different reasoning effort for one particular
repo:

```jsonc
// .opencode/opencode.jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "auto-planner": { "reasoningEffort": "xhigh" }
  }
}
```

## Changing models

Every agent's model and reasoning depth is a couple of frontmatter lines in
`agents/*.md`:

| Agent | Default model | Reasoning | Why |
|---|---|---|---|
| `auto` (orchestrator) | `github-copilot/claude-sonnet-5` | medium | routing/sequencing, not implementation |
| `auto-researcher` | `github-copilot/gpt-5.6-sol` | high | broad investigation, interactive |
| `auto-planner` | `github-copilot/claude-fable-5` | max | design decisions, interactive |
| `auto-test-writer` | `github-copilot/gpt-5.6-luna` | medium | focused, mechanical |
| `auto-implementer` | `github-copilot/gpt-5.3-codex` | high | coding-specialized quality without Sol-level cost |
| `auto-test-fixer` | `github-copilot/gpt-5.6-luna` | medium | **pinned** — see below |
| `auto-reviewer` | `github-copilot/gpt-5.6-sol` | max | read-only, quality-dominant |
| `auto-committer` | `github-copilot/gpt-5.6-luna` | low | normal, bootstrap, and fixup commits only |
| `auto-history-finalizer` | `github-copilot/gpt-5.6-terra` | medium | trusted helper invocation and SHA-bound publication |

To change globally, edit the corresponding `agents/<name>.md` frontmatter and
re-run `./install.sh` (symlinks mean this is instant — no reinstall needed
for content changes, only for adding/removing files). To change for one repo
only, use `/auto-init` instead (see above) so the change doesn't affect other
projects.

The implementer deliberately uses GPT-5.3 Codex rather than Luna. Implementation
is where weak first-pass correctness creates repeated reviewer and fixer calls;
the coding-specialized model is more expensive per invocation than Luna but
substantially cheaper than Sol, making it the cost-conscious quality tier for
production code. Keep mechanical test writing, retries, and commits on Luna.

**Note on `auto-test-fixer`:** its model is a hard constraint, not a
suggestion (see `skills/tdd-loop/SKILL.md`) — the harness explicitly never
promotes a failing test to a "smarter" model, on the reasoning that repeated
failure usually means the plan step needs revision, not a better guess. You
*can* still change which model it's pinned to; you just can't make it
escalate mid-loop based on difficulty.

**Reasoning depth:** the models above (via the `github-copilot` provider)
expose effort-style reasoning (`reasoningEffort: low|medium|high|xhigh|max`),
not Anthropic-direct's `thinking.budgetTokens` — check `opencode models` and
[models.dev](https://models.dev) for your own provider's actual schema before
copying these values verbatim to a different provider/model.

The allocation reserves Fable at max for quality-critical planning, Sol at
high/max for broad research and review, Luna for focused implementation and
commit work, Sonnet for orchestration, and Terra for guarded finalization.

## The background PR watcher

When you accept the PR-gate's offer to start it, `auto-pr-watch` runs
detached in the background, periodically re-basing your branch onto the
latest base branch and force-with-lease-pushing, so a long-running task
doesn't silently drift stale behind `main`.

```bash
auto-pr-watch start <branch>              # usually started for you by the harness
auto-pr-watch status <branch>
auto-pr-watch stop <branch>
```

It never resolves conflicts itself: on an unresolvable rebase, it aborts
cleanly (verified to leave a clean working tree), drops
`.auto/NEEDS_REBASE` with resolution instructions, comments once on the PR,
and keeps retrying on its normal interval. Resolve interactively with the
`resolve-merge-conflicts` skill (`@auto` or any OpenCode session — it's not
pipeline-specific). The watcher self-exits once the PR is merged or closed.

## Ticket lookup (MCP)

`opencode.jsonc` in this repo ships two MCP server entries, disabled by
default:

```jsonc
"mcp": {
  "github": { "type": "local", "command": ["gh", "mcp"], "enabled": false },
  "jira": { "type": "remote", "url": "https://your-domain.atlassian.net/mcp", "enabled": false }
}
```

To wire up ticket lookup globally, copy the block you need into your own
`~/.config/opencode/opencode.jsonc` with `"enabled": true` (and real
credentials/URL for Jira). To enable it for one repo only, put the same
block in that repo's `.opencode/opencode.jsonc` instead (see
[Per-project overrides](#per-project-overrides)). Once enabled, mention the
ticket/issue reference in your `/auto` goal and `auto-researcher` will look
it up as part of its research pass.

## Repository layout

```
agents/      auto.md + 7 auto-*.md subagents (see table above)
agent-defaults.nix  repository-owned model and inference defaults
commands/    /auto, /research, /plan, /implement, /auto-init
skills/      address-pr-feedback, resolve-merge-conflicts, review-changes,
              frontend-design
             tdd-loop, atomic-commits, worktree-workflow
                                 — this harness's own doctrine, shared by
                                   every agent above instead of duplicated
                                   per-prompt
plugins/     local-llm-routing.js — local agent inference overlay and Ollama provider
scripts/     pr-watch.sh  (installed as `auto-pr-watch`)
install.sh
opencode.jsonc   base project config + disabled MCP stubs
tui.json         global OpenCode TUI preferences
```

Home Manager generates `~/.config/opencode/local-agents.json` from the selected
`local.opencode.agents.provider` profile, merged with any host-local provider
overrides. The bundled plugin overlays only inference fields, leaving prompts,
permissions, and other agent fields unchanged. Ollama is registered only when
`local.llm.enable` is true. Restart OpenCode after changing this profile.

## Design notes

- **The PR description is the plan artifact**, not a committed file. It
  survives every history rewrite untouched and doubles as durable,
  re-hydratable context for a fresh session, the watcher, or crash recovery —
  effectively a standing `/compact` for the task. See
  `skills/worktree-workflow/SKILL.md`.
- **History is always linear.** This harness rebases, never merges. Only
  commits unique to the working branch are ever rewritten; force-pushes are
  always `--force-with-lease`, never bare `--force`. See
  `skills/atomic-commits/SKILL.md`.
- **No model escalation on test failure.** `auto-test-fixer` runs its entire
  bounded retry loop (default: 5 attempts) on one pinned model, then stops
  and asks — it does not hand off to a "smarter" model. See
  `skills/tdd-loop/SKILL.md`.
- **Every `question` tool call is mirrored as plain chat text** in the same
  turn, across every agent and adapted skill. Some clients (e.g. certain
  `agent-shell` builds) render the structured question UI unreliably; the
  plain-text mirror keeps the question answerable regardless.
