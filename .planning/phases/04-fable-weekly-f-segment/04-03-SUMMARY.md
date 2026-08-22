---
phase: 04-fable-weekly-f-segment
plan: 03
subsystem: testing
tags: [sbx, docker-sandbox, kit, fable, oauth-usage, credentials, portability, evidence, bash-3.2]

# Dependency graph
requires:
  - phase: 04-fable-weekly-f-segment (plan 01)
    provides: kit/files/home/.claude/statusline.sh with the Fable adapter (token from ~/.claude/.credentials.json then Keychain, 300 s cache, STATUSLINE_NO_FABLE kill switch, seg_fable last on line 2)
  - phase: 04-fable-weekly-f-segment (plan 02)
    provides: tests/run.sh Fable probes (220-check harness), tests/fixtures/full.json with the Fable model_scoped shape, 8 fixtures for tests/render-fixtures.sh
  - phase: 03-install-dual-environment-validation (plan 03)
    provides: tests/sandbox.sh host-side orchestrator (create-with-kit, settings poll, in-sandbox harness + render dump, host/sandbox diff -r, two-name lifecycle, EVIDENCE.txt), the Task 2 Docker Desktop human-action precedent, D-46 before/after evidence pattern
provides:
  - tests/sandbox.sh §5.13 — credentials-file PRESENCE probe (test -f, never read) + live in-sandbox Fable render through the kit-delivered script with the kill switch unset and no URL/credentials/cache override (sandbox's own token + HTTPS_PROXY egress); fixed check names for both branches; elapsed seconds and cache ls -l mode recorded as INFO; local ESC/strip_ansi helpers
  - kit/spec.yaml D-33 install guard extended to curl (no-op on the claude-code base image); kit still validates
  - Live evidence tests/out/sandbox/EVIDENCE.txt (gitignored, pasted below) — 12 checks, 0 failures; credentials PRESENT branch observed; Fable segment rendered inside the kit sandbox ("· Fable 90%/1w (1d:18h:32m)") in 1 s; harness in sandbox 220 checks / 0 failures (plan-02 Fable probes green under bash 5 / jq 1.8 / curl 8.18); PORT-01 8/8 fixtures byte-identical host vs sandbox; PORT-04 installed path identical; cache -rw------- agent
  - Sandbox statusline-kit-test left running for the end-of-phase live check
affects: [04 phase verification (live-check harvest, FAB-02 sandbox half), future sbx version bumps (tests/sandbox.sh re-run re-answers D-37a and D-63 on every run)]

# Actuals (#2632) — chars/4 over the Task 1 diff (tests/sandbox.sh + kit/spec.yaml); Task 3 changed no tracked file
actuals:
  tokens: 1399
  tasks: 3
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sandbox credential probes test PRESENCE only (sx NAME test -f …) and the live render goes through the script's own defaults (no proxy flags, no overrides) — evidence carries percentages, seconds and ls -l modes, never file content (T-04-02, T-04-08)"
    - "Conditional-branch checks with fixed names: exactly one counted check is emitted whichever branch the environment is in (present -> 'Fable segment renders in sandbox (FAB-02, D-63)', absent -> 'Fable hidden in sandbox without credentials (D-63)'), so the summary line is meaningful in both and the verifier greps either"
    - "Live-evidence plans are autonomous: false with a blocking-human Docker Desktop checkpoint and a re-asserted precondition (sbx ls exits 0, run with dangerouslyDisableSandbox) — the executor never starts host services and never writes EVIDENCE.txt by hand"

key-files:
  created: []
  modified:
    - tests/sandbox.sh
    - kit/spec.yaml

key-decisions:
  - "Sandbox credentials branch observed: PRESENT (proxy-scoped token via the global sbx `anthropic` secret) — the Fable segment renders live inside the kit sandbox with no kit change; README's Docker sentence (plan 04) already covers this branch, nothing to reconcile"
  - "Host ~/.claude/statusline.sh is currently a stale 9800-byte regular-file COPY of the pre-Phase-4 script (not a symlink, differs from kit/files/home/.claude/statusline.sh); left untouched per D-46 — the host half of the live check requires the user to re-run the README `ln -sf` line first (flagged below for the verifier)"

patterns-established:
  - "D-46 evidence for every sandbox run: /bin/ls -l ~/.claude/statusline.sh + jq -c .statusLine ~/.claude/settings.json before and after — identical; agents read ~/.claude, never write"

requirements-completed: [FAB-01, FAB-02, FAB-04]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "tests/sandbox.sh §5.13 exists with the credentials-presence probe, the live in-sandbox Fable render, both fixed check names, local strip_ansi, no content read of the credentials file; --help still exits 0 before any sbx call; kit/spec.yaml guards curl and validates"
    verification:
      - kind: other
        ref: "/bin/bash -n tests/sandbox.sh && /bin/bash tests/sandbox.sh --help && sbx kit validate kit && grep -F 'Fable segment renders in sandbox (FAB-02, D-63)' / 'Fable hidden in sandbox without credentials (D-63)' / 'test -f /home/agent/.claude/.credentials.json' tests/sandbox.sh && grep -F 'command -v curl' kit/spec.yaml && grep -c 'cat [^|]*credentials' tests/sandbox.sh = 0 (Task 1 verify, commit 99b07e5)"
        status: pass
    human_judgment: false
  - id: D2
    description: "FAB-02 sandbox half: inside the kit-created sandbox the script discovers /home/agent/.claude/.credentials.json (present) and renders '· Fable NN%/1w (countdown)' as the last segment of line 2 through the sandbox's proxy egress; cache file -rw------- owned by agent"
    requirement: FAB-02
    verification:
      - kind: e2e
        ref: "tests/out/sandbox/EVIDENCE.txt#INFO credentials file: present; #PASS Fable segment renders in sandbox (FAB-02, D-63); #INFO sandbox Fable render: 1s  line 2: … · Fable 90%/1w (1d:18h:32m); #INFO sandbox cache: -rw------- 1 agent agent 58"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plan-02 harness (with the Fable probes) is green under the sandbox toolchain (bash 5.3 / jq 1.8 / curl 8.18, proxy-mediated timeouts)"
    requirement: FAB-04
    verification:
      - kind: integration
        ref: "tests/out/sandbox/EVIDENCE.txt#PASS harness in sandbox: 220 checks, 0 failures; tail -1 tests/out/sandbox/run.log = '220 checks, 0 failures'"
        status: pass
    human_judgment: false
  - id: D4
    description: "PORT-01 / PORT-04 regression with the Fable segment in place: 8 fixture renders byte-identical host vs sandbox (kill switch exported by tests/render-fixtures.sh), installed-path renders identical, kit script byte-identical, statusLine merged and surviving stop/start"
    requirement: FAB-01
    verification:
      - kind: e2e
        ref: "tests/out/sandbox/EVIDENCE.txt#PASS PORT-01: host vs sandbox fixture renders byte-identical (8 fixtures); #PASS PORT-04 …; diff -r tests/out/host/repo tests/out/sandbox/repo (empty), 8 .out files each side; summary '12 checks, 0 failures'"
        status: pass
    human_judgment: false
  - id: D5
    description: "D-46: nothing under the host ~/.claude created, modified, or re-pointed by the sandbox run; no tracked file changed by Task 3"
    verification:
      - kind: other
        ref: "before == after: /bin/ls -l ~/.claude/statusline.sh -> '-rwxr-xr-x@ 1 sv  staff  9800 Aug 22 18:58 /Users/sv/.claude/statusline.sh'; jq -c .statusLine ~/.claude/settings.json -> {\"type\":\"command\",\"command\":\"~/.claude/statusline.sh\",\"padding\":0,\"refreshInterval\":60}; git diff --quiet -- kit/files/home/.claude/statusline.sh tests/run.sh tests/sandbox.sh kit/spec.yaml = 0; git status --porcelain tests/out empty"
        status: pass
    human_judgment: false
  - id: D6
    description: "End-of-phase live check (roadmap SC1/SC2): a live claude session on the host and one in the kit sandbox both show the two-line status line with '· Fable NN%/1w (Nd:Nh:Nm)' last on line 2 (dim label, coloured number), rendering instantly on later messages; host ~/.claude/settings.json statusLine unchanged"
    requirement: FAB-02
    verification: []
    human_judgment: true
    rationale: "Visual comparison of a live Claude Code TUI in two environments (plan Task 3 <human-check>, human_verify_mode = end-of-phase). NOTE for the human: the host ~/.claude/statusline.sh is currently a stale regular-file copy of the pre-Phase-4 script — re-run the README `ln -sf` line BEFORE the host half, otherwise the host line 2 will not show the Fable segment (D-46 forbade the executor from fixing it)"

# Metrics
duration: 1h 20m
completed: 2026-08-22
status: complete
---

# Phase 04 Plan 03: Live sandbox evidence for the Fable segment (FAB-02 sandbox half) Summary

**`tests/sandbox.sh` §5.13 now probes the kit sandbox for `/home/agent/.claude/.credentials.json` (presence only) and renders `tests/fixtures/full.json` through the kit-delivered script with the Fable path live; the fresh-sandbox run recorded `12 checks, 0 failures` — credentials PRESENT, `· Fable 90%/1w (1d:18h:32m)` rendered inside the sandbox in 1 s from the sandbox's own proxy-scoped token, the 220-check harness green under the sandbox toolchain, 8/8 fixtures byte-identical host vs sandbox, cache `-rw-------` owned by `agent`; the kit's D-33 guard now also covers curl; the host `~/.claude` was not touched.**

## Performance

- **Duration:** ~1h 20m wall clock (Task 1 dispatched after 04-04's metadata commit at 22:08Z; includes the Task 2 Docker Desktop human-action gate; Task 3 itself took ~2 min — the sandbox run was 27 s)
- **Started:** ~2026-08-22T22:09Z (Task 1); continuation for Task 3 at 2026-08-22T23:27:09Z
- **Completed:** 2026-08-22T23:28:23Z
- **Tasks:** 3 (2 auto + 1 human-action checkpoint)
- **Files modified:** 2 tracked (tests/sandbox.sh, kit/spec.yaml — Task 1); Task 3 wrote only gitignored evidence under tests/out/

## Accomplishments

- `tests/sandbox.sh` §5.13 (Task 1, `99b07e5`): `INFO credentials file: present|absent (presence only — never read)`; live render via `sx "$NAME" /bin/bash -c "unset STATUSLINE_NO_FABLE; /bin/bash /home/agent/.claude/statusline.sh < $PWD/tests/fixtures/full.json"` (no URL/credentials/cache override, so the script's own discovery + `HTTPS_PROXY` egress are exercised); ANSI stripped locally; one counted check per branch with fixed names; `INFO sandbox Fable render: <s>s  line 2: …` and `INFO sandbox cache: <ls -l>`; header comment lists the Fable probe; `ESC`/`strip_ansi` helpers copied from tests/run.sh
- `kit/spec.yaml` (Task 1): D-33 guard `command -v jq && command -v git && command -v curl || apt-get … jq git curl`, description names curl; `sbx kit validate kit` exits 0; nothing credential-related in the kit
- Task 2 (human-action, `gate="blocking-human"`): the user started Docker Desktop; the orchestrator and then this executor both verified `sbx ls` exits 0 outside the agent dev sandbox — the executor never started a host service
- Task 3 live run (fresh `statusline-kit-test`, 27 s wall clock): `12 checks, 0 failures`; **credentials branch observed: PRESENT** → `PASS Fable segment renders in sandbox (FAB-02, D-63)`; line 2 inside the sandbox: `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 90%/1w (1d:18h:32m)`; `PASS harness in sandbox: 220 checks, 0 failures` (> 126 — the plan-02 Fable probes, file:// fixtures and the proxy-mediated timeout probe all pass under bash 5.3 / jq 1.8 / curl 8.18); `PASS PORT-01 … (8 fixtures)`; `PASS PORT-04`; statusLine merged and surviving stop/start; cache `-rw------- 1 agent agent 58`
- Roadmap SC2 evidenced: the token is discovered from `~/.claude/.credentials.json` inside the kit sandbox and the Fable segment renders there — no kit change, no token ever read or printed by the harness

## Task Commits

Each task was committed atomically:

1. **Task 1: tests/sandbox.sh §5.13 — credentials presence + live in-sandbox Fable render probe; curl in the kit's install guard** - `99b07e5` (feat)
2. **Task 2: Start Docker Desktop so sandboxd is reachable for the live sandbox run** - human-action checkpoint, no commit (resolved by the user; `sbx ls` exits 0)
3. **Task 3: Live sandbox evidence run (tests/sandbox.sh) and the end-of-phase live-check hand-off** - no tracked file changed (tests/out/ is gitignored); its commit is the `docs(04-03)` metadata commit that lands this SUMMARY

**Plan metadata:** see the `docs(04-03): complete …` commit that lands this SUMMARY.

## Files Created/Modified

- `tests/sandbox.sh` - §5.13 Fable probe (presence + live render + cache mode), `ESC`/`strip_ansi` helpers, header comment (Task 1)
- `kit/spec.yaml` - curl added to the D-33 install guard and its apt fallback; description updated (Task 1)
- `tests/out/sandbox/EVIDENCE.txt`, `tests/out/sandbox/run.log`, `tests/out/sandbox/render.log`, `tests/out/{host,sandbox}/{repo,installed}/*.out` - gitignored evidence written by the run (Task 3)

## Decisions Made

- **Credentials branch observed: PRESENT.** The kit sandbox (created from the user's sbx configuration with the global `anthropic` OAuth secret) carries `/home/agent/.claude/.credentials.json`; the script found it and rendered the segment through the proxy. README's Docker sentence (plan 04-04) already states "renders when the file exists via the sbx `anthropic` secret or `/login`, hidden otherwise" — the observation matches; no follow-up for README.
- **Host `~/.claude/statusline.sh` is a stale copy, not fixed here.** `/bin/ls -l` shows `-rwxr-xr-x@ … 9800 Aug 22 18:58 /Users/sv/.claude/statusline.sh` — a regular file (not a symlink), `cmp` differs from the 21023-byte `kit/files/home/.claude/statusline.sh` (the Phase 4 script). D-46 forbids the executor from creating, modifying or re-pointing anything under the host `~/.claude`, so it was left as is and is flagged for the human live check (the plan's `<human-check>` already says "re-run the README `ln -sf` line if it is a stale copy").
- **Run executed in the foreground** with the maximum tool timeout rather than background + poll: the claude-code image was already present, so the whole run took 27 s (Phase 3: 21 s).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **sandboxd checkpoint (Task 2):** the Task 2 `checkpoint:human-action` (`gate="blocking-human"`) was returned after Task 1; the user started Docker Desktop. This continuation re-asserted the Task 3 precondition before any sandbox work: `sbx ls` → exit 0 ("No sandboxes found." — the Phase 3 sandbox had been removed meanwhile), `git diff --quiet -- kit/files/home/.claude/statusline.sh` → exit 0.
- **`sbx` unusable inside the agent dev sandbox:** `sbx ls`, `tests/sandbox.sh` and the D-46 listings were run with the sandbox override (`dangerouslyDisableSandbox: true`) per the established project workaround; nothing outside the repo's `tests/out/` was written.
- **Interactive `ls` alias breaks on globs:** `/bin/ls` used for the `*.out` counts and the D-46 listing (known host quirk).

## Authentication Gates

None in Task 3. (Commit signing via 1Password is exercised by the metadata commit; see the final output for its hash.)

## Live evidence (tests/out/sandbox/EVIDENCE.txt, pasted verbatim)

```text
INFO sandbox.sh start: 2026-08-22T23:27:21Z repo=/Users/sv/github/claude-code-status-line kit=/Users/sv/github/claude-code-status-line/kit name=statusline-kit-test
PASS kit validate: sbx kit validate kit
PASS sandbox created with kit: statusline-kit-test
PASS statusLine merged after first start (D-32/D-34)
INFO observed .statusLine: {"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}
INFO settings.json keys: ["alwaysThinkingEnabled","bypassPermissionsModeAccepted","defaultMode","skipDangerousModePermissionPrompt","statusLine","themeId"]
PASS kit script present and executable: /home/agent/.claude/statusline.sh
PASS kit script byte-identical to repo file
INFO sbx exec user: agent HOME=/home/agent
PASS harness in sandbox: 220 checks, 0 failures
PASS render dump in sandbox: installed == repo (PORT-04 sandbox half)
PASS render dump on host (PORT-04 host half)
PASS PORT-01: host vs sandbox fixture renders byte-identical (8 fixtures)
PASS PORT-04: host vs sandbox installed-path renders byte-identical
INFO canary written before stop: 1
PASS statusLine survives stop/start (D-32)
INFO restart: canary survived — other keys preserved across stop/start; statusLine re-merged idempotently
FAIL sbx kit add delivers kit files + startup merge to an existing sandbox (D-37a) [probe, not counted — README documents sbx rm + recreate]
INFO kit-add probe: sbx kit add rc=1 output: ERROR: kit "claude-code-status-line" declares setup.startup, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via `sbx rm` + `sbx create --kit` to use this kit
INFO probes (not counted): kit-add=FAIL (D-37a)
INFO credentials file: present (presence only — never read)
INFO sandbox Fable render: 1s  line 2: 10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 90%/1w (1d:18h:32m)
PASS Fable segment renders in sandbox (FAB-02, D-63)
INFO sandbox cache: -rw------- 1 agent agent 58 Aug 22 23:27 /home/agent/.claude/statusline-usage-cache.json
INFO sandbox statusline-kit-test kept for the live check: sbx run --name statusline-kit-test  (remove with: sbx rm -f statusline-kit-test)
12 checks, 0 failures
```

Supporting facts (all re-run after the sandbox run):
- Plan `<verify><automated>` command executed verbatim → exit 0.
- **Credentials branch observed: present → rendered.** `INFO sandbox Fable render:` line 2 ends with `· Fable 90%/1w (1d:18h:32m)`; render took 1 s (cold fetch through `HTTPS_PROXY`); cache file `-rw------- 1 agent agent 58 …/statusline-usage-cache.json` (0600, agent-owned, in the sandbox's home — not the host's).
- `tail -1 tests/out/sandbox/run.log` → `220 checks, 0 failures` (host harness after the run: `220 checks, 0 failures`).
- `diff -r tests/out/host/repo tests/out/sandbox/repo` → empty; `/bin/ls … /repo/*.out | wc -l` → 8 on both sides.
- `sbx kit add` probe (D-37a, informational, not counted): still FAIL on sbx v0.39.0 — README's recreate sentence stands.
- `git status --porcelain tests/out` → empty (gitignored); `git diff --quiet -- kit/files/home/.claude/statusline.sh tests/run.sh tests/sandbox.sh kit/spec.yaml` → exit 0 (the run changed no tracked file; README.md and the planning docs were not touched by this plan).
- **D-46 before == after:** `/bin/ls -l ~/.claude/statusline.sh` → `-rwxr-xr-x@ 1 sv  staff  9800 Aug 22 18:58 /Users/sv/.claude/statusline.sh`; `jq -c .statusLine ~/.claude/settings.json` → `{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}` — identical before and after the run (nothing under the host `~/.claude` created, modified, or re-pointed).
- Sandboxes after the run (`sbx ls`): `statusline-kit-test  claude  running  /Users/sv/github/claude-code-status-line` — **left running for the live check**; `statusline-kit-test-add` removed by the script; no other sandbox touched.

## End-of-phase live check (human — hand-off, human_verify_mode = end-of-phase)

Coverage D6; no checkpoint task — the verifier harvests this.

**Host (prerequisite first):** `ls -l ~/.claude/statusline.sh` currently shows a stale 9800-byte regular file (pre-Phase-4 copy, not a symlink). Re-run the README install line so it points at this repo's `kit/files/home/.claude/statusline.sh` (the `ln -sf` line in README "Install"), then start `claude` in this repo, send one short message, and look at line 2: it must end with `· Fable NN%/1w (Nd:Nh:Nm)` — dim `Fable`, the number green/yellow/red by threshold, `/1w` and the countdown plain — and keep rendering instantly on later messages (cached; one fetch per 5 minutes). The host `~/.claude/settings.json` statusLine object must stay `{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}`.

**Sandbox:** with Docker Desktop running, `sbx run --name statusline-kit-test` (the sandbox this run left in place and running; recreate with `sbx run claude . --kit "$PWD/kit"` if it is gone), accept any trust prompt, send one short message, and confirm the same Fable segment appears at the end of line 2 (the sandbox has its own `~/.claude/.credentials.json` — observed present in this run) — or, if the sandbox has no credentials, that line 2 renders normally without it.

**Expected:** both environments show the two-line status line with the Fable segment last on line 2 (same layout, glyphs, colours as the rest), no lag on subsequent renders, no blank line; the host settings unchanged.

## User Setup Required

None - no external service configuration required. (Docker Desktop must be running for `tests/sandbox.sh` and the sandbox live check; the host symlink refresh above is a one-line README step the user performs.)

## Next Phase Readiness

- Phase 4 plans 01–04 all have SUMMARYs; FAB-01/FAB-02/FAB-04 evidenced here (sandbox half), FAB-03 by plan 02. Ready for `/gsd-verify-work 04` — the verifier has EVIDENCE.txt (above), `tests/run.sh` (220/0 host and sandbox), `tests/sandbox.sh` (12/0), and the two-environment live-check script.
- Follow-up for the verifier/human: refresh the host `~/.claude/statusline.sh` symlink before the host live check (stale copy observed; D-46 kept the executor from touching it).
- Known sbx limitation unchanged: `sbx kit add` for kits with `setup.startup` (probe re-answers D-37a on every run).

---
*Phase: 04-fable-weekly-f-segment*
*Completed: 2026-08-22*

## Self-Check: PASSED

- Files: tests/sandbox.sh, kit/spec.yaml (tracked, committed in 99b07e5), tests/out/sandbox/EVIDENCE.txt (gitignored, exists), this SUMMARY — all present
- Commit 99b07e5 present in `git log`; Task 3 changed no tracked file by design
- Task 3 acceptance criteria re-run after the run: summary line `12 checks, 0 failures`; all required PASS/INFO lines present (sandbox created, harness 220 > 126, render dump sandbox, PORT-01 8 fixtures, credentials present, exactly one Fable PASS, render line ends with `· Fable 90%/1w (1d:18h:32m)`, cache `-rw-------`); `diff -r` empty with 8 `.out` files each side; `git status --porcelain tests/out` empty; tracked files unchanged; D-46 before == after; plan `<automated>` verify exit 0
