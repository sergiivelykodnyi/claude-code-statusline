---
phase: quick-260912-vgx
reviewed: 2026-09-12T20:29:44Z
depth: quick
files_reviewed: 7
files_reviewed_list:
  - kit/files/home/.claude/statusline.sh
  - tests/run.sh
  - tests/render-fixtures.sh
  - tests/sandbox.sh
  - README.md
  - project-brief.md
  - .claude/CLAUDE.md
findings:
  critical: 0
  warning: 6
  info: 6
  total: 12
  closed_not_a_defect: 1
status: issues_found
resolutions:
  - id: WR-02
    outcome: closed_not_a_defect
    closed: 2026-09-13
    note: >-
      Same-weekday collision is real but self-disambiguating — within a 7-day window the
      rendered clock time is always at or before the current clock time, so it cannot read
      as today. Verified empirically against the shipped script; no code change applied.
---

# Quick task 260912-vgx: Code Review Report

**Reviewed:** 2026-09-12T20:29:44Z
**Depth:** quick (pattern scan, plus targeted execution probes on the new arithmetic)
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The change replaces countdown durations on row 2 with local wall-clock reset times. Two new
pure-bash helpers (`tz_offset_secs`, `fmt_reset_clock`) were added, `fmt_duration` was deleted,
and the single `date +%s` became `date '+%s %z'`.

**Every specifically flagged risk area came back clean.** I did not take this on faith — I
executed the helpers directly:

- **Negative floor division** — correct. `fmt_reset_clock` corrects `day` and `rem` together
  (`statusline.sh:94`). Verified: `fmt_reset_clock 0 -1 -14400` -> `20:00`,
  `fmt_reset_clock 0 0 -14400` -> `Wed 20:00` (31 Dec 1969 was a Wednesday).
- **Octal parsing** — correct. Both `%z` fields carry `10#` (`statusline.sh:70`). Verified
  `+0800` -> 28800 and `+0900` -> 32400, the two rows that would be fatal without it.
- **`%z` input validation** — the `case` guard is a fixed-width glob with no `*`, so it matches
  exactly five characters. Verified that `""`, `garbage`, `+03:00`, `+08`, `+08000`, `+005345`
  and a literal `$(touch ...)` payload all fall through to `0` with no arithmetic error and no
  command execution.
- **Portability** — no `date -d`, no `date -r`, no bash-4 construct anywhere in the shipped
  script. The `date -r || date -d` oracle is confined to `tests/run.sh:220` (`dfmt`), as claimed.
- **Weekday modulo** — guarded for negatives at `statusline.sh:98`; all seven names are covered
  by the unit table.
- **Zero-padding** — `%02d:%02d` on both fields, both branches.
- **`fmt_duration` deletion** — zero dangling references in shipped code, tests or live docs
  (`grep` over everything outside `.planning/`).

I also ran a 1344-point differential probe of `fmt_reset_clock` against libc across eight zones
(UTC, New_York, Kolkata, Chatham, Tokyo, Berlin, Lord_Howe, Santiago) over the full realistic
`now .. now+7d` domain: **0 mismatches**. Mismatches appear only for pre-1990 instants and for
instants on the far side of a DST transition — exactly the limitation documented at
`statusline.sh:82-86`, and the "~14 days a year" figure in that comment is accurate.

So: no BLOCKER in the shipped arithmetic. The defects are elsewhere — the suite that is supposed
to protect this feature has a hole I proved with a mutation test, the change introduced a new
stderr-emitting path, and one display case is genuinely misleading.

## Warnings

### WR-01: The suite has zero end-to-end coverage of non-UTC rendering — proven by mutation

**File:** `tests/run.sh:24`, `tests/run.sh:228-239`
**Issue:** `export TZ=UTC` is set globally at the top of the harness, and `tests/render-fixtures.sh:39`
pins it too. Every end-to-end render in all 242 checks therefore runs with `TZOFF == 0`. The
`fmt_reset_clock` unit table passes its offset explicitly, so it never exercises the wiring in
`main` either. The result: the entire timezone path of the shipped script is untested end to end.

I proved this is not theoretical. Replacing `statusline.sh:468` with a hard-coded `TZOFF=0` —
which deletes timezone handling from the product outright — still yields:

```
242 checks, 0 failures
```

A swapped argument order in the `fmt_reset_clock` call, a dropped `TZOFF`, or a broken
`tz_offset_secs` wiring would all ship green.

**Fix:** Keep the UTC pin as the default (it is correct for the byte-diff in `render-fixtures.sh`),
but add one end-to-end render under a fixed non-zero zone whose expectation is derived
independently, e.g. after the section-4 block:

```bash
# Non-UTC end-to-end: proves TZOFF actually reaches fmt_reset_clock.
tzx=Asia/Kolkata                       # +0530: a fractional offset, so an
                                       # ignored TZOFF cannot coincidentally pass
t=$(( now + 600 ))
wexp=$(TZ=$tzx dfmt "$t" '%H:%M')
[ "$(TZ=$tzx dfmt "$t" '%F')" = "$(TZ=$tzx dfmt "$now" '%F')" ] \
  || wexp="$(TZ=$tzx dfmt "$t" '%a') $wexp"
l2=$(jq --argjson t "$t" '.rate_limits.five_hour.resets_at = $t' tests/fixtures/full.json \
     | TZ=$tzx /bin/bash "$SL" | strip_ansi | sed -n 2p)
case "$l2" in *"5h 50% $wexp"*) r=0;; *) r=1;; esac
check_ok "non-UTC render: TZ=$tzx yields '$wexp'" $r
```

A fractional-offset zone is the right choice: with `+0530` a silently-dropped `TZOFF` can never
produce the expected string by accident.

### WR-02: A weekly reset exactly 7 local days out renders a weekday identical to today's — CLOSED, not a defect

**File:** `kit/files/home/.claude/statusline.sh:96-103`
**Issue:** `fmt_reset_clock` prints the bare `HH:MM` only when `day -eq today`, and a 3-letter
weekday otherwise. The weekday name repeats every 7 days, and the `seven_day` (and Fable weekly)
window's `resets_at` reaches up to 7 local days ahead — which is exactly where it sits from the
moment a weekly window resets until the next local midnight. During that stretch the segment
renders e.g. `Week 15% Thu 23:00` while today is also Thursday. A user glancing at the line reads
"resets tonight at 23:00"; it is a week away. That is roughly one day in seven for the weekly
window, and the weekly window is the one where the distinction matters most.

`README.md:29` documents "the weekday appears only when the reset falls on another day" without
noting the 7-day collision, so the docs do not cover for it either.

**Fix:** Disambiguate when the gap is a full week or more. Minimal change, still pure arithmetic:

```bash
  wd=$(( (day + 4) % 7 ))
  [ "$wd" -lt 0 ] && wd=$(( wd + 7 ))
  i=0
  for n in $WD_NAMES; do
    if [ "$i" -eq "$wd" ]; then
      # >= 7 local days out: the weekday name alone is ambiguous (D-67).
      if [ $(( day - today )) -ge 7 ]; then printf 'next %s %02d:%02d' "$n" "$h" "$m"
      else printf '%s %02d:%02d' "$n" "$h" "$m"; fi
      return
    fi
    i=$(( i + 1 ))
  done
```

Then add the `day - today == 7` row to the `fmt_reset_clock` table and update `README.md:29`.

---

**RESOLUTION (2026-09-13): closed as not-a-defect. The fix above was NOT applied.**

The finding describes the shape correctly — the same weekday name does appear, for roughly one
day in seven — but it does not check the *direction* of the rendered time, which is what makes
the line readable. Verified empirically against the shipped script:

```
now = Sat 21:42 (TZ=UTC)

delta | reset at  | renders as         | same weekday?
------+-----------+--------------------+---------------
168h  | Sat 21:42 | Week 15% Sat 21:42 | YES
167h  | Sat 20:42 | Week 15% Sat 20:42 | YES
160h  | Sat 13:42 | Week 15% Sat 13:42 | YES
150h  | Sat 03:42 | Week 15% Sat 03:42 | YES
146h  | Fri 23:42 | Week 15% Fri 23:42 | no
```

In every same-weekday row the rendered clock time is **earlier than or equal to the current
clock time**. It is never later. So `Week 15% Mon 21:00` seen at `Mon 22:00` cannot mean tonight —
21:00 has already passed today — and reads correctly as next Monday.

This is forced, not incidental. A 7-day window means `resets_at - now <= 7 days`. Showing the same
weekday name requires exactly 7 local midnights between the two instants, and that combination
constrains the reset's time-of-day to at or before now's time-of-day. A *later* time on the same
weekday would require a window longer than 7 days.

The reset-boundary sequence was also confirmed end to end:

| Real time | Payload `resets_at` | Renders |
|---|---|---|
| Mon 20:59 | Mon 21:00 (today) | `Week 15% 21:00` |
| Mon 21:01 | Mon 21:00 (stale) | `Week 15% now` |
| Mon 21:01 | next Mon 21:00 (fresh) | `Week 15% Mon 21:00` |

The intermediate `now` is correct: the script renders only what stdin gives it and never computes
the next window, so it reports `now` until Claude Code's payload carries a fresh `resets_at`.

**Residual cases, deliberately accepted:**

1. At exactly 168h — the instant a weekly window opens — the rendered time equals the current time.
   One minute later the clock has advanced and it disambiguates itself. Not worth code.
2. DST: the offset comes from `%z` at *now*, not at the reset instant, so across a transition the
   rendered time can shift an hour and land slightly after now's time-of-day on the same weekday.
   This is the already-documented D-68 skew (~14 days/year), not a separate defect.
3. If `resets_at` could ever exceed 7 days out (a fixed server-side schedule rather than a rolling
   window), a later same-weekday time becomes possible and the ambiguity would be real. No evidence
   either way was found; revisit only if such a payload is observed.

`README.md:29` therefore needs no change — "the weekday appears only when the reset falls on
another day" is accurate, and the collision it does not mention is self-disambiguating.

### WR-03: New `-le` comparisons emit stderr when `NOW` is empty — a regression vs. `fmt_duration`

**File:** `kit/files/home/.claude/statusline.sh:257`, `:271`, `:287` (and `:466-469`)
**Issue:** The old code did `$(( P5_RST - NOW ))`, where an empty `NOW` evaluates to 0 silently.
The new gate is `[ "$P5_RST" -le "$NOW" ]`, which is **not** silent:

```
$ NOW=""; [ 100 -le "$NOW" ]
/bin/bash: line 4: [: : integer expression expected
```

`NOW` is derived by parameter expansion from `date '+%s %z'` with no numeric validation
(`statusline.sh:467`). If that call ever fails or returns an unexpected shape, the script emits
three `[:` errors on stderr, `TODAY` silently collapses to `0`, and every window renders a 1970
wall clock instead of hiding. The project holds itself to a hard "0 stderr bytes" contract
(`tests/run.sh` asserts this in several places) and `claude --debug` surfaces statusline stderr,
so this is a contract regression, not just noise.

**Fix:** Validate `NOW` once, right where it is parsed:

```bash
  NOW_Z=$(date '+%s %z')
  NOW=${NOW_Z%% *}
  case "$NOW" in ''|*[!0-9]*) NOW=0 ;; esac   # date failed / odd shape -> locked, silent
  TZOFF=$(tz_offset_secs "${NOW_Z##* }")
```

With `NOW=0` the `-le` gate is well-formed and every window degrades to the existing `now`
literal — the correct hide-over-placeholder outcome, with no stderr.

### WR-04: `TODAY` omits the floor-division correction that `fmt_reset_clock` applies

**File:** `kit/files/home/.claude/statusline.sh:469`
**Issue:** `TODAY=$(( (NOW + TZOFF) / 86400 ))` is the same truncating division that
`statusline.sh:90-94` goes out of its way to correct, minus the correction. The two day numbers
are then compared with `-eq`, so they must be computed by the *same* rule or the same-day test is
wrong. It happens to be unreachable today (`NOW + TZOFF` is positive for any real clock), but the
asymmetry is exactly the trap the comment at `:91-93` warns about, sitting one screen below that
comment. It also becomes live the moment WR-03's `NOW=0` guard (or any clock fault) lands.

**Fix:** Reuse the correction, or extract it:

```bash
  TODAY=$(( (NOW + TZOFF) / 86400 ))
  [ $(( (NOW + TZOFF) % 86400 )) -lt 0 ] && TODAY=$(( TODAY - 1 ))
```

### WR-05: The GNU `date '+%s %z'` sandbox probe is emit-only and can never fail the run

**File:** `tests/sandbox.sh:296-306`
**Issue:** The comment states plainly that this is "the only place the Linux half can be settled"
— the whole feature rests on one `date` call emitting both fields, and that shape was only ever
verified against BSD `date` on the macOS host. Yet the probe calls `emit "WARN ..."` on failure
and never touches `CHECKS`/`FAILS`. `tests/sandbox.sh:316` summarises `"$CHECKS checks, $FAILS failures"`,
so a GNU userland that returns an unexpected shape — the single fault that silently forces every
reset clock in the container to UTC — leaves the sandbox gate fully green. The stated rationale
("a surprising answer should be read, not silently swallowed by a red X") inverts the actual
outcome: as written the answer is what gets swallowed.

**Fix:** Make it a real check. It is a pure shape assertion with a deterministic expectation:

```bash
case "$DZ" in
  [0-9]*" "[+-][0-9][0-9][0-9][0-9]) r=0 ;;
  *) r=1 ;;
esac
check_ok "folded date '+%s %z' shape under GNU userland (D-68) -> [$DZ]" $r
```

### WR-06: The sandbox Fable assertion was weakened to near-vacuous

**File:** `tests/sandbox.sh:286`
**Issue:** The pattern went from `*"· Fable "*"%/1w"*` to `*"· Fable "*"%"*`. The old form pinned
the segment's trailing shape; the new form matches any line containing `· Fable ` followed
anywhere by a `%`. It would pass on a garbled or empty time slot, on a trailing-space render, and
on any future regression in the reset-clock half of the segment — which is precisely the half this
change rewrote. Loosening the only sandbox-side assertion over the changed code is the wrong
direction.

**Fix:** Re-pin the new shape instead of dropping the constraint:

```bash
  # "Fable NN% now" or "Fable NN% HH:MM" / "Fable NN% Ddd HH:MM"
  case "$FAB_L2" in
    *"· Fable "[0-9]*"% now"|*"· Fable "[0-9]*"% "[0-9][0-9]:[0-9][0-9]|*"· Fable "[0-9]*"% "[A-Z][a-z][a-z]" "[0-9][0-9]:[0-9][0-9]) r=0 ;;
    *) r=1 ;;
  esac
```

## Info

### IN-01: `seg_5h` / `seg_1w` / `seg_fable` are now three byte-identical blocks

**File:** `kit/files/home/.claude/statusline.sh:251-291`
**Issue:** The change turned a one-line tail into an identical 4-line `if/else` copied three
times; the three functions now differ only in two variable names and a label string. Any future
fix to the reset-clock rendering rule (WR-02's fix, for instance) has to be applied three times
and can be applied inconsistently.
**Fix:** Extract the shared tail, e.g.
`reset_slot EPOCH -> "" | " now" | " HH:MM" | " Ddd HH:MM"`, and have each segment call it.

### IN-02: `fmt_reset_clock` falls off the end of its loop and prints nothing

**File:** `kit/files/home/.claude/statusline.sh:99-103`
**Issue:** If `wd` were ever outside `0..6` the `for` loop completes with no `printf` and returns
0. The caller has already appended a space (`out="${out} $(fmt_reset_clock ...)"`), so the segment
would render with a dangling trailing space before the dim separator. Unreachable today given the
`-lt 0` guard on line 98 and `% 7`, but it is a silent-empty fallthrough in a function whose whole
contract is "always print something".
**Fix:** Add an explicit terminal fallback after the loop:
`printf '%02d:%02d' "$h" "$m"` — degrade to the time without a weekday rather than to nothing.

### IN-03: `WD_NAMES` is an unguarded top-level global in a deliberately sourceable file

**File:** `kit/files/home/.claude/statusline.sh:75`
**Issue:** The file carries a `BASH_SOURCE` guard (`:496`) precisely so the test harness can source
the helpers without side effects, yet this adds a top-level assignment between two function
definitions that silently clobbers any `WD_NAMES` in the sourcing shell. Also note the lookup
`for n in $WD_NAMES` relies on word-splitting; it is safe in the shipped path (bash resets `IFS`
to its default at startup — verified: `env IFS=: bash -c 'for x in $V ...'` still splits on
spaces), but it is not safe for a sourcing shell that has changed `IFS`.
**Fix:** Move the constant inside `fmt_reset_clock` as a `local`, or mark it `readonly`.

### IN-04: The `fmt_reset_clock` table has no fractional-offset row

**File:** `tests/run.sh:112-132`
**Issue:** Offsets exercised are `0`, `10800` and `-14400` — all whole hours. `tz_offset_secs`
is tested with `+1345` and `-0430`, but those values never reach `fmt_reset_clock`. A minute-level
bug in the `rem % 3600 / 60` path would not be caught, and a whole-hour-only table cannot
distinguish a correct offset from one rounded to the hour.
**Fix:** Add rows with `19800` (`+0530`), `-12600` (`-0330`) and `49500` (`+1345`), and one
`day - today == 7` row for WR-02.

### IN-05: `dfmt()` has no both-forms-failed guard, and `date -r N` resolves `N` as a filename on GNU

**File:** `tests/run.sh:220`
**Issue:** `dfmt() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null; }`. Two
small hazards: (a) if both forms fail, `w5` becomes empty and the section-4 pattern degrades to
`*"5h 50% "*` — which matches any render, silently voiding half the assertion (the `w7` half still
fails, so the check does not go fully green, but the 5h half stops asserting); (b) on GNU, `date -r`
means "file mtime", so a stray file in the repo root named after the epoch integer would make the
BSD branch succeed with a wrong oracle.
**Fix:** Fail loudly instead of silently:

```bash
dfmt() {
  date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null \
    || { echo "FATAL: no usable date(1) oracle" >&2; exit 1; }
}
```

### IN-06: `.claude/CLAUDE.md` still calls the status line "box-drawing"

**File:** `.claude/CLAUDE.md:7`
**Issue:** This sentence was edited by this change (the countdown clause was rewritten) but the
stale "two-line, **box-drawing** status line" was left in place. The script header declares
`D-21: frameless` (`statusline.sh:2`) and neither the renderer nor the README example emits any
box-drawing character on the status line itself. A doc touched by the change should not leave a
contradiction with the file it describes.
**Fix:** Drop "box-drawing" from the sentence (the `╭─`/`╰─` reference at `.claude/CLAUDE.md:70`
is about multi-line support in general and can stay, though it also predates D-21).

---

_Reviewed: 2026-09-12T20:29:44Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_
