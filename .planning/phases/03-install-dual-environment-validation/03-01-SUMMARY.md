---
phase: 03-install-dual-environment-validation
plan: 01
subsystem: infra
tags: [sbx, docker-sandbox, mixin-kit, jq, bash, statusline, harness, portability]

# Dependency graph
requires:
  - phase: 02-git-segment-hardening
    provides: the verified 226-line statusline.sh (never-fail, bash 3.2) and the 125-check tests/run.sh harness this plan relocates and re-points
provides:
  - kit/spec.yaml — valid sbx v0.39.0 mixin kit (schemaVersion "2", requires.agent claude, install jq/git guard, root startup jq merge of only .statusLine after the platform seed, chmod 0755 + chown insurance)
  - kit/files/home/.claude/statusline.sh — the canonical script, relocated by pure git mv (mode 100755, byte-identical to 64b3c1b:statusline.sh); repo root holds no script and no shim
  - tests/run.sh re-pointed to the kit path with a proven-to-bite `exec bit` check (126 checks, 0 failures), shellcheck advisory over tests/*.sh, `INFO installed:` advisory
  - tests/render-fixtures.sh — raw, escape-preserving per-fixture render dumper with installed-vs-repo diff -r (PORT-04 per-environment half) and INSTALLED/REQUIRE_INSTALLED knobs for the sandbox
  - .gitignore tests/out/ + host evidence under tests/out/host (7 repo renders, installed == repo PASS)
affects: [03-02 README install story, 03-03 live sandbox validation, 04 fable segment (script path)]

# Actuals (#2632) — chars/4 over files actually changed (spec.yaml + render-fixtures.sh + run.sh/.gitignore diff); the git mv is a zero-content rename
actuals:
  tokens: 2212
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: [sbx kit spec v2 (kind mixin)]
  patterns:
    - "Kit startup reconcile: POSIX sh as root, wait for the platform seed (themeId poll ≤60 s), jq `try (input) catch {}` + object guard, atomic tmp+mv, set ONLY .statusLine, chown back to agent (D-32/D-34)"
    - "Harness checks proven to bite before commit (chmod -x -> FAIL, chmod +x -> PASS)"
    - "Cross-environment evidence written inside the repo under gitignored tests/out/<env>/ (TMPDIR-independent), compared with POSIX diff -r / cmp"

key-files:
  created:
    - kit/spec.yaml
    - kit/files/home/.claude/statusline.sh
    - tests/render-fixtures.sh
  modified:
    - tests/run.sh
    - .gitignore

key-decisions:
  - "Kit lives at kit/ (repo root) with name claude-code-status-line, version 1.0.0; setup.install command is a single string, setup.startup command is [sh, -c, script] with user \"0\" — the only grammar sbx v0.39.0 accepts"
  - "Startup merge pre-seeds `{}` when settings.json is absent (jq exits 2 on a missing path) and never falls back to a wholesale rewrite — the jq filter alone turns empty/invalid/non-object content into a valid object"
  - "chown is non-recursive (dir, settings.json, statusline.sh only) so the root reconcile never walks session data"
  - "tests/render-fixtures.sh tracks whether it rendered the installed half with a flag (not a stale directory test) and clears only *.out files in its two subdirs (T-03-05)"
  - "Tracer feedback gate handled per orchestrator instruction: re-ran the tracer <verify> after commit (passed) and continued; no mid-flight human-verify checkpoint emitted (human_verify_mode end-of-phase)"

patterns-established:
  - "Shell helpers in tests/ follow run.sh: #!/bin/bash, cd to repo root, SL=kit/files/home/.claude/statusline.sh, PASS/FAIL/INFO vocabulary, helpers may exit non-zero"
  - "Decision-ID comments (# D-32, # D-34, # Pitfall 2, PORT-04) on every non-obvious line in kit and test code"

requirements-completed: [PORT-01, PORT-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Canonical statusline.sh relocated to kit/files/home/.claude/statusline.sh by pure git mv — mode 100755, byte-identical to 64b3c1b:statusline.sh, no script/shim at the repo root"
    requirement: PORT-01
    verification:
      - kind: other
        ref: "git show 64b3c1b:statusline.sh | cmp - kit/files/home/.claude/statusline.sh && test ! -e statusline.sh && git ls-files -s kit/files/home/.claude/statusline.sh | grep ^100755"
        status: pass
    human_judgment: false
  - id: D2
    description: "kit/spec.yaml is a valid sbx v0.39.0 mixin kit (schemaVersion \"2\", kind mixin, requires.agent claude, install jq/git guard, root startup jq merge of only statusLine = {type:command,command:~/.claude/statusline.sh,padding:0,refreshInterval:60} after the themeId seed, chmod 0755, chown agent)"
    requirement: PORT-04
    verification:
      - kind: other
        ref: "sbx kit validate kit (VALID, rc 0) && sbx kit inspect --json kit lists .claude/statusline.sh; startup body passes sh -n and shellcheck --shell=sh; jq filter probed on empty/invalid/array/object/missing inputs"
        status: pass
    human_judgment: false
  - id: D3
    description: "tests/run.sh re-pointed to the kit path, new `exec bit` check proven to bite (chmod -x -> FAIL 126/1, chmod +x -> PASS 126/0), shellcheck advisory over tests/*.sh, INFO installed: advisory"
    requirement: PORT-04
    verification:
      - kind: integration
        ref: "/bin/bash tests/run.sh -> '126 checks, 0 failures' (rc 0); bites run -> 'FAIL exec bit: ...' '126 checks, 1 failures'"
        status: pass
    human_judgment: false
  - id: D4
    description: "tests/render-fixtures.sh writes raw renders of all 7 fixtures through the repo path and the installed path, diff -r's them, exits 1 on difference or REQUIRE_INSTALLED miss; on the host installed == repo PASS (PORT-04 host half); tests/out/ gitignored"
    requirement: PORT-04
    verification:
      - kind: integration
        ref: "/bin/bash tests/render-fixtures.sh tests/out/host -> 7 repo renders + 'PASS installed path renders byte-identical to repo path (PORT-04)'; REQUIRE_INSTALLED=1 INSTALLED=/nonexistent -> FAIL rc 1; git status --porcelain tests/out empty"
        status: pass
    human_judgment: false
  - id: D5
    description: "Direct execution of kit/files/home/.claude/statusline.sh (shebang + exec bit) on tests/fixtures/full.json renders 'Opus 5 (high) · myproject' / '10%/100k/1M · 50%/5h (now) · 15%/1w (now)' — the move changed nothing about the render (PORT-01 host side; the host-vs-sandbox byte diff itself is plan 03)"
    requirement: PORT-01
    verification:
      - kind: e2e
        ref: "kit/files/home/.claude/statusline.sh < tests/fixtures/full.json | strip SGR | lines 1-2"
        status: pass
    human_judgment: false

# Metrics
duration: 5 min
completed: 2026-08-22
status: complete
---

# Phase 03 Plan 01: Relocate into sbx mixin kit, validate offline, re-point harness, add raw render dumper Summary

**statusline.sh relocated unchanged into a validated sbx mixin kit (`kit/spec.yaml` with an idempotent root-side jq `statusLine` merge), the 126-check harness re-pointed with a proven exec-bit check, and `tests/render-fixtures.sh` producing byte-for-byte install-path evidence (installed == repo PASS on the host).**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-22T11:56:37Z
- **Completed:** 2026-08-22T12:01:23Z
- **Tasks:** 2
- **Files modified:** 5 (3 created incl. the renamed script, 2 modified)

## Accomplishments
- `git mv statusline.sh kit/files/home/.claude/statusline.sh` — index mode 100755, `cmp` against `64b3c1b:statusline.sh` identical, no script or shim at the repo root (D-31)
- `kit/spec.yaml`: `schemaVersion "2"`, `kind: mixin`, `requires.agent: claude`, install-time `command -v jq/git || apt-get install` guard (D-33), root `sh -c` startup that waits for the platform `themeId` seed (≤60 s), pre-seeds `{}` if absent, jq-merges ONLY `.statusLine = {type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}` via atomic tmp+mv, `chmod 0755` the delivered script, non-recursive `chown agent:agent` (D-30, D-32, D-34) — `sbx kit validate kit` → `VALID`, `inspect --json` lists `.claude/statusline.sh`
- `tests/run.sh`: header + `SL=kit/files/home/.claude/statusline.sh`; new `exec bit: ... (PORT-04)` check directly under the syntax gate; shellcheck advisory now lints `"$SL" tests/*.sh`; `INFO installed:` advisory prints `ls -l ~/.claude/statusline.sh` when present — **126 checks, 0 failures**
- Bite proof recorded: `chmod -x` run → `FAIL exec bit: kit/files/home/.claude/statusline.sh is executable (PORT-04)` / `126 checks, 1 failures` (rc 1); `chmod +x` run → `PASS exec bit: ...` / `126 checks, 0 failures` (rc 0); index still 100755 afterwards
- Tracer end-to-end: direct execution `kit/files/home/.claude/statusline.sh < tests/fixtures/full.json` → `Opus 5 (high) · myproject` / `10%/100k/1M · 50%/5h (now) · 15%/1w (now)`
- `tests/render-fixtures.sh OUTDIR` (bash 3.2-safe, BSD/GNU-neutral, shellcheck clean): raw renders of the 7 fixtures to `OUTDIR/repo`, and through the installed path (executed directly) to `OUTDIR/installed` when `[ -x "$INSTALLED" ]`; `diff -r` → PASS/FAIL, `REQUIRE_INSTALLED` strictness, `${1:?usage}` guard; stale `*.out` cleared only inside the two subdirs
- Host evidence: `tests/out/host/{repo,installed}/*.out` (7 each) with `PASS installed path renders byte-identical to repo path (PORT-04)`; `tests/out/` gitignored, `git status --porcelain tests/out` empty
- D-46 honored: nothing under `~/.claude` created, modified, or re-pointed (host copy still the Aug 22 13:53 regular file, bytes identical to the kit script)

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer — relocate statusline.sh into the sbx mixin kit, validate the kit offline, re-point the harness** - `923264f` (feat)
2. **Task 2: Raw render dumper for byte-for-byte cross-environment comparison + gitignored evidence dir** - `cf9bc74` (feat)

**Plan metadata:** see final `docs(03-01)` commit

## Files Created/Modified
- `kit/spec.yaml` - sbx mixin kit manifest: static file delivery, install dependency guard, idempotent startup statusLine merge (D-30, D-32, D-33, D-34)
- `kit/files/home/.claude/statusline.sh` - the canonical script, relocated by pure rename (content unchanged, 100755)
- `tests/run.sh` - re-pointed `SL=`, new exec-bit check, shellcheck advisory over tests/*.sh, `INFO installed:` advisory
- `tests/render-fixtures.sh` - raw fixture render dumper + installed-vs-repo `diff -r` (D-39, PORT-01, PORT-04)
- `.gitignore` - `tests/out/` added

## Decisions Made
- Kit directory `kit/` at the repo root, kit name `claude-code-status-line`, version `1.0.0` (Claude's Discretion per CONTEXT)
- Startup merge: pre-seed `{}` when `settings.json` is absent rather than a `|| printf` wholesale fallback — keeps the single jq filter the only writer of the object and never replaces a file that exists (T-03-01/T-03-02)
- `chown` is non-recursive over exactly three paths — no walk over `/home/agent/.claude` session data
- `tests/render-fixtures.sh` uses a `have_installed` flag (set when the installed path is executable at run time) instead of testing for a stale `installed/` directory; clears only `*.out` inside `repo/` and `installed/` (T-03-05)
- Tracer feedback gate: auto mode is not active (`auto_advance: false`), but `human_verify_mode` is `end-of-phase` and the orchestrator prompt directed "re-run the tracer `<verify>` before starting the next task; HALT if it fails" — the re-run passed (`VALID`, root clean, cmp identical, `126 checks, 0 failures`) and execution continued; no mid-flight checkpoint was emitted

## Deviations from Plan

None - plan executed exactly as written.

(Execution note, not a deviation: the first `git commit` failed inside the command sandbox with `1Password: Could not connect to socket` — commit signing needs the 1Password SSH-agent Unix socket. Both task commits were re-run outside the sandbox with the identical message; no content differed.)

## Issues Encountered
- The extended shellcheck advisory (now linting `tests/*.sh`) surfaces pre-existing SC2319/SC2194/SC2034 warnings in `tests/run.sh` (the `[ cond ]; check_ok ... $?` house idiom, the constant `case` word in the palette loops, the unused latency loop counter). INFO-only, non-failing, out of scope for this plan (not introduced here except that the new exec-bit check deliberately copies the same house idiom). `tests/render-fixtures.sh` itself is shellcheck clean.

## User Setup Required

None - no external service configuration required. (The host symlink re-point and the `settings.json` snippet are the user's README-driven action in plan 02 — D-46.)

## Threat Flags

None beyond the plan's threat model: the kit's root startup command text is static repo content (T-03-03 accepted); no new network endpoints, auth paths, or schema changes.

## Next Phase Readiness
- Plan 02 (README) can document `ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh`, the D-34 snippet (byte-for-byte what the kit merges), `sbx run claude --kit "$PWD/kit"` / `sbx kit add`, and the mock-input verify command against the kit path.
- Plan 03 (live sandbox) consumes `tests/run.sh` and `INSTALLED=/home/agent/.claude/statusline.sh REQUIRE_INSTALLED=1 /bin/bash tests/render-fixtures.sh tests/out/sandbox`, then `diff -r tests/out/host/repo tests/out/sandbox/repo` on the host; `tests/out/host` evidence is already generated.
- Open (by design, plan 03): whether the sandbox engine preserves the exec bit and whether the `statusLine` merge survives stop/start — the startup `chmod 0755` and the themeId-wait merge are the insurance.

---
*Phase: 03-install-dual-environment-validation*
*Completed: 2026-08-22*

## Self-Check: PASSED

- key files present on disk; commits 923264f, cf9bc74 found; all Task 1 + Task 2 acceptance criteria re-run PASS; harness `126 checks, 0 failures`; plan-level verification PASS (kit VALID, cmp identical, root clean, render dump PASS, ~/.claude untouched)
