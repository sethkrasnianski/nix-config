---
description: Run just the planning phase against existing research, producing a TDD-shaped plan and getting explicit approval. Does not implement.
agent: auto-planner
subtask: false
---
Read `.auto/research.md` (run `/research` first if it doesn't exist yet for this goal) and produce an ordered, TDD-shaped implementation plan for it, following your agent instructions and the `tdd-loop` skill's shape for what makes a step plannable. Surface design decisions as questions with a recommended option rather than silently choosing. Write the plan to `.auto/plan.md` and do not finish until the user has explicitly approved it (or you're explicitly told to leave it in draft for later approval).

Additional context or goal refinement, if any:
$ARGUMENTS
