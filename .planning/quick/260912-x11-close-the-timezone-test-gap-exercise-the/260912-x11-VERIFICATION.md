---
phase: quick-260912-x11
verified: 2026-09-12T21:32:52Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
warnings:
  - finding: "tests/mutation-tz.sh drops the exec bit on the mutated copy"
    severity: warning
    file: "tests/mutation-tz.sh:70"
    detail: >-
      `awk ... > "$work/$SRC.mut" && mv "$work/$SRC.mut" "$work/$SRC"` replaces the
      copied script's inode with a fresh 0644 file, so the mutated copy is not
      executable. Every mutant run therefore also fails the unrelated
      `exec bit: ... is executable (PORT-04)` check — the mutant suite reports
      `250 checks, 5 failures`, not the `4 failures` the SUMMARY claims.
      Consequence: the `status -ne 0` half of the gate's two-part PASS condition is
      now vacuously satisfied by the gate's own artifact, so the gate rests entirely
      on the `killed > 0` half. Verified NOT to make the gate lie (two independent
      blinding experiments below both produced `2 mutants, 2 survivors`, exit 1),
      so this is a robustness/accuracy wart, not a blocker.
    fix: 'add `chmod +x "$work/$SRC"` after the mv, or write with `cat > "$work/$SRC"` instead of mv'
deferred:
  - truth: "The two re-pinned sandbox assertions behave correctly inside a real container"
    addressed_in: "WINDOWS.md unrun-verify id 2 (open)"
    evidence: >-
      `docker info` fails on this host, so `tests/sandbox.sh` cannot run end to end.
      Already recorded as an accepted open window with the tzdata question for the
      sandbox image. The assertion LOGIC was verified here without Docker (see
      Behavioral Spot-Checks); only the `sx` container round-trip is unexercised.
---

# Quick Task 260912-x11: Close the Timezone Test Gap — Verification Report

**Phase Goal:** Close the timezone test gap — exercise the reset-clock offset path end-to-end under a non-UTC TZ
**Verified:** 2026-09-12T21:32:52Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The central question was not "is the suite green" but "can the suite go red when the timezone path
breaks". I answered it by mutation, independently of `tests/mutation-tz.sh`, on throwaway copies of
the repo. The original defect proof was reproduced, the fix was shown to catch it, and the gate was
attacked twice to try to make it report success while blind. It did not.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `tests/run.sh` renders the real script under four sub-hour, no-DST zones and compares each rendered reset clock against libc's own tzdata (D-67, D-68) | ✓ VERIFIED | `tests/run.sh:240-289`. Oracle is `TZ=$tzx dfmt` (libc `date`), never the script's own arithmetic. The four renders produce genuinely zone-specific clocks — `03:05 / 03:20 / 06:20 / 12:05` for `+0530 / +0545 / +0845 / -0930` — so the offset really flows through `tz_offset_secs -> TZOFF -> TODAY -> fmt_reset_clock` |
| 2 | A clean tree reports `250 checks, 0 failures` (was 242) | ✓ VERIFIED | Ran twice: `250 checks, 0 failures`, exit 0, **0 stderr bytes**. Old harness at `586e481` reproduces the `242 checks, 0 failures` baseline |
| 3 | `tests/mutation-tz.sh` exits non-zero when a broken-offset `statusline.sh` still passes the suite | ✓ VERIFIED | Both directions exercised. Healthy tree: `2 mutants, 0 survivors`, exit 0. Blinded harness (zones that cannot resolve): `2 mutants, 2 survivors`, exit 1. Moved anchor: `2 mutants, 2 survivors`, exit 1 with the "re-point the awk match" message |
| 4 | `tests/mutation-tz.sh` does not CHANGE the working tree | ✓ VERIFIED | `git status --porcelain` captured before and after and compared by `diff` (not an emptiness test): identical, sha `1dd4e15e…` both sides. No `$TMPDIR/statusline-mutation.*` left behind |
| 5 | The sandbox folded-date probe and the sandbox Fable shape assertion can each turn the sandbox summary red | ✓ VERIFIED | Both now end in `check_ok`, which bumps `CHECKS`/`FAILS`; `FAILS` feeds `emit "$CHECKS checks, $FAILS failures"` and the final `[ "$FAILS" -eq 0 ]`. Driven with bad answers through the file's own `emit`/`check_ok`/summary text: `2 checks, 2 failures`, exit 1. With good answers: `2 checks, 0 failures`, exit 0 |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### The Central Question: Is the Gap Actually Closed?

Three throwaway trees, each `cp -R kit tests` into `mktemp -d`, mutated with `awk`, exec bit
preserved (`cat >` over the original, so the PORT-04 check is not disturbed). The real repo was
never written to.

| Experiment | Harness | Mutation | Result | Reading |
|---|---|---|---|---|
| A | `tests/` at `586e481` (pre-task) | `TZOFF=0` | **exit 0 — `242 checks, 0 failures`** | The original defect reproduced exactly as the review described. Deleting timezone handling from the product shipped green |
| B | `tests/` at HEAD | `TZOFF=0` | **exit 1 — `250 checks, 4 failures`**, all four `FAIL non-UTC render …` | The same mutation now turns the suite red. **The gap is closed.** |
| C | `tests/` at HEAD | offset floored to whole hours | **exit 1 — `250 checks, 4 failures`**, all four `FAIL non-UTC render …` | The minute-level half of the offset is also covered |

### Is the Sub-Hour Zone Table Load-Bearing?

I replaced the zone table with four **whole-hour**, no-DST zones (`Asia/Tokyo +0900`,
`Asia/Dubai +0400`, `Asia/Bangkok +0700`, `Pacific/Tahiti -1000`) and re-ran both mutants:

| Zone table | Mutation | Result |
|---|---|---|
| whole-hour | offset rounded to hours | **exit 0 — `250 checks, 0 failures` (SURVIVOR)** |
| whole-hour | `TZOFF=0` | exit 1 — `250 checks, 4 failures` (killed) |
| sub-hour (shipped) | offset rounded to hours | exit 1 — `250 checks, 4 failures` (killed) |

The `:30`/`:45` zones are mechanically load-bearing, not decorative: mutant 2 is invisible to a
whole-hour table and visible only to the shipped one.

### Can the Gate Be Made to Lie?

Two attempts to get `0 survivors` out of a harness that is actually blind. Both failed closed.

| Attack | Setup | Gate output | Verdict |
|---|---|---|---|
| Runtime with no zone database | Zone names rewritten to `Nowhere/*` so every `TZ` falls back to UTC. Oracle and script then agree at UTC and the render checks pass while proving nothing | `2 mutants, 2 survivors`, exit 1, `FAIL non-UTC render lines: 0` | Cannot lie. The `zone database present` rows are what make this loud |
| Mutation anchor moved | `TZOFF=$(…)` reworded to `TZOFF="$(…)"` in the copy so the `awk` match misses | `2 mutants, 2 survivors`, exit 1, `mutation did not apply — the anchor line … moved or was reworded` | Cannot lie. The `cmp -s` applicability guard fires with an actionable message |

The gate's discriminator is `grep -c '^FAIL non-UTC render'`, which is only produced by section 4b
comparing a rendered clock against libc under the same zone. A suite that crashes early, a suite
that fails for an unrelated reason, and a suite whose zone block was removed all yield `killed=0`
and a FAIL. See the WARNING below for the one part of the gate that has gone vacuous.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `tests/run.sh` | new section 4b between section 4 and section 5 | ✓ VERIFIED | +50/-0 lines vs `586e481` — purely additive, **no deletions**, nothing elsewhere loosened. Block sits at `:240-289`, between `live reset clock:` and the `--- 5.` banner |
| `tests/mutation-tz.sh` | new, mode 0755 | ✓ VERIFIED | `-rwxr-xr-x`, `bash -n` clean, standalone (not called from `run.sh`) |
| `tests/sandbox.sh` | §5.13 arms re-pinned, §5.14 converted to a counted check | ✓ VERIFIED | Diff shows exactly those two hunks; 0 `emit "WARN` occurrences remain anywhere in the file |
| `kit/files/home/.claude/statusline.sh` | byte-identical to `586e481` | ✓ VERIFIED | Blob `8cd1ba0baecac3ca4f1ccfd22c0aaed100286386` on both sides; `git diff --name-only 586e481 HEAD -- kit/` is empty. Full change set is `A tests/mutation-tz.sh`, `M tests/run.sh`, `M tests/sandbox.sh` |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| section 4b | section 4 | reuses `dfmt`, `now`, `t5`, `t7` | ✓ WIRED | No recomputation; block is placed after section 4 and before section 5 |
| section 4b | the real script | `TZ=$tzx /bin/bash "$SL"` command prefix | ✓ WIRED | Probe inserted after the 4b loop in a copy: `TZ-AFTER-4B=[UTC] offset=+0000` — the per-command prefix does **not** leak, the global `TZ=UTC` pin (D-72) survives intact |
| `tests/mutation-tz.sh` | section 4b | `grep -c '^FAIL non-UTC render'` | ✓ WIRED | Check name in `run.sh:287` starts with that literal and carries a "do not reword" comment; gate reported `killed: 4` for each mutant |
| `tests/mutation-tz.sh` | `statusline.sh` TZOFF line | `awk` anchor + `cmp -s` guard | ✓ WIRED | Anchor matches `:468`; guard proven to fire when the line is reworded |
| sandbox §5.13/§5.14 | summary counters | `check_ok` -> `CHECKS`/`FAILS` | ✓ WIRED | Driven to red and to green through the file's own function text |

### Data-Flow Trace (Level 4)

| Artifact | Data value | Source | Produces real data | Status |
|---|---|---|---|---|
| `tests/run.sh` 4b | `z5` / `z7` expectations | `TZ=$tzx dfmt` — libc tzdata, an independent implementation | Yes — four distinct per-zone clocks | ✓ FLOWING |
| `tests/run.sh` 4b | rendered `l2` | real `kit/.../statusline.sh` over `tests/fixtures/full.json` with injected `resets_at` | Yes | ✓ FLOWING |
| `tests/mutation-tz.sh` | `killed` | `grep -c` over the mutant's own run log | Yes — `4` on a healthy tree, `0` when blinded | ✓ FLOWING |
| `tests/sandbox.sh` §5.14 | `DZ` | in-container `date '+%s %z'` | Untestable here (Docker down) — logic verified with injected values | ⚠️ deferred (WINDOWS id 2) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Suite is green on a clean tree | `/bin/bash tests/run.sh` | `250 checks, 0 failures`, exit 0, 0 stderr bytes (run twice) | ✓ PASS |
| The 4 + 4 new checks are present and passing | `grep -c '^PASS non-UTC render'` / `'^PASS zone database present'` | `4` and `4` | ✓ PASS |
| Mutation gate on a healthy tree | `/bin/bash tests/mutation-tz.sh` | `2 mutants, 0 survivors`, exit 0 | ✓ PASS |
| Tree unchanged by the gate | `git status --porcelain` before vs after, compared with `diff` | identical | ✓ PASS |
| Syntax of all three scripts | `/bin/bash -n` ×3 | clean | ✓ PASS |
| WR-06 arms vs 12 sample renders | extracted `sandbox.sh:300-306` executed against a table | 4 legitimate forms accepted (incl. the D-69 no-slot `Fable 42%`); trailing space, `% 1:5`, `% Monday 21:10`, trailing junk, no-digits, no-percent, empty line, hidden-Fable all rejected — 12/12 as specified | ✓ PASS |
| WR-06 arms vs **real** renders | real `statusline.sh` driven through `STATUSLINE_USAGE_CACHE` with pct-only / future / past / +3d `resets_at` | produced `Fable 42%`, `Fable 42% 01:30`, `Fable 42% now`, `Fable 42% Wed 00:30` — all four accepted (`r=0`) | ✓ PASS |
| WR-05 shape vs 7 samples | extracted `sandbox.sh:327-330` | `+0000` and `-0530` accepted; empty, bare epoch, `+05:30`, `CEST`, `+530` rejected — 7/7 | ✓ PASS |
| Both sandbox checks can turn the summary red | mini-harness built from `sandbox.sh`'s own `emit`/`check_ok`/summary lines | bad answers -> `2 checks, 2 failures`, exit 1; good answers -> `2 checks, 0 failures`, exit 0 | ✓ PASS |
| `tests/sandbox.sh` full run | `docker info` | fails on this host | ? SKIP — deferred, WINDOWS id 2 |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| WR-01 | Suite has zero end-to-end coverage of non-UTC rendering | ✓ SATISFIED | Experiments A vs B: the review's own defect proof (`TZOFF=0` -> 242/0) now yields 250/4. Plus a mutation gate that keeps it closed |
| WR-05 | GNU `date '+%s %z'` sandbox probe is emit-only and can never fail | ✓ SATISFIED | §5.14 ends in `check_ok`; proven to reach `FAILS` and flip the exit status; 0 `emit "WARN` arms remain |
| WR-06 | Sandbox Fable assertion weakened to near-vacuous | ✓ SATISFIED | Four end-anchored arms; 12/12 discrimination table; all four arms confirmed against renders produced by the real script, including the D-69 no-slot form the review's own patch would have rejected |
| WR-02 | Weekly reset 7 local days out renders today's weekday | — OUT OF SCOPE, still open | `statusline.sh:96-103` unchanged — no `next`/`>= 7` disambiguation |
| WR-03 | `-le` on an empty `NOW` emits stderr | — OUT OF SCOPE, still open | `statusline.sh:466-467` unchanged — no `case "$NOW" in ''|*[!0-9]*)` guard |
| WR-04 | `TODAY` omits the floor-division correction | — OUT OF SCOPE, still open | `statusline.sh:469` is still the bare `TODAY=$(( (NOW + TZOFF) / 86400 ))` |

All three out-of-scope findings are untouched by construction: the product blob is byte-identical
to `586e481`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `tests/mutation-tz.sh` | 70 | `mv` over the copied script drops its exec bit | ⚠️ Warning | Each mutant run also fails the unrelated `exec bit … (PORT-04)` check — `250 checks, 5 failures`, not the `4` the SUMMARY reports. The `status -ne 0` half of the gate's PASS condition is now always true, so the gate depends solely on `killed > 0`. Proven not to make the gate lie; fix is one `chmod +x` |
| `tests/run.sh`, `tests/sandbox.sh`, `tests/mutation-tz.sh` | — | `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` | ℹ️ none | Only `mktemp` `XXXXXX` templates matched — false positives |

### Accuracy of the SUMMARY

Checked, not assumed. Everything in the SUMMARY holds except one number:

- Claimed "both mutants killed — `250 checks, 4 failures` each". Actual mutant suites report
  **`250 checks, 5 failures`**; the extra one is the exec-bit artifact above. The *kill* count
  (4 `FAIL non-UTC render` lines) is correct and is what the gate actually keys on.
- The "`git status --porcelain` before/after byte-identical" claim is correct and was re-measured
  as a `diff`, not an emptiness test.
- The "`kit/` byte-identical" claim is correct at blob-hash level.

### Residual Risk (informational, not a gap)

Section 4b inherits and multiplies section 4's documented clock race: `now` is captured once, the
four renders happen a second or two later, and each zone has its own local midnight. Crossing one
of those midnights inside that window would flake a `non-UTC render` row red. The window is ~seconds
out of 86400 per zone per run, and the plan documents the trade (a production `STATUSLINE_NOW` seam
was judged a worse trade). Worth knowing if a row ever goes red once and then passes on re-run.

### Gaps Summary

None. The phase goal is achieved and was proven adversarially rather than accepted from the
SUMMARY: the exact mutation that used to ship green (242 checks, 0 failures) now turns the suite
red, a second minute-level mutation is caught only because the zone table is sub-hour, the gate
that enforces this fails closed under both blinding attacks I could construct, it leaves the tree
byte-identical, and the product code is untouched.

One WARNING is recorded for the exec-bit side effect in `tests/mutation-tz.sh` — a one-line fix that
does not affect the goal. One item is deferred to the already-tracked WINDOWS entry: the
in-container run of `tests/sandbox.sh` (Docker unavailable on this host), whose assertion logic was
nonetheless verified here without Docker.

---

_Verified: 2026-09-12T21:32:52Z_
_Verifier: Claude (gsd-verifier)_
