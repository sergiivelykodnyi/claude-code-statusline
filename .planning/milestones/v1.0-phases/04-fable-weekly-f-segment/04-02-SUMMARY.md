---
phase: 04-fable-weekly-f-segment
plan: 02
subsystem: testing
tags: [bash-3.2, jq, curl-file-url, regression-harness, eval-injection, fable, iso-8601]

# Dependency graph
requires:
  - phase: 04-fable-weekly-f-segment
    provides: plan 04-01 — iso_to_epoch, the Fable adapter behind get_fable_weekly (kill switch -> stdin -> TTL cache -> fetch -> grace -> hidden), seg_fable, the STATUSLINE_* env contract, fixtures usage/fable.json and fable-stdin.json, kill switch exported in tests/run.sh
  - phase: 02-git-segment
    provides: check_eq/check_ok, strip_ansi, $ERRTMP/$TESTTMP, the |-delimited spec loops, the raw-byte case idiom, §7 eval-boundary probes, git_render helper template, prove-it-bites convention
provides:
  - tests/run.sh §2 iso_to_epoch table (17 RESEARCH Pattern 3 rows + injected-string guard)
  - tests/run.sh §11 fable_render CACHE URL CREDS FIXTURE helper (FB_OUT / FB_RC / FB_ERRBYTES / FB_L2)
  - tests/run.sh §11 functional Fable probes: cold render line/bytes/cache mode+content, threshold quartet, palette purity, cache hit, stale-grace serve, past-grace hide, no resets_at, negative cache write+hit, no/expired credentials, kill switch over a warm cache, stdin-first, peer rule, bounded blackhole timeout
  - tests/run.sh §11.11 security probes: stdin injection/array on rate_limits.model_scoped, hostile cache (garbage + subscript-injection JSON), hostile endpoint bodies — all under /bin/bash 3.2.57
  - tests/run.sh §7.4 comment: all 12 @sh-ingested fields probed
  - tests/fixtures/usage/no-bucket.json (valid usage answer without a weekly_scoped entry — the D-49 negative-cache case)
  - 220-check hermetic harness (was 126) that plan 04-03 runs inside the sandbox
affects: [04-03 sandbox proof, 04-04 docs reconciliation, README testing section]

# Actuals (#2632) — same estimateTokens scale as the plan estimate (chars/4).
# chars/4 over the two files actually changed = 9258; chars/4 over the realized diff alone = 4957.
actuals:
  tokens: 9258
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "fable_render CACHE URL CREDS FIXTURE: every live-path probe sets the kill switch empty plus all three overrides (cache under $TESTTMP, file:// or missing URL, synthetic credentials file) — the harness never reads the Keychain, never reaches the network, never writes under ~/.claude"
    - "Synthetic credentials generated at run time under $TESTTMP (accessToken test-token, far-future / expired expiresAt) — never a committed credentials file"
    - "Endpoint mutations as jq one-liners over tests/fixtures/usage/fable.json into $TESTTMP, served via file://$TESTTMP/<name>; payload literals stay visible in run.sh"
    - "Prove-it-bites: sed the pristine copy into the script path (redirect keeps the mode), run the harness, grep the named FAIL lines, cp the pristine copy back, git diff --quiet before the next mutation"

key-files:
  created:
    - tests/fixtures/usage/no-bucket.json
  modified:
    - tests/run.sh

key-decisions:
  - "stdin array on model_scoped[0].resets_at is asserted as 'Fable 33%/1w' without parens (pct kept, D-54) instead of the plan's 'hidden' wording — the guard empties only resets_at, the valid utilization still drives the stdin branch; the plan's acceptance list already omitted a resets_at 'hidden' line"
  - "M1 (kill switch line deleted) also flipped six §3 fixture line-2 checks on this host (real Keychain token + live endpoint -> 'Fable 87%/1w (1d:20h:7m)'): the exported kill switch is demonstrably the only thing keeping the fixture loop hermetic (RESEARCH Pitfall 1) — recorded as extra bite evidence, nothing written under ~/.claude"

patterns-established:
  - "L2_BASE constant for the three-segment full.json line 2 — every hidden-segment assertion is an exact line equality, not a 'no Fable substring' test"
  - "Security probes render the mutated stdin via a $TESTTMP file through fable_render, so FB_RC/FB_ERRBYTES/FB_L2 are captured identically to the functional probes"

requirements-completed: [FAB-01, FAB-02, FAB-03, FAB-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "iso_to_epoch contract pinned: 17 RESEARCH Pattern 3 rows (UTC, fractional, ±HH:MM/±HHMM, leap days, century boundary, epoch 0, year-end, garbage, month 13, empty, date-only, injected string -> empty) under /bin/bash 3.2"
    requirement: FAB-01
    verification:
      - kind: unit
        ref: "tests/run.sh#iso_to_epoch <iso> -> <want> (17 rows) + iso_to_epoch injected string: tests/.pwned not created"
        status: pass
    human_judgment: false
  - id: D2
    description: "Functional Fable probes from file:// fixtures: exact line 2, dim label + threshold bytes on the number only (69/70/89/90), palette purity, 0600 cache with [true,74,0], cache hit without fetch, stale-grace serve, past-grace hide, no resets_at -> no parens, negative cache written + hit, no/expired credentials hide with no cache, kill switch over a warm cache, stdin-first with no cache, Fable alone on line 2, blackhole hidden within 3 s with 0 stderr"
    requirement: FAB-03
    verification:
      - kind: integration
        ref: "tests/run.sh#fable: cold render line 2 … fable: timeout wall <= 3s (31 checks)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Security probes under /bin/bash 3.2.57: injection + array payloads on model_scoped (array, display_name, utilization, resets_at), garbage and subscript-injection cache, five hostile endpoint bodies — exit 0, no tests/.pwned, 0 stderr, hidden; all 12 @sh-ingested fields probed (T-04-03)"
    requirement: FAB-04
    verification:
      - kind: integration
        ref: "tests/run.sh#fable: stdin injection … / fable: stdin array … / fable: hostile cache … / fable: hostile body … (45 checks)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every new probe family bites: eight script mutations (M1-M8) each produced the named FAIL line(s); real script restored byte-identical (git diff --quiet, mode 100755), harness green again"
    requirement: FAB-02
    verification:
      - kind: manual_procedural
        ref: "executor-time bite runs, table below (M1-M8)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Harness stays hermetic: kill switch exported globally, every Fable probe sets URL + credentials-file + cache overrides; no Keychain read, no network, nothing under ~/.claude (ls -l ~/.claude/statusline-usage-cache.json: No such file or directory before and after)"
    requirement: FAB-02
    verification:
      - kind: other
        ref: "ls -l ~/.claude/statusline-usage-cache.json before/after + grep -rc accessToken tests/fixtures/ == 0 for every file"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-08-22
status: complete
---

# Phase 04 Plan 02: Fable weekly harness probes (iso_to_epoch table, fable_render, §11 functional + security block, bite-proven) Summary

**tests/run.sh grows from 126 to 220 hermetic checks: a 17-row iso_to_epoch table, a fable_render helper, every functional branch of the Fable adapter rendered from file:// fixtures (cold/warm/grace/negative/credentials/kill-switch/stdin-first/peer/timeout/colour), and hostile stdin/cache/endpoint probes under /bin/bash 3.2.57 — each family shown to FAIL against eight deliberately mutated script copies and PASS against the real one.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-22T21:46:45Z
- **Completed:** 2026-08-22T21:55:03Z
- **Tasks:** 2
- **Files modified:** 2 (tests/run.sh, tests/fixtures/usage/no-bucket.json)

## Accomplishments

- §2 `iso_to_epoch` table: the 17 RESEARCH Pattern 3 rows pass under `/bin/bash` 3.2.57 (`2026-08-24T18:00:00.097816+00:00 -> 1787594400`, `-05:30 -> 1787614200`, `2000-02-29 -> 951782400`, `1970-01-01 -> 0`, `2100-03-01T12:34:56.5Z -> 4107587696`, …, garbage / month 13 / empty / date-only / injected `x[$(touch tests/.pwned)]` → `<empty>`) plus a `tests/.pwned not created` guard.
- §11 `fable_render CACHE URL CREDS FIXTURE` (FB_OUT / FB_RC / FB_ERRBYTES / FB_L2) and the functional block: cold render line 2 `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 74%/1w (now)`, cache `-rw-------` with `[true,74,0]`, `ESC[2mFable ESC[0m ESC[33m74% ESC[0m/1w` bytes, threshold quartet 69→32m / 70→33m / 89→33m / 90→31m, palette purity, cache hit (URL switched to a 42 % fixture still renders 74), stale-grace serve (fetched_at now-400, URL `file:///nonexistent`), past-grace hide (now-4000) with 0 stderr, no resets_at → no parens, no bucket → hidden + `pct: null` cached + next render against the valid fixture still hidden, no credentials / expired token → hidden with no cache file, kill switch over a warm cache, stdin-first `Fable 33%/1w (now)` with no cache, Fable alone after context with `no-rate-limits.json`, blackhole `http://192.0.2.1/` with `STATUSLINE_CURL_MAX_TIME=1` → exit 0, hidden, 0 stderr, wall ≤ 3 s.
- §11.11 security probes (T-04-03): stdin `x[$(touch tests/.pwned)]` on `model_scoped[0].utilization` / `.resets_at`; stdin arrays `["","touch","tests/.pwned"]` on `model_scoped` itself, `display_name`, `utilization`, `resets_at`; cache file `garbage` and `{"fetched_at":"x[$(touch tests/.pwned)]","pct":["","touch","tests/.pwned"],"resets_at":1e100}`; endpoint bodies `not json at all`, `.limits = "x"`, percent injection string, percent array, display_name array — every one exits 0, leaves `tests/.pwned` absent, prints 0 stderr bytes, hides the segment. §7.4 comment now states all 12 @sh-ingested fields are probed.
- `tests/fixtures/usage/no-bucket.json`: fable.json minus the `weekly_scoped` entry (session + weekly_all kept, numbers only).
- Hermetic: `ls -l ~/.claude/statusline-usage-cache.json` → `No such file or directory` before and after every harness run (including the bite runs); `grep -rc accessToken tests/fixtures/` is 0 for all 10 fixture files; synthetic credentials live only under `$TESTTMP`.

## Task Commits

Each task was committed atomically:

1. **Task 1: iso_to_epoch table, fable_render helper, and the functional Fable probe block** - `106b4dd` (test)
2. **Task 2: Security probes (hostile stdin model_scoped, hostile cache, hostile endpoint body), 12-field comment update, and the prove-it-bites mutation runs** - `34eb4d0` (test)

**Plan metadata:** see the final `docs(04-02)` commit

## Files Created/Modified

- `tests/run.sh` - header sentence names the Fable probes; §2 iso_to_epoch table; §7.4 comment (12 fields, pointer to §11); §11 Fable weekly block (fable_render, 11.1–11.10 functional, 11.11 security); Result line still last
- `tests/fixtures/usage/no-bucket.json` - sanitized usage answer without a weekly_scoped entry (D-49 negative-cache case)

## Prove-it-bites table (Task 2 step 3)

Pristine copy saved with `cp -p`; each mutation applied with `sed` from the pristine copy into the script path (redirect keeps mode 100755); harness run; named FAIL lines grepped; pristine copy restored; `git diff --quiet -- kit/files/home/.claude/statusline.sh` confirmed before the next mutation.

| Mutation | Edit | Observed FAIL lines | Restored |
|----------|------|---------------------|----------|
| M1 | deleted the `STATUSLINE_NO_FABLE` test line in get_fable_weekly | `FAIL fable: kill switch hidden` — plus `FAIL full/no-effort/no-rate-limits/only-five-hour/null-context/empty: line 2` (see Issues: the §3 renders went live on this host) | yes (git diff --quiet ok) |
| M2 | `[ -n "$FAB_PCT" ] && write_cache …` | `FAIL fable: negative cache written`, `FAIL fable: negative cache hit (no fetch)` | yes |
| M3 | `FAB_GRACE=0` | `FAIL fable: stale-grace serve` | yes |
| M4 | `FAB_GRACE=999999` | `FAIL fable: past-grace hide` | yes |
| M5 | `FAB_TTL=0` | `FAIL fable: cache hit (no fetch)` (+ `stale-grace serve`, `negative cache hit (no fetch)`) | yes |
| M6 | explicit `STATUSLINE_CREDENTIALS_FILE` branch falls through to the default file / Keychain (`else` → `fi; if [ -z "$t" ]; then`) | `FAIL fable: no credentials hidden`, `FAIL fable: no credentials no cache` (+ `expired token hidden`, `expired token no cache`) — Keychain item present on this host, fixture URL local, no network, no dialog | yes |
| M7 | deleted the `FAB_SI_PCT=` line from main's jq program | `FAIL fable: stdin-first line 2` (+ `stdin array resets_at -> no parens (pct kept)`) | yes |
| M8 | dropped `| uint` from read_cache's `.fetched_at` extraction | `FAIL fable: hostile cache injection tests/.pwned not created` (the subscript string reached `$(( NOW - C_AT ))` under bash 3.2.57); `tests/.pwned` removed afterwards | yes |

After the last restore: `git diff --quiet -- kit/files/home/.claude/statusline.sh` succeeds, `test -x` succeeds, `git ls-files -s` starts with `100755`, `/bin/bash tests/run.sh` → `220 checks, 0 failures`, `test ! -e tests/.pwned`, `git status --porcelain` listed only `tests/run.sh` before the Task 2 commit.

## Decisions Made

- `fable: stdin array resets_at` is asserted as the exact rendered line `… · Fable 33%/1w` (pct kept, no parens — D-54) rather than "hidden": emptying `resets_at` cannot hide a segment whose `utilization` is still valid, and the plan's own acceptance list omits a `resets_at hidden` line. The exit-0 and `tests/.pwned not created` checks are unchanged. See Deviations.
- Mutated stdin payloads are written to `$TESTTMP/stdin-probe.json` and rendered through `fable_render` (same env set as every other probe) instead of piping jq straight into the script, so FB_RC / FB_ERRBYTES / FB_L2 are captured identically; the jq lines keep the §7.2 / §7.4 quoting forms verbatim, so the static payload-count greps hold (6 `touch tests/.pwned` code lines, 5 array-payload code lines).
- `L2_BASE` holds the three-segment full.json line 2; every "hidden" assertion is an exact equality against it (stronger than a substring test).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in the plan's expectation] `fable: stdin array resets_at hidden` cannot pass by design**
- **Found during:** Task 2 (stdin array loop)
- **Issue:** The plan's action text asks for a `hidden` check on all four model_scoped array payloads; for `resets_at` the string guard empties only the reset, `utilization` 33 remains valid, so the stdin branch renders `Fable 33%/1w` (no parens) — the correct D-54 behaviour. The plan's acceptance criteria and `<verify>` list already require only the exit-code / `tests/.pwned` checks (and `hidden` for the other three).
- **Fix:** Emitted `fable: stdin array resets_at -> no parens (pct kept)` asserting the exact rendered line instead; the other three labels keep `fable: stdin array <label> hidden`.
- **Files modified:** tests/run.sh
- **Verification:** harness 220/0; M7 additionally flips this check (stdin branch removed), proving it bites
- **Committed in:** 34eb4d0

---

**Total deviations:** 1 auto-fixed (1 bug in the plan's expected outcome)
**Impact on plan:** None on scope; the resets_at array case is still fully probed (exit 0, no tests/.pwned, exact render).

## Issues Encountered

- **M1 bite run went live on the host (read-only, nothing written):** with the kill-switch line deleted, the §3 `run_fixture` renders (which set no overrides by design) read the Keychain token and fetched the real endpoint, rendering `Fable 87%/1w (1d:20h:7m)` on six fixture lines in addition to the expected `FAIL fable: kill switch hidden`. This is exactly RESEARCH Pitfall 1 and confirms the exported kill switch is load-bearing for hermeticity. The default cache write under `~/.claude` did not happen (`ls -l ~/.claude/statusline-usage-cache.json` → `No such file or directory` after; no `.usage.*` temp files under `~/.claude`); the real script was restored immediately. The plan expected only M6 to touch the Keychain — M1 does too whenever run on a host with a token; recorded for plan 04-03/04-04.
- **1Password SSH signing inside the Bash sandbox:** both task commits failed sandboxed with `1Password: Could not connect to socket` and succeeded on the immediate retry of the same command with the sandbox disabled — signing never bypassed (no `--no-verify`, no `commit.gpgsign=false`).
- Shellcheck advisory (non-failing): the new block adds one SC1007 on the intentional `STATUSLINE_NO_FABLE=` empty prefix assignment (the exact form the plan prescribes and greps for) and SC2319/SC2012 notes of the same kind the existing sections already carry.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 04-03 (sandbox proof): `/bin/bash tests/run.sh` is the 220-check hermetic suite to run inside `statusline-kit-test`; the timeout probe asserts only the ≤ 3 s upper bound (RESEARCH Pitfall 6), so the sandbox proxy's immediate failure passes as well. Ready for 04-04 (docs): README testing section should mention the Fable probes, the kill switch, and the `STATUSLINE_*` override contract the harness relies on.

---
*Phase: 04-fable-weekly-f-segment*
*Completed: 2026-08-22*

## Self-Check: PASSED

- key-files.created exist; commits 106b4dd and 34eb4d0 present; harness 220/0 on re-run; kit/files/home/.claude/statusline.sh byte-identical to HEAD (mode 100755); tests/.pwned absent; Task 1 + Task 2 <verify> one-liners PASS under /bin/bash; ~/.claude/statusline-usage-cache.json absent before and after.
