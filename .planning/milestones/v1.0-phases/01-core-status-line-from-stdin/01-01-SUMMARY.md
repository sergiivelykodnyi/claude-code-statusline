---
phase: 01-core-status-line-from-stdin
plan: 01
subsystem: cli
tags: [bash, jq, ansi, statusline, bash-3.2]

requires: []
provides:
  - "statusline.sh walking skeleton: stdin JSON → jq @sh eval → pure helpers → segment renderers → hide-empty assembler → two-line ANSI framed stdout"
  - "Pure helpers shorten_num, fmt_duration, pct_color, join_segments (bash 3.2-verified, lifted from 01-RESEARCH.md)"
  - "Segment renderers seg_model_effort, seg_dir, seg_context, seg_5h, seg_1w with hide-on-empty gates"
  - "tests/fixtures/full.json happy-path mock payload"
  - "Phase 2 seam: dir_seg held in its own variable so the git segment can append with a plain space"
affects: [01-02, phase-02-git-segment, phase-04-fable-weekly]

actuals:
  tokens: 1601
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Single-pass jq -r '@sh ...' eval ingestion with // \"\" on every field, jq stderr suppressed, no exit-code branching"
    - "ANSI named-16 palette as $'\\033[...]' byte literals printed via printf '%s' (data stays inert)"
    - "Truncate-then-guard before every arithmetic comparison (${PCT%.*}, empty→0)"
    - "Layer order: palette → pure helpers → renderers → main (ingestion + assembler); source guard for testability"

key-files:
  created:
    - statusline.sh
    - tests/fixtures/full.json
  modified: []

key-decisions:
  - "Threshold color wraps the percentage number plus its % sign (color…NN%…reset), reset before the /5h //1w //tokens labels — per the plan's binding verify greps; applied identically to all three percentage sites for consistency"
  - "Tracer feedback gate executed as automated end-to-end re-verify (not a human checkpoint): plan is autonomous:true with no checkpoint tasks and workflow.human_verify_mode=end-of-phase suppresses mid-flight human-verify halts"
  - "SGR 2 (faint) chosen for dim per research recommendation (adapts to light/dark themes; degrades to normal weight)"

patterns-established:
  - "Renderers echo their segment or the empty string; assembler joins with a dim-dot separator via join_segments (no dangling separators)"
  - "Both output lines end with RESET; printf '%s\\n' only; unconditional exit 0"

requirements-completed: [SESH-01, SESH-02, SESH-03, CTX-01, CTX-02, LIM-01, LIM-02, LIM-03, PRES-01, PRES-02, PRES-03]

coverage:
  - id: D1
    description: "Happy-path two-line framed render: line 1 '╭─ Opus 5 (high) · myproject', line 2 '╰─ 10%/100k/1M · 50%/5h (now) · 15%/1w (now)' from full.json, exit 0, empty stderr"
    requirement: PRES-01
    verification:
      - kind: integration
        ref: "/bin/bash statusline.sh < tests/fixtures/full.json | sed ANSI-strip → exact-match both lines (Task 1 + Task 2 <verify>, TRACER-OK/LIMITS-OK)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Rate-limit segments with epoch-arithmetic countdowns (2h:50m / 3d:3h:57m / 3d:1h:0m / (now)) and threshold colors at 69/70/89/90 boundaries on all three percentage sites"
    requirement: LIM-01
    verification:
      - kind: integration
        ref: "jq-mutated payloads through statusline.sh: dynamic resets_at countdown exact-match + SGR grep for green-69/yellow-70/yellow-89/red-90 (Task 2 <verify> + plan <verification>)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Dim frame/separator styling (SGR 2 faint) is visibly dim yet readable on both light and dark terminal themes (D-01/D-02, research assumption A1)"
    verification: []
    human_judgment: true
    rationale: "Visual readability across terminal themes cannot be asserted by automated byte checks — needs a human glance at a live render"

duration: 5min
completed: 2026-08-21
status: complete
---

# Phase 1 Plan 01: Core Status Line from Stdin Summary

**Walking-skeleton statusline.sh renders the full happy path — suffix-stripped model, effort, dir on line 1; context, 5h and 1w rate-limit segments with countdowns and threshold colors on line 2 — from one jq @sh pass under bash 3.2.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-21T18:29:20Z
- **Completed:** 2026-08-21T18:34:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- End-to-end tracer proven: stdin JSON → single jq `@sh` eval → pure helpers → segment renderers → hide-empty assembler → ANSI two-line framed stdout, exit 0, silent stderr
- Complete line-2 layout `pct/used/window · pct/5h (countdown) · pct/1w (countdown)` with green/yellow/red threshold colors at 70/90 cutoffs on truncated integers
- Countdowns from pure epoch arithmetic (single `date +%s`), D-09/D-10 semantics verified: `2h:50m`, `3d:3h:57m`, inner-zero `3d:1h:0m`, past reset → `(now)`
- Edge behavior verified: absent model → `╭─ myproject` (no dangling separator); multi-byte model name `Ōpus 5 (1M context)` → `Ōpus 5` byte-identically

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end framed status from stdin (tracer)** - `64b9cbe` (feat)
2. **Task 2: 5h and 1w rate-limit segments** - `4c6630c` (feat)

## Files Created/Modified

- `statusline.sh` - The status line CLI: palette, pure helpers, jq @sh ingestion, five segment renderers, hide-empty assembler, source-guarded main
- `tests/fixtures/full.json` - Happy-path mock stdin payload (floats, 1M window, suffix-carrying model name, past-epoch resets_at)

## Decisions Made

- Threshold color spans `NN%` (number + percent sign) with RESET before the labels — required by the plan's binding verify greps (`\033[33m89%`); applied to context, 5h, and 1w sites identically so all three percentage renders look the same
- SGR 2 (faint) for dim styling, per research recommendation (theme-adaptive, safe degrade)
- Tracer feedback gate run as an automated end-to-end re-verify rather than a human checkpoint (plan `autonomous: true`, no checkpoint tasks, `workflow.human_verify_mode: end-of-phase`); the dim-styling visual check is routed to end-of-phase UAT via coverage item D3

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Color-span placement contradicted the plan's verify greps**
- **Found during:** Task 2 (rate-limit segments)
- **Issue:** The action text reads "pct wrapped in pct_color (number only) + '%/5h'", which puts RESET between the number and `%` — but the task's binding `<verify>` greps for the SGR sequence directly followed by `89%`/`90%`, which failed
- **Fix:** Moved the `%` sign inside the color span (`${color}${pct}%${RESET}/5h`) on all three percentage sites (context, 5h, 1w) for consistency; labels and countdowns remain uncolored (D-05 intact)
- **Files modified:** statusline.sh
- **Verification:** Task 2 `<verify>` passes (LIMITS-OK); boundary checks 69-green/70-yellow/89-yellow/90-red pass on five_hour and context sites
- **Committed in:** 4c6630c (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — internal plan contradiction resolved in favor of the executable verify)
**Impact on plan:** Cosmetic byte-ordering only; layout, semantics, and D-05 (labels/countdowns uncolored) unchanged. No scope creep.

## Issues Encountered

- First Task 1 commit attempt failed: git commit signing could not reach the 1Password SSH agent socket from the sandbox; retried outside the sandbox successfully (documented as environment friction, not a code issue)
- A `2>&1 >/dev/null | wc -c` stderr probe reported 120 bytes due to zsh MULTIOS duplicating stdout into the pipe; authoritative `2>file` capture confirmed 0 stderr bytes

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Skeleton is production-quality and ready for Plan 02 (edge-state hardening: no-effort, no-rate-limits, null-context, empty/malformed stdin fixtures + tests/run.sh harness)
- Source guard in place so Plan 02's harness can source helpers without triggering cat/exit
- Phase 2 git-segment seam documented in main (dir_seg variable + plain-space append comment)

---
*Phase: 01-core-status-line-from-stdin*
*Completed: 2026-08-21*

## Self-Check: PASSED

- statusline.sh exists and is executable: FOUND
- tests/fixtures/full.json exists: FOUND
- Commit 64b9cbe (Task 1) in git log: FOUND
- Commit 4c6630c (Task 2) in git log: FOUND
- All task acceptance criteria and plan `<verification>` commands re-run: PASS
