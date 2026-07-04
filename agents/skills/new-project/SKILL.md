---
name: new-project
description: Bootstrap a new application or project from scratch. Use when asked to create, scaffold, start, or bootstrap a new project, app, service, or library.
---

# Bootstrapping a new project

Give every new project a Nix dev environment, direnv activation, agent
instructions, and living documentation. Adapt contents to the language/stack
being used — prefer its idioms over generic boilerplate.

## Files to create

1. **flake.nix** — dev environment from nixpkgs: `devShells.default` with the
   stack's toolchain (runtime/compiler, package manager, LSP, formatter).
2. **.envrc** — `use flake`; remind the user to run `direnv allow`.
3. **AGENTS.md** — source of truth for agent instructions. Succinct initial
   instructions: what the project is, layout, build/test/run, conventions that
   prefer the idioms of the chosen language/technologies. Include standing
   instructions for agents: keep README.md as living documentation, and
   self-update AGENTS.md as the project expands — without bloating it.
4. **CLAUDE.md** — exactly one line: `@AGENTS.md`. Never duplicate content.
5. **README.md** — succinct, complete overview: what it is, setup
   (nix/direnv), how to run.
6. **.gitignore** — stack-appropriate, plus Nix/direnv artifacts (`result`,
   `result-*`, `.direnv/`).

## Then

- `git init` (if needed) and `git add -A` — flakes only see tracked files, so
  the dev shell fails to evaluate until files are staged.
- Verify: `nix develop -c <tool> --version` (or `direnv exec . <tool> --version`).
