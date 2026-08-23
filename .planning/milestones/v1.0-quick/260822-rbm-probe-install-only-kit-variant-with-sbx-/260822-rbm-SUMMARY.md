---
phase: quick-260822-rbm
plan: 01
subsystem: sandbox-kit
tags: [sbx, docker-sandbox, kit, kit-add, probe, bash-3.2, D-37a, evidence]
requires:
  - kit/spec.yaml (HEAD: D-33 install guard + D-32/D-34 startup merge — the text the probe variant moves into setup.install)
  - kit/files/home/.claude/statusline.sh (copied read-only into the scratch kit; cmp inside the sandbox proves identity)
  - tests/sandbox.sh (emit / check_ok / sx / wait_statusline helpers, stage order, two-name cleanup discipline)
  - sbx v0.39.0 + reachable sandboxd (Docker Desktop) on the macOS host
provides:
  - tests/probe-kit-add.sh — re-runnable D-37a install-only probe (--help / --build-only / --keep), builds + validates a disposable install-only kit under gitignored tests/out/, answers Q-a and Q-b with PASS/FAIL + INFO verdict lines
  - Live evidence on sbx v0.39.0 (below, verbatim): Q-a=FAIL (sbx kit add refuses kits that declare files), Q-b=PASS (install-time merge survives the create-time seed and stop/start)
affects:
  - D-37a follow-up decision (resolved: keep the startup-based kit; README sbx rm + recreate sentence stands)
tech-stack:
  added: []
  patterns:
    - "Disposable scratch kit under gitignored tests/out/ with a distinct kit name (claude-code-status-line-installonly) so probes never touch kit/ or confuse sbx"
    - "Fixed, hard-coded sandbox names (no NAME argument) + grep-gated sbx rm lines — the script cannot be pointed at a foreign sandbox"
    - "Probe verdict lines tagged [probe, not counted]; the summary line certifies infrastructure only, the INFO verdict line carries the answer"
key-files:
  created:
    - tests/probe-kit-add.sh
    - tests/out/kit-add-probe/EVIDENCE.txt (gitignored; verbatim below)
    - tests/out/kit-add-probe/kit-installonly/spec.yaml (gitignored scratch kit, rebuilt on every run)
  modified: []
decisions:
  - "D-37a closed by live evidence: sbx v0.39.0 `sbx kit add` refuses this kit even without setup.startup — the refusal now names `files` (\"declares files, which the kit-add recreate flow does not yet apply\"). An install-only kit shape cannot unlock kit add on v0.39.0; kit/spec.yaml stays startup-based and the README keeps the sbx rm + recreate route"
  - "Q-b evidence for a future sbx bump: an install-time statusLine merge DOES coexist with the platform's late settings.json seed and survives stop/start; files/ lands BEFORE setup.install (marker script_at_install=yes, install_user=root); settings.json and statusline.sh end up owned by 1000:1000 (agent). So the only blocker for install-only is the kit-add recreate flow itself, not the seed"
  - "Infra check names never start with the exact verdict prefix (`Q-a: ` / `Q-b: `) so the PASS/FAIL verdict line is unique and grep-able — fixed in 5f20baf"
metrics:
  duration: "~6 min (16:49:14Z → 16:55Z incl. two live runs of ~1 min each)"
  completed: 2026-08-22
  tasks: 2
  commits: 2
actuals:
  tokens: 3774
  tasks: 2
  commits: 2
status: complete
---

# Quick 260822-rbm: Probe install-only kit variant with sbx kit add Summary

**`tests/probe-kit-add.sh` built and validated a disposable install-only variant of the sbx kit on sbx v0.39.0 and answered D-37a live: Q-a=FAIL — `sbx kit add` refuses the kit because it declares `files` (not only `setup.startup`), so no kit shape that ships `statusline.sh` can be kit-added on v0.39.0; Q-b=PASS — an install-time `statusLine` merge survives the create-time `settings.json` seed and stop/start. Recommendation: keep the startup-based kit; README unchanged.**

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `6a4b3bf` | feat(quick-260822-rbm): add tests/probe-kit-add.sh — install-only kit variant probe (D-37a) |
| 2 (fix) | `5f20baf` | fix(quick-260822-rbm): evidence line hygiene — strip the 'sbx version: ' prefix, rename the Q-a create check |

Only `tests/probe-kit-add.sh` was staged in each commit. Nothing under `kit/`, `README.md`, `tests/sandbox.sh` or `tests/out/` was touched or committed.

## What was built

`tests/probe-kit-add.sh` (331 lines, 0755, `#!/bin/bash`, bash 3.2-safe, BSD/GNU-neutral, shellcheck clean) — eight load-bearing stages in this order: args (`--help` exits 0 before any sbx call; `--build-only`; `--keep`; any other flag or positional exits 2 — there is NO name argument) → preamble (helpers copied from tests/sandbox.sh plus `wait_seed` and `script_ok`) → prechecks (`command -v sbx`; `sbx ls` unless `--build-only`; never starts Docker) → evidence dir + EXIT trap removing exactly `statusline-kit-test-addonly` and `statusline-kit-test-installonly` → scratch kit build under `tests/out/kit-add-probe/kit-installonly/` (distinct name `claude-code-status-line-installonly`; `setup.install` only — entry 1 = the HEAD D-33 guard verbatim, entry 2 = the HEAD jq merge / chmod / chown moved to install time plus a `.installonly-probe` marker; no `startup:` key, grep-gated) + `sbx kit validate` (COUNTED) → Q-a (create WITHOUT kit, baseline, `sbx kit add`, poll, script cmp, marker) → Q-b (create WITH the scratch kit, `wait_seed`, then `wait_statusline`, keys, marker, ownership, stop/start) → verdict + recommendation + summary line.

Static gates (all green before commit): `bash -n`, `--help` prints Usage, `--bogus`/positional exit 2, stage order by line (help 57 < sbx ls 150 < trap 163 < kit validate 216 < first sbx create 235), non-comment sandbox names = exactly the two probe names, every `sbx rm` line references `$ADD_NAME`/`$INST_NAME`, no `--all`, no `date -d|readlink -f|sed -i|mapfile|declare -A`. `--build-only` run: `1 checks, 0 failures`, built spec greps: startup 0 / install 1 / commands 2 / installonly name 1 / refreshInterval:60 1 / kind: mixin 1 / agent: claude 1; scratch `statusline.sh` executable and `cmp`-identical to `kit/files/home/.claude/statusline.sh`.

## Live evidence

sbx version: `sbx version: v0.39.0 def8cb0523a77e757bdd6ef52b459fe374f3783e` (`sbx --version` is not a valid flag on v0.39.0 — the script records `sbx version`). Run timestamp: 2026-08-22T16:53:37Z (run 2 — the recorded evidence, produced by the script at `5f20baf`; default mode, trap removed both probe sandboxes at exit). `tests/out/kit-add-probe/EVIDENCE.txt` verbatim:

```text
INFO probe-kit-add.sh start: 2026-08-22T16:53:37Z repo=/Users/sv/github/claude-code-status-line scratch=/Users/sv/github/claude-code-status-line/tests/out/kit-add-probe/kit-installonly sbx=v0.39.0 def8cb0523a77e757bdd6ef52b459fe374f3783e
PASS kit validate: sbx kit validate <scratch install-only kit>
PASS Q-a create: sandbox created WITHOUT kit: statusline-kit-test-addonly
PASS Q-a baseline: no kit script and no statusLine before kit add
INFO Q-a baseline: script=absent statusLine=null seed(themeId)=yes
INFO Q-a: sbx kit add rc=1 output: ERROR: kit "claude-code-status-line-installonly" declares files, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via `sbx rm` + `sbx create --kit` to use this kit
FAIL Q-a: sbx kit add lands files/ + install-time statusLine merge on an existing sandbox (D-37a) [probe, not counted] reason=kit-add-rc
INFO Q-b: sbx create --kit rc=0
INFO Q-b: platform seed (themeId) observed: yes
INFO Q-b: observed .statusLine after first start: {"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}
INFO Q-b: settings.json keys: ["alwaysThinkingEnabled","bypassPermissionsModeAccepted","defaultMode","skipDangerousModePermissionPrompt","statusLine","themeId"]
INFO Q-b: marker: script_at_install=yes install_user=root
INFO Q-b: ownership: -rw------- 1 1000 1000  308 Aug 22 16:53 /home/agent/.claude/settings.json
-rwxr-xr-x 1 1000 1000 9800 Aug 22 16:53 /home/agent/.claude/statusline.sh
INFO Q-b: .statusLine after stop/start: {"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}
PASS Q-b: install-time statusLine merge survives the create-time seed and stop/start (D-37a) [probe, not counted]
INFO verdict: Q-a=FAIL Q-b=PASS (D-37a install-only probe, sbx v0.39.0 def8cb0523a77e757bdd6ef52b459fe374f3783e)
INFO recommendation: keep the startup-based kit; README unchanged
3 checks, 0 failures
```

`run.log` (stdout+stderr of the run) is byte-identical to EVIDENCE.txt — no stray output.

### Verdicts

- **Q-a: FAIL** — `sbx kit add statusline-kit-test-addonly <scratch-kit>` exited 1 with `ERROR: kit "claude-code-status-line-installonly" declares files, which the kit-add recreate flow does not yet apply; recreate the sandbox from scratch via sbx rm + sbx create --kit to use this kit` (reason=kit-add-rc). Removing `setup.startup` moved the refusal from "declares setup.startup" (Phase 3) to "declares files": on v0.39.0 the kit-add recreate flow applies neither, so any kit that ships `statusline.sh` via `files/` is refused regardless of where the merge runs. The baseline proved the no-kit sandbox had no script and `.statusLine=null` (with the platform seed already present), so the FAIL is sbx's refusal, not a stale state.
- **Q-b: PASS** — the sandbox created `--kit <scratch-kit>` showed the platform seed (`themeId`) AND the exact D-34 `.statusLine` object afterwards (keys: alwaysThinkingEnabled, bypassPermissionsModeAccepted, defaultMode, skipDangerousModePermissionPrompt, statusLine, themeId — the same six keys the shipped kit produces), the kit script was executable and `cmp`-identical to the repo file, and `.statusLine` was still exact after `sbx stop` + restart. Marker: `script_at_install=yes install_user=root` (files/ lands BEFORE setup.install runs; install runs as root). Ownership after the tolerant chown: both `settings.json` (0600) and `statusline.sh` (0755) owned by 1000:1000 (agent).

### Recommendation

Script output, verbatim: `INFO recommendation: keep the startup-based kit; README unchanged`.

Expanded: any FAIL → **keep the startup-based kit, README unchanged** (the README's `sbx rm` + recreate `--kit` route from 03-03 stands). No code change is made to `kit/`, `README.md`, or `tests/sandbox.sh`. The install-only switch is NOT worth a follow-up on sbx v0.39.0 because Q-a fails on `files`, which every viable kit shape needs. Q-b's PASS is recorded for the day a future sbx release teaches the kit-add recreate flow to apply `files` (and install): at that point an install-only spec is known to survive the seed, and `tests/probe-kit-add.sh` can be re-run as-is after the sbx bump to re-answer Q-a.

### Supporting facts — run 1 (2026-08-22T16:51:59Z, script at `6a4b3bf`)

Identical verdicts and INFO values (Q-a=FAIL reason=kit-add-rc with the same sbx refusal text; Q-b=PASS with the same keys, marker `script_at_install=yes install_user=root`, same ownership, `.statusLine` exact after first start and after stop/start; `3 checks, 0 failures`). Only two label differences motivated run 2: the start/verdict lines read `sbx=sbx version: v0.39.0 …` (sbx's own prefix was not stripped) and the infra check was named `PASS Q-a: sandbox created WITHOUT kit: …`, which made `grep -Ec '^(PASS|FAIL) Q-a: '` count 2 instead of the required exactly-one verdict line. Run 1's files are kept as `tests/out/kit-add-probe/EVIDENCE.run1.txt` / `run1.log` (gitignored).

## Pre / post state proofs

Pre-state `sbx ls` (16:49Z, before Task 1) and post-state `sbx ls` (after run 2) — identical:

```text
SANDBOX               AGENT    STATUS    PORTS   WORKSPACE
claude-config         claude   running           /Users/sv/github/config
claude-sedcard        claude   stopped           /Users/sv/workspace/sedcard-creation/sedcard
statusline-kit-test   claude   running           /Users/sv/github/claude-code-status-line
```

`statusline-kit-test` present and running before and after; `statusline-kit-test-addonly` and `statusline-kit-test-installonly` absent after each run (also after `--build-only`, which never creates them); no other sandbox created, stopped, or removed.

Unchanged files (T-quick-rbm-02): `git status --short kit/ README.md tests/sandbox.sh` = ` M kit/spec.yaml` before and after (the unrelated uncommitted user edit, never staged); `md5 -q kit/spec.yaml` = `1f403a260ce1eb5f77e7221becc571bb` before and after; `git log --oneline -1 -- kit/ README.md tests/sandbox.sh` still `b172b21` (no new commit); `git status --short tests/out/` empty (gitignored).

Host `~/.claude` untouched (D-46, T-quick-rbm-03) — before == after: `/bin/ls -l ~/.claude/statusline.sh` → `-rwxr-xr-x@ 1 sv  staff  9800 Aug 22 18:58 /Users/sv/.claude/statusline.sh`; `jq -c .statusLine ~/.claude/settings.json` → `{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Evidence line hygiene: sbx version prefix + Q-a infra check name collided with the verdict grep**
- **Found during:** Task 2 (reading run 1's EVIDENCE.txt against the acceptance criteria)
- **Issue:** (a) `sbx version` prints `sbx version: v0.39.0 <sha>`, so the start and verdict lines read `sbx=sbx version: …`; (b) the plan-mandated infra check name `Q-a: sandbox created WITHOUT kit` matches the acceptance regex `^(PASS|FAIL) Q-a: `, so EVIDENCE.txt had two Q-a lines instead of the required exactly one.
- **Fix:** strip the `sbx version: ` prefix with `${SBX_VER#sbx version: }`; rename the infra check to `Q-a create: sandbox created WITHOUT kit: …`. Re-ran static gates (bash -n, shellcheck, the full Task 1 gate) and then the live probe once more (run 2 = recorded evidence; run 1 kept as supporting facts, same verdicts).
- **Files modified:** tests/probe-kit-add.sh
- **Commit:** `5f20baf`

No other deviations — the probe ran with `3 checks, 0 failures` on both runs; no infrastructure failure, no auth gate, no package installs.

## Known Stubs

None — the script is complete and re-runnable; the scratch kit is intentionally disposable (rebuilt under gitignored `tests/out/` on every run).

## Threat Flags

None — no new network endpoints, auth paths or host writes; the root install command runs only inside the two disposable probe sandboxes, which the trap removes (T-quick-rbm-05 accepted as planned).

## Self-Check: PASSED

- FOUND: /Users/sv/github/claude-code-status-line/tests/probe-kit-add.sh (executable)
- FOUND: /Users/sv/github/claude-code-status-line/tests/out/kit-add-probe/EVIDENCE.txt (gitignored)
- FOUND: /Users/sv/github/claude-code-status-line/tests/out/kit-add-probe/kit-installonly/spec.yaml (gitignored)
- FOUND commit 6a4b3bf; FOUND commit 5f20baf
