---
phase: 04-fable-weekly-f-segment
plan: 01
subsystem: statusline-fable-adapter
tags: [bash-3.2, jq, curl, oauth-usage-endpoint, keychain, ttl-cache, statusline, fable]

# Dependency graph
requires:
  - phase: 02-git-segment
    provides: single-pass @sh/eval jq ingestion with uint/strings type guards, seg_1w / pct_color / fmt_duration / join_segments helpers, hide-over-placeholder discipline, 126-check harness and render dumper
  - phase: 03-docker-sandbox-kit
    provides: canonical script at kit/files/home/.claude/statusline.sh, tests/render-fixtures.sh byte-for-byte dumps, host symlink install
provides:
  - iso_to_epoch pure-bash ISO-8601 -> epoch helper (BSD/GNU-neutral, no date(1))
  - Fable weekly adapter behind one seam — get_token (credentials file -> Keychain, read-only, expiresAt pre-check), read_cache / write_cache (0600 atomic mktemp+mv, negative results cached), fetch_usage (curl -K - headers on stdin, 2 s bound, guarded jq parse), get_fable_weekly (kill switch -> stdin -> TTL cache -> fetch -> grace -> hidden)
  - seg_fable renderer as the last line-2 peer ("Fable NN%/1w (countdown)", dim label, threshold colour on the number only)
  - stdin-first probe of rate_limits.model_scoped[] folded into the single jq pass (FAB_SI_PCT / FAB_SI_RST, 12 @sh-ingested fields)
  - STATUSLINE_NO_FABLE / STATUSLINE_USAGE_URL / STATUSLINE_CREDENTIALS_FILE / STATUSLINE_USAGE_CACHE / STATUSLINE_CURL_MAX_TIME env contract documented in the script header
  - fixtures tests/fixtures/usage/fable.json (endpoint body, file:// served) and tests/fixtures/fable-stdin.json (model_scoped stdin payload)
  - kill switch exported in tests/run.sh and tests/render-fixtures.sh so the existing harness and dumper stay network-free and Keychain-free
affects: [04-02 harness Fable block, 04-03 sandbox proof, 04-04 docs reconciliation, README, tests/sandbox.sh]

# Actuals (#2632) — same estimateTokens scale as the plan estimate (chars/4).
# chars/4 over the five files actually changed = 11648; chars/4 over the realized diff alone = 4644.
actuals:
  tokens: 11648
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: [curl (fetch only, --max-time bounded, -K - config on stdin), security find-generic-password (macOS host token, read-only), mktemp + mv -f (atomic 0600 cache)]
  patterns:
    - "One collector behind one seam: get_fable_weekly sets FAB_PCT/FAB_RST in main's shell; seg_fable only reads them (renderers never know the source)"
    - "Every untrusted parse (stdin model_scoped, endpoint body, cache file, credentials JSON) is its own guarded jq program emitting @sh single words; non-JSON -> empty -> hidden"
    - "Fetch-then-write: body into a variable, then mktemp in the cache directory + mv -f; readers see old or new complete JSON, never torn"
    - "Kill switch exported globally in every harness entry point; live-path probes always set URL + credentials-file + cache overrides into a temp dir"

key-files:
  created:
    - tests/fixtures/usage/fable.json
    - tests/fixtures/fable-stdin.json
  modified:
    - kit/files/home/.claude/statusline.sh
    - tests/run.sh
    - tests/render-fixtures.sh

key-decisions:
  - "Fable value rendered as a separate last peer segment 'Fable NN%/1w (countdown)' (D-51), not f(pct) inside the weekly segment — REQUIREMENTS/PROJECT/README/ROADMAP wording reconciled in plan 04-04"
  - "Stdin model_scoped is probed first (D-48) inside the existing single jq pass; today it is empty (Claude Code 2.1.240 projects only five_hour/seven_day) so the OAuth endpoint is the effective source"
  - "Token discovered read-only in one ordered list — STATUSLINE_CREDENTIALS_FILE (sole source when set) -> ~/.claude/.credentials.json -> Keychain item 'Claude Code-credentials'; expiresAt (epoch ms) pre-check skips guaranteed-401 calls; never refreshed, never printed, never in argv (curl -K - on stdin)"
  - "Cache is a shared per-user JSON at ~/.claude/statusline-usage-cache.json (0600, atomic), TTL 300 s, stale-while-error grace 3600 s, negative results (no Fable bucket) cached too so a missing bucket costs one fetch per TTL"
  - "Kill switch STATUSLINE_NO_FABLE disables every Fable path including stdin; exported in tests/run.sh and tests/render-fixtures.sh so 126 checks and 8 dumps stay hermetic"

patterns-established:
  - "iso_to_epoch: case-pattern-gated, 10#-forced two-digit fields, days-from-civil arithmetic — the pure-bash way to consume ISO resets_at without date -d/-j/-r"
  - "Live-path test idiom: STATUSLINE_NO_FABLE= STATUSLINE_USAGE_URL=file://<fixture> STATUSLINE_CREDENTIALS_FILE=<synthetic> STATUSLINE_USAGE_CACHE=<tmp>/usage.json /bin/bash statusline.sh < fixture"

requirements-completed: [FAB-01, FAB-02, FAB-03, FAB-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "seg_fable renders 'Fable 74%/1w (now)' as the last line-2 segment from the file:// endpoint fixture — dim label, threshold colour on the number only, own countdown, joined with the dim separator"
    requirement: FAB-01
    verification:
      - kind: integration
        ref: "04-01-PLAN.md Task 1 <verify> command (cold file:// render of tests/fixtures/full.json, line 2 exact match + ESC[2mFable byte check)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Token discovered credentials-file -> Keychain, read-only, handed to curl via -K - on stdin; live host render against the production endpoint with the Keychain token produced 'Fable 85%/1w (1d:20h:25m)' in 1 s"
    requirement: FAB-02
    verification:
      - kind: integration
        ref: "live host render recorded below (STATUSLINE_USAGE_CACHE=<tmp>, no URL/credentials override, exit 0, 0 stderr, cache -rw------- pct 85)"
        status: pass
      - kind: other
        ref: "acceptance grep: no -H/--header/--noproxy/--insecure/-k/security add-/credentials redirect on code lines (0 hits)"
        status: pass
    human_judgment: true
    rationale: "Roadmap SC1 'looks right at a glance' on the live host and the sandbox credentials-file path are confirmed by the end-of-phase human check (plan 04-03); the automated evidence here is one live render on the host"
  - id: D3
    description: "300 s TTL cache at 0600 written atomically (mktemp in the cache dir + mv -f), warm hit serves without fetching, negative result cached, 3600 s stale-while-error grace, curl bounded by --max-time 2"
    requirement: FAB-03
    verification:
      - kind: integration
        ref: "04-01-PLAN.md Task 1 <verify> (cache mode -rw-------, [true,74,0], warm render with file:///nonexistent still 74%); Task 1 probes: stale -400 s served, -4000 s hidden, blackhole URL max-time 1 -> hidden in 1 s wall"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every failure path hides the Fable segment and its separator with exit 0 and zero stderr — kill switch, absent credentials (no cache written), expired expiresAt, no Fable bucket (negative cache), hostile/garbage cache, hostile stdin model_scoped"
    requirement: FAB-04
    verification:
      - kind: integration
        ref: "04-01-PLAN.md Task 1/Task 2 <verify> commands + hostile probes (model_scoped string / array of strings / array-valued utilization+resets_at / injected display_name: hidden or countdown-less, no tests/.pwned*, 0 stderr)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Stdin-first source: rate_limits.model_scoped[] Fable entry renders 'Fable 33%/1w (now)' with no cache read, no cache write and no network; kill switch disables the stdin path too"
    requirement: FAB-02
    verification:
      - kind: integration
        ref: "04-01-PLAN.md Task 2 <verify> command (tests/fixtures/fable-stdin.json, test ! -e cache, STATUSLINE_NO_FABLE=1 hides)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Existing harness and dumper stay hermetic and green with the kill switch exported: /bin/bash tests/run.sh 126 checks / 0 failures; /bin/bash tests/render-fixtures.sh tests/out/host renders 8 fixtures, PASS installed == repo"
    requirement: FAB-04
    verification:
      - kind: unit
        ref: "/bin/bash tests/run.sh -> '126 checks, 0 failures'"
        status: pass
      - kind: integration
        ref: "/bin/bash tests/render-fixtures.sh tests/out/host -> 'INFO rendered 8 fixtures', 'PASS installed path renders byte-identical to repo path (PORT-04)'"
        status: pass
    human_judgment: false

# Metrics
duration: 16min
completed: 2026-08-23
status: complete
---

# Phase 4 Plan 01: Fable Weekly Adapter Tracer Summary

**Fable weekly segment via the OAuth usage endpoint behind a 0600 TTL cache with fail-silent hide, stdin-first source folded into the single jq pass, proven end-to-end on the host with a file:// fixture and live against the production endpoint (`Fable 85%/1w (1d:20h:25m)`).**

## Performance

- **Duration:** ~16 min (Task 1 ~9 min by the first executor, Task 2 + close-out ~7 min by this continuation; signing-lock checkpoint wait excluded)
- **Started:** 2026-08-22T21:21:00Z (approx., first executor)
- **Completed:** 2026-08-22T21:37:00Z (Task 2 commit 21:36:19Z)
- **Tasks:** 2
- **Files modified:** 5 (3 modified, 2 created)

## Accomplishments

- `kit/files/home/.claude/statusline.sh` (+216/-3 lines, now 432 lines): header "Env inputs" block; `iso_to_epoch` (pure bash, 17/17 table cases); the Fable weekly adapter section — `FAB_TTL=300`, `FAB_GRACE=3600`, `FAB_MAXTIME`, `FAB_URL`, `FAB_CACHE` constants, `get_token`, `read_cache`, `write_cache`, `fetch_usage`, `get_fable_weekly`; `seg_fable` after `seg_1w`; `main()` calls `get_fable_weekly` directly after `NOW` and joins line 2 with `"$(seg_fable)"` last.
- Stdin-first probe (D-48): `( [ .rate_limits.model_scoped? // [] | arrays[]? | objects | select(... startswith("fable")) ] | first // {} ) as $ms |` bound before the `@sh` string; `FAB_SI_PCT` (uint) and `FAB_SI_RST` (string-guarded) appended — 12 @sh-ingested fields (4 string, 8 numeric), hostile shapes yield empty single words.
- Fixtures: `tests/fixtures/usage/fable.json` (sanitized endpoint body, Fable `percent: 74`, `resets_at` epoch-0 ISO, served via `file://`), `tests/fixtures/fable-stdin.json` (full.json + `model_scoped` Fable 33).
- Kill switch `export STATUSLINE_NO_FABLE=1` in `tests/run.sh` and `tests/render-fixtures.sh`; dumper determinism note counts 8 fixtures and explains why `fable-stdin.json` renders without the segment.
- Live host proof (roadmap SC1, FAB-02) — run once outside the agent sandbox with the real Keychain token, no URL/credentials override, `STATUSLINE_USAGE_CACHE=<tmp>/live-usage.json`:
  - stripped line 2: `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 85%/1w (1d:20h:25m)`
  - exit 0, 0 stderr bytes, elapsed **1 s** (whole seconds, `date +%s` before/after)
  - temp cache: `-rw-------`, `jq -c .pct` = `85`, `.fetched_at > 0` = `true`; temp dir deleted afterwards
  - no Keychain dialog appeared; the token was never printed, echoed or stored; `ls -l ~/.claude/statusline-usage-cache.json` → `No such file or directory` before and after (nothing written under `~/.claude`)

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer — Fable weekly adapter + seg_fable end-to-end through a file:// endpoint fixture, kill switch exported in the harness and dumper** - `5955507` (feat)
2. **Task 2: Stdin-first source (D-48) folded into the single jq pass + stdin fixture, then the live host render against the production endpoint (roadmap SC1)** - `6e99fc9` (feat)

**Plan metadata:** see the final `docs(04-01)` commit

## Files Created/Modified

- `kit/files/home/.claude/statusline.sh` - header env-input docs, `iso_to_epoch`, Fable adapter (`get_token`/`read_cache`/`write_cache`/`fetch_usage`/`get_fable_weekly`), `seg_fable`, stdin `model_scoped` probe in the jq pass, line-2 join with Fable last
- `tests/fixtures/usage/fable.json` - sanitized OAuth usage response with a `weekly_scoped` Fable bucket (74 %, epoch-0 reset); sub-directory so the dumper glob never pipes it as stdin
- `tests/fixtures/fable-stdin.json` - `full.json` + `rate_limits.model_scoped[]` Fable 33 % (session_id `fix-fable-stdin`)
- `tests/run.sh` - `export STATUSLINE_NO_FABLE=1` after the `SL=` line (D-64)
- `tests/render-fixtures.sh` - same export + determinism paragraph ("all 8 fixtures", Fable path disabled, `fable-stdin.json` renders without the segment)

## Decisions Made

- Followed the plan and RESEARCH Patterns 1-6 as specified; no new decisions. The `$ms` binding precedes the `@sh` string (required: `@sh` applies to the whole program output). `FAB_SI_*` are assigned by the same `eval` as the other ten fields, so `get_fable_weekly` reads them by dynamic scope exactly like `seg_5h` reads `P5_*`.
- Duplicate comment line about the kill switch kept in the dumper header (the existing D-64 sentence from Task 1 plus the new fixture-specific sentence) — both are true and the plan asked for the "all 8 fixtures" sentence to mention `fable-stdin.json`.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0
**Impact on plan:** none.

## Issues Encountered

- **Environment, not code — 1Password SSH signing locked:** the first executor's `git commit` for Task 1 failed because the 1Password agent was locked; it returned a `checkpoint:human-action`, the user unlocked 1Password ("done"), and the orchestrator committed the already-staged Task 1 files as `5955507`. In this continuation the Task 2 commit failed inside the sandbox (`1Password: Could not connect to socket`) and succeeded on the retry with the sandbox disabled — signing was never bypassed (no `--no-verify`, no `commit.gpgsign=false`).
- **`ls` alias on the host shell:** the plan's `<verify>` one-liners call plain `ls`, which is aliased with incompatible flags in the interactive zsh used by the Bash tool; both one-liners were re-run verbatim under `/bin/bash <script>` (no aliases) and PASS. No change to the plan or the repo.

## Authentication Gates

None — the live host render used the Keychain token without any prompt (the item was already approved for `security` on this host; D-61 "Always Allow" was not needed).

## User Setup Required

None - no external service configuration required. The live path uses the credentials Claude Code already maintains (Keychain on the host, `~/.claude/.credentials.json` in sandboxes).

## Next Phase Readiness

Ready for 04-02 (harness Fable block: `fable_render` helper, §11 checks, `iso_to_epoch` table, §7 `model_scoped` hostile rows, `usage/no-bucket.json`). The adapter's env contract (`STATUSLINE_NO_FABLE`, `STATUSLINE_USAGE_URL`, `STATUSLINE_CREDENTIALS_FILE`, `STATUSLINE_USAGE_CACHE`, `STATUSLINE_CURL_MAX_TIME`), the cache path and JSON shape, and the two fixtures are in place for plans 02-04.

---
*Phase: 04-fable-weekly-f-segment*
*Completed: 2026-08-23*

## Self-Check: PASSED

- key-files.created exist; commits 5955507 and 6e99fc9 present; 2 commit(s) match 04-01; harness 126/0; dumper PASS (8 fixtures); tests/out clean; Task 1 + Task 2 <verify> one-liners re-run PASS under /bin/bash.
