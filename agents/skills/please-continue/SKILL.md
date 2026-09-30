---
name: please-continue
description: >
  Wake up and resume interrupted work. Use after the workstation slept, lost
  internet, or the session stalled mid-task — when the user says
  "/please-continue", "continue", "wake up", "are you still there", or the
  agent has been sitting idle with work unfinished.
---

# please-continue

You went to sleep mid-task — the workstation slept or lost its connection, and
you have been sitting there doing nothing. Wake up and continue.

1. **Re-orient from evidence, not memory.** The interruption may have killed
   things silently. Check the actual state before resuming:
   - the last task you were working on in this conversation (re-read your own
     last messages for what you promised to do next)
   - `git status` / current branch — did an in-flight rebase, commit, or edit
     land, half-land, or abort?
   - background tasks and their output files (e.g. `/tmp/review-with-*.md`,
     running `claude`/`codex` processes) — a subprocess that was running when
     the machine slept is probably dead; check for partial/empty output.
2. **Resume, don't restart.** Pick up from the last completed step. Re-run only
   what verifiably didn't finish (dead subprocess, empty output file,
   uncommitted half-done edit). Do not redo finished work, and do not ask the
   user whether to continue — continuing is the instruction.
3. If the interruption genuinely lost something unrecoverable, or the resumed
   work needs a decision the transcript doesn't answer, say exactly what was
   lost or is needed — one line — and continue with everything else.

Report briefly: where you found the state, what you resumed, what (if anything)
was lost.
