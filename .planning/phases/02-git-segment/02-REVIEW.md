---
phase: 02-git-segment
reviewed: 2026-08-21T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - .gitignore
  - project-brief.md
  - statusline.sh
  - tests/run.sh
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-08-21
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Phase 2 git-segment work: the new `seg_git()` renderer and the
substantially expanded `tests/run.sh` harness, plus the doc-only diffs to
`project-brief.md` and `.gitignore`. The git segment itself is well-built —
single porcelain-v2 call, `GIT_OPTIONAL_LOCKS=0`, bash-3.2-safe here-string
parse, hide-over-placeholder discipline, and a genuinely thorough real-repo
test matrix. All 82 harness checks pass.

However, adversarial probing of the **existing** ingestion path (touched at
this phase's seam and exercised by the new git fixtures) uncovered a
**confirmed arbitrary command-execution vulnerability**: the `resets_at`
payload fields flow unvalidated into a bash `$(( ))` arithmetic context, and
under the project's pinned interpreter `/bin/bash` 3.2.57 this executes
embedded command substitutions. The `@sh` quoting the project relies on for
injection safety is completely bypassed by the arithmetic sink, and the
harness's dedicated injection regression test only covers `current_dir`, so
the gap passes CI silently. This is a BLOCKER.

## Critical Issues

### CR-01: Command injection via `resets_at` fields into `$(( ))` arithmetic

**File:** `statusline.sh:147` and `statusline.sh:157` (sinks); `statusline.sh:176,178` (source)
**Issue:**
`seg_5h` and `seg_1w` compute the countdown with:

```bash
[ -n "$P5_RST" ] && out="${out} ($(fmt_duration $(( P5_RST - NOW ))))"   # line 147
[ -n "$P7_RST" ] && out="${out} ($(fmt_duration $(( P7_RST - NOW ))))"   # line 157
```

`P5_RST` / `P7_RST` come straight from the payload
(`.rate_limits.five_hour.resets_at` / `.seven_day.resets_at`) via
`@sh`-quoted `eval`. The `@sh` quoting makes the *eval* safe, so each variable
holds the string **literally** — but that literal is then fed into a bash
arithmetic expansion. In bash, an operand like `x[$(cmd)]` is parsed as an
array reference whose subscript is command-substituted, so `$(cmd)` runs.

Confirmed under the project's target interpreter (execution trace line 110
shows `touch` firing inside `$(( P5_RST - NOW ))`):

```
$ /bin/bash --version
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ printf '%s' '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp"},
  "rate_limits":{"five_hour":{"used_percentage":50,"resets_at":"x[$(touch /tmp/pwned)]"}}}' \
  | /bin/bash statusline.sh >/dev/null 2>&1
$ ls /tmp/pwned   # -> file created (arbitrary command executed)
```

Both `five_hour` and `seven_day` `resets_at` are exploitable. Note this fires
specifically on **macOS `/bin/bash` 3.2.57 — the primary target platform**;
newer bash (4/5) does not command-substitute the subscript here, which is why
the vulnerability can hide from a reviewer testing under a modern shell.

Impact: any payload value reaching `resets_at` (server-controlled via the
OAuth usage API response, or an MITM/compromised proxy) executes arbitrary
shell commands locally on every status-line render. The project's own threat
model already treats payload fields as untrusted (hence `@sh` and the T-01-01
injection regression test); the arithmetic sink defeats that protection.

**Fix:** Enforce numeric type at the jq boundary so non-numbers become empty
(and are then skipped by the `[ -n "$P5_RST" ]` guard). Apply to every numeric
field for defense-in-depth:

```bash
vars=$(printf '%s' "$input" | jq -r '@sh "
    MODEL=\(.model.display_name // "")
    EFFORT=\(.effort.level // "")
    DIR=\(.workspace.current_dir // "")
    CTX_PCT=\(.context_window.used_percentage // "" | numbers // "")
    CTX_TOK=\(.context_window.total_input_tokens // "" | numbers // "")
    CTX_WIN=\(.context_window.context_window_size // "" | numbers // "")
    P5_PCT=\(.rate_limits.five_hour.used_percentage // "" | numbers // "")
    P5_RST=\(.rate_limits.five_hour.resets_at // "" | numbers // "")
    P7_PCT=\(.rate_limits.seven_day.used_percentage // "" | numbers // "")
    P7_RST=\(.rate_limits.seven_day.resets_at // "" | numbers // "")
  " ' 2>/dev/null)
```

(`numbers // ""` passes number values through and maps anything else to empty;
verified: `"x[$(touch pwn)]"` → `P5_RST=''`, `1700000000` → `P5_RST=1700000000`.)
A bash-3.2 belt-and-suspenders alternative at the sink is
`P5_RST=${P5_RST//[^0-9-]/}` before the arithmetic, but the jq guard is the
cleaner single-point fix.

## Warnings

### WR-01: Injection regression test covers only `current_dir`, masking CR-01

**File:** `tests/run.sh:147-156`
**Issue:** Section 7 ("Injection probe — T-01-01 regression") asserts safety by
injecting into `.workspace.current_dir` only. Every numeric field that flows
into an arithmetic context (`resets_at`, and the `%`/`-ge` comparisons) is
untested, and all fixtures carry well-formed integer `resets_at`, so the
BLOCKER in CR-01 passes all 82 checks. The passing suite gives false
confidence that payload injection is closed.
**Fix:** Extend the injection probe to the arithmetic-reachable fields, e.g.:

```bash
rm -f tests/.pwned
jq '.rate_limits.five_hour.resets_at = "x[$(touch tests/.pwned)]"' \
   tests/fixtures/full.json | /bin/bash "$SL" > /dev/null 2>&1
[ ! -e tests/.pwned ]
check_ok "injection probe: resets_at not executed" $?
```

Add the same for `.rate_limits.seven_day.resets_at`. These must be run under
`/bin/bash` (3.2 on the host) to catch the version-specific behavior.

### WR-02: Numeric fields unvalidated — non-numeric input leaks to stderr

**File:** `statusline.sh:22-23` (`shorten_num`), `132-138` (`seg_context`)
**Issue:** `seg_context` guards only for empty (`[ -z "$tok" ] && tok=0`), not
for non-numeric. A non-numeric `total_input_tokens`/`context_window_size`
(contract violation or hostile payload) makes `shorten_num`'s
`[ "$n" -ge 1000000 ]` emit `integer expression expected` to stderr:

```
$ printf '%s' '{"...":"...","context_window":{"context_window_size":200000,
  "used_percentage":10,"total_input_tokens":"abc"}}' | /bin/bash statusline.sh 2>&1 >/dev/null
statusline.sh: line 23: [: abc: integer expression expected
statusline.sh: line 24: [: abc: integer expression expected
```

The `test`/`[` sink does **not** command-inject (verified — only `$(( ))`
does, per CR-01), so this is a robustness/noise defect, not a security one.
But the harness asserts `stderr bytes == 0` on every fixture while no fixture
carries a non-numeric numeric field, so the guard gap is uncovered.
**Fix:** The `numbers // ""` jq guard from CR-01 also closes this — non-numbers
become empty, seg renders hide-over-placeholder, no stderr. Optionally add a
fixture with a non-numeric numeric field asserting clean stderr.

## Info

### IN-01: Globals `NOW`, `LINE1`, `LINE2` not declared `local` in `main()`

**File:** `statusline.sh:182,193,197,199`
**Issue:** `main()` declares `local input vars sep model_seg dir_seg git_seg
body` but `NOW`, `LINE1`, and `LINE2` are assigned without `local`, leaking to
global scope. Harmless in this single-run-then-`exit` script, but inconsistent
with the file's otherwise-careful scoping.
**Fix:** Add them to the `local` declaration line for consistency:
`local input vars sep model_seg dir_seg git_seg body NOW LINE1 LINE2`.

---

_Reviewed: 2026-08-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
