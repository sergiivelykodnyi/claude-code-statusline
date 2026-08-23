---
phase: 02-git-segment
plan: 03
subsystem: security
tags: [bash-3.2, jq, command-injection, input-validation, regression-harness, gap-closure]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: single jq @sh/eval ingestion boundary, hide-over-empty segment gates, tests/run.sh harness with ERRTMP/check_eq/check_ok conventions
  - phase: 02-git-segment (plans 01-02)
    provides: the 82-check harness baseline, section-7 current_dir injection probe, full.json fixture, PORT-02 single-jq-pass latency budget
provides:
  - jq numeric type guard (`| numbers // ""`) on all 7 numeric stdin fields at the single jq @sh boundary — closes CR-01 (resets_at RCE on bash 3.2.57) and WR-02 (integer-expression stderr leak)
  - harness section 7.2: five injection probes (five_hour/seven_day resets_at + three context_window fields) run under /bin/bash, asserting no command execution (WR-01)
  - harness section 7.3: non-numeric numeric-field probe asserting zero stderr + hide-over-placeholder render
  - NOW/LINE1/LINE2 scoped local in main() (IN-01)
affects: [03-install-docs, 04-fable-weekly, any future field added to the jq ingestion block]

# Actuals (#2632) — same estimateTokens scale as the plan estimate: chars/4 over the realized diff hunks
actuals:
  tokens: 1100
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Numeric fields are type-enforced at the jq boundary (`\\(.path // \"\" | numbers // \"\")`) — every numeric field added to the ingestion block in future MUST carry the guard; string fields MUST NOT"
    - "Injection probes for arithmetic-reachable fields run under /bin/bash (host 3.2.57) via a label:path loop — the version-specific subscript command-substitution is invisible under bash 4/5"

key-files:
  created: []
  modified:
    - statusline.sh
    - tests/run.sh

key-decisions:
  - "Closed CR-01 at the single jq boundary (numbers guard) rather than at the two arithmetic sinks — one choke point, no second jq call, string fields untouched"
  - "Harness injection probes assert on fixed output NAMES per field (label:path loop) so the verify greps harness OUTPUT, not the file — a file-wide `grep -c resets_at` would be self-satisfying"
  - "context_window fields guarded and probed for defense-in-depth even though `[`/`%` sinks do not command-inject — only the two resets_at probes plus the WR-02 probes fail against the unpatched script (4/95)"

patterns-established:
  - "jq numeric guard: `// \"\" | numbers // \"\"` on numeric fields only — non-numbers become empty and fall through the existing hide-on-empty gates"
  - "Adversarial probes follow the harness inline-jq mutation convention (no new fixture files); exactly two named checks per injected field"

requirements-completed: [PORT-02, GIT-06]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Hostile x[$(cmd)] resets_at in either rate-limit window executes nothing on /bin/bash 3.2.57 (CR-01 closed)"
    requirement: PORT-02
    verification:
      - kind: integration
        ref: "tests/run.sh#injection probe: five_hour resets_at tests/.pwned not created"
        status: pass
      - kind: integration
        ref: "tests/run.sh#injection probe: seven_day resets_at tests/.pwned not created"
        status: pass
      - kind: other
        ref: "git show ac5c87a~1:statusline.sh > statusline.sh; /bin/bash tests/run.sh -> 95 checks, 4 failures (both resets_at probes fail unpatched)"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 7 numeric stdin fields type-enforced at the single jq @sh boundary; string fields unguarded; one jq pass preserved"
    requirement: PORT-02
    verification:
      - kind: other
        ref: "sed -n '/jq -r/,/2>\\/dev\\/null)/p' statusline.sh | grep -c 'numbers // \"\"' -> 7; grep -c 'jq -r' statusline.sh -> 1"
        status: pass
      - kind: integration
        ref: "tests/run.sh#latency: 10 full renders in 0s (budget 2s)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A non-numeric numeric field (total_input_tokens as a string) renders hide-over-placeholder with zero stderr bytes (WR-02 closed)"
    requirement: GIT-06
    verification:
      - kind: integration
        ref: "tests/run.sh#non-numeric probe: total_input_tokens stderr bytes"
        status: pass
      - kind: integration
        ref: "tests/run.sh#non-numeric probe: total_input_tokens line 2"
        status: pass
    human_judgment: false
  - id: D4
    description: "Harness hardened from 82 to 95 checks, all green on /bin/bash 3.2.57, with no regression to the git segment, two-line layout, or full.json render"
    requirement: GIT-06
    verification:
      - kind: integration
        ref: "/bin/bash tests/run.sh -> 95 checks, 0 failures, exit 0"
        status: pass
      - kind: integration
        ref: "tests/run.sh#full: line 1 / full: line 2 / git full form: line 1"
        status: pass
    human_judgment: false

# Metrics
duration: 3min
completed: 2026-08-22
status: complete
---

# Phase 2 Plan 3: CR-01 RCE Gap Closure Summary

**jq `numbers` type guard on all 7 numeric stdin fields severs the resets_at -> `$(( ))` command-injection path on bash 3.2.57, and the harness now probes every arithmetic-reachable field under /bin/bash (82 -> 95 checks).**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-08-22T07:31:24Z
- **Completed:** 2026-08-22T07:34:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Closed CR-01 (confirmed RCE): `| numbers // ""` appended inside the single jq `@sh` program on CTX_PCT, CTX_TOK, CTX_WIN, P5_PCT, P5_RST, P7_PCT, P7_RST. A hostile `x[$(cmd)]` value now becomes the empty string and is skipped by the existing `[ -n "$P5_RST" ]` / `[ -z "$tok" ] && tok=0` gates, so it never reaches the `$(( P5_RST - NOW ))` / `$(( P7_RST - NOW ))` sinks. Reproduced FAIL before (file created) and PASS after on host `/bin/bash` 3.2.57 for both rate-limit windows.
- Closed WR-02: the same guard maps a non-numeric `total_input_tokens` to empty, so `shorten_num` no longer emits `integer expression expected`; render is `10%/0/1M · ...` with 0 stderr bytes.
- Closed WR-01: harness section 7.2 loops over five `label:path` pairs (five_hour/seven_day `resets_at`, three `context_window` fields), injecting `x[$(touch tests/.pwned)]` through `/bin/bash "$SL"` and asserting exit 0 + no touched file; section 7.3 adds the non-numeric stderr/line-1/line-2 triple. 13 new checks, fixed names, suite is 95/95 green.
- Proved the probes bite: with the pre-fix `statusline.sh` swapped in, the suite reports `95 checks, 4 failures` (both resets_at probes + both WR-02 probes).
- IN-01: `NOW LINE1 LINE2` added to `main()`'s `local` line.
- Unregressed: single `jq -r` pass, full.json renders `Opus 5 (high) · myproject` / `10%/100k/1M · 50%/5h (now) · 15%/1w (now)`, git matrix and latency check unchanged, no `numbers // ""` literal outside the jq block (scoped count 7 == whole-file count 7).

## Task Commits

Each task was committed atomically:

1. **Task 1: Enforce numeric type at the jq @sh boundary (closes CR-01 + WR-02)** - `ac5c87a` (fix)
2. **Task 2: Extend the harness injection probe to resets_at + a non-numeric-field stderr probe (closes WR-01 + WR-02 coverage)** - `4775cf2` (test)

**Plan metadata:** see final docs commit

## Files Created/Modified

- `statusline.sh` - jq ingestion block: 7 numeric fields carry `| numbers // ""`; ingestion comment describes the guard in prose (no literal); `local ... NOW LINE1 LINE2`
- `tests/run.sh` - section 7.2 (five injection probes under /bin/bash, label:path loop) and 7.3 (non-numeric probe, stderr via `$ERRTMP`); 95 checks total

## Decisions Made

- Fix at the jq boundary, not the sinks: one choke point inside the existing jq program keeps the PORT-02 one-jq-pass budget and leaves MODEL/EFFORT/DIR unguarded (where `numbers` would wrongly empty them).
- Probe names are fixed strings emitted by a loop; the plan's verify greps harness OUTPUT for `PASS <name>` lines, so the assertion cannot be satisfied by file contents alone.
- context_window fields guarded/probed for defense-in-depth even though `[`/`%` sinks do not command-substitute — expected and observed: those three probes pass even against the unpatched script.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `git commit` failed once inside the sandbox (`1Password: Could not connect to socket` — commit signing agent socket blocked). Re-ran the identical commit outside the sandbox; no code impact.

## Known Stubs

None.

## Threat Flags

None — no new surface introduced; T-02-01/02/03 mitigations applied as planned, T-02-04 unchanged.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 2 gap closed: the verifier's single blocking gap (CR-01 + WR-01/WR-02) is remediated and regression-locked; ready for re-verification of phase 02.
- The remaining Phase 2 item is the human UAT (live-terminal color legibility), unchanged by this plan.
- Future fields added to the jq ingestion block must follow the established pattern: numeric -> `// "" | numbers // ""`, string -> `// ""` only.

---
*Phase: 02-git-segment*
*Completed: 2026-08-22*

## Self-Check: PASSED

- `statusline.sh` modified, `tests/run.sh` modified — both present on disk
- Commits `ac5c87a` and `4775cf2` present in `git log`
- Plan `<verification>` items 1-6 re-run on /bin/bash 3.2.57: all pass; `/bin/bash tests/run.sh` -> `95 checks, 0 failures`, exit 0
