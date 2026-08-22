---
phase: 02-git-segment
reviewed: 2026-08-22T00:00:00Z
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

# Phase 02: Code Review Report (re-review after gap closure)

**Reviewed:** 2026-08-22
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Re-reviewed Phase 02 after gap-closure plan 02-03 (commits `ac5c87a`,
`4775cf2`) landed. All three prior findings were independently re-verified
against the current code under `/bin/bash` 3.2.57 + jq 1.7.1. The harness now
reports **95 checks, 0 failures**.

**Prior findings — verified resolved:**

- **CR-01 (resets_at RCE) — RESOLVED.** `| numbers // ""` was appended to all
  seven numeric fields. Direct re-probe with
  `resets_at="x[$(touch MARKER)]"` (both windows) plus the same payload in
  `used_percentage`/`total_input_tokens`/`context_window_size` produced **no
  marker, zero stderr, exit 0**. The jq numeric guard empties the field before
  it reaches the `$(( ))` sink, and a JSON array in a numeric field is likewise
  mapped to empty. Confirmed the array-subscript command-substitution defect
  still exists in the host shell (`echo $(( 'x[$(touch f)]' - 1 ))` runs
  `touch` on 3.2.57), so the guard — not the shell — is what closes it.
- **WR-01 (missing regression probe) — RESOLVED.** `tests/run.sh` section 7.2
  adds arithmetic-reachable injection probes for `resets_at` (both windows) and
  the three `context_window` numerics, all piped through `/bin/bash` so the
  3.2-specific behavior is actually exercised. 7.3 adds the non-numeric-field
  probe.
- **WR-02 (non-numeric stderr leak) — RESOLVED for the reported case.**
  `total_input_tokens="abc"` now renders `10%/0/1M` with zero stderr (7.3
  asserts this). Note the guard closes only the *non-number-type* class; a
  residual leak for pathological *numeric* values survives — see WR-03 below.
- **IN-01 (missing `local`) — RESOLVED.** Line 170 now declares
  `local input vars sep model_seg dir_seg git_seg body NOW LINE1 LINE2`.

Fresh adversarial review then surfaced one **new BLOCKER of the same class as
CR-01 through a different vector**: the gap-closure hardened the seven *numeric*
fields but left the three *string* fields (`MODEL`, `EFFORT`, `DIR`) with only
`// ""` — and a JSON **array** in any of those fields breaks out of `@sh`
per-element quoting into multiple `eval` words, executing arbitrary commands.
This is confirmed exploitable on the target shell.

## Critical Issues

### CR-02: Array-valued string field escapes `@sh` quoting into `eval` — arbitrary command execution

**File:** `statusline.sh:172-184` (source: lines 173-175; sink: `eval "$vars"` line 184)
**Issue:**
CR-01's fix added `| numbers // ""` to the seven numeric fields, which also
neutralizes arrays (an array is not a number → `""`). But the three string
fields were left unguarded:

```
MODEL=\(.model.display_name // "")     # line 173
EFFORT=\(.effort.level // "")          # line 174
DIR=\(.workspace.current_dir // "")    # line 175
```

`@sh` shell-quotes each element of its input. When the field is a **string**,
that yields one safe quoted token (this is why the existing T-01-01
`current_dir` probe — a string with `;$()` — passes). But when the field is a
JSON **array**, `@sh` emits one quoted token *per element separated by spaces*,
and `eval` then parses them as separate words:

```
$ echo '{"model":{"display_name":["","touch","/tmp/pwn"]}}' \
    | jq -r '@sh "MODEL=\(.model.display_name // "")"'
MODEL='' 'touch' '/tmp/pwn'
```

`eval "MODEL='' 'touch' '/tmp/pwn'"` runs `MODEL=''` as a command-scope
assignment prefix and then executes `touch /tmp/pwn`. Confirmed under the target
interpreter — all three fields are exploitable:

```
$ echo '{"model":{"display_name":["","touch","'$M'"]}}'     | /bin/bash statusline.sh  # MARKER created
$ echo '{"workspace":{"current_dir":["","touch","'$M'"]}}'  | /bin/bash statusline.sh  # MARKER created
$ echo '{"effort":{"level":["","touch","'$M'"]}}'           | /bin/bash statusline.sh  # MARKER created
```

Each fires with `rc=0` and zero stderr — a silent RCE on every render. This is
the same eval-injection class the project already treats as in-scope: the
existing T-01-01 test guards `current_dir` against string injection, proving
`current_dir` is considered attacker-reachable — and it is still exploitable
here via the array form. `resets_at`/OAuth-usage fields are server-controlled
(MITM/compromised-proxy reachable), so the threat model is not hypothetical.

**Fix:** Enforce string type at the jq boundary exactly as the numeric fields
enforce number type, so a non-string (array/object/bool) collapses to `""` and
is then hidden by the existing `[ -n ... ]` gates:

```
MODEL=\(.model.display_name // "" | strings // "")
EFFORT=\(.effort.level // "" | strings // "")
DIR=\(.workspace.current_dir // "" | strings // "")
```

Verified: array `display_name` → `MODEL=''`; object `current_dir` → `DIR=''`;
a normal string (`"high"`) passes through unchanged. This makes all ten fields
uniformly type-guarded before `eval`.

## Warnings

### WR-03: Numeric guard still passes floats / exponent / `nan`, leaking arithmetic stderr

**File:** `statusline.sh:147,157` (`$(( P5_RST - NOW ))` / `$(( P7_RST - NOW ))`), `51-52`, `23-24`
**Issue:** `numbers // ""` maps only non-*number* types to empty. Legitimate
JSON numbers that are not bash-parseable integers still flow to the integer
sinks and violate the project's fail-silent / `stderr == 0` invariant:

```
resets_at = 1755800000.5   -> line 147: "syntax error: invalid arithmetic operator (error token is .5)"
resets_at = 1e100          -> line 147: "1E: value too great for base (error token is 1E)"
total_input_tokens = 100000.7 -> line 23/24: "[: 100000.7: integer expression expected"
used_percentage = 1e2      -> line 51/52: "[: 1E+2: integer expression expected"  (renders "1E+2%")
used_percentage = nan      -> line 51/52: "[: null: integer expression expected"  (renders "null%")
```

The PCT fields are partially protected by `${PCT%.*}` (so a plain `23.5` →
`23`), but that does not strip exponent notation (`1E+2` has no `.`) or
truncate `resets_at` at all before the arithmetic. `resets_at` is contractually
an epoch number; a float or exponent epoch — or any malformed payload — prints a
bash error to stderr on every render. The reported WR-02 case ("abc") is fixed,
but this adjacent class (well-typed-but-non-integer numbers) is not, and no
fixture/probe covers it (all fixtures carry clean integers). Severity is
robustness/noise, not RCE — the `[` and `$(( ))` sinks error but do not
command-inject once the value is a real number.

**Fix:** Canonicalize to a bash-safe non-negative integer at the jq boundary,
e.g. a reusable filter:

```
def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
```

applied to `CTX_TOK`, `CTX_WIN`, `P5_RST`, `P7_RST` (and `floor` alone for the
0–100 PCT fields). `floor` also rids the output of exponent notation. Verified:
`1e100 → ""`, `100000.7 → 100000`, `nan → ""`, `1755800000 → 1755800000`.
Add a fixture or probe asserting zero stderr for a float `resets_at` /
`used_percentage`.

### WR-04: Injection probes cover only the string-payload vector, not the array vector

**File:** `tests/run.sh:147-188`
**Issue:** Every injection probe (7.1 `current_dir`, 7.2 numeric fields, 7.3
non-numeric) injects a **string** value (`"x[$(...)]"`, `"/tmp/x; $(...)"`,
`"abc"`). None inject a JSON **array**, which is the exact vector that bypasses
`@sh` quoting in CR-02. The suite therefore passes 95/95 while the string
fields are wide open. This is the same false-confidence failure mode WR-01
called out for CR-01 — the regression net has a hole shaped like the live bug.
**Fix:** Add an array-payload probe for each `@sh`-ingested field (at minimum
the three string fields), run under `/bin/bash`:

```bash
for path in .model.display_name .effort.level .workspace.current_dir \
            .rate_limits.five_hour.resets_at .context_window.total_input_tokens; do
  rm -f tests/.pwned
  jq "$path = [\"\",\"touch\",\"tests/.pwned\"]" tests/fixtures/full.json \
     | /bin/bash "$SL" > /dev/null 2>&1
  [ ! -e tests/.pwned ]
  check_ok "array-injection probe: $path not executed" $?
done
rm -f tests/.pwned
```

## Info

### IN-02: Branch literally named `(detached)` is misdetected as detached HEAD

**File:** `statusline.sh:111`
**Issue:** `if [ "$label" = '(detached)' ]` treats the porcelain sentinel by
string match, but `git check-ref-format --branch '(detached)'` confirms
`(detached)` is a *valid* branch name. A repo on such a branch would render the
short SHA instead of the branch name and suppress the sync glyph (D-25). This is
a cosmetic edge case on a near-impossible branch name, not a correctness risk
for real usage.
**Fix:** If desired, distinguish the sentinel from a real branch by also
checking `# branch.oid (initial)` / detached state via a dedicated porcelain
signal, or accept the ambiguity as out-of-scope. Low priority.

---

_Reviewed: 2026-08-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
