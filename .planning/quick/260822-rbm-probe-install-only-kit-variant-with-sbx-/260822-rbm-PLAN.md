---
phase: quick-260822-rbm
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/probe-kit-add.sh
autonomous: true
requirements: [PORT-04]
tags: [sbx, docker-sandbox, kit, kit-add, probe, bash-3.2, D-37a]

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "A re-runnable host script tests/probe-kit-add.sh builds a disposable install-only variant of the kit under tests/out/ (never under kit/), validates it with sbx kit validate, and answers Q-a (sbx kit add on an existing sandbox) and Q-b (install-time merge survives the create-time seed) with PASS/FAIL lines in an evidence file"
    - "Q-a and Q-b verdicts and a recommendation are recorded verbatim in the SUMMARY from a live run on sbx v0.39.0 (D-37a)"
    - "Only the two probe sandboxes statusline-kit-test-addonly and statusline-kit-test-installonly are ever created or removed; statusline-kit-test and every other sandbox are untouched"
    - "kit/spec.yaml (with its uncommitted user edit), kit/files/, README.md and tests/sandbox.sh are byte-for-byte unchanged and nothing under kit/ is committed"
  artifacts:
    - path: tests/probe-kit-add.sh
      provides: "bash 3.2-safe, BSD/GNU-neutral host orchestrator: --help / --build-only / --keep, scratch kit builder, Q-a + Q-b probes, EVIDENCE.txt writer, two-name cleanup trap"
    - path: tests/out/kit-add-probe/EVIDENCE.txt
      provides: "live PASS/FAIL/INFO lines incl. the INFO verdict line (gitignored; pasted verbatim into the SUMMARY)"
    - path: tests/out/kit-add-probe/kit-installonly/spec.yaml
      provides: "disposable install-only kit spec (setup.install only, distinct name claude-code-status-line-installonly) built by the script, never committed"
  key_links:
    - from: tests/probe-kit-add.sh
      to: kit/files/home/.claude/statusline.sh
      via: "read-only cp into the scratch kit's files/home/.claude/ (mode 0755); cmp inside the sandbox proves byte identity"
    - from: tests/out/kit-add-probe/kit-installonly/spec.yaml
      to: /home/agent/.claude/settings.json (inside the probe sandboxes)
      via: "second setup.install string command running the exact jq merge from HEAD kit/spec.yaml at create/recreate time"
    - from: tests/probe-kit-add.sh
      to: sbx kit add statusline-kit-test-addonly <scratch-kit>
      via: "rc + verbatim output recorded, then 120 s poll with jq -cS .statusLine and test -x + cmp"
---

<objective>
Probe whether an install-only variant of the sbx mixin kit (no `setup.startup`; the jq `statusLine` merge moved into a second `setup.install` command) (a) can be applied to an EXISTING sandbox with `sbx kit add` on sbx v0.39.0 and (b) survives the platform's late create-time seed of `/home/agent/.claude/settings.json`, and record both answers as live evidence so a follow-up task can decide whether to switch `kit/spec.yaml` to install-only and restore the README `sbx kit add` sentence (D-37a).

Purpose: Phase 3 proved sbx v0.39.0 refuses `sbx kit add` for any kit declaring `setup.startup` (observed: `kit "claude-code-status-line" declares setup.startup, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via sbx rm + sbx create --kit to use this kit`). Docker's own contrib statusline kit merges at install time only, which MAY survive the seed (MEDIUM confidence, unverified) and would unlock `sbx kit add`. Two unverified claims need a live answer, not more reading.

Output: `tests/probe-kit-add.sh` (new, committed, re-runnable on future sbx bumps); `tests/out/kit-add-probe/EVIDENCE.txt` (gitignored) pasted verbatim into the SUMMARY with the Q-a / Q-b verdicts and the recommendation. NO change to `kit/`, `README.md`, or `tests/sandbox.sh`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@tests/sandbox.sh
@.planning/phases/03-install-dual-environment-validation/03-03-SUMMARY.md

Established facts (do NOT re-research):
- sbx v0.39.0; `sbx kit add SANDBOX REFERENCE` (local dir accepted, no confirmation flag; help text: "The sandbox's container is recreated with the new kit appended to its original kit list, preserving kit-owned volumes"). `sbx create --name NAME claude DIR [--kit DIR]` is the verified create form (tests/sandbox.sh 5.2). `sbx stop NAME`; `sbx exec NAME cmd` starts a stopped sandbox.
- Valid spec grammar on v0.39.0: `schemaVersion: "2"`, `kind: mixin`, `requires.agent: claude`, `setup.install[].command` is a STRING (multi-line `|` block OK) run as root at create; `setup.startup[].command` is a string array — the install-only variant must contain NO `setup.startup` key at all.
- The CURRENT kit spec must be read with `git show HEAD:kit/spec.yaml` — the working-tree `kit/spec.yaml` carries an unrelated uncommitted USER edit that must stay untouched and uncommitted.
- The engine does NOT re-seed settings.json on stop/start (Phase 3 canary survived); it DOES seed late at create time (keys observed: alwaysThinkingEnabled, bypassPermissionsModeAccepted, defaultMode, skipDangerousModePermissionPrompt, statusLine, themeId).
- Every `sbx` invocation from the executor's Bash tool MUST use `dangerouslyDisableSandbox: true` (the Claude Code command sandbox blocks the sandboxd unix socket — proven in 03-03). Commits may also need it (1Password commit signing) — see MEMORY.
- Hard constraints: sandbox names start with `statusline-kit-test`; remove ONLY `statusline-kit-test-addonly` and `statusline-kit-test-installonly`; never touch `statusline-kit-test` or any other sandbox; never the remove-everything form of `sbx rm`; the scratch kit is disposable and lives under gitignored `tests/out/`, never under `kit/`.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write tests/probe-kit-add.sh — scratch install-only kit builder + Q-a/Q-b probe orchestrator</name>
  <files>tests/probe-kit-add.sh</files>
  <read_first>
    - tests/sandbox.sh (copy its stage order, `emit` / `check_ok` / `sx` / `wait_statusline` helpers verbatim, its two-name cleanup discipline and its comment style)
    - `git show HEAD:kit/spec.yaml` (source of the D-33 install guard line and the exact jq merge program / chmod / chown lines to move into the install command — copy them character-for-character; do NOT open or edit the working-tree kit/spec.yaml)
    - .claude/CLAUDE.md "Bash 3.2 portability rules" table (the script is host-side: macOS bash 3.2 + BSD userland)
  </read_first>
  <action>
Create `tests/probe-kit-add.sh` (mode 0755, shebang `#!/bin/bash`, bash 3.2-safe, BSD/GNU-neutral per the CLAUDE.md portability table — no GNU-only date/stat/sed/readlink forms, no bash 4 builtins or parameter-expansion case operators). Model it on `tests/sandbox.sh` stage by stage; the orchestration stages are load-bearing in this order: (1) argument parsing, (2) preamble, (3) prechecks, (4) evidence dir + EXIT trap, (5) scratch kit build + validate, (6) Q-a, (7) Q-b, (8) verdicts + summary. Using the Write tool is fine for the script; the script itself may use a single-quoted heredoc to emit the scratch spec.

Header comment: purpose (D-37a install-only probe: Q-a = does `sbx kit add` land `files/` + an install-time statusLine merge on an existing sandbox; Q-b = does an install-time merge survive the create-time settings.json seed), usage, exit codes (0 = probe ran to completion and every infrastructure check passed — the Q-a/Q-b answers are in the `INFO verdict:` line and may be PASS or FAIL either way; 1 = an infrastructure check failed; 2 = usage error or sbx / sandboxd unavailable), safety (only the two script-owned names are ever removed; the remove-everything form of `sbx rm` is never used; nothing under `kit/`, `README.md` or the host `~/.claude` is written; the scratch kit and evidence live under gitignored `tests/out/`).

Stage 1 — args (before any cd/mkdir/sbx/trap): `--help|-h` prints usage and exits 0; `--keep` keeps the two probe sandboxes at exit (default: remove them); `--build-only` builds + validates the scratch kit, writes evidence, and exits WITHOUT creating any sandbox; any other `--flag` or any positional argument prints usage to stderr and exits 2 (names are fixed — no NAME argument, so the script can never be pointed at another sandbox).

Stage 2 — preamble: `cd "$(dirname "$0")/.." || exit 1`; `KIT_SRC=$PWD/kit`; `OUT=tests/out/kit-add-probe`; `SCRATCH=$PWD/$OUT/kit-installonly` (absolute — `sbx` resolves it on the host); `EVID=$OUT/EVIDENCE.txt`; `ADD_NAME=statusline-kit-test-addonly`; `INST_NAME=statusline-kit-test-installonly`; `EXPECT_SL` = the same sorted-key compact literal as tests/sandbox.sh (`{"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}`); `SBX_SL=/home/agent/.claude/statusline.sh`; `SBX_SETTINGS=/home/agent/.claude/settings.json`; `CHECKS=0 FAILS=0`; helpers `emit`, `check_ok`, `sx`, `wait_statusline` copied from tests/sandbox.sh; plus `wait_seed SANDBOX` (poll up to 120 x 1 s until `sx SANDBOX grep -q themeId "$SBX_SETTINGS"` succeeds; 0/1) and `script_ok SANDBOX` (0 iff `sx SANDBOX test -x "$SBX_SL"` AND `sx SANDBOX cmp -s "$SBX_SL" "$PWD/kit/files/home/.claude/statusline.sh"` — the workspace is bind-mounted at the same absolute path inside the sandbox, as tests/sandbox.sh 5.5 relies on).

Stage 3 — prechecks: `command -v sbx` else message + exit 2; unless `--build-only`, `sbx ls > /dev/null 2>&1` else message ("start Docker Desktop (or: sbx daemon start) and retry") + exit 2 — never start Docker from the script.

Stage 4 — `mkdir -p "$OUT"`, truncate `$EVID`; unless `--build-only` or `--keep`, install `trap 'sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true; sbx rm -f "$INST_NAME" > /dev/null 2>&1 || true' EXIT` (exactly those two names, nothing else, ever). `emit "INFO probe-kit-add.sh start: <UTC timestamp via date -u +%Y-%m-%dT%H:%M:%SZ> repo=$PWD scratch=$SCRATCH sbx=<first line of sbx --version or sbx version, whichever one works — try both once with the sandbox override while writing; record the one that prints a version>"`.

Stage 5 — build the scratch kit: `rm -rf "$SCRATCH"` (fixed path under tests/out/), `mkdir -p "$SCRATCH/files/home/.claude"`, `cp "$KIT_SRC/files/home/.claude/statusline.sh" "$SCRATCH/files/home/.claude/statusline.sh"`, `chmod 0755` it. Write `$SCRATCH/spec.yaml` with EXACTLY this shape: a short leading comment saying it is a disposable install-only PROBE variant built by tests/probe-kit-add.sh (not the shipped kit); `schemaVersion: "2"`; `kind: mixin`; `name: claude-code-status-line-installonly` (distinct from the shipped kit's name so sbx never confuses the two); `version: "1.0.0"`; `displayName: Claude Code Status Line (install-only probe)`; a one-line `description`; `requires:` with `agent: claude`; `setup:` with ONLY an `install:` list of TWO entries and NO `startup:` key anywhere in the file (grep-gated below): entry 1 = the D-33 jq/git guard `command:` line and its `description:` copied verbatim from `git show HEAD:kit/spec.yaml`; entry 2 = `command: |` multi-line string (a sh script; GNU tools acceptable, it runs inside the Linux sandbox) doing, in order: `set -e`; `H=/home/agent`; `S=$H/.claude/settings.json`; `mkdir -p "$H/.claude"`; write a one-line marker file `$H/.claude/.installonly-probe` containing `script_at_install=yes|no install_user=<id -un>` (yes iff `$H/.claude/statusline.sh` already exists when install runs — this tells the follow-up whether `files/` lands before or after `setup.install`); `[ -f "$S" ] || printf '{}\n' > "$S"`; `tmp=$(mktemp "$H/.claude/.settings.XXXXXX")`; the `jq -n 'try (input) catch {} | ... .statusLine = {type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}' "$S" > "$tmp"` program copied character-for-character from the HEAD spec's startup command; `mv "$tmp" "$S"`; `chmod 0755 "$H/.claude/statusline.sh" || true`; `chown agent:agent "$H/.claude" "$S" || true`; `chown agent:agent "$H/.claude/statusline.sh" || true` (every chmod/chown tolerant so a files-after-install ordering or a non-root install user can never abort `sbx create` — the end-state checks and the INFO `ls -ln` line below surface such cases as evidence instead); `description: Install-time statusLine merge (D-37a install-only probe)`. No `user:` key on either install entry (install runs as root per the HEAD spec's apt-get guard). Then `sbx kit validate "$SCRATCH" > /dev/null 2>&1` → `check_ok "kit validate: sbx kit validate <scratch install-only kit>"` (COUNTED); on failure emit the validate output as INFO, the summary line, exit 1. If `--build-only`: `emit "INFO build-only: scratch kit at $SCRATCH"`, summary line, exit.

Stage 6 — Q-a (kit add on an existing sandbox): `sbx rm -f "$ADD_NAME"` (ours; start clean) → `CREATE_OUT=$(sbx create --name "$ADD_NAME" claude "$PWD" 2>&1)` (NO --kit) → `check_ok "Q-a: sandbox created WITHOUT kit: $ADD_NAME"` (COUNTED; on failure emit the output, set QA=FAIL with reason "not run", skip to Stage 7). Baseline: `sx "$ADD_NAME" test -e "$SBX_SL"` must FAIL and `sx "$ADD_NAME" jq -c .statusLine "$SBX_SETTINGS" 2>/dev/null` must be `null` or empty → `check_ok "Q-a baseline: no kit script and no statusLine before kit add"` (COUNTED); emit `INFO Q-a baseline: script=<present|absent> statusLine=<value or <none>> seed(themeId)=<yes|no>`. Then `ADD_OUT=$(sbx kit add "$ADD_NAME" "$SCRATCH" 2>&1); rc_a=$?` → `emit "INFO Q-a: sbx kit add rc=$rc_a output: $ADD_OUT"` (verbatim, multi-line allowed). If rc_a=0: `wait_statusline "$ADD_NAME"` → ra_sl; `emit "INFO Q-a: .statusLine after kit add: ${WAIT_GOT:-<none>}"`; `emit "INFO Q-a: settings.json keys after kit add: $(sx ... jq -c keys ...)"`; `script_ok "$ADD_NAME"` → ra_f; `emit "INFO Q-a: kit script after kit add: $(sx "$ADD_NAME" ls -ln "$SBX_SL" 2>&1)"`; `emit "INFO Q-a: marker: $(sx "$ADD_NAME" cat /home/agent/.claude/.installonly-probe 2>&1)"`. QA=PASS iff rc_a=0 AND ra_sl=0 AND ra_f=0; otherwise FAIL. Emit exactly one of `PASS Q-a: sbx kit add lands files/ + install-time statusLine merge on an existing sandbox (D-37a) [probe, not counted]` / `FAIL Q-a: sbx kit add lands files/ + install-time statusLine merge on an existing sandbox (D-37a) [probe, not counted] reason=<kit-add-rc|no-merge|no-script|not-run>`.

Stage 7 — Q-b (install-time merge vs the create-time seed): `sbx rm -f "$INST_NAME"` → `INST_CREATE=$(sbx create --name "$INST_NAME" claude "$PWD" --kit "$SCRATCH" 2>&1); rc_c=$?` → `emit "INFO Q-b: sbx create --kit rc=$rc_c"` plus the output as INFO when rc_c != 0 (a create failure is a Q-b answer, NOT counted — the evidence decides). If rc_c=0: `wait_seed "$INST_NAME"` → rb_seed (emit `INFO Q-b: platform seed (themeId) observed: yes|no`); THEN `wait_statusline "$INST_NAME"` → rb_sl (evaluated AFTER the seed was seen, so a match proves the merge coexists with the seed); emit `INFO Q-b: observed .statusLine after first start: ${WAIT_GOT:-<none>}` and `INFO Q-b: settings.json keys: ...`; `script_ok "$INST_NAME"` → rb_f; emit `INFO Q-b: marker: <cat .installonly-probe>` and `INFO Q-b: ownership: <ls -ln settings.json statusline.sh>`. Restart: `sbx stop "$INST_NAME" > /dev/null 2>&1`; `wait_statusline "$INST_NAME"` (sbx exec restarts it) → rb_rs; emit `INFO Q-b: .statusLine after stop/start: ${WAIT_GOT:-<none>}`. QB=PASS iff rc_c=0 AND rb_seed=0 AND rb_sl=0 AND rb_f=0 AND rb_rs=0. Emit exactly one of `PASS Q-b: install-time statusLine merge survives the create-time seed and stop/start (D-37a) [probe, not counted]` / `FAIL Q-b: install-time statusLine merge survives the create-time seed and stop/start (D-37a) [probe, not counted] reason=<create-rc|no-seed|no-merge|no-script|lost-on-restart>`.

Stage 8 — `emit "INFO verdict: Q-a=$QA Q-b=$QB (D-37a install-only probe, sbx <version>)"`; then `emit "INFO recommendation: ..."` = when both PASS: "switch kit/spec.yaml to install-only in a FOLLOW-UP task and restore the README sbx kit add sentence"; otherwise: "keep the startup-based kit; README unchanged". With `--keep`: emit the two names and the exact `sbx rm -f <name>` commands to remove them; otherwise the trap removes them. LAST line: `emit "$CHECKS checks, $FAILS failures"`; exit `[ "$FAILS" -eq 0 ]`.

Static verification you run yourself before committing (the daemon is not needed for these): `/bin/bash -n`, `--help` exits 0 and mentions Usage, `--bogus` exits 2, `shellcheck --shell=bash tests/probe-kit-add.sh` if shellcheck is installed (treat warnings seriously; SC2016 disables are acceptable where `$` must expand inside the sandbox, as tests/sandbox.sh does). Then run `/bin/bash tests/probe-kit-add.sh --build-only` with the Bash tool's `dangerouslyDisableSandbox: true` (sbx socket) and check the built spec with the greps in the acceptance criteria. Commit with message `feat(quick-260822-rbm): add tests/probe-kit-add.sh — install-only kit variant probe (D-37a)` (commit may need the sandbox override for 1Password signing). Do NOT stage anything under `kit/`, `README.md`, `tests/sandbox.sh`, or `tests/out/`.
  </action>
  <verify>
    <automated>test -x tests/probe-kit-add.sh && /bin/bash -n tests/probe-kit-add.sh && /bin/bash tests/probe-kit-add.sh --help | grep -qi usage && { /bin/bash tests/probe-kit-add.sh --bogus >/dev/null 2>&1; [ $? -eq 2 ]; } && [ "$(grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -o 'statusline-kit-test[-a-z]*' | sort -u | tr '\n' ' ')" = "statusline-kit-test-addonly statusline-kit-test-installonly " ] && [ "$(grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep 'sbx rm' | grep -vc 'ADD_NAME\|INST_NAME')" -eq 0 ] && [ "$(grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -c -- '--all')" -eq 0 ] && [ "$(grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -cE 'date -d|readlink -f|sed -i|mapfile|declare -A')" -eq 0 ] && [ "$(git status --short kit/ README.md tests/sandbox.sh)" = " M kit/spec.yaml" ] && echo TASK1-STATIC-OK</automated>
  </verify>
  <acceptance_criteria>
    - `test -x tests/probe-kit-add.sh`; `/bin/bash -n tests/probe-kit-add.sh` exits 0; first line is `#!/bin/bash`
    - `/bin/bash tests/probe-kit-add.sh --help` exits 0 and prints a Usage line BEFORE any sbx call; `--bogus` and any positional argument exit 2
    - Stage order by line number: the `--help` case < the `sbx ls` precheck < the `trap` line < the first `sbx create`; `sbx kit validate` appears after the trap and before the first `sbx create`
    - `grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -o 'statusline-kit-test[-a-z]*' | sort -u` prints exactly two lines: `statusline-kit-test-addonly` and `statusline-kit-test-installonly` (the bare primary name never appears outside comments)
    - Every non-comment `sbx rm` line references `"$ADD_NAME"` or `"$INST_NAME"`; `grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -c -- '--all'` = 0
    - `grep -v '^[[:space:]]*#' tests/probe-kit-add.sh | grep -cE 'date -d|readlink -f|sed -i|mapfile|declare -A'` = 0 (bash 3.2 / BSD-GNU neutral)
    - After `/bin/bash tests/probe-kit-add.sh --build-only` (run with the sandbox override) exits 0, the built spec has no startup section: `grep -c '^  startup:' tests/out/kit-add-probe/kit-installonly/spec.yaml` = 0
    - The built spec carries the expected positive markers: `grep -c '^  install:' tests/out/kit-add-probe/kit-installonly/spec.yaml` = 1; `grep -c '^    - command' ...spec.yaml` = 2; `grep -c 'name: claude-code-status-line-installonly' ...spec.yaml` = 1; `grep -c 'refreshInterval:60' ...spec.yaml` = 1; `grep -c 'kind: mixin' ...spec.yaml` = 1; `grep -c '^  agent: claude' ...spec.yaml` = 1
    - After `--build-only`: `test -x tests/out/kit-add-probe/kit-installonly/files/home/.claude/statusline.sh && cmp -s tests/out/kit-add-probe/kit-installonly/files/home/.claude/statusline.sh kit/files/home/.claude/statusline.sh`; `grep -c '^PASS kit validate' tests/out/kit-add-probe/EVIDENCE.txt` = 1; `tail -n 1 tests/out/kit-add-probe/EVIDENCE.txt` matches `^[0-9]+ checks, 0 failures$`; `sbx ls` does NOT list `statusline-kit-test-addonly` or `statusline-kit-test-installonly`
    - `git status --short kit/ README.md tests/sandbox.sh` prints exactly ` M kit/spec.yaml` (unchanged before/after); `git diff --cached --name-only` at commit time lists only `tests/probe-kit-add.sh`
    - Committed as `feat(quick-260822-rbm): ...`
  </acceptance_criteria>
  <done>`tests/probe-kit-add.sh` exists, is executable, passes the static gates above, builds and `sbx kit validate`s the scratch install-only kit in `--build-only` mode with `1 checks, 0 failures`, names only its two probe sandboxes, and is committed alone.</done>
</task>

<task type="auto">
  <name>Task 2: Run the live probe on sbx v0.39.0, record Q-a / Q-b verdicts + recommendation as verbatim evidence</name>
  <files>tests/probe-kit-add.sh</files>
  <precondition>`sbx ls` exits 0 on the host (Docker Desktop / sandboxd reachable — it was reachable when this task was planned; if it is not, return a `checkpoint:human-action` asking the user to start Docker Desktop, exactly as 03-03 Task 2 did, then re-assert) and `sbx ls` lists `statusline-kit-test` (the Phase 3 sandbox that must survive this task untouched — record its presence before and after).</precondition>
  <action>
All `sbx` and `tests/probe-kit-add.sh` invocations in this task go through the Bash tool with `dangerouslyDisableSandbox: true` (the Claude Code command sandbox blocks the sandboxd unix socket); use `/bin/ls` if the shell `ls` alias is broken (03-03 note).

1. Record the pre-state: `sbx ls` (full output) and `git status --short kit/ README.md tests/sandbox.sh` (must be exactly ` M kit/spec.yaml`); `md5 -q` (macOS) of `kit/spec.yaml` — keep the value to compare after the run.
2. Run `/bin/bash tests/probe-kit-add.sh > tests/out/kit-add-probe/run.log 2>&1; echo rc=$?` (default mode: the trap removes both probe sandboxes at exit). Expect several minutes worst-case (two creates, up to four 120 s polls, one stop/start).
3. Read `tests/out/kit-add-probe/EVIDENCE.txt` in full. Rules of interpretation: the `INFO verdict: Q-a=... Q-b=...` line is the answer; PASS and FAIL are BOTH valid outcomes of the probe — a FAIL verdict is evidence, not a bug. ONLY re-run after fixing the script when an INFRASTRUCTURE check failed (summary line `N checks, M failures` with M > 0 — kit validate, the no-kit create, or the Q-a baseline) or when the script itself misbehaved (e.g. a stale WAIT_GOT reported for the wrong sandbox, a poll that never ran, or a missing INFO line that the verdict depends on) — the same Rule-1 discipline as 03-03's two auto-fixes. If a second run is needed, keep run 1's lines in the SUMMARY as "Supporting facts" and record run 2 as the evidence. Every script fix is committed as `fix(quick-260822-rbm): ...` with the reason.
4. Sanity-read the INFO lines: the `sbx kit add rc=` line carries sbx's verbatim output (on v0.39.0 either a refusal text or success); the Q-b `platform seed (themeId) observed:` line, the `marker:` lines (`script_at_install=yes|no install_user=...`) and the `ownership:` line are the facts the follow-up decision needs — if any is missing or empty while its sandbox existed, treat that as a script bug (step 3).
5. Post-state: `sbx ls` must still list `statusline-kit-test` and must NOT list `statusline-kit-test-addonly` or `statusline-kit-test-installonly`; `git status --short kit/ README.md tests/sandbox.sh` is still exactly ` M kit/spec.yaml` and the `md5 -q kit/spec.yaml` value is unchanged; `git status --short` shows nothing under `tests/out/` (gitignored). Host `~/.claude` untouched (D-46): `/bin/ls -l ~/.claude/statusline.sh` and `jq -c .statusLine ~/.claude/settings.json` identical before and after.
6. SUMMARY (the quick workflow's `260822-rbm-SUMMARY.md`, `status: complete`): paste `tests/out/kit-add-probe/EVIDENCE.txt` VERBATIM in a fenced `text` block under `## Live evidence`; state the two verdicts on their own lines (`Q-a: PASS|FAIL — <one-sentence reason from the INFO lines>`, `Q-b: PASS|FAIL — <reason>`); state the recommendation exactly as the script printed it and expand it: both PASS → "follow-up task: switch kit/spec.yaml to install-only (move the merge into setup.install, drop setup.startup, keep the themeId-wait question answered by Q-b) and restore the README `sbx kit add` sentence — NOT done here"; any FAIL → "keep the startup-based kit, README unchanged"; also record the sbx version string, the run timestamp, the pre/post `sbx ls` lines, and the unchanged-kit/README/sandbox.sh proof from step 5. No code change is made to `kit/`, `README.md`, or `tests/sandbox.sh` regardless of the verdicts.
  </action>
  <verify>
    <automated>test -s tests/out/kit-add-probe/EVIDENCE.txt && grep -Eq '^INFO verdict: Q-a=(PASS|FAIL) Q-b=(PASS|FAIL)' tests/out/kit-add-probe/EVIDENCE.txt && grep -Eq '^(PASS|FAIL) Q-a: ' tests/out/kit-add-probe/EVIDENCE.txt && grep -Eq '^(PASS|FAIL) Q-b: ' tests/out/kit-add-probe/EVIDENCE.txt && grep -q '^INFO Q-a: sbx kit add rc=' tests/out/kit-add-probe/EVIDENCE.txt && grep -q '^INFO recommendation: ' tests/out/kit-add-probe/EVIDENCE.txt && tail -n 1 tests/out/kit-add-probe/EVIDENCE.txt | grep -Eq '^[0-9]+ checks, 0 failures$' && [ "$(git status --short kit/ README.md tests/sandbox.sh)" = " M kit/spec.yaml" ] && echo TASK2-EVIDENCE-OK</automated>
  </verify>
  <acceptance_criteria>
    - `tests/out/kit-add-probe/EVIDENCE.txt` exists; its last line matches `^[0-9]+ checks, 0 failures$` (infrastructure checks all passed — the Q-a/Q-b verdicts themselves may be PASS or FAIL)
    - EVIDENCE.txt contains exactly one `^(PASS|FAIL) Q-a: ` line and exactly one `^(PASS|FAIL) Q-b: ` line, one `^INFO verdict: Q-a=(PASS|FAIL) Q-b=(PASS|FAIL)` line and one `^INFO recommendation: ` line whose branch matches the verdicts (both PASS → the switch-in-a-follow-up text; otherwise the keep-startup text)
    - EVIDENCE.txt contains `^INFO Q-a: sbx kit add rc=` with sbx's verbatim output; when Q-a create succeeded it also contains `^INFO Q-a baseline: script=absent`; when the Q-b create succeeded it contains `^INFO Q-b: platform seed (themeId) observed: (yes|no)`, `^INFO Q-b: observed .statusLine after first start: `, `^INFO Q-b: marker: script_at_install=(yes|no) install_user=`, `^INFO Q-b: ownership: `, and `^INFO Q-b: .statusLine after stop/start: `
    - `sbx ls` after the run lists `statusline-kit-test` and lists neither `statusline-kit-test-addonly` nor `statusline-kit-test-installonly`; no sandbox other than those two was created, stopped, or removed
    - `git status --short kit/ README.md tests/sandbox.sh` = ` M kit/spec.yaml` before and after; `md5 -q kit/spec.yaml` unchanged; `git log --oneline -5 -- kit/ README.md tests/sandbox.sh` shows no new commit; nothing under `tests/out/` tracked
    - Host `~/.claude/statusline.sh` listing and `jq -c .statusLine ~/.claude/settings.json` identical before and after (D-46)
    - SUMMARY carries the full EVIDENCE.txt verbatim, the two verdict lines with reasons, the recommendation, sbx version, pre/post `sbx ls`, and the unchanged-files proof; any script fix made during the run is committed as `fix(quick-260822-rbm): ...`
  </acceptance_criteria>
  <done>Live evidence from sbx v0.39.0 answers Q-a and Q-b with PASS/FAIL lines and an `INFO verdict:` line, the recommendation follows the verdicts, both probe sandboxes are gone, `statusline-kit-test` and everything under `kit/`, `README.md`, `tests/sandbox.sh`, and the host `~/.claude` are untouched, and the SUMMARY reproduces the evidence verbatim.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| host script → sbx daemon | `sbx create/kit add/stop/rm` act on the user's sandbox inventory; the wrong name removes a sandbox the user keeps |
| scratch kit → sandbox `/home/agent/.claude` | install command runs as root inside the probe sandboxes only |
| repo working tree | `kit/spec.yaml` holds an uncommitted user edit; `tests/out/` is gitignored |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-rbm-01 | Denial of Service | `sbx rm -f` in tests/probe-kit-add.sh | high | mitigate | fixed literal names `statusline-kit-test-addonly` / `statusline-kit-test-installonly` only, no NAME argument, every `sbx rm` line grep-gated to `$ADD_NAME`/`$INST_NAME`, remove-everything form grep-gated absent; `sbx ls` before/after proves `statusline-kit-test` survives |
| T-quick-rbm-02 | Tampering | kit/spec.yaml, kit/files/, README.md, tests/sandbox.sh | medium | mitigate | scratch kit built under gitignored `tests/out/kit-add-probe/`; HEAD spec read via `git show`; `git status --short kit/ README.md tests/sandbox.sh` == ` M kit/spec.yaml` and `md5 -q kit/spec.yaml` unchanged gate both tasks; only `tests/probe-kit-add.sh` staged |
| T-quick-rbm-03 | Tampering | host `~/.claude` (D-46) | medium | mitigate | the script writes only under `tests/out/` and inside the probe sandboxes; `/bin/ls -l ~/.claude/statusline.sh` + `jq -c .statusLine ~/.claude/settings.json` before == after |
| T-quick-rbm-04 | Information Disclosure | EVIDENCE.txt / SUMMARY | low | accept | evidence contains sandbox paths, settings keys and sbx output only — no tokens or credentials are read or printed (settings.json keys listed via `jq -c keys`, never values other than `.statusLine`) |
| T-quick-rbm-05 | Elevation of Privilege | root install command inside the probe sandboxes | low | accept | disposable sandboxes removed at exit; command is the same merge the shipped kit already runs as root at startup; tolerant chmod/chown limited to `/home/agent/.claude` paths |
| T-quick-rbm-SC | Tampering | package installs | low | accept | no npm/pip/cargo installs; the kit's apt-get guard is a verbatim copy of the shipped D-33 line and is a no-op on the claude-code base image |
</threat_model>

<verification>
- Task 1 static gates (no daemon): exec bit, `bash -n`, `--help`/`--bogus` semantics, stage ordering, two-names-only, portability grep, unchanged `kit/`/README/sandbox.sh; `--build-only` proves the scratch spec is grammatically valid on sbx v0.39.0 (`PASS kit validate`) with no `startup:` key and two install commands.
- Task 2 live gates: EVIDENCE.txt summary line `N checks, 0 failures`, one Q-a and one Q-b PASS/FAIL line, the `INFO verdict:` and `INFO recommendation:` lines, the verbatim `sbx kit add rc=` line; `sbx ls` post-state; D-46 and unchanged-files proofs; SUMMARY carries the evidence verbatim.
</verification>

<success_criteria>
- `tests/probe-kit-add.sh` committed (feat), re-runnable on future sbx bumps, bash 3.2 / BSD-GNU neutral, safe (two fixed names, no remove-everything form).
- Live run on sbx v0.39.0 recorded: Q-a verdict, Q-b verdict, recommendation — all three in EVIDENCE.txt and verbatim in the SUMMARY.
- Zero changes to `kit/` (user edit intact and uncommitted), `README.md`, `tests/sandbox.sh`, the host `~/.claude`, and the `statusline-kit-test` sandbox.
</success_criteria>

<output>
Create `.planning/quick/260822-rbm-probe-install-only-kit-variant-with-sbx-/260822-rbm-SUMMARY.md` (frontmatter `status: complete`) with: the two task commits, `## Live evidence` (EVIDENCE.txt verbatim in a fenced text block), `Q-a:` / `Q-b:` verdict lines with reasons, the recommendation (follow-up task vs keep), sbx version, pre/post `sbx ls`, the unchanged-files and D-46 proofs, and any deviations (script fixes) with their commits.
</output>
