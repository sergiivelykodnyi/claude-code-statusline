---
phase: 01-core-status-line-from-stdin
plan: 02
subsystem: testing
tags: [bash, jq, fixtures, regression-harness, bash-3.2, ansi]

requires:
  - phase: 01-core-status-line-from-stdin (plan 01)
    provides: "statusline.sh walking skeleton with pure helpers, segment renderers, hide-empty assembler, source guard, tests/fixtures/full.json"
provides:
  - "Six edge-state fixtures: no-effort, no-rate-limits, only-five-hour, null-context (D-12), empty (zero bytes), malformed (D-13)"
  - "tests/run.sh — 66-check never-fail regression harness: helper unit tables (via BASH_SOURCE guard), 7-fixture end-to-end loop with exit/stderr contract, live countdowns, threshold SGR byte placement, palette purity, T-01-01 injection probe"
  - "Proof that Plan 01's gate structure already satisfies every edge state — statusline.sh unchanged this plan"
affects: [phase-02-git-segment, phase-03-install, phase-04-fable-weekly]

actuals:
  tokens: 2239
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Table-driven unit checks by sourcing statusline.sh under its BASH_SOURCE guard (stdin from /dev/null)"
    - "End-to-end assertions capture stdout, stderr, and exit code separately; compare ANSI-stripped lines byte-exactly"
    - "colon-delimited pair lists for bash-3.2-safe test tables (no assoc arrays)"

key-files:
  created:
    - tests/run.sh
    - tests/fixtures/no-effort.json
    - tests/fixtures/no-rate-limits.json
    - tests/fixtures/only-five-hour.json
    - tests/fixtures/null-context.json
    - tests/fixtures/empty.json
    - tests/fixtures/malformed.json
  modified: []

key-decisions:
  - "statusline.sh required zero changes: Plan 01's hide-on-empty gates, // \"\" defaults, truncate-then-guard arithmetic, and structural fall-through (seg_dir PWD fallback + bare-frame assembler) already held for the entire Fixture Matrix on first run (EDGES-OK)"
  - "Threshold-byte checks assert the full span ESC[{code}m{NN}%ESC[0m/5h — proving both the boundary color and D-05 (label/countdown outside the colored span) in one assertion"
  - "Harness cd's to repo root from its own dirname, so the D-13 fallback expectation is computed at runtime from the harness's PWD basename"

patterns-established:
  - "tests/run.sh is the phase regression net: Phases 2-4 re-run it before touching the render path"
  - "Vacuity guard: breaking a helper threshold makes the harness exit non-zero (spot-checked, 6 FAILs)"

requirements-completed: [LIM-04, PRES-04, PORT-03, CTX-01, SESH-02, PRES-03]

coverage:
  - id: D1
    description: "Every fixture (full, no-effort, no-rate-limits, only-five-hour, null-context, empty, malformed) renders its exact matrix lines with exit 0 and zero stderr bytes under /bin/bash"
    requirement: PORT-03
    verification:
      - kind: integration
        ref: "tests/run.sh end-to-end loop (28 checks: exit code, stderr bytes, line 1, line 2 per fixture)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Independent segment hides with no dangling separators (SESH-02 effort hide, LIM-04 per-window hides, PRES-04 join) and D-12 context zero-state 0%/0/200k rendered green, never popping in"
    requirement: LIM-04
    verification:
      - kind: integration
        ref: "tests/run.sh: no-effort/no-rate-limits/only-five-hour/null-context fixture assertions + GREEN-SGR-before-0% check in Task 1 verify"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-13 worst case: empty and malformed stdin degrade to framed PWD basename + bare bottom frame, exit 0, keyed off empty MODEL/DIR after eval (never jq's exit code)"
    requirement: PRES-04
    verification:
      - kind: integration
        ref: "tests/run.sh empty/malformed fixture assertions + grep proving no jq exit-status branch in statusline.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "Durable harness contract: helper tables (D-08/D-09/D-10/PRES-03 boundaries), live countdowns, threshold SGR bytes, palette purity (D-02), injection probe (T-01-01) — 66 checks, non-vacuous"
    requirement: PRES-03
    verification:
      - kind: unit
        ref: "/bin/bash tests/run.sh — 66 checks, 0 failures; vacuity spot-check: broken shorten_num threshold => exit 1 with 6 FAILs"
        status: pass
    human_judgment: false
  - id: D5
    description: "Dim frame/separator styling (SGR 2 faint) is visibly dim yet readable on both light and dark terminal themes (plan <verification> human-check, research assumption A1, D-02)"
    verification: []
    human_judgment: true
    rationale: "Visual readability of SGR 2 across terminal themes needs a human glance at a live render; routed to end-of-phase UAT per workflow.human_verify_mode=end-of-phase (carried from Plan 01 coverage D3)"

duration: 5min
completed: 2026-08-21
status: complete
---

# Phase 1 Plan 02: Edge-State Hardening + Regression Harness Summary

**Six edge-state fixtures plus a 66-check tests/run.sh harness prove the never-fail contract — every absent/null/zero/malformed input renders exactly per the matrix with exit 0 and silent stderr, and statusline.sh needed zero changes to pass.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-21T18:37:03Z
- **Completed:** 2026-08-21T18:42:30Z
- **Tasks:** 2
- **Files modified:** 7 (all created)

## Accomplishments

- Created the full edge-fixture set derived from full.json via jq: effort absent, rate_limits absent, seven_day-only absent, D-12 null-context zero-state, zero-byte empty, and `not json` malformed
- Proved every Fixture Matrix state passes against the unmodified Plan 01 script on first run (EDGES-OK) — hide gates, D-12 `0%/0/200k` green zero-state, D-13 structural fall-through, arithmetic guards all held
- Built `tests/run.sh` (163 lines, bash 3.2-safe, executable): 66 PASS checks covering syntax gate, the complete D-08/D-09/D-10 helper tables, the 69/70/89/90 pct_color quartet, join_segments, all seven fixtures end-to-end (exit 0 + zero stderr bytes + exact ANSI-stripped lines), live countdowns `(2h:50m)`/`(3d:3h:57m)`, threshold SGR byte placement with D-05 reset-before-label, palette purity (only 0m/2m/31m/32m/33m/34m/36m), and the T-01-01 injection probe with a `tests/.pwned` canary
- Proved the harness non-vacuous: a deliberately broken `shorten_num` threshold makes it exit 1 with 6 FAIL lines (restored cleanly)

## Task Commits

Each task was committed atomically:

1. **Task 1: Edge-state fixtures (hide gates, D-12, D-13)** - `c713240` (test)
2. **Task 2: tests/run.sh durable never-fail harness** - `638bb49` (test)

## Files Created/Modified

- `tests/run.sh` - 66-check regression harness: sources statusline.sh helpers via its BASH_SOURCE guard, asserts fixtures end-to-end, threshold bytes, palette, injection safety
- `tests/fixtures/no-effort.json` - SESH-02 effort-hide payload
- `tests/fixtures/no-rate-limits.json` - LIM-04 both-windows-absent payload
- `tests/fixtures/only-five-hour.json` - independently-absent seven_day payload
- `tests/fixtures/null-context.json` - D-12 zero-state payload (null pct, 0 tokens, 200k window)
- `tests/fixtures/empty.json` - zero-byte D-13 payload
- `tests/fixtures/malformed.json` - `not json` D-13 payload

## Decisions Made

- **No statusline.sh edits:** the plan's Task 1 instruction "complete every state that does not already hold" resolved to nothing — Plan 01's gate structure already satisfied all six new fixtures and every acceptance criterion (green-before-0%, no `null` word, no jq exit-status branch). Committed fixtures only, documented in the commit message.
- **Threshold assertion as a single byte-span:** matching `ESC[{code}m{NN}%ESC[0m/5h` verifies boundary color and D-05 span limits in one check.
- **Runtime PWD expectation for D-13 fixtures:** the harness computes `╭─ ${PWD##*/}` after cd'ing to repo root, so it passes from any invocation directory.

## Deviations from Plan

None - plan executed exactly as written. (Task 1 listed statusline.sh in `<files>` as a may-modify target; no modification proved necessary, which the plan's own wording anticipated.)

## Issues Encountered

- Git commit signing cannot reach the 1Password SSH agent socket from the sandbox (known from Plan 01); both task commits were retried outside the sandbox per the orchestrator's standing instruction.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 contract is fully locked: `/bin/bash tests/run.sh` is the one-command regression net Phases 2-4 must re-run before touching the render path (Phase 2 inserts the git segment at the documented `dir_seg` seam)
- Outstanding for end-of-phase UAT: the dim-styling visual check (coverage D5 here, carried from Plan 01's D3) — light/dark theme readability of SGR 2 faint
- Phase 2 (git segment) can start; PORT-02 render-latency budget is assigned there

---
*Phase: 01-core-status-line-from-stdin*
*Completed: 2026-08-21*

## Self-Check: PASSED

- tests/run.sh exists and is executable: FOUND
- All six new fixtures exist (empty.json is 0 bytes): FOUND
- Commit c713240 (Task 1) in git log: FOUND
- Commit 638bb49 (Task 2) in git log: FOUND
- `/bin/bash tests/run.sh`: 66 checks, 0 failures, exit 0; tests/.pwned absent
- Plan `<verification>` spot check `printf '' | /bin/bash statusline.sh`: rc=0, two frame lines, 0 stderr bytes
