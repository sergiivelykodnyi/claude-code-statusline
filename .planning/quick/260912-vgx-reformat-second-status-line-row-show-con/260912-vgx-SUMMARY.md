---
phase: quick-260912-vgx
plan: 01
subsystem: ui
tags: [bash, statusline, ansi, date, timezone, portability, testing]

# Dependency graph
requires:
  - phase: "04"
    provides: "seg_fable as a separate last line-2 peer segment, and the 226-check harness this task retargets"
  - phase: "01"
    provides: "seg_5h / seg_1w, the jq uint canonicalizer, and the single-date-call LIM-03 contract"
provides:
  - "tz_offset_secs — guarded ±hhmm parser with a UTC fallback, the only path from the environment-controlled TZ into arithmetic"
  - "fmt_reset_clock — epoch to local HH:MM / Ddd HH:MM in pure floor-division, no date(1) and no banned flags"
  - "Row 2 rate-limit segments in LABEL PCT% TIME shape across all three windows"
  - "A zone-pinned harness whose one clock-dependent check is verified against a libc/tzdata oracle instead of hard-coded strings"
affects: [future row-2 segments, any phase adding a rate-limit window, sandbox parity runs]

actuals:
  tokens: 10859
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Folded date(1) call: one process emits epoch and offset together, split by parameter expansion"
    - "case shape guard before any arithmetic on environment-derived strings"
    - "Harness-local libc oracle (date -r || date -d) for clock expectations the script must not compute itself"

key-files:
  created: []
  modified:
    - kit/files/home/.claude/statusline.sh
    - tests/run.sh
    - tests/render-fixtures.sh
    - tests/sandbox.sh
    - README.md
    - project-brief.md
    - .claude/CLAUDE.md
    - .planning/PROJECT.md

key-decisions:
  - "D-66: row-2 rate-limit segments render LABEL PCT% TIME — label first, no /window suffix, no parentheses"
  - "D-67: 24-hour zero-padded local HH:MM, weekday prefix only when the reset falls on another local day"
  - "D-68: local offset comes from %z folded into the existing single date(1) call; unusable %z falls back to UTC rather than hiding the time"
  - "D-69: reset at or before now renders the literal 'now'; absent reset drops the time slot but keeps label and percentage"
  - "D-70: threshold colour wraps the percentage number only; 5h and Week labels render dim like Fable; clock text is plain"
  - "D-71: fmt_duration deleted once its last caller was gone"
  - "D-72: tests pin TZ=UTC and rebuild the one live time check against a harness-only libc oracle; no STATUSLINE_NOW production seam added"
  - "DST skew accepted and documented in code: the offset is the one in effect now, not at the reset instant, so a clock can read one hour off for roughly 14 days a year"

patterns-established:
  - "Environment-derived strings pass a case shape guard before any $(( )) sink, matching the existing jq uint canonicalizer posture"
  - "Both fields of a two-digit numeric parse carry the 10# base-10 prefix — a bare $(( 08 )) is a fatal error that blanks the whole line"
  - "Floor-division correction fixes day and remainder together, never one without the other"
  - "Clock expectations in tests come from libc, not from the implementation under test"

requirements-completed: [LIM-01, LIM-02, LIM-03, FAB-01, PORT-01, PORT-04, PRES-04]

coverage:
  - id: D1
    description: "Row 2 renders each rate-limit window as LABEL PCT% TIME with the label first"
    requirement: LIM-01
    verification:
      - kind: unit
        ref: "tests/run.sh#run_fixture full / no-effort / only-five-hour line 2"
        status: pass
      - kind: unit
        ref: "tests/run.sh#threshold bytes: pct $p -> dim 5h label, SGR ${code}m around ${num}% only"
        status: pass
    human_judgment: false
  - id: D2
    description: "The clock is a 24-hour zero-padded local HH:MM; the 3-letter weekday prefix appears only when the reset falls on a local day other than today"
    requirement: LIM-02
    verification:
      - kind: unit
        ref: "tests/run.sh#fmt_reset_clock table (15 rows, explicit TODAY, all seven weekday names)"
        status: pass
      - kind: integration
        ref: "tests/run.sh#live reset clock — expectation supplied by the libc dual-fallback oracle"
        status: pass
    human_judgment: false
  - id: D3
    description: "A reset at or before now renders the literal 'now'; an absent or unparseable resets_at omits the time slot and keeps label and percentage"
    requirement: PRES-04
    verification:
      - kind: unit
        ref: "tests/run.sh#non-integer probe: five_hour resets_at exponent line 2 (out-of-range epoch drops the slot)"
        status: pass
      - kind: unit
        ref: "tests/run.sh#fable: no resets_at -> no time slot"
        status: pass
    human_judgment: false
  - id: D4
    description: "A window with no percentage still hides completely together with its separator"
    requirement: PRES-04
    verification:
      - kind: unit
        ref: "tests/run.sh#run_fixture no-rate-limits line 2; fable: past-grace hide / no bucket hidden"
        status: pass
    human_judgment: false
  - id: D5
    description: "The context-usage segment and all of row 1 are byte-identical to before the change"
    requirement: PRES-04
    verification:
      - kind: integration
        ref: "old-vs-new render of all 8 fixtures, ANSI-stripped: row 1 and the context segment identical in every one"
        status: pass
    human_judgment: false
  - id: D6
    description: "The script still calls date(1) exactly once per render and never uses the two banned epoch-formatting flags"
    requirement: LIM-03
    verification:
      - kind: automated_ui
        ref: "tracer gate: grep -cF '$(date' == 1 and grep -cE 'date[[:space:]]+-[dr]' == 0 over non-comment lines"
        status: pass
    human_judgment: false
  - id: D7
    description: "tz_offset_secs rejects hostile and malformed offsets before any arithmetic, and survives the base-10 prefix trap"
    requirement: PORT-04
    verification:
      - kind: unit
        ref: "tests/run.sh#tz_offset_secs table incl. +0800, empty, garbage, +03:00 and a command-substitution payload"
        status: pass
    human_judgment: false
  - id: D8
    description: "Fixture renders stay byte-identical between host and sandbox because both test scripts pin the zone"
    requirement: PORT-01
    verification:
      - kind: integration
        ref: "tests/render-fixtures.sh — 8 renders produced; export TZ=UTC present in run.sh and render-fixtures.sh"
        status: pass
      - kind: manual_procedural
        ref: "tests/sandbox.sh §5.13 Fable probe + §5.14 folded-date probe under GNU userland"
        status: unknown
    human_judgment: true
    rationale: "The Linux half of the folded '+%s %z' format string is the one assumption research could not settle — the Docker daemon was not running. Only a real sandbox run can confirm it."
  - id: D9
    description: "The four live spec docs describe the shipped format; historical records untouched"
    verification:
      - kind: automated_ui
        ref: "Task 3 docs gate: zero stale format/countdown matches, new format present in all four, ban sentence byte-identical, achievement lines intact"
        status: pass
    human_judgment: true
    rationale: "The gate proves the strings changed, not that the README legend reads well end to end — that needs a human pass."

duration: 42min
completed: 2026-09-12
status: complete
---

# Quick Task 260912-vgx: Reset Clock Times on Row 2 Summary

**Row 2's three rate-limit windows now answer "when do I get my quota back" directly — `5h 50% 14:50` instead of `50%/5h (2h:50m)` — computed in pure bash arithmetic from one folded `date '+%s %z'` call, with no new process and neither banned epoch-formatting flag.**

## Performance

- **Duration:** ~42 min
- **Tasks:** 3/3
- **Commits:** 3
- **Test suite:** 226 → 242 checks, 0 failures

## Accomplishments

- **Two new pure helpers.** `tz_offset_secs` turns `%z` into seconds behind a `case` shape guard that accepts exactly a sign plus four digits; everything else — including an empty `%z`, which POSIX explicitly permits — returns `0`, the locked UTC fallback. `fmt_reset_clock` floor-divides `epoch + offset` into a local day number and seconds-into-day, emits `printf '%02d:%02d'`, and prefixes a weekday picked by `(day + 4) % 7` only when the day differs from today.
- **Process count held flat.** `main`'s `NOW=$(date +%s)` became `NOW_Z=$(date '+%s %z')`, split by parameter expansion. One `date` call before, one after — LIM-03 intact, and measurably cheaper than the two-call alternative research rejected.
- **All three segments reshaped** to dim label, threshold-coloured percentage, plain clock — with `now` for a passed reset and no time slot at all when the reset is unknown.
- **`fmt_duration` deleted** along with its ten-row test table; its only three callers were the segments just rewritten.
- **The harness got stronger, not just updated.** The one genuinely clock-dependent check no longer compares against hard-coded duration strings — it asks libc (via a `date -r || date -d` dual fallback, harness-only) what the answer should be. The script's pure arithmetic is now checked against an independent implementation with real tzdata rather than against itself.
- **Zone pinned in both test scripts**, which removes DST from the test matrix entirely and hardens the host-vs-sandbox byte comparison against any future fixture carrying a non-zero reset.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Render one reset epoch as a local wall clock, end to end | `b248f95` | kit/files/home/.claude/statusline.sh |
| 2 | Make the harness deterministic and green against the new format | `9032d7e` | tests/run.sh, tests/render-fixtures.sh, tests/sandbox.sh |
| 3 | Bring the four live spec docs in line with what ships | `0f9488c` | README.md, project-brief.md, .claude/CLAUDE.md, .planning/PROJECT.md |

## Verification Evidence

**Tracer gate (Task 1)** — `TRACER-OK`. Fixture renders `10%/100k/1M · 5h 50% now · Week 15% now`; a future-epoch render matched the libc oracle for both a same-day and a three-days-out reset; zero banned flags; `fmt_duration` gone; exactly one `$(date` substitution.

**Harness gate (Task 2)** — `HARNESS-OK`. 242 checks / 0 failures, both scripts zone-pinned, no stale helper table, no stale row-2 text, all 8 fixtures rendered.

**Docs gate (Task 3)** — `DOCS-OK`. Zero stale format or countdown wording in the live docs, new format present in all four, the `date -d` / `date -r` ban sentence byte-identical, PROJECT.md's shipped-milestone achievement lines untouched, `kit/spec.yaml` re-confirmed to carry no format text.

**Byte-identity check (success criterion, run outside the task gates):** every one of the 8 fixtures rendered through the pre-change script and the post-change script produced an identical row 1 and an identical context segment. Only the rate-limit segments moved.

**Live render against the real host zone (+0300), with future resets injected:**

```
10%/100k/1M · 5h 50% Sun 01:51 · Week 15% Tue 23:21
libc:                   Sun 01:51          Tue 23:21
```

Exact agreement, including the weekday prefix appearing on the 5h window because its reset crosses midnight into the next local day.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ten hand-computed rows in the new `fmt_reset_clock` table were wrong**

- **Found during:** Task 2, before the first suite run
- **Issue:** I wrote the expectation table by hand (weekday names and times for a set of epochs). Cross-checking each epoch against `date -r` showed ten of the fifteen rows had the wrong weekday, the wrong time, or both — e.g. epoch `1728291000` is `Mon 08:50`, not the `Mon 21:10` I had written, and `1728118800` is `Sat 09:00`, not `Fri 01:00`.
- **Fix:** Recomputed every row against libc and rewrote the table. Also replaced a duplicate-Thursday row with one that reaches Friday, so all seven weekday names are now covered by the mapping test.
- **Why this matters:** had I committed the table first and then "fixed" failures by adjusting the script, I would have bent a correct implementation to match wrong expectations. The oracle-first discipline the plan mandates for §4 applies just as much to the static table.
- **Files modified:** tests/run.sh
- **Commit:** `9032d7e`

### Plan-Directed Additions

**2. Example strings added to `.claude/CLAUDE.md`**

Task 3's own gate requires the literal `5h 50%` in all four docs. The CLAUDE.md edits the plan enumerated (description sentence, stack-table row, `refreshInterval` rationale) are prose and carried no rendered example, so the gate failed on the first run. Added `5h 50% 14:50` / `Week 15% Mon 21:10` to the stack-table notes cell, which is where the arithmetic is described and where a concrete example earns its place. The ban sentence in that same cell was not touched.

### Process Note

**3. The pre-staged PLAN.md was swept into the Task 1 commit and removed**

`.planning/quick/.../260912-vgx-PLAN.md` was already `git add`-ed when I started, so the first `git commit` picked it up alongside the script. Caught it immediately, unwound with `git reset --soft HEAD~1`, unstaged the doc, and re-committed the script alone as `b248f95`. No planning artifact is in any of the three task commits — the orchestrator's docs commit still owns them.

## Known Stubs

None. Every branch of both new helpers is exercised by the harness, and no placeholder or TODO was introduced.

## Threat Flags

None. The task added no network call, no new data source, and no new file read; the only new trust boundary — `TZ` steering the offset string — is the one the plan's threat register anticipated (T-VGX-01/02), and it is guarded by the `case` shape check and the `10#` prefix, both covered by harness rows.

## Accepted Limitations

**DST skew, documented in the code.** `%z` reports the offset in effect *now*, not at the reset instant. A window whose reset straddles a changeover therefore displays a clock one hour off. Bounded: at most 1 hour, on roughly 14 days a year, for a soft informational number, and never in a zone without DST. Fixing it properly requires the tz database, which is unreachable without the two flags this project bans. Measured, bounded, accepted — and stated in a comment above `fmt_reset_clock` so a future reader does not mistake it for an oversight.

**Pre-existing shellcheck info-level findings** (SC2016, SC2015, SC2153) sit in the untouched Fable adapter. Out of scope per the plan's scope boundary; none originate in the new helpers.

## Outstanding Human Verification

Deferred to end-of-phase per `workflow.human_verify_mode: end-of-phase`:

1. **Sandbox run** (`tests/sandbox.sh`) — confirms §5.13 against the new Fable shape and settles the one assumption research could not: that GNU `date` accepts the folded `'+%s %z'` format string. A new §5.14 informational probe reports the raw answer and warns rather than failing, so the evidence is readable either way.
2. **README legend read-through** — the gate proves the strings changed; a human should confirm the legend reads well against the line they actually see.

## Self-Check: PASSED

All 8 modified files present on disk; all 3 commit hashes (`b248f95`, `9032d7e`, `0f9488c`) found in `git log`.
