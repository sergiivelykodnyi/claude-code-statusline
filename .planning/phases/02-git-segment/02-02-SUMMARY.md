---
phase: 02-git-segment
plan: 02
subsystem: testing
tags: [bash, git, temp-repos, ansi, latency, regression-harness]

requires:
  - phase: 02-git-segment plan 01
    provides: "seg_git renderer with semantic marker colors and the frameless two-line layout the matrix asserts against"
  - phase: 01-core-statusline
    provides: "tests/run.sh harness (check_eq/check_ok, strip_ansi, ERRTMP trap, fixture loop, palette-purity pattern)"
provides:
  - "Git-state regression matrix: 7 states (not-a-repo, clean in-sync, boundary ones, full form, no-upstream verbatim branch, detached, unborn) asserted by exact ANSI-stripped line-1 equality against real temp repos"
  - "Hermetic temp-repo helpers: tgit (config-isolated git), mk_repo, git_render, git_line1, TESTTMP root on the EXIT trap"
  - "D-17..D-20 marker color byte assertions and a git-render palette-purity pass"
  - "Timed render-latency budget: 10 uncached full renders ≤ 2 wall-clock seconds via portable date +%s arithmetic (PORT-02, D-28, D-29)"
affects: [03-install-readme, 04-fable-weekly]

actuals:
  tokens: 2600
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "tgit wrapper: GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null for hermetic repo building (host gpgsign/hooks/defaultBranch cannot leak in)"
    - "Progressive single repo advanced through clean → boundary-ones → full-form states instead of three separate repo builds"
    - "Whole-second N-iteration timing bound for portable latency assertions (no GNU-only date formats)"

key-files:
  created: []
  modified: [tests/run.sh]

key-decisions:
  - "Latency budget operationalized as 10 sequential renders ≤ 2 whole-clock seconds (avg ≤200ms) — measured 1s actual, ~2x headroom, flake-proof at whole-second granularity"
  - "Bare remote HEAD pinned to main via symbolic-ref immediately after init --bare so the hermetic clone checks out main (isolated config would otherwise leave a dangling master HEAD and an empty clone)"
  - "Detached-SHA expectation computed with tgit rev-parse per plan; verified host has no core.abbrev override so it matches production's plain git rev-parse"

patterns-established:
  - "git_render/git_line1: jq --arg dir-mutation of full.json piped through the script, capturing stdout/exit/stderr-bytes in globals (run_fixture discipline for non-fixture payloads)"

requirements-completed: [GIT-06, PORT-02]

coverage:
  - id: D1
    description: "Seven git edge states each render the exact expected line 1 against real temp repos: not-a-repo (segment absent), clean in-sync, boundary ones, full form, no-upstream with slashed branch verbatim, detached short-SHA, unborn"
    requirement: GIT-06
    verification:
      - kind: integration
        ref: "tests/run.sh section 8 — 'git not-a-repo/clean in-sync/boundary ones/full form/no-upstream verbatim branch/detached/unborn: line 1' exact-equality checks"
        status: pass
    human_judgment: false
  - id: D2
    description: "Zero/one counter boundary proven on both sides: clean in-sync renders exactly '⎇ main ≡' (zero counters and star absent); counts of exactly one render '↓1 ↑1 #1'"
    requirement: GIT-06
    verification:
      - kind: integration
        ref: "tests/run.sh — 'git clean in-sync: line 1' and 'git boundary ones: line 1' exact-equality checks (D-27)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Semantic marker colors byte-asserted: magenta branch span, yellow star, green ≡, yellow ↓N, green ↑N, dim #N, red ≢; git render passes palette purity"
    verification:
      - kind: integration
        ref: "tests/run.sh — 'git color bytes: ...' case-substring raw-byte checks plus 'git palette purity' whitelist loop over the full-form render"
        status: pass
    human_judgment: false
  - id: D4
    description: "Render latency regression-proof: 10 sequential uncached full renders against the full-form repo complete within 2 wall-clock seconds (avg ≤200ms, under the ~300ms debounce)"
    requirement: PORT-02
    verification:
      - kind: integration
        ref: "tests/run.sh section 9 — 'latency: 10 full renders in 1s (budget 2s)' via date +%s arithmetic"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-08-21
status: complete
---

# Phase 02 Plan 02: Git-State Regression Net Summary

**tests/run.sh grew from 67 to 82 checks: seven git states proven by exact line equality against hermetic temp repos, D-17..D-20 colors byte-pinned, and a portable 10-renders-in-2s latency budget — all green at 1s measured**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-21T20:27:09Z
- **Completed:** 2026-08-21T20:31:47Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Git-state matrix: a progressive repo `w` walks clean-in-sync → boundary-ones (`↓1 ↑1 #1`) → full form (`⎇ main* ≡ ↓2 ↑3 #2`), plus not-a-repo, no-upstream with verbatim `feature/x-1`, detached short-SHA, and unborn states — each asserted by exact ANSI-stripped line-1 equality, with exit-0/zero-stderr proofs on the not-a-repo and full-form renders
- Hermetic infrastructure: `tgit` isolates host git config for repo building (the rendered script keeps calling plain git as in production); `mk_repo` pins main via `symbolic-ref` with no `init -b` version dependency; everything lives under a mode-700 `TESTTMP` removed by the EXIT trap (T-02-05)
- Marker colors byte-asserted against seg_git's exact composition: `35m⎇ main 0m 33m* 0m 32m≡ 0m 33m↓2 0m 32m↑3 0m 2m#2 0m` in the full-form raw render and `31m≢ 0m` in the no-upstream render; a second palette-purity pass runs on the git render (section 6's runs on a non-repo fixture and never sees magenta)
- Latency budget (PORT-02/D-28): payload materialized once, then 10 sequential uncached full renders bounded at ≤ 2 wall-clock seconds via `date +%s` arithmetic only — measured 1s, so ~2x headroom without any cache, warm-up, or skip logic (D-29)

## Task Commits

Each task was committed atomically:

1. **Task 1: Git-state regression matrix with real temp repos** - `3f60d93` (test)
2. **Task 2: Timed render-latency budget (D-28)** - `daa4a44` (test)

## Files Created/Modified
- `tests/run.sh` - Added `TESTTMP` + extended EXIT trap, `tgit`/`mk_repo`/`git_render`/`git_line1` helpers, section 8 (git-state matrix: 7 scenarios, color-byte checks, git palette purity), section 9 (latency budget); shellcheck advisory renumbered to 10; header comment updated

## Decisions Made
- Bare remote HEAD pinned to `refs/heads/main` right after `init --bare` — under the isolated config the default HEAD would dangle at `master`, making the w2 clone check out nothing and breaking the boundary-ones scenario
- `git stash push -q` used instead of bare `git stash -q` (explicit subcommand accepts `-q` unambiguously on both target git versions)
- Latency check name embeds the measured value (`latency: 10 full renders in ${elapsed}s (budget 2s)`) so a slow run is diagnosable from the PASS/FAIL line alone

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `git commit` inside the command sandbox fails with "1Password: Could not connect to socket" (commit signing needs the 1Password agent's Unix socket). Retried outside the sandbox per the Wave 1 note; both commits succeeded. Not a code issue.

## Flagged Assumptions (carried from plan, for verifier review)
- **GIT-06:** Edge-state universe assumed to be the five research-Pitfall-7 states plus the boundary-ones scenario. Bare repos and submodule/worktree exotica are not separately tested — a bare repo fails the porcelain call exactly like not-a-repo, so it is covered structurally by the hidden-segment path.
- **PORT-02:** "Well under ~300ms" operationalized as 10 sequential renders ≤ 2 whole-clock seconds (average ≤200ms). Per-render sub-millisecond timing deliberately not measured — GNU nanosecond date formats are not portable to BSD userland, and the whole-second bound stays flake-proof on both targets (D-28 discretion).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 2 complete: both plans summarized; the harness is the single one-command regression net (82 checks) Phases 3-4 re-run before touching the render path
- Roadmap criteria 1-3 are regression-proven (not just tracer-proven); criterion 4 (latency) has its timed proof with ~2x headroom
- End-of-phase UAT still owed for plan 01's D5 (color legibility in a live terminal on light/dark themes) — a visual judgment routed to verify-work

## Self-Check: PASSED

- tests/run.sh and this SUMMARY exist on disk; commits `3f60d93` and `daa4a44` present in git log
- mk_repo()/tgit()/git_render()/git_line1() each defined once; trap line references TESTTMP once
- tests/run.sh re-run: 82 checks, 0 failures, exit 0; PASS latency line present exactly once

---
*Phase: 02-git-segment*
*Completed: 2026-08-21*
