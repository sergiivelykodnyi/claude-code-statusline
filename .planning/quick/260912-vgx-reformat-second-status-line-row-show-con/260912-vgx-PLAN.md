---
phase: quick-260912-vgx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - kit/files/home/.claude/statusline.sh
  - tests/run.sh
  - tests/render-fixtures.sh
  - tests/sandbox.sh
  - README.md
  - project-brief.md
  - .claude/CLAUDE.md
  - .planning/PROJECT.md
autonomous: true
requirements: [LIM-01, LIM-02, LIM-03, FAB-01, PORT-01, PORT-04, PRES-04]

estimate:
  tokens: 90000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Row 2 renders each rate-limit window as `LABEL PCT% TIME` with the label first (D-66): `5h 50% 14:50`, `Week 15% Mon 21:10`, `Fable 74% Mon 21:10`"
    - "The clock is a 24-hour zero-padded local `HH:MM`; the 3-letter weekday prefix appears only when the reset falls on a local day other than today (D-67)"
    - "A reset at or before now renders the literal `now`; an absent or unparseable `resets_at` omits the time slot entirely and keeps label + percentage (D-69)"
    - "A window with no percentage still hides completely together with its separator — hide-over-placeholder unchanged (D-69)"
    - "The context-usage segment on row 2 is byte-identical to before the change"
    - "The script still calls date(1) exactly once per render and still never uses the two banned epoch-formatting flags (D-68)"
    - "`/bin/bash tests/run.sh` reports 0 failures on the host"
    - "Fixture renders stay byte-identical between host and sandbox (PORT-01) because both test scripts pin the zone (D-72)"
  artifacts:
    - "kit/files/home/.claude/statusline.sh — adds `tz_offset_secs` + `fmt_reset_clock`, rewires `main`, rewrites `seg_5h`/`seg_1w`/`seg_fable`, removes `fmt_duration` (D-71)"
    - "tests/run.sh — zone pin, `fmt_duration` table removed, §4 rebuilt against a libc oracle, all row-2 expectations updated"
    - "tests/render-fixtures.sh — zone pin beside the existing kill-switch export"
    - "tests/sandbox.sh — §5.13 Fable pattern updated to the new segment shape"
    - "README.md, project-brief.md, .claude/CLAUDE.md, .planning/PROJECT.md — live format spec updated"
  key_links:
    - "`main`'s folded `date '+%s %z'` → `NOW` / `TZOFF` / `TODAY` locals → dynamic scope into `seg_5h` / `seg_1w` / `seg_fable` (the same route `NOW` already travels)"
    - "jq `uint` canonicalizer → `P5_RST` / `P7_RST` → `fmt_reset_clock` arithmetic sink (the sink must not widen)"
    - "`iso_to_epoch` (unchanged, still needed) → `FAB_RST` → `fmt_reset_clock`"
    - "zone pin in both test scripts → identical fixture bytes on macOS and in the Linux sandbox (PORT-01 / PORT-04)"
---

<objective>
Change the three rate-limit segments on status-line row 2 from countdown durations to
concrete local wall-clock reset times, with the window label moved to the front of each
segment.

Before: `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)`
After:  `10%/100k/1M · 5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`

Purpose: a wall-clock time answers "when do I get my quota back" in one glance; a
countdown makes the reader do arithmetic against their own clock.

Output: the reformatted script, a green and still-deterministic test harness, and the
four live spec docs brought in line with what the script actually renders.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@.planning/quick/260912-vgx-reformat-second-status-line-row-show-con/260912-vgx-CONTEXT.md
@.planning/quick/260912-vgx-reformat-second-status-line-row-show-con/260912-vgx-RESEARCH.md
@kit/files/home/.claude/statusline.sh
</context>

<decision_ledger>
This quick task continues the project's D-numbering, which ended at D-65.

| ID | Decision | Source |
|----|----------|--------|
| D-66 | Segment shape is `LABEL PCT% TIME` — label first, no `/window` suffix, no parentheses. Labels: `5h`, `Week`, `Fable`. Order and the ` · ` separator are unchanged (context, 5h, Week, Fable last). | CONTEXT "Labels & order" |
| D-67 | 24-hour zero-padded local `HH:MM`. The 3-letter weekday prefix (`Mon`..`Sun`) appears only when the reset is on a local day other than today; "today" is decided on the same local day boundary as the clock. | CONTEXT "Weekday display rule" + "Clock format & timezone" |
| D-68 | The local UTC offset comes from `%z`, folded into the existing single date(1) call. Day / hour / minute come from pure floor-division arithmetic — no new process, and the project's two banned epoch-formatting flags stay unused. Unusable `%z` falls back to UTC rather than hiding the time. | CONTEXT "Clock format & timezone" + edge cases |
| D-69 | Reset at or before now → the literal `now`. Absent or unparseable `resets_at` → the time slot is omitted, label and percentage remain. Missing percentage → the whole segment still hides with its separator. | CONTEXT "Edge cases" |
| D-70 | Threshold colour wraps the percentage number only, `RESET` right after it. `5h` and `Week` labels render dim, matching the already-dim `Fable` label. The clock text is plain. | CONTEXT "Claude's Discretion" — colouring |
| D-71 | `fmt_duration` is deleted once its last caller is gone — no dead code. | CONTEXT "Claude's Discretion" — helper deletion |
| D-72 | Tests pin the zone to UTC and rebuild the one live time test against a harness-only libc oracle. No `STATUSLINE_NOW` production seam is added. | RESEARCH "Test Determinism", constraints |
</decision_ledger>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Render one reset epoch as a local wall clock, end to end</name>
  <files>kit/files/home/.claude/statusline.sh</files>
  <read_first>
    Read the whole script once (442 lines) before editing. Four regions matter:
    - the `fmt_duration` helper and its comment block (search: `fmt_duration()`)
    - `iso_to_epoch` — the forward days-from-civil reference; it stays untouched, it is
      still what parses the Fable ISO `resets_at` (search: `iso_to_epoch()`)
    - `seg_5h` / `seg_1w` / `seg_fable` (search: `seg_5h()`)
    - `main`'s one-line `local` declaration and the `NOW=$(date +%s)` assignment
      (search: `local input vars sep` and `single date call`)
    Line numbers in RESEARCH.md drift by ~6 against the live file — anchor every edit on
    these search strings, never on a line number.
  </read_first>
  <behavior>
    The two new helpers are unit-testable in isolation; write the expectations down before
    implementing, then prove them in Task 2's harness table.

    `tz_offset_secs`:
    - `+0300` → `10800`; `-0430` → `-16200`; `+0000` → `0`; `-0000` → `0`; `+1345` → `49500`
    - `+0800` → `28800` (proves the base-10 prefix is present; without it the expansion is
      a fatal octal error that blanks the entire status line in eight timezones)
    - empty string → `0`; `garbage` → `0`; `+03:00` → `0`; a command-substitution payload → `0`
      (the shape guard runs before any arithmetic, so hostile input never reaches a sink)

    `fmt_reset_clock EPOCH TODAY_DAY OFFSET_SECS`:
    - reset on the same local day → `HH:MM`, zero-padded both fields (`09:05`, `21:10`)
    - reset on any other local day → `Ddd HH:MM` (`Mon 21:10`), weekday from the local day
      number, 3-letter English abbreviation
    - a negative local instant (reachable: the fixtures carry epoch 0 and any west-of-
      Greenwich offset drives it below zero) still yields a correct day and remainder —
      day and remainder are corrected together, never one without the other
    - the result matches libc for every modern epoch in every zone
  </behavior>
  <action>
    Implement the locked clock rendering (D-66 through D-71). RESEARCH.md carries executed,
    cross-checked snippets for every piece below — lift them rather than improvising, and
    keep the file's existing comment voice (short, requirement-tagged).

    1. Add `tz_offset_secs` where `fmt_duration` sits today. It takes the offset field,
       validates it with a `case` shape guard accepting exactly a sign followed by four
       digits, and returns seconds; anything else returns `0`, which is the locked
       UTC fallback (D-68). POSIX lets `%z` emit no characters when no zone is
       determinable, so the empty case is a specified outcome, not a hypothetical — say so
       in the comment. Both two-digit fields need the base-10 expansion prefix that
       `iso_to_epoch` already uses; copy that idiom verbatim instead of inventing one.

    2. Add `WD_NAMES="Sun Mon Tue Wed Thu Fri Sat"` as a plain space-separated string and
       `fmt_reset_clock EPOCH TODAY_DAY OFFSET_SECS` next to it. Compute the local instant,
       floor-divide by 86400 for the local day number and take the remainder for seconds
       into the day; when the remainder is negative add a day's worth back and decrement
       the day in the same branch. Hours and minutes come from the remainder; emit them
       with `printf '%02d:%02d'` (string concatenation would render `9:5`, which D-67
       forbids). When the day equals TODAY_DAY, print the clock alone; otherwise prefix the
       weekday, picked by index `(day + 4) % 7` against `WD_NAMES` with a word-splitting
       `for` loop — epoch day 0 is a Thursday and `0` is Sunday, hence the `+ 4`.
       Associative arrays are bash 4 and are banned here.

       Add a short comment recording the accepted DST limitation: the offset is the one in
       effect now, not the one at the reset instant, so a displayed clock can be one hour
       off for the ~14 days a year a window straddles a changeover. Fixing it properly
       needs the tz database, which is unreachable without the banned flags. Measured,
       bounded, accepted.

    3. Rewire `main`. Replace the single `NOW=$(date +%s)` assignment with one folded call
       that emits both the epoch and the offset in a single process, split the two fields
       with parameter expansion (`${x%% *}` / `${x##* }` — not `read`, whose IFS behaviour
       the project already distrusts, and which would not degrade correctly when the offset
       field is empty), derive `TZOFF` through `tz_offset_secs`, and derive
       `TODAY=$(( (NOW + TZOFF) / 86400 ))`. Process count is unchanged at one date(1) call,
       which is what LIM-03 requires. Keep the folded call in the same command-substitution form
       the old line used — the process-count gate counts exactly one such substitution across the
       whole script — and keep that substitution text out of the line's trailing comment, or the
       gate counts it twice. Add every new variable to `main`'s existing one-line
       `local` list — omitting them leaks them into the shell; omitting an assignment makes
       the arithmetic silently read `0` and render midnight instead of failing loudly.

    4. Rewrite the three segments to the locked shape (D-66, D-70). Each keeps its existing
       hide-on-empty-percentage gate and its existing percentage guard untouched, then
       builds: dim label, space, threshold-coloured percentage with `RESET` immediately
       after, and — only when the window carries a reset — a space plus either the literal
       `now` (reset at or before `NOW`) or `fmt_reset_clock` output (D-69). `seg_5h` labels
       `5h`, `seg_1w` labels `Week`, `seg_fable` keeps its existing dim `Fable` label.
       Update each segment's comment header to describe the clock instead of the countdown,
       and add D-66/D-67/D-69/D-70 to the requirement tags already on those lines.

    5. Delete `fmt_duration` and its comment block. Confirm first that the three segments
       were its only callers — after step 4 nothing references it, and D-71 forbids leaving
       it behind.

    Do not touch `seg_context`, `iso_to_epoch`, the jq canonicalizer, or anything on row 1.
    `resets_at` values still arrive through the existing integer canonicalizer; pass them to
    the new helper quoted and do not widen that sink.
  </action>
  <verify>
    <automated>/bin/bash -c 'set -e; SL=kit/files/home/.claude/statusline.sh; E=$(printf "\033"); NC="grep -vE ^[[:space:]]*#";
      export STATUSLINE_NO_FABLE=1;
      L2=$(cat tests/fixtures/full.json | /bin/bash "$SL" | sed "s/$E\[[0-9;]*m//g" | sed -n 2p);
      test "$L2" = "10%/100k/1M · 5h 50% now · Week 15% now" || { echo "past-reset shape: [$L2]"; exit 1; };
      dfmt() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null; };
      now=$(date +%s); t5=$(( now + 600 )); t7=$(( now + 259200 ));
      w5=$(dfmt $t5 "%H:%M"); test "$(dfmt $t5 %F)" = "$(dfmt $now %F)" || w5="$(dfmt $t5 %a) $w5";
      w7="$(dfmt $t7 %a) $(dfmt $t7 "%H:%M")";
      L2=$(jq --argjson a $t5 --argjson b $t7 ".rate_limits.five_hour.resets_at=\$a | .rate_limits.seven_day.resets_at=\$b" tests/fixtures/full.json | /bin/bash "$SL" | sed "s/$E\[[0-9;]*m//g" | sed -n 2p);
      case "$L2" in *"5h 50% $w5"*"Week 15% $w7"*) ;; *) echo "live clock: got [$L2] want [$w5] [$w7]"; exit 1;; esac;
      test "$($NC "$SL" | grep -cE "date[[:space:]]+-[dr]")" = 0 || { echo "banned epoch flag reached code"; exit 1; };
      test "$($NC "$SL" | grep -cE "fmt_duration")" = 0 || { echo "dead helper still present"; exit 1; };
      test "$($NC "$SL" | grep -cF "\$(date")" = 1 || { echo "date(1) substitution count changed - expected exactly one"; exit 1; };
      echo TRACER-OK'</automated>
    <human-check>Run the script against a live session and confirm the three clock times match a wall clock.</human-check>
  </verify>
  <!-- planner-discipline-allow: fmt_duration -->
  <!-- planner-discipline-allow: countdown -->
  <!-- planner-discipline-allow: $(date -->
  <done>
    The full fixture renders `10%/100k/1M · 5h 50% now · Week 15% now`; a future-epoch render
    matches the libc oracle's `HH:MM` for a same-day reset and `Ddd HH:MM` for a three-day-out
    reset; the two banned epoch-formatting flags appear nowhere outside comments; `fmt_duration`
    is gone; date(1) is still invoked once per render.
    NOTE: `/bin/bash tests/run.sh` is expected to FAIL after this task — it still asserts the old
    format. Task 2 makes it green. Do not "fix" the script to satisfy the stale assertions.
  </done>
</task>

<task type="auto">
  <name>Task 2: Make the harness deterministic and green against the new format</name>
  <files>tests/run.sh, tests/render-fixtures.sh, tests/sandbox.sh</files>
  <read_first>
    Read `tests/run.sh` fully (766 lines) — the row-2 expectations are spread across seven
    sections, and RESEARCH.md's line-number table drifts against the live file. Anchor on the
    assertion text. Also read `tests/render-fixtures.sh` (85 lines) and the §5.13 block of
    `tests/sandbox.sh` (search: `5.13 Fable weekly in the sandbox`).
    Baseline before any edit: `226 checks, 0 failures`.
  </read_first>
  <action>
    Bring the harness to the new format without weakening any existing guarantee (D-72).

    1. Pin the zone in both `tests/run.sh` and `tests/render-fixtures.sh`, on the line right
       after each script's existing `export STATUSLINE_NO_FABLE=1`. Comment it as what it is:
       rendered clock times must not depend on the runner's zone. This also hardens the
       host-vs-sandbox byte comparison (PORT-01) against any future fixture that carries a
       non-zero reset.

    2. Delete the ten-row `fmt_duration` expectation table in §2 — the helper no longer
       exists (D-71). Leave the `shorten_num` and `iso_to_epoch` tables alone; `iso_to_epoch`
       is still live code.

    3. Add a table for the two new helpers in the same style as the tables around it, sourcing
       the helpers the same way the existing helper tables do. Cover every row listed in
       Task 1's `<behavior>` block, including the base-10-prefix row, the hostile-input row,
       and a negative-local-instant row for the clock formatter. Feed `fmt_reset_clock` an
       explicit TODAY argument so these rows never depend on the runner's clock.

    4. Update every stale row-2 expectation to the new shape. The full inventory, by assertion
       text rather than line number:
       - the `run_fixture` expectations for `full`, `no-effort` and `only-five-hour`
       - the non-numeric-payload probe expectation in §7
       - all five §7.5 non-integer probe rows, including the one whose out-of-range epoch is
         supposed to drop the time slot entirely — that row must now expect label and
         percentage with no time slot at all (D-69), which is the regression guard for the
         omit-the-slot branch
       - `L2_BASE` in §11 and every Fable expectation built from it
       - the two no-reset Fable rows, which likewise lose their time slot
       Byte-level assertions need care: the §5 threshold-colour expectation and the §11.2 /
       §11.3 Fable byte expectations must now describe a dim label before the coloured
       percentage and no trailing window suffix. Palette purity already permits the dim code,
       so that check needs no change.

    5. Rebuild the §4 live time test. It is the only genuinely clock-dependent check and its
       old hard-coded duration strings cannot survive. Replace them with a harness-local
       oracle helper that asks libc for the expected text — BSD form first with the GNU form
       as fallback, the same dual-fallback shape CLAUDE.md already prescribes for `stat`. The
       ban applies to the shipped script, not to test code; state that in the helper's comment
       so a future reader does not "fix" it. Drive it with a near-future epoch (same local day
       in almost every case — let the oracle decide whether a weekday prefix belongs) and a
       three-days-out epoch (always a different local day, so the weekday prefix must appear).
       This is strictly stronger than the test it replaces: the expectation now comes from an
       independent implementation with real tzdata rather than from the script's own arithmetic.
       Add a comment noting the one residual race — the harness and the script read their
       clocks milliseconds apart, so they could disagree about "today" only if local midnight
       falls in that gap. Do not add a production time seam to close it; a permanent env var on
       the shipped script is a bad trade for that probability (D-72).

    6. Update the §5.13 pattern in `tests/sandbox.sh` so it matches the new Fable segment shape.
       RESEARCH.md missed this file — it is a real assertion on the old text and will fail in
       the sandbox otherwise. While in there, add one informational probe that the sandbox's
       date(1) accepts the folded format string and returns a well-formed offset: that is the
       single unverified Linux assumption in the research, and the sandbox run is the only place
       it can be settled.

    Every fixture keeps its epoch-0 reset, so all eight fixture renders stay clock- and
    zone-independent and the host-vs-sandbox byte diff keeps working unchanged.
  </action>
  <verify>
    <automated>/bin/bash -c 'set -e; NC="grep -hvE ^[[:space:]]*#";
      out=$(/bin/bash tests/run.sh 2>/dev/null); printf "%s\n" "$out" | tail -1;
      printf "%s\n" "$out" | grep -qE "^[0-9]+ checks, 0 failures$" || { echo "suite not green"; exit 1; };
      n=$(printf "%s\n" "$out" | tail -1 | cut -d" " -f1); test "$n" -ge 226 || { echo "check count regressed: $n below 226"; exit 1; };
      for f in tests/run.sh tests/render-fixtures.sh; do grep -qE "^export TZ=" "$f" || { echo "no zone pin in $f"; exit 1; }; done;
      test "$($NC tests/run.sh | grep -cE "fmt_duration")" = 0 || { echo "stale helper table"; exit 1; };
      test "$($NC tests/run.sh tests/render-fixtures.sh tests/sandbox.sh | grep -cE "%/(5h|1w)")" = 0 || { echo "stale row-2 expectation"; exit 1; };
      D=$(mktemp -d); /bin/bash tests/render-fixtures.sh "$D" 1>/dev/null;
      nf=$(ls "$D"/repo/*.out 2>/dev/null | wc -l);
      test "$nf" -eq 8 || { echo "fixture render count is $nf, expected 8"; exit 1; };
      echo "rendered $nf fixtures"; echo HARNESS-OK'</automated>
  </verify>
  <!-- planner-discipline-allow: fmt_duration -->
  <!-- planner-discipline-allow: %/5h -->
  <done>
    `/bin/bash tests/run.sh` reports 0 failures with at least 226 checks; both test scripts pin
    the zone; no `fmt_duration` table remains; no old percentage-slash-window text survives in any
    harness file outside comments; `tests/render-fixtures.sh` still dumps all eight fixture renders.
  </done>
</task>

<task type="auto">
  <name>Task 3: Bring the four live spec docs in line with what ships</name>
  <files>README.md, project-brief.md, .claude/CLAUDE.md, .planning/PROJECT.md</files>
  <read_first>
    `grep -n '5h\|1w\|countdown' README.md project-brief.md .claude/CLAUDE.md .planning/PROJECT.md`
    gives the complete edit surface — confirmed by grep this session. `kit/spec.yaml` carries no
    row-2 format text and needs no change; re-run the grep against it to confirm before skipping it.
  </read_first>
  <action>
    Update every live doc that states the row-2 format, so the docs describe what the script now
    renders (D-66, D-67, D-69).

    README.md — eight places: the example row 2 near the top; the three legend rows for the 5h,
    weekly and Fable segments; the `refreshInterval` sentence; the mock-input sample output and
    the Fable note beside it; and the Fable prose paragraph lower down. The `refreshInterval`
    rationale — the sentence claiming the reset countdowns keep ticking while the session is idle —
    needs rewording rather than deleting: the setting still earns its keep, but now
    because it drives the past-reset flip to `now` and the today-to-weekday flip at local
    midnight, not because anything ticks. Keep the legend table's column shape and voice.

    project-brief.md — four places (the row-2 format line, the two segment descriptions, and the
    example render). These still describe the original pre-Phase-4 in-segment Fable shape, which
    the shipped script has not rendered since Phase 4. Bring them all the way to the current
    reality — a separate last Fable segment in the new shape — rather than preserving the stale
    form in a new coat of paint.

    .claude/CLAUDE.md — three places: the project description sentence (it ends "with reset
    countdowns on line two"); the stack-table row for the epoch arithmetic; and the
    `refreshInterval` rationale (it says the reset countdowns are time-based). In the stack-table
    row BOTH cells change: its Purpose cell still reads "Reset countdowns" and must now name the
    clock, and its notes cell should also cover the offset field and the clock arithmetic.
    CRITICAL: the sentence in that row naming the two banned epoch-formatting flags must survive
    verbatim, character for character — it is a binding project constraint, not prose, and this
    task must not soften or reflow it.

    .planning/PROJECT.md — update the format-spec lines only: the project description sentence, the
    row-2 shape line, the example render, the Phase-4 layout-correction note, and the three
    segment-format bullets. Leave the shipped-milestone achievement lines (the ones marked with a
    check and "— v1.0 (Phase N)") and the Key Decisions table rows exactly as they are. Those are
    historical records of what shipped when; rewriting them would falsify history.

    Self-check before finishing: the word this task retires has exactly four live occurrences
    across these docs — one in README.md (the `refreshInterval` sentence) and three in
    `.claude/CLAUDE.md` (the project description sentence, the stack-table Purpose cell, and the
    `refreshInterval` rationale). `project-brief.md` has none. All four must be gone, which is what
    the zero-match gate in `<verify>` asserts. `.planning/PROJECT.md` is deliberately outside that
    gate: its shipped-milestone achievement lines keep the old wording as historical record.

    Do not touch anything under `.planning/milestones/` or `.planning/quick/` — all historical.
    Keep every example consistent with the one authoritative target string from CONTEXT.md, so a
    reader who greps for the format finds the same text everywhere.
  </action>
  <verify>
    <automated>/bin/bash -c 'set -e; DOCS="README.md project-brief.md .claude/CLAUDE.md";
      test "$(cat $DOCS | grep -cE "%/(5h|1w)")" = 0 || { echo "stale format in live docs"; grep -nE "%/(5h|1w)" $DOCS; exit 1; };
      test "$(cat $DOCS | grep -icE "countdown")" = 0 || { echo "stale countdown wording"; grep -inE "countdown" $DOCS; exit 1; };
      for f in $DOCS .planning/PROJECT.md; do grep -qF "5h 50%" "$f" || { echo "new format missing from $f"; exit 1; }; done;
      grep -qF "**Never** use \`date -d\` (GNU-only) or \`date -r\` (BSD-only)" .claude/CLAUDE.md || { echo "portability ban text was altered"; exit 1; };
      test "$(cat kit/spec.yaml | grep -cE "%/(5h|1w)")" = 0 || { echo "kit/spec.yaml unexpectedly carries format text"; exit 1; };
      grep -qF -- "- ✓ Line 2 renders 5h rate-limit usage percent with reset countdown — v1.0 (Phase 1)" .planning/PROJECT.md || { echo "historical achievement line was rewritten"; exit 1; };
      test "$(cat .planning/PROJECT.md | grep -cE "%/(5h|1w)")" -le 2 || { echo "PROJECT.md spec lines not updated"; grep -nE "%/(5h|1w)" .planning/PROJECT.md; exit 1; };
      echo DOCS-OK'</automated>
    <human-check>Read the README legend top to bottom and confirm it describes the line you actually see.</human-check>
  </verify>
  <!-- planner-discipline-allow: countdown -->
  <!-- planner-discipline-allow: %/5h -->
  <done>
    No live doc states the old percentage-slash-window shape or calls the reset a countdown; all four
    docs carry the new `5h 50% …` shape; the portability ban sentence in `.claude/CLAUDE.md` is
    byte-identical to before; PROJECT.md's shipped-milestone achievement lines are untouched;
    `kit/spec.yaml` confirmed to need no change.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| stdin JSON → script | Claude Code supplies `rate_limits.*.resets_at`; already type-guarded by the jq `uint` canonicalizer, which this task must not widen |
| environment → script | `TZ` is environment-controlled and steers the new offset field; the offset string reaches new parsing code |
| OAuth usage endpoint → `FAB_RST` | unchanged by this task; still passes through `iso_to_epoch` |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-VGX-01 | Tampering | `tz_offset_secs` — environment-steered offset string reaching arithmetic | medium | mitigate | `case` shape guard accepting exactly sign-plus-four-digits runs BEFORE any expansion; everything else returns `0`. Verified against a command-substitution payload (Task 1 behavior table, Task 2 harness row) |
| T-VGX-02 | Denial of Service | whole status line blanks on an arithmetic fatal error | high | mitigate | base-10 expansion prefix on both offset fields (a bare expansion is a fatal error for eight real timezones); `printf '%02d'` for padding; guarded `case` upstream. Covered by the base-10 harness row in Task 2 |
| T-VGX-03 | Elevation of Privilege | `$(( ))` sinks in `fmt_reset_clock` fed from stdin `resets_at` | medium | mitigate | the existing jq `uint` canonicalizer is unchanged and still the only path to `P5_RST`/`P7_RST`; values are passed quoted and the sink is not widened. §7.5 probes in Task 2 keep asserting this |
| T-VGX-04 | Information Disclosure | rendered output | low | accept | no new data source, no network, no new file read; the change only reformats values already on screen |
| T-VGX-05 | Tampering | harness oracle uses the two flags the script bans | low | accept | the ban is a portability constraint on the shipped script, not on test code; the dual-fallback covers both userlands and the helper comment records why |
| T-VGX-SC | Tampering | supply chain | — | n/a | no npm/pip/cargo install in this task; no dependency added or changed |
</threat_model>

<verification>
1. `/bin/bash tests/run.sh` — 0 failures, check count at or above the 226 baseline.
2. `/bin/bash tests/render-fixtures.sh <dir>` — all eight fixture renders produced; run it
   before and after and confirm the only diffs are the three rate-limit segments (row 1 and
   the context segment must be byte-identical).
3. Live render against a real session: the three clock times agree with a wall clock, a
   same-day reset shows no weekday, a multi-day reset shows one.
4. Sandbox: the §5.13 Fable probe passes and the informational date(1) probe confirms the
   folded format string works under GNU userland — the one unverified research assumption.
</verification>

<success_criteria>
- Row 2 renders `10%/100k/1M · 5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10`
- The context-usage segment and all of row 1 are byte-identical to before
- Past reset → `now`; missing reset → label and percentage only; missing percentage → segment
  and separator both gone
- date(1) is still called once per render and the two banned epoch-formatting flags stay out
  of the shipped script
- `fmt_duration` is gone with no callers left behind
- Harness green and zone-pinned; fixture renders identical on host and in the sandbox
- The four live docs describe the shipped format; historical records untouched
</success_criteria>

<output>
Create `.planning/quick/260912-vgx-reformat-second-status-line-row-show-con/260912-vgx-SUMMARY.md` when done
</output>
