---
name: post-plan-autonomy
description: Use after initial plan approval to classify discoveries and keep an auto-agent task moving without routine user interruptions.
---

# Post-Plan Autonomy

After plan approval, the orchestrator is the sole user-question broker. Every
subagent returns exactly one structured outcome:

```text
OUTCOME: continue | plan-delta | needs-context | safety-decision
SUMMARY: <concise factual result>
DETAILS: <evidence, paths, commands, failure output, or finding IDs>
PROPOSED_DELTA: <only for plan-delta>
QUESTION: <only for needs-context or safety-decision>
```

## Routing

- `continue`: proceed autonomously.
- `plan-delta`: update `.auto/plan.md` and the draft PR body, split or reorder
  work, then continue if the change is clearly in scope.
- `needs-context`: ask only when an ambiguous product/public contract,
  security/privacy/data/migration decision, true scope expansion, or a blocker
  remains after one targeted research-and-plan-adjustment cycle.
- `safety-decision`: ask only for external publication or destructive actions.

Correct tests, investigate failures, and remediate clear in-scope review
findings autonomously. Allow one targeted research/plan adjustment per root
cause and two review-remediation passes. Classify review items independently by
severity and actionability; non-actionable or out-of-scope items are recorded,
not silently fixed. The exact publish gate is the sole routine final question.
