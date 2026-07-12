---
name: tdd-loop
description: Use when implementing a planned unit of work test-first inside the auto-agent harness — writing a failing test, verifying it fails for the right reason, implementing the minimum to pass, and handling failures without escalating models. Use for each step of an approved plan, not for exploratory or throwaway scripts.
metadata:
  audience: auto-test-writer, auto-implementer, auto-test-fixer, auto agents
  workflow: auto-agent
---

# TDD Loop

This skill encodes the harness's non-negotiable test-first discipline: every behavior change starts with a test that fails for the right reason, then the smallest implementation that makes it pass. It exists so `auto-test-writer`, `auto-implementer`, and `auto-test-fixer` share one protocol instead of improvising independently.

## Core Principles

- Red before green, always. A test that has never been observed failing proves nothing — it may be vacuous, miswired, or testing the wrong thing.
- Write the test against the *interface you wish existed*, not the implementation you're about to write. If the interface doesn't compile/resolve yet, that's an acceptable form of "red."
- One unit of behavior per red/green cycle. Do not batch multiple unrelated behaviors into one giant failing test file before writing any implementation.
- BDD-style (`describe`/`it`, Given/When/Then, feature files) and classic TDD (unit test per function/method) are both acceptable — follow whatever convention the target repo already uses (discovered per the repo-adaptation protocol in `auto.md`/`auto-researcher.md`). Default to the repo's existing test style; if the repo has none yet, default to the test framework already in its manifest, or ask.
- **Never promote a failing test to a higher-tier model.** The test-fixer loop runs on the same pinned model for its entire duration (see `auto-test-fixer.md`), regardless of how many attempts it takes. Escalating model tier on failure is explicitly disallowed by this harness — it hides the fact that a task may need re-planning, not a smarter guess.
- After a bounded number of failed fix attempts (default 5, configurable per agent), stop looping and return a structured `plan-delta` outcome to the orchestrator rather than continuing indefinitely on the same model.
- Every commit produced from this loop bundles the test(s) and the implementation that satisfies them together (see `atomic-commits` skill) — never a commit with new behavior and no test, or a test committed alone with a TODO to implement later.

## Required Workflow

### 1. Confirm The Unit Of Work

Before writing a test, restate the single behavior this cycle targets, taken from the current step in `.auto/plan.md` (see `worktree-workflow` skill). If the step is too large to describe as one behavior in a sentence, it should have been split further at planning time — flag this back to the orchestrator rather than silently writing a sprawling test.

### 2. Discover The Repo's Test Command

Before writing anything, confirm how tests actually run in this repo. Prefer, in order:

1. `.auto/research.md` findings from the repo-adaptation protocol (test command, framework, file naming/location conventions).
2. Repo docs: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`.
3. Manifest scripts: `package.json` `scripts.test`, `Makefile` `test:` target, `Cargo.toml` + `cargo test`, `pyproject.toml`/`tox.ini`, CI config (`.github/workflows/*.yml`) test steps.
4. Ask the user only if none of the above yield a usable command.

Record the discovered command if not already recorded, so every later cycle reuses it verbatim instead of re-deriving it.

### 3. Write The Failing Test First

Write the test (or tests) for the behavior identified in step 1. Follow the repo's existing test file naming, location, fixture, and mocking conventions — do not introduce a new test style into a repo that already has one.

Keep the test focused: it should fail for exactly one reason (the behavior doesn't exist yet), not for incidental reasons like a typo, missing import unrelated to the feature, or misconfigured fixture.

### 4. Verify Red For The Right Reason

Run the discovered test command scoped to the new test(s) if the framework supports scoping, otherwise the full suite. Confirm:

- The new test(s) fail.
- The failure message matches the *expected* absence of behavior (e.g., "function not defined," "assertion failed on the not-yet-implemented behavior") — not an unrelated error (syntax error, import error, fixture crash, wrong test even running).
- No pre-existing tests newly fail as a side effect of adding the test file (e.g., shared fixture mutation).

If the test fails for the wrong reason, fix the test itself (not the production code) and re-verify red. Do not proceed to implementation on a test that is red for an unintended reason — that produces a false "green" later that doesn't actually validate the target behavior.

If, after reasonable effort, the test cannot be made to fail for the right reason, stop and ask the user rather than guessing at test infrastructure that may be unfamiliar.

### 5. Implement The Minimum To Pass

Write the smallest, most direct implementation that makes the red test(s) pass. Avoid:

- Speculative generalization beyond what the current step's plan calls for.
- Unrelated refactors bundled into this cycle (a refactor is its own commit — see `atomic-commits` skill).
- Silencing the test (e.g., loosening an assertion, adding `skip`/`xfail`) instead of implementing real behavior.

### 6. Verify Green

Run the same discovered test command. Confirm:

- The new test(s) now pass.
- No previously passing tests regressed. Run the full relevant suite (not just the new test) before calling this cycle green — a scoped pass is not sufficient evidence for a commit.

### 7. Handle Failure Without Escalating

If step 6 fails (test still red, or other tests regressed):

- Diagnose using the actual failure output — read the assertion diff, stack trace, or error message rather than re-guessing blindly.
- Make one focused fix attempt per iteration; re-run verification after each attempt.
- Stay on the same pinned model for every attempt in this loop. Do not switch to a higher-tier model mid-loop under any circumstance — this is a hard constraint of the harness, not a per-task judgment call.
- Track attempt count. After the configured limit (default 5) is reached without success:
  1. Stop looping.
  2. Summarize what was tried, the current failure output, and your best hypothesis for why it's still failing.
  3. Return `OUTCOME: plan-delta` with that diagnostic context. The orchestrator runs one targeted research pass and one bounded post-approval plan adjustment, then brokers a user question only if the resulting structured outcome requires context or a safety decision.
  4. Do not ask the user directly, silently abandon the step, or fabricate a passing result.

### 8. Commit The Green Cycle

Once green, hand off to the atomic-commits protocol: stage exactly the hunks belonging to this behavior (test + implementation together), and produce one Conventional Commit for the cycle. Do not leave the working tree with an uncommitted green state before starting the next cycle — each cycle should end in a clean, committed, green state so any interruption (crash, user pause) leaves recoverable history.

### 9. Refactor (Optional, Separate Commit)

If the green implementation reveals an obvious, low-risk cleanup (rename, extract, dedupe) that doesn't change behavior, it may follow as its own `refactor:` commit — re-running the full test suite to confirm still-green before committing. Do not fold refactor hunks into the feature/fix commit from step 8.

## Stop And Ask Conditions

- The plan step is too coarse to express as a single testable behavior.
- The test cannot be made to fail for the right reason after reasonable effort.
- The fix-attempt limit is reached (return `plan-delta` per step 7).
- The repo's test command cannot be determined from research, docs, manifests, or CI config.
- A "fix" would require weakening an existing test's assertions rather than correcting the implementation.
- Making the test pass would require touching code outside the scoped step in a way the plan didn't anticipate.

## Important Constraints

- Never write implementation code before a corresponding test has been verified red.
- Never mark a step done on a test that is green for the wrong reason (vacuous assertion, skipped test, mocked-out subject under test).
- Never escalate to a higher-tier model within the fix loop; only the user can decide to change models, and only between cycles, not mid-loop.
- Never bundle a refactor into the same commit as the red-to-green behavior change.
- Never silently loop forever — the attempt limit is a hard stop, not a suggestion.
