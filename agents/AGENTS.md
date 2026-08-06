# Global agent instructions

Tool-agnostic guidance applied across every project. Source of truth lives in
this repo's `agents/AGENTS.md`; each agent CLI reads it through an alias into
`~/.agents` (see `home/default.nix`).

## General guidelines

- Favor quality, simplicity, robustness, scalability, and long-term maintainability when making technical decisions; do not over-optimize for short-term development cost.
- Begin bug fixes by reproducing the issue. Prefer an end-to-end reproduction that closely matches the affected user experience.
- Hold end-to-end tests to a high visual standard, including pixel-level accuracy. If an unrelated visual defect is clearly apparent, consider addressing it as a separate atomic fix.
- Treat lint errors, test failures, and flaky tests as engineering defects that require resolution. When unrelated failures surface, consider addressing them as a separate atomic fix.
- Finalize plans as atomic, independently reviewable units of work. Each unit must
  include its verification, precise staging, and commit step before the next unit
  begins. Never include unrelated pre-existing changes in a plan commit. Before
  reporting the plan complete, run `git status` and confirm no planned changes
  remain staged or unstaged.

## Code Search

When the client exposes the external `code-search` skill, use it for initial
discovery in an unfamiliar repository, semantic searches across files, or
finding implementations related to a known location. Do not try to resolve
that external skill through the current project's `.agents/` directory. For a
single known file or symbol, use the client's built-in file/content search
directly instead of invoking the skill.
