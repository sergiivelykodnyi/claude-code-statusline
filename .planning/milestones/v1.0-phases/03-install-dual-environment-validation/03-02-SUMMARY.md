---
phase: 03-install-dual-environment-validation
plan: 02
subsystem: docs
tags: [readme, install, symlink, settings-json, refreshInterval, sbx, docker-sandbox, mixin-kit, statusline]

# Dependency graph
requires:
  - phase: 03-install-dual-environment-validation (plan 01)
    provides: kit/files/home/.claude/statusline.sh (canonical script), kit/spec.yaml (sbx mixin kit with the D-34 statusLine merge), tests/run.sh pinned expected strings, tests/fixtures/full.json
provides:
  - README.md (97 lines, five level-2 sections) — what it shows, symbol legend, host symlink/copy install with overwrite warning, statusLine settings snippet (padding 0, refreshInterval 60), mock-input verify command + claude --debug hint, Docker Sandboxes kit install (local --kit / sbx kit add and git+https with kit.allowedSources note), requirements
  - .planning/research/ARCHITECTURE.md project tree + Filesystem integration row reconciled with the kit layout and the sbx sandbox route
  - .planning/PROJECT.md installation-model bullet corrected (host symlink into the kit path; sandboxes do not import ~/.claude, the kit installs the same file)
  - Proof that the README's verify payload renders exactly the documented two lines through the shipped kit script
affects: [03-03 live sandbox validation (README sbx kit add sentence conditional on its probe), 04 fable segment (README What-it-shows + legend update when f() lands)]

# Actuals (#2632) — chars/4 over README.md (new) + the ARCHITECTURE.md/PROJECT.md diff
actuals:
  tokens: 2316
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "README install blocks are copy-pasteable literals that match the code byte-for-byte: the settings snippet equals the kit's jq merge object (D-34), the verify payload equals tests/fixtures/full.json and its expected lines equal the tests/run.sh pins"
    - "Docs-only tasks still close with a contract check against the shipped artifact (payload piped through kit/files/home/.claude/statusline.sh) plus a harness re-run"

key-files:
  created:
    - README.md
  modified:
    - .planning/research/ARCHITECTURE.md
    - .planning/PROJECT.md

key-decisions:
  - "README verify command uses the tests/fixtures/full.json payload verbatim (resets_at 0 renders '(now)' forever, so the documented output is stable) and targets ~/.claude/statusline.sh so the same line works on the host and inside a sandbox shell (D-38)"
  - "README remote kit reference uses the real GitHub repo name claude-code-statusline (git remote -v), not the CONTEXT spelling; the #ref= pin note is written as '#ref=<tag-or-commit>&dir=kit' so the exact '#dir=kit' reference appears once"
  - "ARCHITECTURE.md tree shows kit/spec.yaml and kit/files/home/.claude/statusline.sh with the script's section list nested under the kit path (pure Edit, no rewrite); the literal 'kit/spec.yaml' string was added to the tree comment so the artifact grep holds"
  - "README landed at 97 lines — inside the D-40 hard bounds (50–100) but above the 60–80 aim; kept, because every line is a required D-35..D-45 element or the blank line a fenced block needs"

patterns-established:
  - "Host evidence for D-46 is recorded as before/after `ls -l ~/.claude/statusline.sh` + `jq -c .statusLine ~/.claude/settings.json` — agents only read ~/.claude, never write"

requirements-completed: [DOCS-01, DOCS-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "README.md: 97 lines, exactly five ## sections in D-40 order (What it shows, Symbol legend, Install on the host, Install in Docker Sandboxes, Requirements), no Development section, no Phase 4 / fable / f( content"
    requirement: DOCS-01
    verification:
      - kind: other
        ref: "test -f README.md && wc -l 50..100 && grep -c '^## ' = 5 && grep -ci fable = 0 && grep -Fc 'f(' = 0 && grep -Fc '## Development' = 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "What-it-shows block carries exactly the two current-output lines and the legend table covers ⎇, *, ≡/≢, ↓N, ↑N, #N, the context segment and the 5h/1w segments"
    requirement: DOCS-01
    verification:
      - kind: other
        ref: "grep -Fc 'Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2' = 1; grep -Fc '10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)' = 1; legend rows present"
        status: pass
    human_judgment: false
  - id: D3
    description: "Host install: ln -sf \"$PWD/kit/files/home/.claude/statusline.sh\" ~/.claude/statusline.sh one-liner, live-symlink note ('immediately'), rm -f && cp copy variant with bold overwrite Warning (D-35, D-36, D-42b)"
    requirement: DOCS-01
    verification:
      - kind: other
        ref: "grep -Fc ln-sf-one-liner = 1; grep -Fc 'rm -f ~/.claude/statusline.sh && cp kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh' = 1; grep -ci overwrite >= 1; grep -Fc immediately >= 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "Settings snippet: one JSON block with statusLine {type command, command ~/.claude/statusline.sh, padding 0, refreshInterval 60} — byte-for-byte the object kit/spec.yaml merges (D-34, D-43, D-44, D-45)"
    requirement: DOCS-02
    verification:
      - kind: other
        ref: "grep -Fc '\"statusLine\"' = 1; '\"type\": \"command\"' = 1; '\"command\": \"~/.claude/statusline.sh\"' = 1; '\"padding\": 0' = 1; '\"refreshInterval\": 60' = 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "Verify command (full.json payload | ~/.claude/statusline.sh) with expected lines 'Opus 5 (high) · myproject' / '10%/100k/1M · 50%/5h (now) · 15%/1w (now)' and the claude --debug hint — and the promise is TRUE against the shipped script (D-38)"
    requirement: DOCS-02
    verification:
      - kind: e2e
        ref: "payload extracted from README | /bin/bash kit/files/home/.claude/statusline.sh | strip SGR -> line1 'Opus 5 (high) · myproject', line2 '10%/100k/1M · 50%/5h (now) · 15%/1w (now)' (rc 0, 0 stderr bytes); equals README comments and tests/run.sh:108 pins"
        status: pass
    human_judgment: false
  - id: D6
    description: "Docker Sandboxes section: one-line why (host ~/.claude not imported, symlinks cannot cross), local --kit for new + sbx kit add for existing sandboxes, remote git+https://github.com/sergiivelykodnyi/claude-code-statusline.git#dir=kit with kit.allowedSources note and #ref= pin (D-37, D-42a)"
    requirement: DOCS-01
    verification:
      - kind: other
        ref: "grep -Fc 'sbx run claude --kit' = 2; 'sbx kit add' = 1; git+https ref = 1; 'kit.allowedSources' = 1; 'do not import' = 1"
        status: pass
    human_judgment: false
  - id: D7
    description: "ARCHITECTURE.md and PROJECT.md no longer claim sandboxes share the host ~/.claude; both name kit/ as the canonical script location and the sbx kit as the sandbox route (scoped edits only)"
    verification:
      - kind: other
        ref: "grep -Fc 'kit/spec.yaml' ARCHITECTURE.md = 1; 'kit/files/home/.claude/statusline.sh' in both = 1; 'not imported' PROJECT.md = 1; 'sandboxes share' / 'mount/share' = 0; git diff --stat touched only the two files"
        status: pass
    human_judgment: false
  - id: D8
    description: "Harness still green after the docs work (nothing in the render path changed)"
    verification:
      - kind: integration
        ref: "/bin/bash tests/run.sh -> '126 checks, 0 failures' (rc 0)"
        status: pass
    human_judgment: false
  - id: D9
    description: "Host UAT: following ONLY the README (ln -sf one-liner + settings snippet) gets the status line rendering in Claude Code on the macOS host, ~/.claude/statusline.sh resolves to the kit path, and the countdowns tick while the session is idle (refreshInterval 60)"
    requirement: DOCS-02
    verification: []
    human_judgment: true
    rationale: "Requires editing files outside the repo (agents never touch ~/.claude — D-46) and observing a live Claude Code TUI over time; harvested end-of-phase per human_verify_mode = end-of-phase (roadmap criteria 1 and 3)"

# Metrics
duration: 3 min
completed: 2026-08-22
status: complete
---

# Phase 03 Plan 02: README install story + planning-doc reconciliation Summary

**97-line README with the host `ln -sf` one-liner into the kit path, the safe `rm -f && cp` variant with overwrite warning, the D-34 `statusLine` snippet (`padding` 0, `refreshInterval` 60), a mock-input verify command proven true against the shipped script, and the Docker Sandboxes kit install both local (`--kit` / `sbx kit add`) and remote (`git+https…#dir=kit`); ARCHITECTURE.md and PROJECT.md no longer claim sandboxes share `~/.claude`.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-22T12:05:37Z
- **Completed:** 2026-08-22T12:08:38Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `README.md` (new, 97 lines, 5 `##` sections in D-40 order): title + one-sentence pitch; fenced two-line example `Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2` / `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)` plus the 70 %/90 % color and hide-when-empty sentence; one 11-row legend table (`↓` = behind, `↑` = ahead per the implementation); host install — symlink one-liner, live-link note, `rm -f … && cp …` with bold **Warning**, paste-this JSON snippet, `refreshInterval` explanation, verify command with expected `(now)` lines, `claude --debug` + `chmod +x` hint; Docker Sandboxes — why a kit (host `~/.claude` not imported, symlinks cannot cross), local absolute-path `--kit` for new and `sbx kit add` for existing sandboxes, remote `git+https://github.com/sergiivelykodnyi/claude-code-statusline.git#dir=kit` with `kit.allowedSources` and `#ref=` notes, sandbox-shell verify note; requirements (bash 3.2+, jq, git, Claude Code ≥ 2.1.x, sbx ≥ 0.39). No `fable`, no `f(`, no `## Development`.
- `.planning/research/ARCHITECTURE.md`: project tree now `kit/spec.yaml` + `kit/files/home/.claude/statusline.sh` (script sections nested under it), `README.md` and `tests/` (run.sh, render-fixtures.sh, sandbox.sh, fixtures/) lines kept; `Filesystem (~/.claude)` row rewritten — host `ln -sf` into the kit path, sandboxes via the `kit/` mixin kit copying to `/home/agent/.claude/statusline.sh` + `statusLine` merge every start because sandboxes do not import the host `~/.claude`.
- `.planning/PROJECT.md`: installation-model bullet rewritten (repo is source of truth; host symlink to the kit path; sandboxes do not import `~/.claude` — not imported, symlinks not followable — so the kit installs the same file and merges `statusLine`). Nothing else in PROJECT.md touched.
- README contract check: payload extracted from the README's verify line → `/bin/bash kit/files/home/.claude/statusline.sh` → rc 0, 0 stderr bytes, escape-stripped line 1 `Opus 5 (high) · myproject`, line 2 `10%/100k/1M · 50%/5h (now) · 15%/1w (now)` — identical to the README's comment lines and the `tests/run.sh` pins. Harness re-run: **126 checks, 0 failures**.
- D-46 honored — `~/.claude` untouched. Evidence before and after (identical):
  - `ls -l ~/.claude/statusline.sh` → `-rwxr-xr-x@ 1 sv  staff  9800 Aug 22 13:53 /Users/sv/.claude/statusline.sh`
  - `jq -c .statusLine ~/.claude/settings.json` → `{"type":"command","command":"~/.claude/statusline.sh","padding":0}`
  (still the pre-Phase-3 regular file and a snippet without `refreshInterval` — the user's README-driven host UAT re-points the link and merges the snippet.)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write README.md — what it shows, legend, host install + settings snippet + verify, Docker Sandboxes kit install, requirements** - `c451d24` (docs)
2. **Task 2: Reconcile planning docs with the kit layout and prove the README's verify promise against the shipped script** - `5cccf71` (docs)

**Plan metadata:** see final `docs(03-02)` commit

## Files Created/Modified
- `README.md` - the user-facing install story (DOCS-01, DOCS-02; D-35..D-38, D-40..D-45)
- `.planning/research/ARCHITECTURE.md` - project tree + Filesystem integration row for the kit layout / sbx route (scoped edits)
- `.planning/PROJECT.md` - installation-model bullet corrected (scoped edit)

## Decisions Made
- Verify payload = `tests/fixtures/full.json` verbatim, target `~/.claude/statusline.sh` (works on host and in a sandbox shell); `resets_at: 0` keeps the documented output stable.
- Remote kit reference uses the real repo name `claude-code-statusline`; the `#ref=` pin note is phrased `#ref=<tag-or-commit>&dir=kit` so the exact `.git#dir=kit` string appears exactly once (acceptance grep).
- README kept at 97 lines (within the 50–100 hard bounds, above the 60–80 aim) — every remaining line is a mandated element or a fenced-block separator; no content was cut to chase the aim.
- ARCHITECTURE.md tree comment carries the literal `kit/spec.yaml` so the plan's artifact `contains` grep and acceptance criterion hold.

## Deviations from Plan

None - plan executed exactly as written.

(Execution notes, not deviations: (1) the first `git commit` of Task 1 failed inside the command sandbox with `1Password: Could not connect to socket` — the known signing-socket limitation; both task commits were re-run outside the sandbox with identical messages. (2) Task 2 acceptance `grep -Fc 'kit/spec.yaml' ARCHITECTURE.md` was 0 after the first tree edit (the tree showed `kit/` + `├── spec.yaml`); fixed on the first attempt by adding the literal path to the tree comment before committing.)

## Issues Encountered
None.

## User Setup Required

**Host install is the user's action (D-46).** Follow `README.md` → *Install on the host*: run the `ln -sf` one-liner from the repo root and merge the `statusLine` snippet (with `refreshInterval: 60`) into `~/.claude/settings.json`. Today's host state (unchanged by this plan): `~/.claude/statusline.sh` is a regular file from before Phase 3 and `settings.json` has no `refreshInterval`. This is the end-of-phase human UAT (coverage D9).

## Threat Flags

None beyond the plan's threat model: T-03-06 mitigated (copy variant is `rm -f … && cp …` with the warning; no bare `cp` shown), T-03-07 mitigated (local `--kit` documented first, `kit.allowedSources` and `#ref=` notes present, real repo name). No new endpoints, auth paths, or schema changes.

## Next Phase Readiness
- Plan 03 (live sandbox): README's `sbx kit add <sandbox-name> …` sentence and the `sbx run claude --kit` routes are what its probes verify; keep or reword the `sbx kit add` sentence per the kit-add probe result (research Open Question 1).
- Phase 4: when the Fable `f()` sub-segment lands, update the README example line 2 and add a legend row (D-41 deferred the mention).
- Host UAT pending (human, end-of-phase): README-only install on the macOS host, symlink resolves to the kit path, countdowns tick while idle.

---
*Phase: 03-install-dual-environment-validation*
*Completed: 2026-08-22*

## Self-Check: PASSED

- `README.md` present (97 lines); `.planning/research/ARCHITECTURE.md` and `.planning/PROJECT.md` present; commits `c451d24`, `5cccf71` found via `git log --grep=03-02`; all Task 1 acceptance criteria re-run PASS (counts: sections 5, example lines 1/1, ln -sf 1, rm+cp 1, overwrite 1, statusLine/type/command/padding/refreshInterval 1 each, pipe ≥1, now-line 1, claude --debug 1, `sbx run claude --kit` 2, `sbx kit add` 1, git+https 1, allowedSources 1, do not import 1, immediately 1, bash 3.2 1, Claude Code 4, fable 0, f( 0, Development 0); Task 2 criteria PASS (PROJECT kit path 1, not imported 1, ARCH kit/spec.yaml 1, ARCH kit script path 1, contract check lines match, harness 126/0, diff scope = the two planning files); host before/after evidence identical.
