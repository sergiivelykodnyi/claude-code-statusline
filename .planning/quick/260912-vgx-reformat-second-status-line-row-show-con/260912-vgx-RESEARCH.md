# Quick Task 260912-vgx: Reset clock times on row 2 — Research

**Researched:** 2026-09-12
**Domain:** bash 3.2 portable epoch → local wall-clock formatting; test determinism
**Confidence:** HIGH (every mechanism below was executed on this macOS host; outputs pasted)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Weekday display rule**
- Show the weekday name only when the reset falls on a day other than today.
- Reset today -> `14:50`. Reset another day -> `Mon 21:10`.
- "Today" is decided in local time, using the same local day boundary as the clock time.

**Clock format & timezone**
- 24-hour clock, zero-padded: `HH:MM` (`09:05`, `21:10`).
- Local timezone of the machine running the script.
- Implementation constraint: the project bans `date -d` (GNU) and `date -r` (BSD).
  Get the local UTC offset from `date +%z`, add it to the epoch, then run
  days-from-epoch -> civil date arithmetic in pure bash (the inverse of the existing
  `iso_to_epoch` helper, which already does Hinnant civil-from-days). Weekday comes
  from the epoch day number (epoch day 0 = Thursday).
- Must stay bash 3.2 safe and spawn at most one extra process (`date +%z`), ideally
  folded into the existing `date +%s` call site.

**Labels & order**
- Segment shape: `LABEL PCT% TIME` (label first, no `/window` suffix, no parentheses).
- Labels: `5h`, `Week`, `Fable`.
- The context-usage segment keeps its current `pct%/tokens/window` shape - untouched.
- Full row 2 example: `12%/24k/200k · 5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`
- Segment order and the ` · ` separator stay as they are today (context, 5h, week, Fable last).

**Edge cases**
- Reset already passed (`resets_at <= now`) -> render the literal `now` in the time slot:
  `5h 50% now`.
- `resets_at` absent or unparseable -> omit the time slot entirely, keep label and
  percentage: `5h 50%`.
- A segment still hides completely (with its separator) when its percentage is absent -
  existing hide-over-placeholder behaviour is unchanged.
- If `date +%z` gives nothing usable, fall back to UTC rather than hiding the time.

### Claude's Discretion
- Colouring: keep the existing scheme's spirit - threshold colour on the percentage
  number only, `RESET` after it. Default choice: render the `5h` and `Week` labels dim,
  matching the already-dim `Fable` label, and leave the clock time plain.
- Whether the old `fmt_duration` helper is deleted or kept: delete it if nothing else
  uses it after the change; do not keep dead code.
- Naming of the new helper (e.g. `fmt_reset_clock` / `epoch_to_local_hm`).

### Deferred Ideas (OUT OF SCOPE)
Row 1 (model/dir/git) and the context-usage segment.
</user_constraints>

---

## Summary

Every mechanism the locked decisions call for works, and all of it was executed on this
host rather than recalled. `date +%z` exists on macOS BSD `date`, prints `±hhmm`, and can
be folded into the existing `date +%s` call as a single `date '+%s %z'` — so the change
costs **zero extra process spawns** and actually halves the cost versus two calls.

The one genuine simplification research found: **the full Hinnant civil-from-days inverse
is not needed.** Nothing in the locked output ever prints a year, month, or day number —
only `HH:MM` and a 3-letter weekday. Both fall out of a single floor-division of
`epoch + offset` by 86400. The Y/M/D branch of the algorithm would be dead code on day
one. Recommend the ~12-line minimal helper instead of the ~25-line full inverse; this is
an implementation detail inside the locked "days-from-epoch arithmetic in pure bash"
constraint, not a departure from it.

`awk strftime` is **ruled out by direct evidence** — macOS `/usr/bin/awk` (one-true-awk
20200816) errors with `calling undefined function strftime`.

The real risk in this task is not the arithmetic — it is **test determinism**. The
harness has no `TZ` pin and no `STATUSLINE_NOW` seam (both verified absent). It survives
today only because all 8 fixtures set `resets_at: 0`, which renders `now` forever. That
accident keeps working under the new format, but the one live test (run.sh §4) that
injects future epochs will break and must be rebuilt against a libc oracle.

**Primary recommendation:** fold `date +%s` into `date '+%s %z'`, parse the offset with a
guarded `case` + `10#` arithmetic, derive day/HH/MM by floor-division with the negative-
remainder correction, pick the weekday from `(day + 4) % 7` against a space-separated
name list, `export TZ=UTC` in both test scripts, and rebuild run.sh §4 against a
`date -r || date -d` dual-fallback oracle (harness-only — the script itself still never
calls either).

---

## Project Constraints (from CLAUDE.md)

Binding directives that apply to this task:

- Script must be **bash 3.2** syntax (host `/bin/bash` is `3.2.57(1)-release` — verified).
  No `declare -A`, no `${var,,}`, no `mapfile`, no `${var:0:-1}`.
- **`date -d @epoch` (GNU-only) and `date -r epoch` (BSD-only) are banned in the script.**
- Prefer `printf '%b'` / `$'\033[…]'` over `echo -e`.
- Must render byte-identically on macOS (BSD userland) and Docker Sandbox Linux (GNU).
- Hide-over-placeholder: a segment with no data disappears with its separator.
- Status line runs on every render — no new process cost without justification.

---

## Findings

### F1 — `date +%z` is available, POSIX-specified, and safe to rely on

`[VERIFIED: /bin/date on this host]` — actual outputs:

```
$ date +%z
+0300
$ TZ=UTC date +%z          -> +0000
$ TZ=Asia/Kolkata date +%z -> +0530
$ TZ=Asia/Kathmandu date +%z -> +0545
$ TZ=Pacific/Chatham date +%z -> +1245
$ TZ=America/New_York date +%z -> -0400
$ env -i /bin/date +%z     -> +0300      # survives a stripped environment
$ TZ=Invalid/Zone date +%z -> +0000      # bad TZ degrades to UTC, never errors
```

Half-hour (`+0530`), 45-minute (`+0545`, `+1245`) and negative (`-0400`) offsets all come
back in the same fixed 5-character `±hhmm` shape. No edge case in the format.

`[CITED: pubs.opengroup.org/onlinepubs/9799919799/functions/strftime.html]` — `%z` is
marked **[CX]** (POSIX extension beyond ISO C) and is specified as: *"Replaced by the
offset from UTC in the ISO 8601:2019 standard format (+hhmm or −hhmm), **or by no
characters if no timezone is determinable**."* Both BSD and GNU `date` pass the format to
strftime, so `%z` is portable across the two target userlands.

The standard's "no characters" clause is exactly the CONTEXT edge case *"if `date +%z`
gives nothing usable, fall back to UTC"* — it is a real specified outcome, not a
hypothetical, and the parser below returns `0` for it.

`[ASSUMED]` GNU coreutils `date` accepts the combined `'+%s %z'` format string. The Docker
daemon is not running on this host (`dial unix …docker.sock: no such file`), so the Linux
half could not be probed this session. The risk is near-nil (both `%s` and `%z` go through
one strftime call and GNU supports both), but it is untagged-verified and belongs in the
Assumptions Log.

### F2 — `awk strftime` is NOT an option (macOS)

`[VERIFIED: /usr/bin/awk on this host]`:

```
$ awk 'BEGIN{print strftime("%H:%M")}'
awk: calling undefined function strftime
 source line number 1
$ awk --version
awk version 20200816
```

macOS ships BWK one-true-awk, which has no `strftime`. gawk and mawk do, but they are not
present on the macOS host. **Verdict: ruled out.** The pure-arithmetic path is the only
genuinely portable option, which confirms the locked decision.

### F3 — The full Hinnant inverse is unnecessary; floor-division is enough

The locked output needs `HH`, `MM`, and a weekday abbreviation. It never needs Y/M/D.
Given `loc = epoch + offset_seconds`:

- local day number = `floor(loc / 86400)`
- seconds into day = `loc - day * 86400`
- `HH = secs / 3600`, `MM = secs % 3600 / 60`
- weekday index = `(day + 4) % 7` with `0 = Sun`

Epoch day 0 = 1970-01-01 = **Thursday** `[VERIFIED: cross-checked against BSD date -r,
below]`. With `0 = Sun`, Thursday is index 4, hence the `+ 4`.

The `iso_to_epoch` helper's days-from-civil block (statusline.sh:97-101) is the *forward*
direction and stays untouched — it is still needed to parse the Fable ISO `resets_at`.

### F4 — The arithmetic is exact (cross-checked against libc)

Candidate implementation was run against BSD `date -r` — the libc/tzdata oracle — across
**11 timezones × 6 modern epochs**, feeding the helper the offset that BSD reports *at the
target instant*:

```
EXACT: 66/66 modern-epoch cases match BSD date -r
(11 zones incl. +0530 / +0545 / +1245 / -0330 / +1400)
```

Zones covered: `UTC, Europe/Berlin, America/New_York, Asia/Kolkata, Asia/Kathmandu,
Pacific/Chatham, Pacific/Kiritimati, Australia/Adelaide, Asia/Tokyo, America/Sao_Paulo,
America/St_Johns`. `[VERIFIED: executed this session]`

Two pre-1994 cases (`Asia/Kathmandu` at epoch 0, `Pacific/Kiritimati` at epoch 0)
"mismatched", but the fault is BSD's own `%z`, not the arithmetic:

```
$ TZ=Asia/Kathmandu date -r 0 '+%z %Z %a %H:%M'
+0545 +0530 Thu 05:30        # %z reports the CURRENT offset, %Z/%H:%M the 1970 one
```

Irrelevant here — rate-limit resets are always within 7 days of now.

### F5 — DST / offset drift: bounded at 1 hour, twice a year — accept it

`date +%z` gives the offset **now**, not the offset at the reset instant. Measured
divergence, with the helper fed the *current* offset while `date -r` used the historical
one:

```
MISMATCH tz=Europe/Berlin      e=0          got='Thu 02:00'  want='Thu 01:00'   (1h)
MISMATCH tz=America/New_York   e=0          got='Wed 20:00'  want='Wed 19:00'   (1h)
MISMATCH tz=Pacific/Chatham    e=1800000000 got='Fri 20:45'  want='Fri 21:45'   (1h)
MISMATCH tz=Australia/Adelaide e=1800000000 got='Fri 17:30'  want='Fri 18:30'   (1h)
```

`[VERIFIED: executed this session]`

**Quantified risk:**

| Window | Max lookahead | Can straddle a DST change? | Error when it does |
|--------|---------------|----------------------------|--------------------|
| `5h`   | ~5 h          | Only if the change falls inside that 5 h window | 1 h, for ≤5 h per year, twice a year |
| `Week` / `Fable` | ≤7 days | Yes, in the 7 days before each change | 1 h, ~14 days a year |
| Any window in a no-DST zone (UTC, Asia/Kolkata, Asia/Tokyo, …) | — | Never | 0 |

Worst case for a DST-observing user: a displayed reset clock is **1 hour off, on about 14
days out of 365, for a non-critical informational number**. Fixing it properly means
reading the tz database — impossible without `date -d`/`date -r` (banned) or a zoneinfo
parser (absurd for a status line).

**Recommendation: accept, and document it in a code comment.** The cost of the bug is a
one-hour display skew on a soft deadline; the cost of the fix is either breaking the
project's portability ban or adding a binary tz parser. No contest.

### F6 — Folding into one `date` call: verified and measurably faster

`[VERIFIED: /bin/date on this host]`:

```
$ date '+%s %z'
1789242329 +0300
$ TZ=America/New_York date '+%s %z'
1789242329 -0400
```

Timing, 200 iterations each `[VERIFIED: measured this session]`:

```
for … do a=$(date "+%s %z"); done          0.463s total   (~2.3 ms / render)
for … do a=$(date +%s); b=$(date +%z); done 0.967s total   (~4.8 ms / render)
```

**Process count: unchanged from today (one `date`), not "one extra" as CONTEXT allowed.**
Splitting the fields needs no `read` (which the CLAUDE.md `@tsv` warning rightly distrusts)
— plain parameter expansion suffices, and it degrades correctly when `%z` is empty:

```
$ x="1789242329 +0300"; echo "${x%% *} / ${x##* }"    ->  1789242329 / +0300
$ y="1789242329 ";      echo "[${y%% *}] [${y##* }]"  ->  [1789242329] []
```

### F7 — "Is it today?" — compare day numbers, not date strings

Comparing local **day numbers** (integers) is both cheaper and free of string-formatting
bugs, and it reuses the value the clock formatter already computes. Comparing rendered
`Y-M-D` strings would force the full civil-from-days branch back in for no gain.

Compute `TODAY` once in `main` from `NOW + offset` and pass it down; the segment functions
already see `main`'s locals by dynamic scope through `$(seg_5h)` command substitution
(same mechanism `NOW` uses today).

---

## Recommended Implementation

All three snippets below were executed and cross-checked against `date -r`; this is tested
code, not a sketch.

### Offset parser (guarded `case`, injection-proof, `10#` octal-proof)

```bash
# tz_offset_secs ±HHMM -> offset in seconds, 0 for anything unparseable
# (POSIX strftime lets %z emit no characters when no zone is determinable —
# the empty case lands here and yields UTC, per the locked edge case).
tz_offset_secs() {
  local z=$1 sign oh om s
  case "$z" in
    [+-][0-9][0-9][0-9][0-9]) ;;
    *) printf '0'; return 0 ;;
  esac
  sign=${z:0:1}; oh=${z:1:2}; om=${z:3:2}
  s=$(( 10#$oh * 3600 + 10#$om * 60 ))     # 10# — "+0830" would else be bad octal
  [ "$sign" = "-" ] && s=$(( -s ))
  printf '%s' "$s"
}
```

Verified behaviour `[VERIFIED: executed this session]`:

```
[+0300] -> 10800   [-0430] -> -16200   [+0000] -> 0      [-0000] -> 0
[+1345] -> 49500   []      -> 0        [garbage] -> 0    [+03:00] -> 0
[$(touch /tmp/pwn)] -> 0               # hostile input falls through the case, no eval
```

### Clock formatter

```bash
WD_NAMES="Sun Mon Tue Wed Thu Fri Sat"     # bash 3.2: no assoc arrays

# fmt_reset_clock EPOCH TODAY_DAY OFFSET_SECS -> "HH:MM" or "Ddd HH:MM"
fmt_reset_clock() {
  local e=$1 today=$2 off=$3 loc day rem h m wd n i
  loc=$(( e + off ))
  day=$(( loc / 86400 )); rem=$(( loc % 86400 ))
  # bash truncates toward zero: -14400/86400 == 0 and -14400%86400 == -14400,
  # but floor() must give -1. Correct both together, never one alone.
  if [ "$rem" -lt 0 ]; then rem=$(( rem + 86400 )); day=$(( day - 1 )); fi
  h=$(( rem / 3600 )); m=$(( rem % 3600 / 60 ))
  if [ "$day" -eq "$today" ]; then printf '%02d:%02d' "$h" "$m"; return; fi
  wd=$(( (day + 4) % 7 ))                   # epoch day 0 = Thursday, 0=Sun
  [ "$wd" -lt 0 ] && wd=$(( wd + 7 ))
  i=0
  for n in $WD_NAMES; do
    [ "$i" -eq "$wd" ] && { printf '%s %02d:%02d' "$n" "$h" "$m"; return; }
    i=$(( i + 1 ))
  done
}
```

### `main` wiring (one `date`, three new locals)

```bash
  # replaces:  NOW=$(date +%s)
  NOW_Z=$(date '+%s %z')                    # ONE process — both fields (LIM-03)
  NOW=${NOW_Z%% *}
  TZOFF=$(tz_offset_secs "${NOW_Z##* }")    # empty %z -> 0 -> UTC fallback
  TODAY=$(( (NOW + TZOFF) / 86400 ))        # NOW+TZOFF > 0 always; no floor fix needed
```

`NOW_Z`, `TZOFF` and `TODAY` must be added to `main`'s `local` list (statusline.sh:384) so
they do not leak, exactly as `NOW` is handled today.

### Segment shape

```bash
seg_5h() {
  [ -n "$P5_PCT" ] || return 0
  local pct=${P5_PCT%.*} out
  [ -z "$pct" ] && pct=0
  out="${DIM}5h${RESET} $(pct_color "$pct")${pct}%${RESET}"
  if [ -n "$P5_RST" ]; then
    if [ "$P5_RST" -le "$NOW" ]; then out="${out} now"
    else out="${out} $(fmt_reset_clock "$P5_RST" "$TODAY" "$TZOFF")"; fi
  fi
  printf '%s' "$out"
}
```

`seg_1w` is identical with `Week` / `P7_*`; `seg_fable` already has the dim label and just
swaps its `(fmt_duration …)` tail for the same `if`.

**`fmt_duration` becomes dead** — `grep` confirms its only three callers are `seg_5h`,
`seg_1w`, `seg_fable`. Delete it (statusline.sh:54-66) together with its 10-row test table
(tests/run.sh:81-86), per the discretion note.

---

## Test Determinism — the important pitfall

### What the harness supports today

`[VERIFIED: tests/run.sh, tests/render-fixtures.sh, tests/fixtures/*.json]`

- **No `TZ` pin anywhere.** `grep -rn "TZ" tests/*.sh` returns nothing.
- **No `STATUSLINE_NOW` seam.** The script's only env seams are the five Fable ones:
  `STATUSLINE_NO_FABLE`, `STATUSLINE_USAGE_URL`, `STATUSLINE_CREDENTIALS_FILE`,
  `STATUSLINE_USAGE_CACHE`, `STATUSLINE_CURL_MAX_TIME`. `NOW=$(date +%s)` is hard-coded in
  `main`.
- **The fixtures dodge time entirely:** every one of the 8 fixtures sets
  `"resets_at": 0`, and `tests/fixtures/usage/fable.json` uses
  `"resets_at": "1970-01-01T00:00:00Z"` (= epoch 0). Both are in the past forever, so they
  render `(now)` on any machine at any moment. `render-fixtures.sh` states this explicitly
  in its "Determinism:" comment block.

**Good news:** that accident survives the reformat unchanged. Epoch 0 is still
`<= NOW`, so the locked edge case renders the literal `now` — every fixture stays
timezone- and clock-independent, and PORT-01/PORT-04 byte comparison keeps working.

### What breaks

**`tests/run.sh` §4 "Live countdown" (lines 164-168)** is the only genuinely
time-dependent test and it asserts the old duration strings:

```bash
now=$(date +%s)
l2=$(jq --argjson t5 $(( now + 10230 )) --argjson t7 $(( now + 273450 )) … )
case "$l2" in *"(2h:50m)"*"(3d:3h:57m)"*) r=0;; *) r=1;; esac
```

Under the new format the expected text depends on the runner's timezone. Hard-coding it is
not possible.

### Recommended strategy

**1. Pin `TZ=UTC` in both test scripts.** Add beside the existing
`export STATUSLINE_NO_FABLE=1` in `tests/run.sh:20` and `tests/render-fixtures.sh:36`:

```bash
export TZ=UTC   # pin the zone: rendered clock times must not depend on the runner
```

Verified `TZ=UTC date +%z -> +0000` on this host. This removes DST entirely from the test
matrix and hardens PORT-01 (host `+0300` vs sandbox `UTC`) against any *future* fixture
that carries a non-zero `resets_at`. Cheap insurance; `grep` confirms no test asserts any
other time-formatted output that a `TZ` change could disturb.

**2. Rebuild §4 against a libc oracle, not a hard-coded string.** The harness may call
`date -r` / `date -d` — the ban is on the *script*, not the test code — as long as both
userlands are covered by a dual fallback:

```bash
# Harness-only oracle (libc + tzdata). BSD form first, GNU fallback — the same
# dual-fallback shape CLAUDE.md already prescribes for stat. statusline.sh itself
# still never calls date -r or date -d.
dfmt() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null; }

now=$(date +%s)
t5=$(( now + 600 ))            # same local day in almost every case — oracle decides
t7=$(( now + 3 * 86400 ))      # always a different local day -> weekday must appear

w5=$(dfmt "$t5" '%H:%M')
[ "$(dfmt "$t5" '%F')" = "$(dfmt "$now" '%F')" ] || w5="$(dfmt "$t5" '%a') $w5"
w7="$(dfmt "$t7" '%a') $(dfmt "$t7" '%H:%M')"

l2=$(jq --argjson t5 "$t5" --argjson t7 "$t7" \
      '.rate_limits.five_hour.resets_at = $t5 | .rate_limits.seven_day.resets_at = $t7' \
      tests/fixtures/full.json | /bin/bash "$SL" | strip_ansi | sed -n 2p)
case "$l2" in *"5h 50% $w5"*"Week 15% $w7"*) r=0;; *) r=1;; esac
check_ok "live reset clock: '$w5' and '$w7' in '$l2'" $r
```

This is strictly **stronger** than the old test: the expectation comes from the C library's
own tzdata, so the script's pure arithmetic is checked against an independent
implementation rather than against itself.

**3. Do NOT add a `STATUSLINE_NOW` seam.** The only remaining race is that the script reads
its own `date +%s` a few milliseconds after the harness reads `now`; the two disagree about
"today" only if local midnight falls inside that gap — roughly 1 in 10^7 runs, and with
`TZ=UTC` it is the same window for everyone. Note it in a harness comment (run.sh:479
already carries a sibling caveat about whole-second `date +%s` granularity) and move on.
The rendered `HH:MM` itself is fully deterministic: it derives from `P5_RST`, which the
harness fixes, and never from the script's own clock.

**4. Consider adding one past-reset fixture assertion** for the `resets_at` present-but-past
path (`5h 50% now`) — already covered free by every existing fixture.

---

## Other run.sh assertions that must be updated

`[VERIFIED: tests/run.sh, read this session]` — every line asserting old row-2 text:

| Line(s) | Current expectation | Becomes |
|---------|--------------------|---------|
| 85 | `fmt_duration` 10-row table | **delete** (helper removed) |
| 149, 150 | `10%/100k/1M · 50%/5h (now) · 15%/1w (now)` | `10%/100k/1M · 5h 50% now · Week 15% now` |
| 152 | `10%/100k/1M · 50%/5h (now)` | `10%/100k/1M · 5h 50% now` |
| 164-168 | live countdown `(2h:50m)` / `(3d:3h:57m)` | rewrite per the oracle pattern above |
| 177 | `want="${ESC}[${code}m${num}%${ESC}[0m/5h"` | `want="${ESC}[2m5h${ESC}[0m ${ESC}[${code}m${num}%${ESC}[0m"` |
| 234 | `10%/0/1M · 50%/5h (now) · 15%/1w (now)` | `10%/0/1M · 5h 50% now · Week 15% now` |
| 279-283 | 5 rows of `…/5h (now) · …/1w (now)`; note 280 asserts the **no-reset** form `50%/5h ·` | `5h 50% ·` (label+pct, no time slot) |
| 539 | `L2_BASE="10%/100k/1M · 50%/5h (now) · 15%/1w (now)"` | `L2_BASE="10%/100k/1M · 5h 50% now · Week 15% now"` |
| 547, 589, 593, 641, 649 | `Fable 74%/1w (now)` / `Fable 33%/1w (now)` | `Fable 74% now` / `Fable 33% now` |
| 554, 575 | `${ESC}[2mFable${ESC}[0m ${ESC}[33m74%${ESC}[0m/1w` | drop the trailing `/1w`, expect ` now` |
| 605, 709 | `Fable 74%/1w` / `Fable 33%/1w` (no-resets_at case) | `Fable 74%` / `Fable 33%` |

Palette purity (line 196) already permits `2m`, so dim labels need no change there.

---

## Docs that assert the old format

`[VERIFIED: grep, this session]` — live docs only; `.planning/milestones/**` and
`.planning/quick/**` are historical records and must not be rewritten.

**`README.md`** — 8 lines:

| Line | Content |
|------|---------|
| 9 | example row 2: `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)` |
| 28 | legend row `` `50%/5h (2h:50m)` `` — "5-hour rate-limit usage and time to reset" |
| 29 | legend row `` `15%/1w (3d:5h:57m)` `` |
| 30 | legend row `` `Fable 74%/1w (2d:4h:30m)` `` |
| 61 | "`refreshInterval` … so the reset **countdowns** keep ticking" — wording now wrong; with absolute clock times the refresh still matters, but for the *today/other-day* flip and the past→`now` flip, not for a ticking countdown |
| 69 | mock-input sample output `# 10%/100k/1M · 50%/5h (now) · 15%/1w (now)` |
| 70 | `# plus "· Fable NN%/1w (…)"` |
| 77 | prose `` · Fable 74%/1w (2d:4h:30m) `` |

**`project-brief.md`** — 4 lines (10, 24, 25, 31). Note these still describe the *original*
pre-Phase-4 `f()` shape (`15%/1w f(60%) (3d:5h:57m)`), which the shipped script already
does not render — the task should bring them to the new format rather than preserve the
stale one.

**`.claude/CLAUDE.md`** — 3 lines:

| Line | Content |
|------|---------|
| 7 | project description "…rate-limit usage with reset **countdowns** on line two" |
| 40 | stack table row: "`date +%s` + shell arithmetic … Reset **countdowns**" — should now also cover `%z` and the clock arithmetic; **the `date -d` / `date -r` ban on this line must stay verbatim** |
| 73 | `refreshInterval` rationale: "because the reset countdowns are time-based" |

**`.planning/PROJECT.md`** — lines 5, 15, 22, 27, 40, 41, 42, 50, 51, 59. This is project
context rather than a live spec doc, and CONTEXT.md's canonical refs name only
`README.md` and `project-brief.md`. **Recommend updating lines 15/22/40/41/42 (the format
spec) and leaving the historical "✓ … — v1.0 (Phase N)" achievement lines 50/51/59 alone**
— rewriting shipped-milestone records would falsify history.

**`kit/spec.yaml`** — **nothing to change.** `grep` found no row-2 format text; the kit
only ships the file and merges the `statusLine` settings key.

---

## Common Pitfalls

### P1 — Truncating division breaks floor() for negative local times
Bash truncates toward zero and `%` takes the sign of the dividend `[VERIFIED: bash 3.2.57]`:

```
$ echo $(( -14400 / 86400 )) $(( -14400 % 86400 ))
0 -14400                       # floor() would be -1 and 72000
```

Reachable: fixtures set `resets_at: 0`, and any west-of-Greenwich offset makes
`0 + (-14400)` negative. In production the past-reset branch catches it first, but a unit
test of the helper will hit it directly. **Always correct day and remainder together** —
fixing one without the other yields a valid-looking wrong time.

### P2 — `$(( 08 ))` is a fatal octal error
`[VERIFIED: bash 3.2.57]`:

```
$ echo $(( 08 ))
/bin/bash: line 3: 08: value too great for base (error token is "08")
$ echo $(( 10#08 ))
8
```

Offsets `+0800`/`+0900`/`+0845` and minutes `08`/`09` all hit this. The existing
`iso_to_epoch` already uses `10#` correctly (statusline.sh:87-90) — copy the idiom, do not
improvise. A bare `$(( $oh * 3600 ))` would blank the whole status line in eight timezones.

### P3 — Zero-padding needs `printf '%02d'`, not string concat
`printf 'pad: %02d:%02d' 9 5` -> `09:05` `[VERIFIED]`. `$h:$m` would render `9:5`, which
the locked spec forbids.

### P4 — New locals must be declared in `main`
`main` declares its locals on one line (statusline.sh:384). `NOW_Z`, `TZOFF` and `TODAY`
must join it. Segment functions see them by dynamic scope through `$(seg_5h)` — the same
route `NOW` uses today. Forgetting the `local` leaks them into the shell; forgetting the
assignment makes `$(( … ))` silently treat them as `0`, which renders `00:00` rather than
failing loudly.

### P5 — Do not use `read` to split `date '+%s %z'`
The CLAUDE.md `@tsv`+`read` warning generalises: parameter expansion
(`${x%% *}` / `${x##* }`) is one less process, has no IFS surprises, and degrades correctly
when `%z` is empty `[VERIFIED: F6 output]`.

### P6 — Guard the `%z` parse with `case`, never with arithmetic on raw input
The script's whole security posture is "untrusted values never reach `$(( ))`". `date +%z`
is not attacker-controlled, but `TZ` is environment-controlled, and an unguarded
`$(( 10#${z:1:2} … ))` on a surprising value is exactly the class of sink the existing
uint guards exist to prevent. The `case` in the recommended parser rejects everything that
is not literally `±hhmm`, verified against `$(touch /tmp/pwn)` as input.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Full civil-from-days (Y/M/D) inverse | ~25 lines of era/yoe/doy Hinnant arithmetic | `floor(loc/86400)` + `(day+4)%7` | Y/M/D is never rendered — it would be dead code from day one |
| Timezone-correct historical offsets | zoneinfo parser / `date -d`/`-r` shim | `date +%z` (offset at *now*) | 1 h skew on ~14 days/yr on a soft number; a tz parser in a per-render bash script is absurd |
| A `STATUSLINE_NOW` test seam | new production env var | libc oracle in the harness | the seam buys ~1e-7 of flake reduction at the cost of permanent production surface |
| Weekday name lookup table | `declare -A` | `WD_NAMES="Sun Mon …"` + word-split `for` | bash 3.2 has no associative arrays (binding constraint) |

---

## Environment Availability

| Dependency | Required by | Available | Version | Notes |
|------------|-------------|-----------|---------|-------|
| `/bin/bash` | script runtime | ✓ | 3.2.57(1)-release | the binding syntax constraint |
| `/bin/date` `%z` | local offset | ✓ | BSD (macOS) | `+0300` on this host; `env -i` safe |
| `/bin/date` `'+%s %z'` | folded call | ✓ | BSD (macOS) | `1789242329 +0300` |
| GNU `date '+%s %z'` | Linux sandbox | **unverified** | — | Docker daemon not running this session |
| `/usr/bin/awk` `strftime` | (rejected alternative) | ✗ | one-true-awk 20200816 | `calling undefined function strftime` |
| `date -r` / `date -d` | **harness oracle only** | ✓ / ✓ (dual fallback) | — | never in `statusline.sh` |
| `jq` | fixture mutation in tests | ✓ | already a project dep | — |

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | GNU coreutils `date` accepts the combined `'+%s %z'` format and prints `±hhmm` | F1 / F6 | Sandbox renders a broken clock or an empty offset (→ UTC fallback, so degraded not fatal). **Mitigation: run `date '+%s %z'` inside the sandbox once during execution** — the harness already runs there (`tests/sandbox.sh`), so this costs one line |
| A2 | `TZ=UTC` yields `+0000` from GNU `date +%z` in the sandbox | Test strategy | Sandbox and host fixture renders diverge → PORT-01 byte-diff failure. Detected immediately by the existing `render-fixtures.sh` diff, so it fails loudly rather than silently |
| A3 | No live spec doc outside README / project-brief / CLAUDE.md / PROJECT.md asserts the row-2 format | Docs section | A stale doc survives. `grep` over `*.md`/`*.yaml`/`*.sh` outside `.planning/milestones` and `.planning/quick` found only those four, so confidence is high |

---

## Open Questions

1. **Should `PROJECT.md` historical achievement lines be rewritten?**
   - Known: lines 15/22/40/41/42 are the live format spec; 50/51/59 are shipped-milestone
     records phrased as "✓ … — v1.0 (Phase N)".
   - Unclear: whether the project treats PROJECT.md achievements as immutable history.
   - Recommendation: update the spec lines, leave the achievement lines. Confirm with the
     user if the planner wants a single consistent doc instead.

2. **Does `refreshInterval: 60` still earn its keep?**
   - Known: it exists because countdowns tick. Absolute clock times do not tick.
   - Still needed for: the past→`now` flip, and the today→weekday flip at local midnight.
   - Recommendation: keep the setting, reword the *rationale* in README:61 and
     CLAUDE.md:73. Not a behaviour change — out of scope for this task beyond the wording.

---

## Sources

### Primary (HIGH confidence)
- **This host, executed 2026-09-12** — `bash --version`, `date +%z` across 8 zones,
  `date '+%s %z'`, `env -i date +%z`, `TZ=Invalid/Zone date +%z`, `awk strftime` probe,
  200-iteration timing of folded vs split `date`, bash negative-division and octal probes,
  66-case cross-check of the candidate helper against `date -r` over 11 timezones.
- **Repo files read this session** — `kit/files/home/.claude/statusline.sh` (442 lines),
  `tests/run.sh` (766), `tests/render-fixtures.sh` (85), all 8 `tests/fixtures/*.json`,
  `tests/fixtures/usage/fable.json`, `README.md`, `project-brief.md`, `kit/spec.yaml`,
  `.claude/CLAUDE.md`, `.planning/PROJECT.md`, `.planning/STATE.md`.
- **POSIX.1-2024 `strftime`** — https://pubs.opengroup.org/onlinepubs/9799919799/functions/strftime.html
  — `%z` marked [CX], `±hhmm` or no characters.
- **POSIX.1-2024 `date`** — https://pubs.opengroup.org/onlinepubs/9799919799/utilities/date.html
  — "formatted as if by strftime() with the specified format string".

### Not consulted
- GNU coreutils manual (HTTP 429 this session) — GNU `%z` behaviour is A1 in the
  Assumptions Log rather than a cited fact.

---

## Metadata

**Confidence breakdown:**
- macOS `date +%z` / folded call / timing: **HIGH** — executed, output pasted
- Arithmetic correctness: **HIGH** — 66/66 against libc across 11 zones
- `awk strftime` rejection: **HIGH** — error output pasted
- DST risk quantification: **HIGH** — divergence measured, bound is structural (≤1 h)
- GNU/Linux half: **LOW** — Docker unavailable; A1/A2 flagged, both fail loudly
- Test-harness inventory: **HIGH** — files read, `grep` for `TZ` and `STATUSLINE_*` run
- Doc inventory: **MEDIUM-HIGH** — `grep`-driven; A3 flagged

**Research date:** 2026-09-12
**Valid until:** stable indefinitely (POSIX + bash 3.2 semantics do not move); re-check A1
on the first sandbox run.
