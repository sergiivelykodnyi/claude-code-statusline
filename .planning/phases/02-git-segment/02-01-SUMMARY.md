---
phase: 02-git-segment
plan: 01
subsystem: ui
tags: [bash, git, porcelain-v2, ansi, statusline]

requires:
  - phase: 01-core-statusline
    provides: "statusline.sh segment-renderer skeleton (seg_* pattern, join_segments, palette, never-fail contract) and tests/run.sh harness"
provides:
  - "seg_git renderer: branch, dirty star, upstream sync symbol, ahead/behind counts, stash count with semantic per-marker colors"
  - "MAGENTA palette constant (35m) for the branch label"
  - "Frameless flush-left two-line layout with blank-line-2 invariant (D-21/D-22/D-23)"
  - "Harness updated: frame-free expectations, 35m whitelist, two-line invariant check (67 checks)"
affects: [02-git-segment plan 02 (latency + git-state tests), 03-install-readme, 04-fable-weekly]

actuals:
  tokens: 3800
  tasks: 2
  commits: 1

tech-stack:
  added: []
  patterns:
    - "Single GIT_OPTIONAL_LOCKS=0 porcelain-v2 status call parsed with a bash-3.2-safe here-string read loop (no subshell variable loss)"
    - "Per-marker semantic coloring with RESET after each colored span"

key-files:
  created: []
  modified: [statusline.sh, tests/run.sh]

key-decisions:
  - "Each colored span covers the whole token (symbol plus number) for glanceability — planner discretion resolved in-plan"
  - "Task 2 required zero code changes: Task 1's porcelain mapping already covered detached/unborn/no-upstream states exactly"

patterns-established:
  - "seg_git guard: renders only from stdin workspace dir ($DIR), never $PWD — keeps D-23 fallback bare and fixtures deterministic"
  - "here-string parse loop: while IFS= read -r ... done <<< \"$status\" keeps parsed vars in the calling shell on bash 3.2"

requirements-completed: [GIT-01, GIT-02, GIT-03, GIT-04, GIT-05, GIT-06, PORT-02]

coverage:
  - id: D1
    description: "Full-state git segment: dirty repo with upstream, behind 2, ahead 3, 2 stashes renders line 1 ending '⎇ main* ≡ ↓2 ↑3 #2'"
    requirement: GIT-01
    verification:
      - kind: e2e
        ref: "Task 1 tracer verify: temp bare-remote/clone repo, exact ANSI-stripped line-1 equality → TRACER-OK"
        status: pass
    human_judgment: false
  - id: D2
    description: "Outside a git repo the segment and its joiner space are entirely absent; empty stdin yields exactly two lines with a blank line 2"
    requirement: GIT-01
    verification:
      - kind: e2e
        ref: "Task 1 tracer verify: non-repo dir exact equality 'Opus 5 (high) · plain'; wc -l = 2 on empty fixture → TRACER-OK"
        status: pass
      - kind: integration
        ref: "tests/run.sh — 'empty: exactly 2 output lines (D-22)' check plus 7 frame-free fixture expectations"
        status: pass
    human_judgment: false
  - id: D3
    description: "Edge states: detached HEAD shows 7-char SHA with no sync symbol; unborn branch shows name with ≢ (star only when files exist); committed no-upstream shows ≢"
    requirement: GIT-06
    verification:
      - kind: e2e
        ref: "Task 2 edge verify: four temp repos, exact-equality assertions → EDGES-OK"
        status: pass
    human_judgment: false
  - id: D4
    description: "Read-only render path: every git call carries GIT_OPTIONAL_LOCKS=0, one primary porcelain call, no network, no eval of git output"
    requirement: PORT-02
    verification:
      - kind: other
        ref: "grep gates: porcelain=v2 non-comment count = 1; git -C lines missing GIT_OPTIONAL_LOCKS=0 = 0; jq -r count = 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "Semantic marker colors (magenta branch, yellow */↓, green ≡/↑, red ≢, dim #) are readable and glanceable in the real terminal on light and dark themes"
    verification: []
    human_judgment: true
    rationale: "Color legibility and glanceability in a live terminal is a visual judgment no string assertion can prove — mirrors Phase 1's dim-readability UAT"

duration: 2min
completed: 2026-08-21
status: complete
---

# Phase 02 Plan 01: Git Segment Summary

**Frameless two-line layout with a single-porcelain-call git segment: `⎇ main* ≡ ↓2 ↑3 #2` with semantic per-marker colors, correct in detached/unborn/no-upstream states, hidden entirely outside a repo**

## Performance

- **Duration:** 2 min
- **Started:** 2026-08-21T20:22:18Z
- **Completed:** 2026-08-21T20:24:34Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `seg_git()` renders the full git situation from one `GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch` call plus one stash count — branch (magenta), dirty `*` (yellow), `≡`/`≢` sync (green/red), `↓behind` (yellow), `↑ahead` (green), `#stash` (dim); zero-value counters never render
- Detached HEAD shows the short SHA with the sync symbol suppressed (D-24/D-25); unborn branches render normally via the porcelain `(initial)` path (D-26)
- Box-drawing frame prefixes removed: both lines flush-left, line 2 prints as a literal blank line when empty so output is always exactly two lines (D-21/D-22/D-23)
- Harness grew to 67 checks: frame-free fixture expectations, `35m` palette whitelist, and a `wc -l` two-line invariant check that line-equality alone could not pin

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer — frameless line 1 with the full git segment end-to-end** - `025a633` (feat)
2. **Task 2: Expansion — detached HEAD, unborn, and no-upstream edge states** - no commit (verification-only: all four edge states passed exact-equality checks against Task 1's implementation with zero code changes; EDGES-OK)

## Files Created/Modified
- `statusline.sh` - Added `MAGENTA` constant and `seg_git()`; attached the segment at the Phase 2 seam via `dir_seg="$dir_seg${git_seg:+ $git_seg}"`; removed `╭─`/`╰─` frame prefixes from both line assemblies
- `tests/run.sh` - Rewrote all seven fixture expectations frame-free, added `35m` to the palette-purity whitelist, added the D-22 two-line invariant check

## Decisions Made
- Colored spans cover the whole token (symbol + number together, e.g. all of `↓2` yellow) — the planner's discretion point, resolved for glanceability
- Kept the `(detached)` porcelain literal as label fallback if `rev-parse --short HEAD` unexpectedly returns empty, so the `⎇` glyph is never followed by nothing (Pitfall 7 failure mode)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- First `git commit` failed with "1Password: Could not connect to socket" — commit signing requires the 1Password SSH agent socket, which the command sandbox blocks. Retried outside the sandbox; commit succeeded. Not a code issue.

## Flagged Assumptions (carried from plan)
- GIT-01: segment hiding includes the joiner space — proven by exact line-equality (a stray trailing space would fail the `"Opus 5 (high) · plain"` assertion)
- GIT-03: `≡` follows porcelain `# branch.upstream` line *presence* — an "upstream gone" branch still shows `≡` with no counters; flagged for verifier review

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Ready for plan 02-02: temp-repo test helpers (`tgit`, `mk_repo`, `git_render`, `git_line1`), git-state harness scenarios, and the timed latency assertion (PORT-02's proof)
- PORT-02 is structurally in place (single jq pass, one primary git status call) — its timed proof lands in 02-02

## Self-Check: PASSED

- statusline.sh, tests/run.sh, SUMMARY exist on disk; commit `025a633` present
- seg_git() count 1, MAGENTA= count 1, 35m present in harness
- tests/run.sh re-run: 67 checks, 0 failures

---
*Phase: 02-git-segment*
*Completed: 2026-08-21*
