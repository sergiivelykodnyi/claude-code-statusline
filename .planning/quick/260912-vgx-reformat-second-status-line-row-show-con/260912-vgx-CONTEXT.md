# Quick Task 260912-vgx: Reformat second status line row: show concrete reset clock times instead of countdown durations - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning

<domain>
## Task Boundary

Change the rate-limit part of status line row 2 from countdown durations to concrete
local wall-clock reset times, and move each window's label to the front of its segment.

Before: `50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)`
After:  `5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`

In scope: `seg_5h`, `seg_1w`, `seg_fable` in `kit/files/home/.claude/statusline.sh`,
plus a new epoch -> local-clock formatter. Out of scope: row 1 (model/dir/git) and
the context-usage segment.
</domain>

<decisions>
## Implementation Decisions

### Weekday display rule
- Show the weekday name only when the reset falls on a day other than today.
- Reset today -> `14:50`. Reset another day -> `Mon 21:10`.
- "Today" is decided in local time, using the same local day boundary as the clock time.

### Clock format & timezone
- 24-hour clock, zero-padded: `HH:MM` (`09:05`, `21:10`).
- Local timezone of the machine running the script.
- Implementation constraint: the project bans `date -d` (GNU) and `date -r` (BSD).
  Get the local UTC offset from `date +%z`, add it to the epoch, then run
  days-from-epoch -> civil date arithmetic in pure bash (the inverse of the existing
  `iso_to_epoch` helper, which already does Hinnant civil-from-days). Weekday comes
  from the epoch day number (epoch day 0 = Thursday).
- Must stay bash 3.2 safe and spawn at most one extra process (`date +%z`), ideally
  folded into the existing `date +%s` call site.

### Labels & order
- Segment shape: `LABEL PCT% TIME` (label first, no `/window` suffix, no parentheses).
- Labels: `5h`, `Week`, `Fable`.
- The context-usage segment keeps its current `pct%/tokens/window` shape - untouched.
- Full row 2 example: `12%/24k/200k · 5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`
- Segment order and the ` · ` separator stay as they are today (context, 5h, week, Fable last).

### Edge cases
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
</decisions>

<specifics>
## Specific Ideas

User-supplied target string (authoritative for spacing and wording):

    5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10

Weekday names are the standard 3-letter English abbreviations: Mon Tue Wed Thu Fri Sat Sun.
</specifics>

<canonical_refs>
## Canonical References

- `.claude/CLAUDE.md` - bash 3.2 portability rules (the `date -d` / `date -r` ban, no
  bash 4 features), stdin JSON contract for `rate_limits.*.resets_at`, hide-over-placeholder.
- `kit/files/home/.claude/statusline.sh` - `fmt_duration` (lines ~54-66), `iso_to_epoch`
  (civil-from-days reference implementation), `seg_5h` / `seg_1w` / `seg_fable` (~207-238).
- `project-brief.md` and `README.md` - live spec docs that document the row 2 format and
  must be updated to match the new rendering.
- `tests/` - `run.sh`, `render-fixtures.sh` and the `fixtures/` JSON payloads assert the
  current row 2 text; they must be updated. Note tests must be deterministic despite the
  new time-of-day rendering (fixtures with fixed `resets_at` now depend on the test
  machine's timezone - the plan must address this).
</canonical_refs>
