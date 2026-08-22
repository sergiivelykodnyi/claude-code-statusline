---
gsd_state_version: 1.0
current_phase: 4
current_phase_name: Fable Weekly f() Segment
status: planning
stopped_at: Phase 4 context gathered
last_updated: "2026-08-22T18:01:28.805Z"
last_activity: 2026-08-22
last_activity_desc: Phase 03 complete, transitioned to Phase 4
state_head: 9d50440d61e3d8180e79fdc8128e7a143838e087
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 9
  completed_plans: 9
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-22)

**Core value:** One glance at the terminal tells you everything about the session: which model at which effort, where you are in git, and how much context and rate limit you have left before things reset.
**Current focus:** Phase 04 — Fable Weekly f() Segment

## Current Position

Phase: 4 — Fable Weekly f() Segment
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-22 - Completed quick task 260822-rbm: sbx kit add install-only probe (Q-a FAIL: kit add refuses kits with files/; Q-b PASS: install-time merge survives the seed)

Progress: [████████████████████] 9/9 plans ([███████░░░] 75%) — Phase 3 of 4 complete (75%)

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

Last session: 2026-08-22T18:01:28.637Z
Stopped at: Phase 4 context gathered
Resume file: .planning/phases/04-fable-weekly-f-segment/04-CONTEXT.md
