---
phase: quick-260912-vgx
verified: 2026-09-12T21:05:00Z
status: human_needed
score: 10/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Run `/bin/bash tests/sandbox.sh` with a working Docker daemon and read §5.13 and §5.14"
    expected: "§5.13 Fable probe passes against the new `· Fable NN% …` shape; §5.14 reports `INFO folded date format OK under GNU userland (D-68)` rather than the WARN branch; host-vs-sandbox fixture byte diff clean"
    why_human: "Docker is unavailable on this host (`docker info` fails with a TLS certificate error, OSStatus -26276), so the GNU-userland half of the folded `date '+%s %z'` format string and the Linux side of the PORT-01 byte diff cannot be exercised here. Already logged as WINDOWS ledger entry #1."
  - test: "Read README.md 'What it shows' + 'Symbol legend' + the mock-input block (lines 5-31, 62-73) against a live status line"
    expected: "The legend reads naturally end to end and describes the line the reader actually sees"
    why_human: "Factual accuracy was verified programmatically (every legend string matches a real render, see evidence below); what remains is a style/readability judgment a grep cannot make."
---

# Quick Task 260912-vgx: Reset Clock Times on Row 2 — Verification Report

**Task Goal:** Reformat second status line row — show concrete reset clock times instead of countdown durations
**Verified:** 2026-09-12
**Status:** human_needed (all host-verifiable must-haves pass; two known-deferred human items remain)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Row 2 renders each rate-limit window as `LABEL PCT% TIME` — label first, no `/5h` `/1w` suffix, no parenthesised countdown (D-66) | ✓ VERIFIED | Real render with the authoritative CONTEXT target injected: `10%/100k/1M · 5h 50% Sun 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`. (The 5h window shows `Sun` only because 14:50 had already passed at verification time and the epoch rolled to the next day — the bare same-day `HH:MM` form is proven by truth 2.) |
| 2 | 24-hour zero-padded local `HH:MM`; 3-letter weekday prefix ONLY when the reset falls on another local day (D-67) | ✓ VERIFIED | **80 live renders across 10 timezones** (UTC, LA, Honolulu, St Johns −02:30, Kathmandu +05:45, Kiritimati +14, Kyiv, Tokyo, São Paulo, Chatham) × 8 deltas (60 s … 7 d), each compared to `date -r` — **0 mismatches**. Zero-padding proven separately (`Sun 00:05`, both fields padded). Same-day → bare `23:35`; +2 h crossing local midnight → `Sun 01:25` (prefix appears); +3 d → `Tue 23:25`. |
| 3 | Reset at or before now → literal `now`; absent or unparseable `resets_at` → time slot omitted, label + percentage kept (D-69) | ✓ VERIFIED | `full.json` (epoch 0) → `5h 50% now · Week 15% now`. Deleting `resets_at` → `5h 50% · Week 15%`. Hostile/out-of-range values through the untouched jq `uint` canonicalizer: `1e20`, `-5`, `"abc"`, `null` all → slot dropped, label+pct kept; `1.9` floors to 1 → `now`. Regression-guarded in `tests/run.sh:350`. |
| 4 | A window with no percentage still hides completely together with its separator (PRES-04) | ✓ VERIFIED | Deleting `five_hour.used_percentage` → `10%/100k/1M · Week 15% now` (no orphan separator). Deleting `.rate_limits` → `10%/100k/1M` alone. |
| 5 | The context-usage segment (`pct%/tokens/window`) is byte-identical to before the change | ✓ VERIFIED | Rendered all 8 fixtures through `git show b248f95^:…/statusline.sh` and the current script; compared raw ANSI bytes up to the first `·`. **Identical in all 8.** Full row 1 also byte-identical in all 8. |
| 6 | Threshold colour wraps the percentage number only, `RESET` right after; labels dim, clock plain (D-70) | ✓ VERIFIED | Raw bytes: `^[[2m5h^[[0m ^[[32m50%^[[0m now`. Boundary quartet intact: 69→`32m`, 70→`33m`, 89→`33m`, 90→`31m`, span always exactly `NN%`. Row-2 SGR set is `{0m, 2m, 32m}` — palette purity held. |
| 7 | The script still calls `date(1)` exactly once and never uses the two banned epoch-formatting flags (LIM-03, D-68) | ✓ VERIFIED | On non-comment lines: `$(date` count = **1** (line 466, `NOW_Z=$(date '+%s %z')`), backtick-date count = 0, `date[[:space:]]+-[dr]` count = **0**. The only other `date` mentions in the file are two comment lines. |
| 8 | `fmt_duration` is fully gone with no dangling references | ✓ VERIFIED | `grep -rn fmt_duration` over the whole repo returns hits **only** inside `.planning/` history (STATE, research, archived milestone artifacts, this task's own plan/summary). Zero hits in `kit/`, `tests/`, or any live doc. Its ten-row test table is gone from `tests/run.sh`. |
| 9 | `/bin/bash tests/run.sh` reports 0 failures on the host | ✓ VERIFIED | Ran it myself: **242 checks, 0 failures** (baseline recomputed from the pre-change tree: 226 checks, 0 failures — so +16 net, matching the SUMMARY). Still green under `TZ=Pacific/Chatham` and `TZ=America/St_Johns`. `bash -n` clean under the real `/bin/bash 3.2.57`. |
| 10 | The four live spec docs describe the shipped format; historical records untouched | ✓ VERIFIED | Zero `%/5h`/`%/1w` and zero "countdown" in README.md, project-brief.md, .claude/CLAUDE.md. New format present in all four. The `**Never** use \`date -d\` … \`date -r\` …` ban sentence is byte-identical. `kit/spec.yaml` carries no format text. PROJECT.md's 2 stale + 4 "countdown" hits are all on shipped-milestone achievement lines (50, 51, 59) and one Key Decisions row (122) — exactly the historical records Task 3 was told to preserve. README's mock-input expectation `10%/100k/1M · 5h 50% now · Week 15% now` matches the real render byte for byte. |
| 11 | Fixture renders stay byte-identical between host and sandbox because both test scripts pin the zone (PORT-01) | ⚠️ PARTIAL — host half verified, Linux half deferred | `export TZ=UTC` present in `tests/run.sh:24` and `tests/render-fixtures.sh:39`. Rendered all 8 fixtures twice under `TZ=Asia/Tokyo` and `TZ=America/Los_Angeles` — `diff -r` **identical**, so the renders are provably runner-zone-independent. The Docker sandbox half could not be run: `docker info` fails with a TLS certificate error. Known-deferred, WINDOWS #1. |

**Score:** 10/11 truths verified; 1 partial (environment unavailable, deliberately deferred)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kit/files/home/.claude/statusline.sh` | `tz_offset_secs` + `fmt_reset_clock` added, `main` rewired, 3 segments rewritten, `fmt_duration` removed | ✓ VERIFIED | 498 lines, executable, `bash -n` clean. `tz_offset_secs` at :65 with a `case [+-][0-9][0-9][0-9][0-9]` guard **before** any expansion and `10#` on both fields. `fmt_reset_clock` at :88 with the negative-remainder correction fixing day and remainder together. `WD_NAMES` is a plain space-split string (no bash-4 assoc array). |
| `tests/run.sh` | zone pin, `fmt_duration` table removed, §4 rebuilt on a libc oracle, row-2 expectations updated | ✓ VERIFIED | `export TZ=UTC` at :24. New 10-row `tz_offset_secs` table (incl. `+0800` octal-trap row, empty, `garbage`, `+03:00`, and a `$(touch tests/.pwned)` payload with a canary assertion). New 15-row `fmt_reset_clock` table with explicit TODAY — **I re-checked every row against `date -r` myself: all 15 correct**, all seven weekday names covered, plus the epoch-0/−04:00 negative-instant row (`Wed 20:00` — 1969-12-31 was a Wednesday). §4 oracle `dfmt()` at :218 is BSD-first/GNU-fallback with a comment explaining the ban does not apply to test code. |
| `tests/render-fixtures.sh` | zone pin | ✓ VERIFIED | `export TZ=UTC` at :39 with the D-72 comment; still dumps 8 `.out` files. |
| `tests/sandbox.sh` | §5.13 Fable pattern updated, §5.14 folded-date probe added | ✓ VERIFIED (static) | §5.13 now matches `*"· Fable "*"%"*` — no longer keyed to the retired `/1w` text. §5.14 added as an informational probe that WARNs rather than failing. Cannot be executed (no Docker). |
| `README.md`, `project-brief.md`, `.claude/CLAUDE.md`, `.planning/PROJECT.md` | live format spec updated | ✓ VERIFIED | See truth 10. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `main` folded `date '+%s %z'` | `NOW` / `TZOFF` / `TODAY` | `${x%% *}` / `${x##* }` + `tz_offset_secs` | ✓ WIRED | Lines 466-469. All four names present in `main`'s `local` list at :443 (`NOW NOW_Z TZOFF TODAY`) — no leak. Degrades correctly when `%z` is empty: the trailing space makes `${NOW_Z##* }` empty → `tz_offset_secs` returns the locked `0`. |
| `NOW` / `TODAY` / `TZOFF` | `seg_5h` / `seg_1w` / `seg_fable` | dynamic scope | ✓ WIRED | All three segments read `$NOW`, `$TODAY`, `$TZOFF` (lines 257-258, 271-272, 287-288) and render correctly end to end. |
| jq `uint` canonicalizer | `P5_RST` / `P7_RST` → `fmt_reset_clock` | quoted arg | ✓ WIRED, sink not widened | `def uint: (numbers \| floor \| select(. >= 0 and . < 1e15)) // "";` unchanged from the pre-change script. Values passed quoted. Hostile payload probes confirm rejection. |
| `iso_to_epoch` | `FAB_RST` → `fmt_reset_clock` | Fable collector | ✓ WIRED | Injected a future ISO reset into the stdin `model_scoped` bucket → rendered `Fable 33% Tue 20:26`, exactly matching `date -r`. Deleting the ISO reset → `Fable 33%` with no slot. |
| zone pin | identical fixture bytes across runners | `export TZ=UTC` | ✓ WIRED (host) | Tokyo vs Los Angeles renders `diff -r`-identical. |

### Behavioural Spot-Checks

| Behaviour | Command | Result | Status |
|-----------|---------|--------|--------|
| Test suite green | `/bin/bash tests/run.sh` | `242 checks, 0 failures` | ✓ PASS |
| Suite zone-independent | `TZ=Pacific/Chatham` / `TZ=America/St_Johns tests/run.sh` | `242 checks, 0 failures` both | ✓ PASS |
| Clock vs libc, 10 zones × 8 deltas | render + `date -r` compare | `checked 80 renders across 10 zones, 0 mismatches` | ✓ PASS |
| `fmt_reset_clock` table vs libc | re-derived all 15 rows with `date -r` | all 15 correct | ✓ PASS |
| Past reset | `full.json` (epoch 0) | `5h 50% now · Week 15% now` | ✓ PASS |
| Absent reset | `del(.resets_at)` | `5h 50% · Week 15%` | ✓ PASS |
| Absent percentage | `del(.used_percentage)` / `del(.rate_limits)` | segment + separator gone | ✓ PASS |
| Context segment + row 1 unchanged | old-vs-new render, all 8 fixtures, raw bytes | identical in all 8 | ✓ PASS |
| `date` discipline | grep on non-comment lines | `$(date`=1, `date -[dr]`=0 | ✓ PASS |
| Hostile `TZ` injection | `TZ='$(touch tests/.pwned)'`, backtick form, `XYZ+8`, `../../etc/passwd`, empty | stable output, exit 0, **no canary file created** | ✓ PASS |
| Fixture renders produced | `tests/render-fixtures.sh` | 8 `.out` files | ✓ PASS |
| bash 3.2 syntax | `/bin/bash -n` under 3.2.57 | clean | ✓ PASS |
| Sandbox parity | `tests/sandbox.sh` | not run — `docker info` fails (TLS cert, OSStatus -26276) | ? SKIP → human |

### Requirements Coverage

| Requirement | Description (as declared in the plan) | Status | Evidence |
|-------------|---------------------------------------|--------|----------|
| LIM-01 | 5-hour window rendered with its reset | ✓ SATISFIED | Truths 1-3, 6 |
| LIM-02 | Weekly window rendered with its reset | ✓ SATISFIED | Truths 1-3, 6 |
| LIM-03 | Pure epoch arithmetic, single `date` call, no banned flags | ✓ SATISFIED | Truth 7 |
| FAB-01 | Fable weekly as a separate last row-2 segment | ✓ SATISFIED | End-to-end Fable render, new shape, ISO reset → correct clock |
| PORT-01 | Identical output on host and in Docker sandbox | ⚠️ PARTIAL | Zone-independence proven on host; Linux run deferred (WINDOWS #1) |
| PORT-04 | Works via symlink in both environments | ⚠️ PARTIAL | Host path unchanged by this task; sandbox half deferred with PORT-01 |
| PRES-04 | Hide-over-placeholder, no orphan separators | ✓ SATISFIED | Truth 4 |

**Note (informational, not a gap):** `.planning/milestones/v1.0-REQUIREMENTS.md` still states LIM-01/LIM-02/FAB-01 in the retired `pct/5h (countdown)` wording. That file is an archived milestone record and Task 3 explicitly forbade touching `.planning/milestones/`, so this is intentional — the live spec docs carry the current format.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No `TODO`, `FIXME`, `TBD`, `HACK`, or `PLACEHOLDER` in any file this task modified | — | Clean. The only `XXXXXX` hits are pre-existing `mktemp` templates. |
| `kit/files/home/.claude/statusline.sh` | 257, 271, 287 | `[ "$P5_RST" -le "$NOW" ]` errors on stderr if `NOW` is empty | ℹ️ Info | Only reachable if `date(1)` is missing from `PATH`. In that case the line still renders and still exits 0 (error contract held); the old script emitted 1 stderr line in the same scenario, the new one emits 3. `date` is a project-assumed tool, so this is noise in an unreachable state, not a defect. |
| `.claude/CLAUDE.md` | 94 | "What NOT to Use" row still suggests `$((resets_at - $(date +%s)))` … "format d/h/m yourself" | ℹ️ Info | Generic portability guidance for the banned flag, not a row-2 format spec; the plan scoped the CLAUDE.md edit to three other places. Slightly stale advice — worth a one-line touch-up next time that file is edited. |

### Human Verification Required

Both items were deliberately deferred to end-of-phase and are already logged in `.planning/WINDOWS.md` (entry #1 covers the first). Neither is a gap.

#### 1. Docker sandbox parity run

**Test:** With a working Docker daemon, run `/bin/bash tests/sandbox.sh`.
**Expected:** §5.13 Fable probe passes against the new `· Fable NN% …` shape; §5.14 emits `INFO folded date format OK under GNU userland (D-68)` rather than the WARN branch; the host-vs-sandbox fixture byte diff stays clean.
**Why human:** `docker info` fails on this host with a TLS certificate error (OSStatus -26276), so the GNU-userland half of the folded `date '+%s %z'` format string — the single assumption research could not settle — remains unverified, along with the Linux side of PORT-01/PORT-04.

#### 2. README legend read-through

**Test:** Read README.md lines 5-31 and 62-73 next to a live status line.
**Expected:** The legend reads naturally and describes the line you actually see.
**Why human:** I verified factual accuracy programmatically — every legend token (`5h 50% 14:50`, `Week 15% Mon 21:10`, `Fable 74% Mon 21:10`), the `refreshInterval` rationale, and the mock-input expected output all match real renders. What is left is a readability judgment.

### Gaps Summary

**No gaps.** Every automated must-have holds under adversarial probing, and I did not take a single SUMMARY claim on faith:

- The 242/0 test result was reproduced independently, and the 226 baseline was recomputed from the pre-change tree rather than read from the SUMMARY.
- The clock arithmetic was checked against libc on **80 live renders across 10 timezones**, including three half-hour and quarter-hour offsets and one +14:00 zone — not just the two deltas the plan's gate used.
- The 15-row `fmt_reset_clock` expectation table was re-derived from `date -r` row by row, since the SUMMARY admits ten of those rows were wrong on the first attempt.
- The context-segment and row-1 byte-identity claim was verified by rendering all 8 fixtures through the actual pre-change script pulled from `b248f95^`.
- `fmt_duration` removal, the single-`date`-call contract, and the banned-flag ban were re-greped on non-comment lines.
- Hostile `TZ` values (command substitution, backticks, path traversal) were fed to the script: no injection, no canary file, stable output, exit 0.

One truth is partial for an environmental reason only (Docker unavailable), and one item is a style read-through. Both were flagged by the executor up front and are tracked in the WINDOWS ledger, so nothing here contradicts the SUMMARY's own account.

---

_Verified: 2026-09-12_
_Verifier: Claude (gsd-verifier)_
