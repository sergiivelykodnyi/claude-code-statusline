---
phase: 04-fable-weekly-f-segment
plan: 04
subsystem: docs
tags: [readme, requirements, project, roadmap, fable, layout-correction, d-51, d-52, d-66]

# Dependency graph
requires:
  - phase: 04-fable-weekly-f-segment
    provides: plan 04-01 — the shipped Fable adapter (get_token file→Keychain, 300 s/0600 cache with 3600 s grace, curl --max-time 2, STATUSLINE_NO_FABLE kill switch, seg_fable last on line 2) whose header "Env inputs" block the README numbers and names were copied from; plan 04-02 — 220-check harness that proves the docs-only change leaves the script green
provides:
  - README.md: Fable segment in the "What it shows" example and legend, a "## Fable weekly segment" section (token sources, fetch/cache/grace, kill switch, Keychain prompt, sandbox credentials), verify-command comment, curl in Requirements
  - .planning/REQUIREMENTS.md FAB-01/FAB-04 reconciled with the D-51 separate-segment layout (checkboxes and traceability table untouched)
  - .planning/PROJECT.md target layout, whole example, segment definitions, validated/active checklist lines, decision row reconciled + "Layout correction (Phase 4)" note
  - .planning/ROADMAP.md Phase 4 goal and success criteria 1-3 reworded, criterion 5 records the layout correction (Plans list / Progress table untouched)
affects: [04-03 sandbox evidence (README sandbox sentence it confirms), phase verifier (FAB-01 judged against one form), milestone completion]

# Actuals (#2632) — same estimateTokens scale as the plan estimate (chars/4).
# chars/4 over the four files actually changed = 8631; chars/4 over the realized diff alone = 3183.
actuals:
  tokens: 8631
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Docs copy names and numbers from the script header's Env inputs block (FAB_TTL 300 s, FAB_MAXTIME 2 s, FAB_GRACE 3600 s, 0600 cache at ~/.claude/statusline-usage-cache.json, STATUSLINE_NO_FABLE) rather than restating them from memory"
    - "Scoped planning-doc edits: exact-match single replacements asserted to occur once, pathspec-scoped git assertions only, ROADMAP re-read immediately before its edit (shared with the orchestrator in the same wave)"

key-files:
  created: []
  modified:
    - README.md
    - .planning/REQUIREMENTS.md
    - .planning/PROJECT.md
    - .planning/ROADMAP.md

key-decisions:
  - "project-brief.md left untouched as the historical brief (CONTEXT D-52 discretion); the layout correction is recorded in PROJECT.md ('> Layout correction (Phase 4)' note next to the Phase 2 frame note) and ROADMAP criterion 5 instead"
  - "README names only the two read-only token sources the script reads and the kill switch — no paste/export/refresh instructions, no token shape (D-62, D-63, T-04-15)"
  - "The README's 'Fable weekly segment' intro quotes the example literal '· Fable 74%/1w (2d:4h:30m)' so the example wording appears in the example block, the legend and the note (one consistent form)"

patterns-established:
  - "Layout corrections are recorded as blockquote notes in PROJECT.md ('> Layout correction (Phase N): ...') and as a numbered ROADMAP success criterion, never by rewriting the historical brief"

requirements-completed: [FAB-01, FAB-02, FAB-03, FAB-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "README shows the Fable segment in the example (line 2 ends with '· Fable 74%/1w (2d:4h:30m)') and the legend, plus a '## Fable weekly segment' section between 'Install on the host' and 'Install in Docker Sandboxes' covering token sources, 5 min / 2 s / 0600 cache with 1 h grace, STATUSLINE_NO_FABLE kill switch (shell or settings.json env), one-time Keychain 'Always Allow', sandbox credentials-file branch; curl under Requirements; verify-command comment; no in-segment notation; no token-handling instructions"
    requirement: FAB-01
    verification:
      - kind: other
        ref: "04-04-PLAN.md Task 1 <verify> one-liner (grep -c 'f(' README.md = 0; every required literal present; grep -ciE 'sk-ant|paste (your|the|a) token|TOKEN=' = 0; git diff --quiet -- project-brief.md) — VERIFY_PASS"
        status: pass
      - kind: unit
        ref: "/bin/bash tests/run.sh -> '220 checks, 0 failures' (docs-only change, script untouched)"
        status: pass
    human_judgment: false
  - id: D2
    description: "REQUIREMENTS.md FAB-01 describes the separate 'Fable pct/1w (countdown)' segment rendered last on line 2 and FAB-04 says 'the Fable segment'; FAB checkboxes still unticked and the traceability table byte-identical"
    requirement: FAB-01
    verification:
      - kind: other
        ref: "grep -c 'f(' .planning/REQUIREMENTS.md = 0; grep -cF 'Fable pct/1w (countdown)' = 1; grep -c 'FAB-04.*Fable segment' = 1; 4 '- [ ] **FAB-0' lines; git diff shows 0 changed table rows"
        status: pass
    human_judgment: false
  - id: D3
    description: "PROJECT.md target layout ends with '· Fable fable_pct/1w (fable_reset)', whole example is '10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)' (50%/1w typo fixed), '> Layout correction (Phase 4)' note added after the Phase 2 note, weekly + new Fable weekly segment definitions, validated/active checklist lines and the rate-limit decision row reworded"
    requirement: FAB-01
    verification:
      - kind: other
        ref: "grep -c 'f(' .planning/PROJECT.md = 0; each of the five PROJECT.md acceptance greps = 1; 'Layout correction (Phase 2)' still = 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "ROADMAP.md Phase 4 goal and success criteria 1-3 use the D-51 form ('… · Fable 60%/1w (2d:4h:30m)'), criterion 5 records the layout correction; title, Plans list, Progress table and Phases 1-3 untouched (diff hunks confined to lines 107 and 114-118 of the Phase 4 block); ROADMAP re-read immediately before the edit, no checkbox state changed"
    requirement: FAB-01
    verification:
      - kind: other
        ref: "git diff -U0 -- .planning/ROADMAP.md hunks: @@ -107 +107 @@ (Goal), @@ -114,3 +114,3 @@ (criteria 1-3), @@ -117,0 +118 @@ (criterion 5); grep -c '### Phase 4: Fable Weekly f() Segment' = 1; grep -c '04-04-PLAN.md' = 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "The README Fable note describes what actually shipped (token sources, cache path/TTL/grace/mode, kill switch, Keychain prompt, sandbox branch) accurately enough that a reader needs no tribal knowledge"
    requirement: FAB-04
    verification: []
    human_judgment: true
    rationale: "Prose accuracy versus the script is checked here by reading the script header and get_token (numbers and names match FAB_TTL/FAB_MAXTIME/FAB_GRACE/FAB_CACHE/get_token), but whether the note reads clearly to a newcomer is a judgment call for the end-of-phase human check"

# Metrics
duration: 7min
completed: 2026-08-23
status: complete
---

# Phase 4 Plan 04: Docs — README Fable Note and D-52 Planning-Doc Reconciliation Summary

**README now shows and explains the separate last `Fable NN%/1w (countdown)` segment (token sources, 5 min / 2 s / 0600 cache with 1 h grace, `STATUSLINE_NO_FABLE` kill switch, Keychain prompt, sandbox credentials branch, curl requirement), and REQUIREMENTS/PROJECT/ROADMAP all describe the D-51 layout with a recorded layout-correction note — scoped edits only, harness still 220/0.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-08-22T22:00:00Z (approx.)
- **Completed:** 2026-08-22T22:07:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `README.md`: example line 2 ends with `· Fable 74%/1w (2d:4h:30m)`; hidden-segments sentence mentions "no Fable usage data (no OAuth login)"; legend row for the Fable segment; new `## Fable weekly segment` section (between "Install on the host" and "Install in Docker Sandboxes") with five bullets — token source (`~/.claude/.credentials.json`, then Keychain item `Claude Code-credentials` via `security`; read-only, never refreshed/printed), fetch and cache (one request per 5 minutes to `https://api.anthropic.com/api/oauth/usage`, 2-second timeout, 0600 cache at `~/.claude/statusline-usage-cache.json`, last value kept up to an hour on failure, then hidden), kill switch `STATUSLINE_NO_FABLE=1` (shell or `"env"` key of `~/.claude/settings.json`), one-time macOS Keychain "Always Allow", Docker Sandboxes (`/home/agent/.claude/.credentials.json` present → renders, absent → hidden; the kit never copies the host token); verify-command comment `# plus "· Fable NN%/1w (…)" …`; `curl` in Requirements. `grep -c 'f(' README.md` = 0.
- `.planning/REQUIREMENTS.md`: FAB-01 → separate `Fable pct/1w (countdown)` segment rendered last on line 2 with its own countdown, "layout correction (Phase 4): supersedes the brief's in-segment notation"; FAB-04 → "the Fable segment is hidden". Checkboxes and traceability table untouched.
- `.planning/PROJECT.md`: target layout `… · usage_pct/1w (when_reset) · Fable fable_pct/1w (fable_reset)`; whole example corrected (also fixes the `50%/1w` typo → `50%/5h`); `> Layout correction (Phase 4)` note after the Phase 2 note; segment definitions split into "Weekly limit" + new "Fable weekly" bullet; validated line "(Fable weekly segment added in Phase 4)"; active line reworded; rate-limit decision row "only the Fable weekly segment needs the OAuth endpoint (Phase 4)".
- `.planning/ROADMAP.md` Phase 4 block: goal reworded; criterion 1 `15%/1w (3d:5h:57m) · Fable 60%/1w (2d:4h:30m)` — separate last peer with its own countdown; criteria 2-3 say "the Fable segment"; criterion 5 records the D-51 layout correction. Title, research flag, Plans list, Progress table and Phases 1-3 byte-identical (diff hunks confined to lines 107 and 114-118).

## Task Commits

Each task was committed atomically:

1. **Task 1: README — Fable segment in the example and legend, the "Fable weekly segment" note, curl in Requirements** - `d5cd6c9` (docs)
2. **Task 2: D-52 reconciliation of REQUIREMENTS.md, PROJECT.md and ROADMAP.md** - `81c3890` (docs)

**Plan metadata:** see final commit below (docs: complete plan)

## Files Created/Modified

- `README.md` - example, hidden-segments sentence, legend row, `## Fable weekly segment` section, verify-command comment, `curl` requirement (+16/-3 lines)
- `.planning/REQUIREMENTS.md` - FAB-01 and FAB-04 wording only (2 lines)
- `.planning/PROJECT.md` - target layout, example, Phase 4 layout-correction note, segment definitions, validated/active lines, decision row (+9/-6 lines)
- `.planning/ROADMAP.md` - Phase 4 goal, success criteria 1-3, new criterion 5 (+5/-4 lines)

## Decisions Made

- `project-brief.md` stays untouched as the historical brief (CONTEXT D-52 left this to discretion); the correction is recorded where readers look — PROJECT.md's blockquote note next to the Phase 2 frame note, and ROADMAP criterion 5. Rationale: the brief is the record of what was asked; PROJECT.md/ROADMAP are the record of what ships.
- The README note quotes the example literal once in its intro so the example block, the legend and the note carry the same form (`· Fable 74%/1w (2d:4h:30m)`); the legend token itself follows the other rows (no leading `·`).
- The README's numbers and names were copied from the script header's "Env inputs" block and `get_token` (FAB_TTL 300 s, FAB_MAXTIME 2, FAB_GRACE 3600 s, FAB_CACHE default, Keychain item name) rather than from the plan text — T-04-17 mitigation; they agree with the plan.

## Deviations from Plan

None - plan executed exactly as written.

**Note on one acceptance literal (not a deviation):** Task 2's criterion `grep -c '^\*\*Plans\*\*: 4 plans' .planning/ROADMAP.md` outputs 0 both before and after this plan — the orchestrator-maintained line reads `**Plans**: 2/4 plans executed` (the tool's `N/M plans executed` format), so the literal never matched. The criterion's intent (Plans line untouched) holds: `git diff -U0 -- .planning/ROADMAP.md` shows hunks only at the Goal line (107) and the Success Criteria lines (114-118); `grep -c '04-04-PLAN.md'` = 1. No ROADMAP Plans-list tick from 04-03 was present at re-read time (04-03 runs after this plan in the wave), so no interleaving occurred.

## Issues Encountered

- `git commit` inside the Bash sandbox failed with `1Password: Could not connect to socket` (SSH commit signing); both task commits were retried unchanged with the sandbox disabled, as the environment notes prescribe. No `--no-verify`, no signing bypass.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None — docs only; no code, no placeholders.

## Threat Flags

None — no new surface; README names only the two read-only token sources the script already reads and the kill switch (T-04-15 acceptance grep for `sk-ant` / "paste … token" / `TOKEN=` = 0).

## Next Phase Readiness

- D-66 and D-52 delivered: no document a reader sees describes the superseded in-segment notation; the verifier judges FAB-01 against the reconciled ROADMAP criteria.
- Plan 04-03 (sandbox evidence, Docker Desktop human gate) remains to run in this wave; it touches only `tests/sandbox.sh` and `kit/spec.yaml`. Its observed sandbox credentials branch should match the README's Docker sentence (renders when `/home/agent/.claude/.credentials.json` exists, hidden otherwise).
- Nothing under the host `~/.claude` was created, modified or re-pointed.

---
*Phase: 04-fable-weekly-f-segment*
*Completed: 2026-08-23*

## Self-Check: PASSED
