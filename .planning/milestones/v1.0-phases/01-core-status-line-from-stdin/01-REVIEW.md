---
phase: 01-core-status-line-from-stdin
reviewed: 2026-08-21T18:47:15Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - statusline.sh
  - tests/run.sh
  - tests/fixtures/empty.json
  - tests/fixtures/full.json
  - tests/fixtures/malformed.json
  - tests/fixtures/no-effort.json
  - tests/fixtures/no-rate-limits.json
  - tests/fixtures/null-context.json
  - tests/fixtures/only-five-hour.json
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-08-21T18:47:15Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 1 statusline implementation (`statusline.sh`), its regression harness (`tests/run.sh`), and seven JSON fixtures against the project's hard constraints: bash 3.2 syntax, BSD/GNU parity, the never-fail contract (exit 0, zero stderr, hide-over-placeholder degradation), and eval-injection safety of the `jq @sh` pipeline.

The core is solid: no bash 4+ syntax was found, no GNU-only or BSD-only flags are used (`date` is only ever `date +%s`, sed/wc/tr usage is portable), the `@sh`-quoted `eval` correctly neutralizes hostile directory names (verified by the harness's injection probe and by inspection of every expansion path), and the fixture matrix covers the documented absent/null field states with deterministic expectations.

Two warnings were found and **empirically reproduced** — both are violations of the never-fail contract's degradation guarantees, triggered by inputs the script does not validate: (1) eval'd variables are never initialized, so a jq failure renders stale values inherited from the calling environment instead of hiding segments; (2) numeric fields other than the percentages are fed to bash `[ -ge ]` / `$(( ))` without validation, producing stderr output and malformed segments (e.g. `50%/5h ()`) on non-integer values. Neither blanks the line or changes the exit code, so both are Warnings, not Critical.

No hardcoded secrets, no dangerous commands, no debug artifacts, no network calls in the render path.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Eval'd variables are not initialized — environment values leak into the render when jq fails

**File:** `statusline.sh:119-133`
**Issue:** `eval "$vars"` is the only place `MODEL`, `EFFORT`, `DIR`, `CTX_PCT`, `CTX_TOK`, `CTX_WIN`, `P5_PCT`, `P5_RST`, `P7_PCT`, `P7_RST` are assigned. When jq produces no output (malformed JSON, non-object payload like `"string"` or `5`, jq missing from PATH, empty stdin), `vars` is empty and `eval ""` leaves all ten names **unset — which means they inherit whatever the calling environment exported under those names**. The degradation contract ("hide segments on missing data") is then violated by rendering foreign data.

Reproduced:
```
$ MODEL='LEAKED-MODEL' DIR=/evil/leaked-dir /bin/bash statusline.sh < tests/fixtures/malformed.json
╭─ LEAKED-MODEL · leaked-dir
╰─
```
Names like `MODEL` and `DIR` are plausibly present in real environments (ML tooling, Makefiles, build scripts). This also makes the harness's `empty`/`malformed` fixture expectations environment-dependent: they pass or fail depending on what the invoking shell has exported.

**Fix:** Initialize every ingested variable to empty immediately before the eval:
```bash
MODEL= EFFORT= DIR= CTX_PCT= CTX_TOK= CTX_WIN= P5_PCT= P5_RST= P7_PCT= P7_RST=
eval "$vars"
```
Optionally add a harness check that runs the malformed fixture with `MODEL=LEAKED DIR=/x/leaked` in the environment and asserts neither string appears in the output.

### WR-02: Unvalidated numeric fields reach `[ -ge ]` and `$(( ))` — non-integer values emit stderr and render malformed segments

**File:** `statusline.sh:50-51, 87-91, 97-100, 107-110`
**Issue:** Only the percentage fields are sanitized (`${VAR%.*}` truncation). `P5_RST`/`P7_RST` are used raw in `$(( P5_RST - NOW ))`, and `CTX_TOK`/`CTX_WIN` are used raw in `shorten_num`'s `[ "$n" -ge ... ]` tests and arithmetic. A float or string value — which the `// ""` jq guard passes straight through — breaks the zero-stderr contract and corrupts the segment instead of hiding it. The truncation guard also misses jq's exponent notation (`1e-05` contains no `.`, so `${VAR%.*}` leaves it intact and `[ "1e-05" -ge 90 ]` errors).

Reproduced (float `resets_at`, e.g. a fractional epoch):
```
$ jq '.rate_limits.five_hour.resets_at = 1766131200.5' tests/fixtures/full.json | /bin/bash statusline.sh
stderr (103 bytes): statusline.sh: line 100: 1766131200.5: syntax error: invalid arithmetic operator (error token is ".5")
stdout line 2:      ╰─ 10%/100k/1M · 50%/5h () · 15%/1w (now)
```
Note the empty `()` — the arithmetic expansion error kills the `$(seg_5h)` subshell mid-string, so a *partial, malformed* segment is emitted rather than the segment being hidden. Similarly, a string percentage (`"abc"`) produces `[: abc: integer expression expected` on stderr (2 lines, 120 bytes), and a float `total_input_tokens` renders un-shortened (`100000.5`) with `[`-test noise. Exit code stays 0 and the line still renders, hence Warning rather than Critical — but stderr silence and hide-over-placeholder are both explicit contract terms.

**Fix:** Add one integer-sanitizer helper and route every value through it before comparison/arithmetic — truncate the fractional part *and* reject anything non-numeric:
```bash
# int_or_empty VALUE -> leading integer part, or "" if not a plain number
int_or_empty() {
  local v=${1%%.*}
  case $v in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
}
```
Apply in `seg_5h`/`seg_1w` (`P5_RST=$(int_or_empty "$P5_RST")` before the `[ -n ... ]` gate; same for percentages instead of the bare `%.*`), and in `seg_context` for `CTX_TOK`/`CTX_WIN`. This makes a bad value hide its segment (contract-conformant) instead of half-rendering it. Add a harness fixture with a float `resets_at` asserting zero stderr bytes.

## Info

### IN-01: `empty.json` fixture is a zero-byte file — the `{}` degradation path is untested

**File:** `tests/fixtures/empty.json`, `tests/run.sh:105`
**Issue:** The fixture named `empty` is an empty *file*, which exercises the empty-stdin path (jq emits nothing, variables stay **unset** — the exact path vulnerable to WR-01). The distinct `{}` path — jq succeeds and explicitly assigns all ten variables to `""` — is never exercised, even though it is the canonical "all fields absent" payload from the stdin contract.
**Fix:** Add a `tests/fixtures/empty-object.json` containing `{}` with the same expected output, keeping the zero-byte fixture for the empty-stdin case.

### IN-02: `seg_dir` renders the script's own PWD basename for `current_dir` of `/` or with a trailing slash

**File:** `statusline.sh:77-81`
**Issue:** `${DIR##*/}` yields empty for `"/"` or any trailing-slash path, silently triggering the PWD fallback — the status line then shows the *statusline process's* working directory basename, which is unrelated to the session's workspace. The D-13/D-16 fallback was intended for *absent* `current_dir`, not for present-but-slash-terminated values.
**Fix:** Strip trailing slashes first: `local d=${DIR%/}; d=${d##*/}`, and render `/` for the root case rather than falling back.

### IN-03: `seg_5h` and `seg_1w` are copy-paste duplicates

**File:** `statusline.sh:95-112`
**Issue:** The two functions differ only in variable names and the `/5h` vs `/1w` label. Phase-2+ changes (e.g. the WR-02 sanitizer, or a `seven_day_opus` window) must be applied twice, inviting drift.
**Fix:** One parameterized renderer: `seg_limit PCT RST LABEL` called as `seg_limit "$P5_PCT" "$P5_RST" 5h` and `seg_limit "$P7_PCT" "$P7_RST" 1w`.

### IN-04: `cat` + `printf | jq` spawns an extra process and pipe per render

**File:** `statusline.sh:120-121`
**Issue:** `input=$(cat)` followed by `printf '%s' "$input" | jq ...` costs one external process (`cat`) and one subshell more than letting jq read stdin directly; `$input` is used nowhere else. The project constraint is minimal spawns on every render. (If `$input` is being held for a Phase 2 second pass, a comment saying so would prevent "cleanup" regressions.)
**Fix:** `vars=$(jq -r '@sh "..."' 2>/dev/null)` reading stdin directly, or keep the capture with an explanatory comment.

---

_Reviewed: 2026-08-21T18:47:15Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
