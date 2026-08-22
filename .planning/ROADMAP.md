# Roadmap: Claude Code Status Line

## Overview

Build the status line inside-out along its risk gradient. Phase 1 delivers everything renderable from the stdin payload alone — model/effort/directory identity, context usage, and both rate-limit segments with countdowns — plus the hide-empty assembly and never-fail error contract every later segment reuses. Phase 2 adds the git segment, the main producer of stateful edge cases, and locks in the render-latency budget. Phase 3 proves the symlink install story on both target environments (macOS host and a live Docker Sandbox) and documents it in the README — at which point v1 is fully shippable. Phase 4 bolts on the isolated, fail-silent Fable weekly `f()` segment, the only feature with an external undocumented dependency, cleanly severable if the endpoint disappears.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Status Line from Stdin** - Two-line colorized status with model, effort, directory, context, and rate limits rendered entirely from the stdin payload (completed 2026-08-21)
- [x] **Phase 2: Git Segment** - Branch, dirty marker, sync symbol, ahead/behind, and stash count with all edge states, within the render-latency budget; layout correction: drop the `╭─ `/`╰─ ` frame prefixes (completed 2026-08-22)
- [x] **Phase 3: Install & Dual-Environment Validation** - Symlink install verified identical on macOS host and Docker Sandbox, documented in README (completed 2026-08-22)
- [ ] **Phase 4: Fable Weekly f() Segment** - Fable-specific weekly usage via the OAuth endpoint, cached and fail-silent

## Phase Details

### Phase 1: Core Status Line from Stdin

**Goal**: One glance shows which model at which effort, where Claude is running, and how much context and rate limit remain — rendered entirely from the stdin JSON payload
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: SESH-01, SESH-02, SESH-03, CTX-01, CTX-02, LIM-01, LIM-02, LIM-03, LIM-04, PRES-01, PRES-02, PRES-03, PRES-04, PORT-03
**Success Criteria** (what must be TRUE):

  1. Piping a full sample payload into the script prints a colorized two-line status framed with `╭─`/`╰─`: suffix-stripped model name, effort, and directory basename on line 1; `10%/100k/1M` context and `50%/5h (2h:50m) · 15%/1w (3d:5h:57m)` rate-limit segments on line 2
  2. Context and rate-limit percentages shift color as usage crosses warning and critical thresholds
  3. With stdin fields absent or null (no effort, no rate limits, no context), the corresponding segments and their separators disappear entirely — no placeholders, no errors
  4. The script always exits 0 and emits nothing to stderr, even on malformed or empty input; line 1 renders in every case

**Plans**: 1/2 plans executed

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Tracer: framed two-line status from the full stdin payload (segments, thresholds, countdowns)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Hide/zero/worst-case states, fixture set, and the never-fail test harness

### Phase 2: Git Segment

**Goal**: Line 1 shows the full git situation at a glance in any repo state, without slowing the render
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: GIT-01, GIT-02, GIT-03, GIT-04, GIT-05, GIT-06, PORT-02
**Success Criteria** (what must be TRUE):

  1. In a dirty repo with an upstream, unpulled/unpushed commits, and stashes, line 1 shows the full segment in the form `⎇ main* ≡ ↓2 ↑3 #2`
  2. Outside a git repo, the entire git segment and its separator are absent
  3. Clean repo, detached HEAD, no-upstream (`≢`), and empty-repo states each render correctly, with zero-value counters (`↓0`, `↑0`, `#0`) never appearing
  4. A full render completes well under the ~300ms debounce, using a single jq pass and one primary git status call
  5. Layout correction: the `╭─ ` and `╰─ ` frame prefixes are removed — both lines render without leading box-drawing frame characters, with all other segments, separators, and colors unchanged

**Plans**: 4/4 plans executed (3 executed, 1 gap-closure pending)

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Git segment end-to-end (seg_git, semantic per-marker colors, edge states) + frame removal, existing harness kept green

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Git-state regression matrix with real temp repos and the timed render-latency budget in tests/run.sh

**Gap closure** *(from 02-VERIFICATION.md — round 1: CR-01 RCE + WR-01/WR-02; round 2: CR-02 RCE + WR-03/WR-04)*

- [x] 02-03-PLAN.md — Enforce numeric type at the jq @sh boundary (closes the resets_at command-injection RCE + stderr leak) and extend the harness injection probe to resets_at + a non-numeric-field stderr probe
- [x] 02-04-PLAN.md — Enforce string type at the jq @sh boundary on MODEL/EFFORT/DIR (closes the CR-02 array-payload eval RCE), array-payload probes for all 10 ingested fields (WR-04), and the bounded non-negative-integer canonicalizer + zero-stderr probes for float/exponent numerics (WR-03)

### Phase 3: Install & Dual-Environment Validation

**Goal**: The status line is installed by symlink from this repo, renders identically on the macOS host and inside a live Docker Sandbox, and the README lets anyone reproduce the setup
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PORT-01, PORT-04, DOCS-01, DOCS-02
**Success Criteria** (what must be TRUE):

  1. Following only the README's `ln -s` one-liner and `settings.json` snippet gets the status line rendering in Claude Code on the macOS host
  2. Inside a live Docker Sandbox, the same symlinked `~/.claude/statusline.sh` resolves (no dangling link) and renders output identical to the host
  3. Reset countdowns keep ticking while the session is idle, via the `refreshInterval` in the documented settings snippet
  4. README shows what the status line displays (with the example output) plus the symlink install command and the `statusLine` settings snippet

**Plans:** 3/3 plans complete

Plans:
**Wave 1**

- [x] 03-01-PLAN.md — Tracer: move statusline.sh into the sbx mixin kit (kit/spec.yaml with the idempotent statusLine merge), validate offline, re-point the harness (+exec-bit check), add tests/render-fixtures.sh for byte-for-byte render diffs

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-PLAN.md — README: what it shows, legend, host symlink/copy install + settings snippet (refreshInterval 60) + verify command, Docker Sandboxes kit install (local + git+https), requirements; planning-doc reconciliation

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 03-03-PLAN.md — Live sandbox evidence: tests/sandbox.sh (create-with-kit, exec checks, harness + render dump in sandbox, host/sandbox byte diff, restart + kit-add probes), README reconciled with observations, live check hand-off

### Phase 4: Fable Weekly f() Segment

**Goal**: Line 2 ends with a separate Fable weekly segment `Fable pct/1w (countdown)`, fetched from the OAuth usage data and cached without ever risking or delaying the rest of the line
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: FAB-01, FAB-02, FAB-03, FAB-04
**Research flag**: Needs research — undocumented `GET /api/oauth/usage` endpoint (confirm current window key and `utilization` scale), per-platform credential discovery (macOS Keychain vs `~/.claude/.credentials.json`), and sandbox credential presence must be verified during planning
**Success Criteria** (what must be TRUE):

  1. With valid OAuth credentials on the macOS host (Keychain), line 2 ends like `15%/1w (3d:5h:57m) · Fable 60%/1w (2d:4h:30m)` — the Fable segment is a separate last peer with its own countdown
  2. Inside a Docker Sandbox, the token is discovered from `~/.claude/.credentials.json` and the Fable segment renders the same way
  3. On any failure — no credentials, endpoint change, timeout, offline — the Fable segment silently disappears while every other segment renders normally
  4. Repeated renders within the cache TTL make no network call, and a cold fetch never delays the render beyond its short curl timeout
  5. Layout correction (D-51): the brief's in-segment notation is superseded by the separate `Fable pct/1w (countdown)` segment rendered last on line 2 — REQUIREMENTS.md, PROJECT.md and README reconciled

**Plans**: 3/4 plans executed

Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Tracer: Fable weekly adapter (iso_to_epoch, get_token file→Keychain, 300 s/0600 atomic cache with 3600 s grace, curl -K - fetch, negative cache, kill switch, stdin-first probe) + seg_fable last on line 2, proven via file:// fixture and a live host render; kill switch exported in harness + dumper

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Harness: iso_to_epoch table, §11 Fable probes (cold/warm/grace/negative/credentials/kill-switch/stdin/alone/no-parens/timeout/colour), hostile stdin/cache/body security probes under /bin/bash 3.2, every probe family bite-proven

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 04-03-PLAN.md — Sandbox probe in tests/sandbox.sh (credentials presence + live in-sandbox Fable render), curl in the kit guard, Docker Desktop human-action gate, live sandbox evidence run, end-of-phase live-check hand-off (autonomous: false)
- [x] 04-04-PLAN.md — Docs: README Fable note + example/legend (D-66), D-52 reconciliation of REQUIREMENTS/PROJECT/ROADMAP with the D-51 separate-segment layout (parallel with 04-03, disjoint files)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Status Line from Stdin | 2/2 | Complete    | 2026-08-21 |
| 2. Git Segment | 4/4 | Complete    | 2026-08-22 |
| 3. Install & Dual-Environment Validation | 3/3 | Complete    | 2026-08-22 |
| 4. Fable Weekly f() Segment | 3/4 | In Progress|  |
