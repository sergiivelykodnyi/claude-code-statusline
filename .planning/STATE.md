---
gsd_state_version: 1.0
current_phase: 04
current_phase_name: Fable Weekly f() Segment
status: executing
stopped_at: Completed 04-03-PLAN.md
last_updated: "2026-08-22T23:58:33.630Z"
last_activity: 2026-08-23
last_activity_desc: Phase 04 execution started
state_head: 87609aee5f971128173f78a1297f99c909bfd26a
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 13
  completed_plans: 13
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-22)

**Core value:** One glance at the terminal tells you everything about the session: which model at which effort, where you are in git, and how much context and rate limit you have left before things reset.
**Current focus:** Phase 04 — Fable Weekly f() Segment

## Current Position

Phase: 04 (Fable Weekly f() Segment) — EXECUTING
Plan: 2 of 4
Status: Ready to execute
Last activity: 2026-08-23 — Phase 04 execution started

Progress: [████████████████████] 9/9 plans ([████████░░] 75%) — Phase 3 of 4 complete (75%)

## Performance Metrics

**Velocity:**

- Total plans completed: 9
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 2 | - | - |
| 02 | 4 | - | - |
| 03 | 3 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 5 min | 2 tasks | 2 files |
| Phase 01 P02 | 5 min | 2 tasks | 7 files |
| Phase 02 P01 | 2 min | 2 tasks | 2 files |
| Phase 02 P02 | 5 min | 2 tasks | 1 files |
| Phase 02 P03 | 3 min | 2 tasks | 2 files |
| Phase 02 P04 | 4 min | 3 tasks | 2 files |
| Phase 03 P01 | 5 min | 2 tasks | 5 files |
| Phase 03 P02 | 3 min | 2 tasks | 3 files |
| Phase 03 P03 | 3h 0m | 3 tasks | 2 files |
| Phase 04 P01 | 16 min | 2 tasks | 5 files |
| Phase 04 P02 | 8 min | 2 tasks | 2 files |
| Phase 04 P04 | 7 min | 2 tasks | 4 files |
| Phase 04 P03 | 1h 20m | 3 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: `f()` Fable weekly is the sole external dependency — isolated behind an adapter seam, cached, fail-silent, deferred to Phase 4
- [Phase 02]: All 10 stdin fields type-guarded inside the single jq `@sh` program — one choke point, one jq pass, byte-identical renders; every new security probe must be proven to bite against the pre-fix script
- [Phase 03]: Canonical script is `kit/files/home/.claude/statusline.sh` (pure `git mv`, 100755); host installs by `ln -sf`, sandboxes by the `kit/` sbx mixin kit whose root `setup.startup` jq-merges only `.statusLine` after the platform seed (themeId wait, atomic mv, chmod 0755, non-recursive chown)
- [Phase 03]: `sbx kit add` is refused by sbx v0.39.0 for kits declaring `setup.startup` — README documents `sbx rm` + recreate; `tests/sandbox.sh` re-probes on every run (D-37a) so the sentence can flip on a future sbx
- [Phase 03]: Cross-environment evidence = `tests/render-fixtures.sh` raw renders under gitignored `tests/out/<env>/` + POSIX `diff -r` (7/7 byte-identical); `tests/sandbox.sh` 11 checks / 0 failures; UAT 3/3 passed; 15/15 threats closed (03-SECURITY.md)
- [Phase 04 prep]: OAuth `GET /api/oauth/usage` endpoint, window key naming, `utilization` scale, and sandbox credential presence are the open research items for `f()`
- [Phase 04]: Fable value is a separate last line-2 peer segment "Fable NN%/1w (countdown)" (D-51), not f(pct) inside the weekly segment; docs reconciled in 04-04
- [Phase 04]: Fable source order stdin model_scoped (D-48, empty today) -> 300 s TTL cache -> OAuth usage endpoint via curl -K - with the read-only token (credentials file -> Keychain, expiresAt pre-check) -> 3600 s grace -> hidden
- [Phase 04]: Shared per-user cache ~/.claude/statusline-usage-cache.json, 0600 via mktemp+mv -f, negative results cached; STATUSLINE_NO_FABLE kill switch exported in tests/run.sh and tests/render-fixtures.sh keeps the harness hermetic
- [Phase 04]: stdin array on model_scoped[0].resets_at asserted as 'Fable 33%/1w' without parens (pct kept, D-54) rather than hidden — the guard empties only the reset
- [Phase 04]: Exported kill switch is load-bearing for harness hermeticity: M1 bite run showed the fixture loop going live (Keychain + endpoint) without it; nothing written under ~/.claude
- [Phase 04]: project-brief.md left untouched as the historical brief; the Phase 4 layout correction is recorded in PROJECT.md (blockquote note) and ROADMAP criterion 5 (04-04)
- [Phase 04]: README names only the two read-only token sources and the kill switch; numbers copied from the script header Env inputs block (04-04)
- [Phase 04]: Sandbox credentials branch observed PRESENT (proxy-scoped token via the global sbx anthropic secret) — the Fable segment renders live inside the kit sandbox with no kit change; README's Docker sentence already covers this branch
- [Phase 04]: Host ~/.claude/statusline.sh is a stale 9800-byte regular-file copy of the pre-Phase-4 script, left untouched per D-46 — the host half of the live check requires the user to re-run the README ln -sf line first

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 4]: OAuth usage endpoint is undocumented and reported unstable — confirm window key naming and `utilization` scale (0-1 vs 0-100) during phase planning
- [sbx bump]: `sbx kit add` on v0.39.0 refuses any kit that ships `files/` (and any with `setup.startup`) — no kit shape can deliver statusline.sh via kit add today; re-run `tests/probe-kit-add.sh` on the next sbx release (install-only merge already proven to survive the create-time seed)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260822-rbm | Probe install-only kit variant with sbx kit add (D-37a): does files/ + install-time statusLine merge land on an existing sandbox, and does the merge survive the create-time seed | 2026-08-22 | 5f20baf | [260822-rbm-probe-install-only-kit-variant-with-sbx-](./quick/260822-rbm-probe-install-only-kit-variant-with-sbx-/) |

### Roadmap Evolution

- Phase 2 edited: edited fields: title-line, success_criteria (layout correction: remove ╭─/╰─ frame prefixes)

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-08-22T23:58:22.990Z
Stopped at: Completed 04-03-PLAN.md
Resume file: None
