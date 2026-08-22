---
phase: 03-install-dual-environment-validation
plan: 03
subsystem: testing
tags: [sbx, docker-sandbox, kit, portability, statusline, evidence, bash-3.2]

# Dependency graph
requires:
  - phase: 03-install-dual-environment-validation (plan 01)
    provides: kit/spec.yaml (mixin kit with the D-34 statusLine startup merge), kit/files/home/.claude/statusline.sh (canonical script), tests/run.sh (126-check harness), tests/render-fixtures.sh (INSTALLED / REQUIRE_INSTALLED raw render dumper, 7 fixtures)
  - phase: 03-install-dual-environment-validation (plan 02)
    provides: README.md Docker Sandboxes section whose sbx kit add sentence was conditional on this plan's probe
provides:
  - tests/sandbox.sh — re-runnable host-side orchestrator for the sandbox half of D-39 (create-with-kit, settings merge poll, exec-bit + byte-identity checks, in-sandbox harness + render dump, host/sandbox byte diff, stop/start probe, kit-add probe, evidence file, safe two-name sandbox lifecycle)
  - Live evidence tests/out/sandbox/EVIDENCE.txt (gitignored, pasted below) — 11 checks, 0 failures; PORT-01 7/7 fixtures byte-identical host vs sandbox; PORT-04 installed path renders identical in both environments; statusLine merged after first start and surviving stop/start (D-32/D-34)
  - Two MEDIUM-confidence research claims replaced by recorded observations (settings.json restart behaviour, sbx kit add scope) and README reconciled with them
  - Sandbox statusline-kit-test left in place for the end-of-phase live check
affects: [03 phase verification (live check harvest), 04 fable segment (tests/sandbox.sh re-run after f() lands), future sbx version bumps (kit-add probe re-answers D-37a)]

# Actuals (#2632) — chars/4 over tests/sandbox.sh (new) + the README.md diff
actuals:
  tokens: 3124
  tasks: 3
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Host-side sbx orchestrator order is load-bearing: arg parsing (--help exits before any sbx call) -> preamble -> prechecks (command -v sbx, sbx ls) -> evidence dir + EXIT trap -> checks; a precheck failure never runs sbx rm against an unreachable daemon"
    - "Evidence is written by an emit helper to stdout AND tests/out/sandbox/EVIDENCE.txt with fixed check-name prefixes, so the SUMMARY, the verifier, and future reruns grep the same strings"
    - "Research probes (kit-add) are reported as PASS/FAIL lines but not counted in the summary line; the summary certifies only the portability checks, the README follows the probe's answer"
    - "Cross-environment identity is proven by running the same dumper on both sides into tests/out/{host,sandbox} (same absolute path inside the bind mount) and diff -r, never by eyeballing"

key-files:
  created:
    - tests/sandbox.sh
  modified:
    - README.md

key-decisions:
  - "The sbx kit add probe (D-37a) is informational: reported as a PASS/FAIL line tagged [probe, not counted] plus an INFO probes line, excluded from CHECKS/FAILS — the plan's verify requires 'N checks, 0 failures' while allowing 'FAIL sbx kit add delivers', which is only consistent if the probe is reported-not-counted"
  - "README takes the recreate branch (D-37): sbx v0.39.0 refuses sbx kit add for kits that declare setup.startup, so the existing-sandbox sentence now says remove and recreate with sbx rm <name> then sbx run claude --kit ...; the sbx kit add sentence is gone"
  - "Restart probe PASSED with the canary surviving (settings.json is not re-seeded by the engine; the kit's startup merge is idempotent), so the kit startup merge stays the only documented sandbox settings route — the project-scope .claude/settings.json fallback is NOT added to the README (D-32)"

patterns-established:
  - "Sandbox lifecycle safety: only the two script-owned names (statusline-kit-test, statusline-kit-test-add) are ever removed; the primary is kept by default for the live check and removed only with --rm; the remove-everything form of sbx rm is absent (grep-gated)"
  - "D-46 evidence is ls -l ~/.claude/statusline.sh + jq -c .statusLine ~/.claude/settings.json before and after — identical; agents read ~/.claude, never write"

requirements-completed: [PORT-01, PORT-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "tests/sandbox.sh exists, is executable, bash 3.2 / BSD-GNU neutral, handles --help before any sbx call, --bogus exits 2, keeps the mandated stage order (help case < sbx ls precheck < trap), names only its two sandboxes, and carries every fixed check-name prefix"
    verification:
      - kind: other
        ref: "test -x tests/sandbox.sh && /bin/bash -n tests/sandbox.sh && /bin/bash tests/sandbox.sh --help | grep -qi usage; grep -n ordering help(l.46) < 'sbx ls'(l.133) < trap(l.144); grep -c -- '--all' = 0; grep -cE 'date -d|readlink -f|sed -i|mapfile|declare -A' = 0; all Task 1 acceptance greps >= required counts"
        status: pass
    human_judgment: false
  - id: D2
    description: "PORT-01: the seven fixture renders produced inside the kit-created sandbox are byte-identical to the host renders"
    requirement: PORT-01
    verification:
      - kind: e2e
        ref: "tests/out/sandbox/EVIDENCE.txt#PASS PORT-01: host vs sandbox fixture renders byte-identical (7 fixtures); diff -r tests/out/host/repo tests/out/sandbox/repo (empty); ls tests/out/sandbox/repo/*.out | wc -l = 7"
        status: pass
    human_judgment: false
  - id: D3
    description: "PORT-04: the kit-installed /home/agent/.claude/statusline.sh is present, executable, byte-identical to the repo file, and renders identically to the repo script inside the sandbox and to the host installed path"
    requirement: PORT-04
    verification:
      - kind: e2e
        ref: "EVIDENCE.txt#PASS kit script present and executable; #PASS kit script byte-identical to repo file; #PASS render dump in sandbox: installed == repo (PORT-04 sandbox half); #PASS render dump on host (PORT-04 host half); #PASS PORT-04: host vs sandbox installed-path renders byte-identical"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-32/D-34: .statusLine in /home/agent/.claude/settings.json equals the documented object within 120 s of first start and is present again after sbx stop + restart; other keys (canary) preserved"
    verification:
      - kind: e2e
        ref: "EVIDENCE.txt#PASS statusLine merged after first start (D-32/D-34); #PASS statusLine survives stop/start (D-32); INFO restart: canary survived"
        status: pass
    human_judgment: false
  - id: D5
    description: "Full harness passes inside the sandbox (D-39, includes the PORT-02 latency budget in the VM)"
    verification:
      - kind: integration
        ref: "EVIDENCE.txt#PASS harness in sandbox: 126 checks, 0 failures; tail -1 tests/out/sandbox/run.log = '126 checks, 0 failures'"
        status: pass
    human_judgment: false
  - id: D6
    description: "README Docker Sandboxes section reconciled with the probes: sbx kit add sentence replaced by sbx rm + recreate (kit-add probe FAIL), no project-scope settings note (restart probe PASS); plan-02 gates still hold"
    verification:
      - kind: other
        ref: "grep -Fc 'sbx kit add' README.md = 0; grep -ci recreate README.md = 1; grep -Fc '.claude/settings.json' README.md = 1; grep -Fc 'sbx run claude --kit' README.md = 2; grep -c '^## ' README.md = 5; wc -l README.md = 98; grep -ci fable = 0; grep -Fc 'f(' = 0"
        status: pass
    human_judgment: false
  - id: D7
    description: "D-46: nothing under the host ~/.claude created, modified, or re-pointed by the sandbox run"
    verification:
      - kind: other
        ref: "before == after: /bin/ls -l ~/.claude/statusline.sh -> '-rwxr-xr-x@ 1 sv staff 9800 Aug 22 13:53 /Users/sv/.claude/statusline.sh'; jq -c .statusLine ~/.claude/settings.json -> {\"type\":\"command\",\"command\":\"~/.claude/statusline.sh\",\"padding\":0}"
        status: pass
    human_judgment: false
  - id: D8
    description: "Live check (D-39 live half, roadmap criterion 2): sbx run --name statusline-kit-test shows the two-line status line after the first message with the same layout, glyphs, and colors as a host claude session in this repo"
    requirement: PORT-01
    verification: []
    human_judgment: true
    rationale: "Visual comparison of a live Claude Code TUI in two environments; the harness and the byte diff prove fixture-render identity, only a human confirms the real session renders it (plan Task 3 human-check; human_verify_mode = end-of-phase)"

# Metrics
duration: 3h 0m
completed: 2026-08-22
status: complete
---

# Phase 03 Plan 03: Live sandbox evidence (PORT-01 / PORT-04 / D-39) Summary

**`tests/sandbox.sh` creates a Docker Sandbox from this repo with `--kit "$PWD/kit"` and proves, with 11 named checks and 0 failures, that the kit-delivered `/home/agent/.claude/statusline.sh` is executable and byte-identical to the repo file, that the D-34 `statusLine` object is merged into `/home/agent/.claude/settings.json` after first start and survives stop/start, that the 126-check harness passes inside the sandbox, and that all 7 fixture renders are byte-identical host vs sandbox; the `sbx kit add` probe answered FAIL (sbx 0.39 refuses kits with `setup.startup`), so the README now documents `sbx rm` + recreate.**

## Performance

- **Duration:** 3h 0m wall clock (includes two human gates: the Docker Desktop start checkpoint and a commit-signing auth gate)
- **Started:** 2026-08-22T12:12:39Z
- **Completed:** 2026-08-22T15:13:29Z
- **Tasks:** 3 (2 auto + 1 human-action checkpoint)
- **Files modified:** 2 (tests/sandbox.sh created, README.md modified)

## Accomplishments

- `tests/sandbox.sh` (new, 0755, bash 3.2-safe, BSD/GNU-neutral): the re-runnable sandbox half of D-39 — four load-bearing stages (args, preamble, `sbx` prechecks, evidence dir + trap), fixed check names, emit-to-stdout-and-EVIDENCE.txt, `wait_statusline` 120 s poll with `jq -cS`, in-sandbox harness + render dump, host/sandbox `diff -r`, restart and kit-add probes, two-name-only sandbox lifecycle, `--rm` opt-in
- Live run (fresh sandbox, 21 s): `11 checks, 0 failures` — PORT-01 7/7 fixtures byte-identical, PORT-04 installed path identical in both environments, D-32/D-34 merge present after first start and after stop/start, harness in sandbox `126 checks, 0 failures`
- Research Open Question 2 closed: the engine does NOT re-seed `settings.json` on restart (canary survived); the kit's startup merge is idempotent and remains the only documented settings route (no project-scope fallback)
- Research Open Question 1 closed: `sbx kit add` is refused for this kit on sbx v0.39.0 (`declares setup.startup, which the kit-add recreate flow does not yet apply`); README's existing-sandbox sentence now documents `sbx rm <sandbox-name>` then the `sbx run claude --kit ...` command
- Host `~/.claude` untouched (D-46); sandbox `statusline-kit-test` kept (stopped) for the live check

## Task Commits

Each task was committed atomically:

1. **Task 1: Write tests/sandbox.sh — the re-runnable sandbox half of D-39** - `80358bd` (feat)
2. **Task 2: Start Docker Desktop so sandboxd is reachable** - human-action checkpoint, no commit (resolved by the user; `sbx ls` exits 0)
3. **Task 3: Run the live sandbox evidence, reconcile the README** - `b172b21` (fix)

**Plan metadata:** see the `docs(03-03)` commit that lands this SUMMARY.

## Files Created/Modified

- `tests/sandbox.sh` - host-side orchestrator: `sbx kit validate`, `sbx rm -f`/`sbx create ... --kit`, settings poll, exec-bit + `cmp`, exec user INFO, in-sandbox `tests/run.sh` and `tests/render-fixtures.sh` (INSTALLED/REQUIRE_INSTALLED), host dump, `diff -r` PORT-01/PORT-04, canary + `sbx stop` + restart probe, kit-add probe (informational), summary line; evidence in `tests/out/sandbox/{EVIDENCE.txt,run.log,render.log,repo/,installed/}` (gitignored)
- `README.md` - Docker Sandboxes section: the `sbx kit add` sentence replaced by the recreate instruction (98 lines, 5 sections, still no Phase 4 content)

## Decisions Made

- **Kit-add probe is informational, not counted.** The plan's automated verify demands the summary line `N checks, 0 failures` AND accepts `FAIL sbx kit add delivers ...` — consistent only if the probe is reported but excluded from CHECKS/FAILS. It is still emitted verbatim (so the acceptance grep for `FAIL sbx kit add delivers` holds) with a `[probe, not counted ...]` tag plus `INFO probes (not counted): kit-add=FAIL (D-37a)`.
- **README recreate branch (D-37).** Observed `sbx kit add` output: `ERROR: kit "claude-code-status-line" declares setup.startup, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via sbx rm + sbx create --kit to use this kit`. README sentence now: "Existing sandboxes cannot take the kit afterwards (`--kit` applies only at creation, and sbx 0.39 refuses to add a kit that declares `setup.startup`) — remove and recreate them: `sbx rm <sandbox-name>`, then the `sbx run` command above."
- **No project-scope settings fallback (D-32).** Restart probe PASS, canary survived: the engine preserves `settings.json` across stop/start and the startup merge re-applies idempotently. The CONTEXT fallback (`.claude/settings.json` note) is not needed and was not added; `grep -Fc '.claude/settings.json' README.md` = 1 (the user-scope snippet only).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kit-add probe counted in the summary made the plan's verify self-contradictory**
- **Found during:** Task 3 (first live run, 13:39:56Z: `12 checks, 1 failures`, the only FAIL being the kit-add probe)
- **Issue:** As written in Task 1, step 12 counted the `sbx kit add` probe through `check_ok`, so the summary could never read `0 failures` when the probe answered FAIL — yet the plan's `<verify>` requires `^[0-9]+ checks, 0 failures$` and its acceptance criteria explicitly allow `FAIL sbx kit add delivers`. A research probe whose answer the README follows is not a portability failure.
- **Fix:** The probe now emits `PASS`/`FAIL sbx kit add delivers ... [probe, not counted ...]` directly via `emit`, plus `INFO probes (not counted): kit-add=PASS|FAIL (D-37a)`; CHECKS/FAILS certify only the PORT-01 / PORT-04 / D-32 checks. Header comment and the 5.12 section comment document this.
- **Files modified:** tests/sandbox.sh
- **Verification:** Second live run `11 checks, 0 failures`; `bash -n` clean; shellcheck clean; all Task 1 acceptance greps and the stage ordering (help l.46 < `sbx ls` l.133 < trap l.144) still hold
- **Committed in:** b172b21 (Task 3 commit)

**2. [Rule 1 - Bug] Stale `WAIT_GOT` emitted as the kit-add `.statusLine after add` value**
- **Found during:** Task 3 (same first run)
- **Issue:** When `sbx kit add` itself failed, the probe never polled the `-add` sandbox, so the INFO line reported the primary sandbox's last `WAIT_GOT` value as if it were the add-sandbox's `.statusLine` — misleading evidence.
- **Fix:** `WAIT_GOT` is reset before the probe and the `.statusLine after add` INFO is only emitted when `sbx kit add` returned 0 (the add-sandbox was actually polled).
- **Files modified:** tests/sandbox.sh
- **Verification:** Run 2 EVIDENCE.txt carries `INFO kit-add probe: sbx kit add rc=1 output: ERROR: ...` and no after-add value line
- **Committed in:** b172b21 (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs, both in the new test helper)
**Impact on plan:** Both fixes make the evidence honest and the plan's own verify satisfiable; no change to the kit, the script under test, or the harness. No scope creep.

## Issues Encountered

- **sandboxd checkpoint (Task 2):** at plan start `sbx ls` could not reach sandboxd; the `checkpoint:human-action` (`gate="blocking-human"`) was returned and the user started Docker Desktop. Task 3's precondition re-asserted `sbx ls` exit 0 before any sandbox work.
- **`sbx` unusable inside the command sandbox:** the tool sandbox blocks the sandboxd unix socket, so `tests/sandbox.sh` (and the commits, see next) had to run with the sandbox override per the harness rules — no files outside the repo and `tests/out/` were written.
- **Commit-signing auth gate (Task 3 commit):** `git commit` failed with a 1Password `op-ssh-sign` error; two executor agents hit it and returned a human-action checkpoint with the two files staged. The user resolved it at 15:11Z (`git commit -m test --allow-empty && git reset --soft HEAD~1` re-established signing; HEAD back at 80358bd with the index intact), and this continuation retried: `b172b21` signed and landed. Documented as normal flow, not a deviation.
- **Shell `ls` alias broken in the executor shell:** `/bin/ls` was used for the `*.out` count and the D-46 listing.

## Authentication Gates

- Task 3 commit: 1Password SSH commit signing unavailable (`op-ssh-sign` error). Outcome: user restored the agent; retry succeeded. No git config changed, no `--no-gpg-sign`/`--no-verify` used.

## Live evidence (tests/out/sandbox/EVIDENCE.txt, run 2, pasted verbatim)

```text
INFO sandbox.sh start: 2026-08-22T13:42:21Z repo=/Users/sv/github/claude-code-status-line kit=/Users/sv/github/claude-code-status-line/kit name=statusline-kit-test
PASS kit validate: sbx kit validate kit
PASS sandbox created with kit: statusline-kit-test
PASS statusLine merged after first start (D-32/D-34)
INFO observed .statusLine: {"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}
INFO settings.json keys: ["alwaysThinkingEnabled","bypassPermissionsModeAccepted","defaultMode","skipDangerousModePermissionPrompt","statusLine","themeId"]
PASS kit script present and executable: /home/agent/.claude/statusline.sh
PASS kit script byte-identical to repo file
INFO sbx exec user: agent HOME=/home/agent
PASS harness in sandbox: 126 checks, 0 failures
PASS render dump in sandbox: installed == repo (PORT-04 sandbox half)
PASS render dump on host (PORT-04 host half)
PASS PORT-01: host vs sandbox fixture renders byte-identical (7 fixtures)
PASS PORT-04: host vs sandbox installed-path renders byte-identical
INFO canary written before stop: 1
PASS statusLine survives stop/start (D-32)
INFO restart: canary survived — other keys preserved across stop/start; statusLine re-merged idempotently
FAIL sbx kit add delivers kit files + startup merge to an existing sandbox (D-37a) [probe, not counted — README documents sbx rm + recreate]
INFO kit-add probe: sbx kit add rc=1 output: ERROR: kit "claude-code-status-line" declares setup.startup, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via `sbx rm` + `sbx create --kit` to use this kit
INFO probes (not counted): kit-add=FAIL (D-37a)
INFO sandbox statusline-kit-test kept for the live check: sbx run --name statusline-kit-test  (remove with: sbx rm -f statusline-kit-test)
11 checks, 0 failures
```

Supporting facts:
- Run 1 (13:39:56Z): `12 checks, 1 failures` — only the kit-add probe failed, same sbx error; led to the two auto-fixes above. Run 2 (13:42:21Z, fresh sandbox, 21 s) is the recorded evidence.
- `diff -r tests/out/host/repo tests/out/sandbox/repo` → empty; `/bin/ls tests/out/sandbox/repo/*.out | wc -l` → 7; `tail -1 tests/out/sandbox/run.log` → `126 checks, 0 failures`.
- Observed `.statusLine`: `{"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}` (= D-34). Settings keys: `alwaysThinkingEnabled, bypassPermissionsModeAccepted, defaultMode, skipDangerousModePermissionPrompt, statusLine, themeId`.
- Exec user: `agent`, `HOME=/home/agent` (research A4 confirmed).
- Canary outcome: survived stop/start (engine does not re-seed; merge idempotent).
- Kit-add outcome: FAIL on sbx v0.39.0 (kit declares `setup.startup`). README branch taken: recreate.
- D-46 before == after: `/bin/ls -l ~/.claude/statusline.sh` → `-rwxr-xr-x@ 1 sv  staff  9800 Aug 22 13:53 /Users/sv/.claude/statusline.sh`; `jq -c .statusLine ~/.claude/settings.json` → `{"type":"command","command":"~/.claude/statusline.sh","padding":0}`.
- Host harness after the run: `126 checks, 0 failures`. Sandboxes: `statusline-kit-test` present (stopped); `statusline-kit-test-add` removed; no other sandbox touched.

## User Setup Required

None - no external service configuration required. (Docker Desktop must be running for `tests/sandbox.sh` and the live check.)

## Next Phase Readiness

- Sandbox `statusline-kit-test` is in place for the end-of-phase live check: `sbx run --name statusline-kit-test`, send "hi", compare with a host `claude` session in this repo (coverage D8; recreate with `sbx run claude . --kit "$PWD/kit"` if it is gone).
- Phase 3 plans 01–03 all have SUMMARYs; PORT-01 and PORT-04 marked complete. Ready for `/gsd-verify-work 03` and Phase 4 (`f()` model-specific weekly segment) — re-run `/bin/bash tests/sandbox.sh` after Phase 4 lands to re-prove identity with the new segment.
- Known sbx limitation to re-check on a future sbx bump: `sbx kit add` for kits with `setup.startup` (the probe re-answers D-37a on every run).

---
*Phase: 03-install-dual-environment-validation*
*Completed: 2026-08-22*

## Self-Check: PASSED

- Key files exist (tests/sandbox.sh, README.md, tests/out/sandbox/EVIDENCE.txt, this SUMMARY)
- Commits 80358bd and b172b21 present; `git log --grep=03-03` >= 2
- Task 3 acceptance criteria re-run: EVIDENCE summary line, all PASS prefixes, kit-add probe line, run.log 126/0, diff -r empty, 7 .out files, README probe branch + plan-02 gates, evidence pasted
