---
description: Audit the current codebase for verified bugs, dead code, and obvious low-risk refactors, then commit each cleanup atomically.
agent: cleanup
subtask: false
---
Audit the current repository for existing bugs, dead code, and obvious,
low-risk refactors. Follow the `cleanup` agent instructions completely:
inspect first, preserve unrelated user changes, verify each finding, add focused
tests for behavioral fixes, run the repository's relevant checks, and make one
atomic commit per coherent cleanup. Do not broaden scope into feature work or
rewrite history.

Additional focus or constraints:
$ARGUMENTS
