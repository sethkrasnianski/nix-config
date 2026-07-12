---
description: Run just the research phase (repo-adaptation + task research) for a goal, without planning or implementing.
agent: auto-researcher
subtask: false
---
Research the goal below. Run the repo-adaptation protocol (base branch, test/lint/build commands, commit convention, any project-level harness overrides) if `.auto/research.md` doesn't already cover it for this repo, then research the task itself: relevant existing code, tests, external library/API behavior, and any ambiguities worth surfacing now. Ask clarifying questions where the goal is genuinely ambiguous. Write your findings to `.auto/research.md` and summarize them when done.

Goal:
$ARGUMENTS
