---
phase: 03-install-dual-environment-validation
verified: 2026-08-22T15:21:15Z
status: passed
score: 21/23 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification: false
mode: mvp
mode_guard: "ROADMAP goal is not in User Story form (user-story.validate valid=false); verified against the 4 ROADMAP success criteria + the plan 01 user story instead of refusing — flagged for the orchestrator (see Warnings)"
behavior_unverified_items:

  - truth: "Reset countdowns keep ticking while the session is idle, via the refreshInterval in the documented settings snippet (ROADMAP SC3)"
    test: "Apply the README settings snippet (refreshInterval 60) to ~/.claude/settings.json, start claude in this repo, send one message, then leave the session idle for at least two minutes and watch line 2"
    expected: "The 5h/1w countdown values change while no new message is sent (Claude Code re-runs the script every 60 s)"
    why_human: "The snippet and the kit merge are present (README lines 48-57; kit/spec.yaml line 44; sandbox evidence shows refreshInterval 60 merged), but idle re-rendering is Claude Code runtime behaviour that no test can exercise without a live TUI session; the host settings.json has no refreshInterval today (D-46: the user applies it)"
coincidental_reliance_items: []
human_verification:

  - test: "Host README install UAT (03-02 Task 1 human-check; coverage D9; ROADMAP SC1 + SC3). On the macOS host, from this repo's root, follow ONLY README.md 'Install on the host': run the ln -sf one-liner, merge the statusLine JSON (with refreshInterval 60) into ~/.claude/settings.json keeping your other keys, start claude in this repo, send one message, look at the status line, leave the session idle >= 2 minutes and watch the countdowns, then run ls -l ~/.claude/statusline.sh"
    expected: "Two-line status line renders: line 1 model + effort, claude-code-status-line, ⎇ main with live git markers; line 2 context usage and the 5h/1w segments with countdowns. While idle the countdown values change (refreshInterval 60). ls -l shows ~/.claude/statusline.sh is a symlink whose target ends in /kit/files/home/.claude/statusline.sh"
    why_human: "Agents never touch ~/.claude (D-46); today ~/.claude/statusline.sh is still the pre-phase regular-file copy (-rwxr-xr-x 9800 bytes, Aug 22 13:53) and settings.json has no refreshInterval — the install has not been applied yet, and a live TUI over time must be observed"

  - test: "Live sandbox eyeball (03-03 Task 3 human-check; coverage D8; ROADMAP SC2 live half, D-39). With Docker Desktop running, from this repo's root run sbx run --name statusline-kit-test (recreate with sbx run claude . --kit \"$PWD/kit\" if it is gone), accept any trust prompt, send one short message, and compare the status line with a host claude session in the same repo. Also run: sbx exec statusline-kit-test jq .statusLine /home/agent/.claude/settings.json"
    expected: "Two flush-left lines identical in layout, glyphs and colors to the host; no blank line, no 'Permission denied', no placeholder. jq shows type command / command ~/.claude/statusline.sh / padding 0 / refreshInterval 60"
    why_human: "Visual comparison of a live Claude Code TUI in two environments; the harness + byte diff prove fixture-render identity (automated, verified), only a human confirms the real session renders it. sandboxd was stopped during verification and the verifier was instructed not to start Docker"

  - test: "Acknowledge the judgment-tier prohibition verdicts (9 items across the three plans, table below). In particular confirm on your machine that nothing under ~/.claude was created, modified, or re-pointed by Phase 3 agents (D-46): ls -l ~/.claude/statusline.sh should still show the pre-phase regular file and jq -c .statusLine ~/.claude/settings.json should still lack refreshInterval — until YOU apply the README"
    expected: "All 9 prohibitions hold (LLM-judge verdict: not violated, with deterministic evidence for each); the human confirms the host ~/.claude state"
    why_human: "Prohibitions carry no verification tier in the PLAN frontmatter (treated as judgment-tier); per ADR-550 the verifier's verdict is non-authoritative and must be explicitly resolved by a human — unverified-prohibition, human review recommended (never a silent pass)"
---

# Phase 3: Install & Dual-Environment Validation — Verification Report

**Phase Goal:** The status line is installed by symlink from this repo, renders identically on the macOS host and inside a live Docker Sandbox, and the README lets anyone reproduce the setup
**Verified:** 2026-08-22T15:21:15Z (repo HEAD 602cc6d, branch main, worktree clean)
**Status:** human_needed
**Re-verification:** No — initial verification
**Mode:** mvp (see Warnings: the ROADMAP goal is not a User Story; verified against the 4 success criteria + the plan 01 story)

## User Flow Coverage (MVP mode — plan 01 story: "As a Claude Code user who works on the macOS host and inside Docker Sandboxes, I want to install this status line once from the repo — a symlink on the host, an sbx mixin kit in sandboxes — so that the same script renders identically wherever Claude runs.")

| Step | Expected | Evidence in codebase | Status |
|------|----------|----------------------|--------|
| 1. Host: run the README `ln -sf` one-liner | `~/.claude/statusline.sh` -> `kit/files/home/.claude/statusline.sh`, renders | README.md:35 carries the exact one-liner; verifier created a temp symlink to the kit script and rendered all 7 fixtures through it: bytes identical to the repo renders; `~/.claude/statusline.sh` today is still the pre-phase copy (user has not applied yet, D-46) | Mechanism VERIFIED; actual host apply = human (H1) |
| 2. Host: paste the settings snippet | Claude Code runs the script with `refreshInterval: 60`, countdowns tick while idle | README.md:48-57 exact D-34 object; `tests/run.sh` pins; kit merges the identical object (EVIDENCE.txt `INFO observed .statusLine`) | Present; idle ticking = PRESENT_BEHAVIOR_UNVERIFIED (H1) |
| 3. Sandbox: create with `--kit kit/` | `/home/agent/.claude/statusline.sh` present, executable, byte-identical; `statusLine` merged | `sbx kit validate kit` -> VALID (re-run); EVIDENCE.txt (live 2026-08-22T13:42:21Z): PASS created with kit, PASS statusLine merged, PASS present and executable, PASS byte-identical, PASS survives stop/start | VERIFIED |
| 4. Outcome: same script renders identically wherever Claude runs | Byte-identical renders host vs sandbox; harness green in both | `diff -r tests/out/host/repo tests/out/sandbox/repo` -> empty (re-run by verifier, 7 files); `diff -r` of `installed/` dirs -> empty; host harness `126 checks, 0 failures` (re-run); sandbox run.log last line `126 checks, 0 failures` | VERIFIED (fixtures); live TUI identity = human (H2) |

## Goal Achievement

### Observable Truths

| # | Truth | Source | Status | Evidence |
|---|-------|--------|--------|----------|
| 1 | Following only the README's `ln -s` one-liner and `settings.json` snippet gets the status line rendering in Claude Code on the macOS host | ROADMAP SC1 | ? UNCERTAIN -> human (H1) | README.md:35 + :48-57 present and proven against the kit script (temp-symlink render byte-identical; README payload renders the documented two lines, 0 stderr bytes); host `~/.claude/statusline.sh` is still the pre-phase regular file and settings.json lacks refreshInterval — by design D-46 the user performs the install as UAT |
| 2 | Inside a live Docker Sandbox, the same symlinked `~/.claude/statusline.sh` resolves (no dangling link) and renders output identical to the host | ROADMAP SC2 | ✓ VERIFIED | Live EVIDENCE.txt (gitignored, files dated 13:42Z; run.log shows `agent agent` ownership of /home/agent/.claude/statusline.sh): `PASS kit script present and executable`, `PASS kit script byte-identical to repo file`, `PASS harness in sandbox: 126 checks, 0 failures`, `PASS render dump in sandbox: installed == repo`, `PASS PORT-01 ... (7 fixtures)`, `PASS PORT-04: host vs sandbox installed-path renders byte-identical`, summary `11 checks, 0 failures`; verifier re-ran `diff -r` host vs sandbox for repo/ and installed/ -> both empty. Flagged assumption ACCEPTED: in the sandbox the installed path is a kit-delivered regular file, not a symlink (D-30 — symlinks cannot cross into the sandbox). Live TUI eyeball -> H2 |
| 3 | Reset countdowns keep ticking while the session is idle, via the `refreshInterval` in the documented settings snippet | ROADMAP SC3 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `"refreshInterval": 60` in README.md:54 and README.md:59 explains it; kit/spec.yaml:44 merges the same value; sandbox observed `.statusLine` carries refreshInterval 60. Idle re-render is Claude Code runtime behaviour -> H1 |
| 4 | README shows what the status line displays (with the example output) plus the symlink install command and the `statusLine` settings snippet | ROADMAP SC4 | ✓ VERIFIED | README.md:7-10 fenced two-line example (`Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2` / `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)`), :16-28 legend table, :35 `ln -sf` one-liner, :48-57 snippet |
| 5 | Canonical script at `kit/files/home/.claude/statusline.sh`, git mode 100755, byte-identical to pre-move `statusline.sh`; no script/shim at repo root (D-31) | 03-01 | ✓ VERIFIED | `git ls-files -s` -> `100755 1cf0071...`; `git show 64b3c1b:statusline.sh \| cmp -` rc 0; `test -e statusline.sh` -> absent |
| 6 | `kit/` is a valid sbx mixin kit: `sbx kit validate kit` exits 0 offline; spec declares schemaVersion "2", kind mixin, requires.agent claude, jq/git install guard (D-33), root startup that waits for the seed and jq-merges ONLY statusLine to the exact D-34 object, chmod 0755, chown back to agent (D-30/32/34) | 03-01 | ✓ VERIFIED | `sbx kit validate kit` -> `VALID: kit (directory)` rc 0 (daemon stopped); kit/spec.yaml inspected lines 9-51: all elements present verbatim (`themeId` poll, `try (input) catch {}`, tmp+mv, `.statusLine = {type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}`, `chmod 0755`, non-recursive `chown`, `user: "0"`) |
| 7 | `tests/run.sh` runs against the relocated path, carries an exec-bit check proven to bite, exits 0 with >= 126 checks and 0 failures | 03-01 | ✓ VERIFIED | `SL=kit/files/home/.claude/statusline.sh` (line 13); line 57 `check_ok "exec bit: ..."`; run -> rc 0, `126 checks, 0 failures`, `PASS exec bit: ...`. Bite proof (chmod -x -> `126 checks, 1 failures`) accepted from SUMMARY + code inspection (`[ -x "$SL" ]` is a direct test); not re-executed because it would require changing the kit file's mode (prohibited for the verifier) |
| 8 | `tests/render-fixtures.sh OUTDIR` writes raw renders of all 7 fixtures to OUTDIR/repo and (when installed path executable) OUTDIR/installed, `diff -r`s them, exits non-zero on any difference | 03-01 | ✓ VERIFIED | Ran: `INFO rendered 7 fixtures`, `PASS installed path renders byte-identical to repo path (PORT-04)` rc 0; 7 + 7 `.out` files; no-arg rc 1; `REQUIRE_INSTALLED=1 INSTALLED=/nonexistent` -> `FAIL ...` rc 1; code lines 63-78 implement diff-or-exit-1 |
| 9 | Running the dumper on the host reports installed == repo without any agent write under `~/.claude`; `tests/out/` gitignored | 03-01 | ✓ VERIFIED | PASS line above; `.gitignore:2 tests/out/`; `git status --porcelain tests/out` empty; host `~/.claude/statusline.sh` unchanged (Aug 22 13:53, bytes identical to kit script) |
| 10 | Direct execution of the kit script (shebang + exec bit) on full.json renders `Opus 5 (high) · myproject` / `10%/100k/1M · 50%/5h (now) · 15%/1w (now)` | 03-01 | ✓ VERIFIED | Executed directly; escape-stripped output matches both lines exactly |
| 11 | README.md at repo root, 50-100 lines, exactly five `##` sections in D-40 order, no contributor/dev section | 03-02 | ✓ VERIFIED | 98 lines; `grep -c '^## '` = 5: What it shows, Symbol legend, Install on the host, Install in Docker Sandboxes, Requirements; `## Development` = 0 |
| 12 | What-it-shows fenced block with the two current lines, one legend table covering ⎇ * ≡/≢ ↓N ↑N #N context 5h/1w; no Phase 4 content | 03-02 | ✓ VERIFIED | Both example lines present exactly once; 11-row legend; `fable` = 0, `f(` = 0 |
| 13 | Host install documents `ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh`, the `rm -f && cp` variant with overwrite warning, and the live-symlink note | 03-02 | ✓ VERIFIED | README.md:35, :38 (`immediately`), :41, :44 (`**Warning:** ... overwrites`); the only `cp` in the file is the rm-first form |
| 14 | README carries the statusLine snippet exactly {type command, command ~/.claude/statusline.sh, padding 0, refreshInterval 60} | 03-02 | ✓ VERIFIED | README.md:49-56; each key grep count = 1; matches kit/spec.yaml:44 object byte-for-byte in value terms |
| 15 | README carries one mock-input verify command piping the full.json payload into `~/.claude/statusline.sh` with the expected two `(now)` lines plus the `claude --debug` hint | 03-02 | ✓ VERIFIED | README.md:64-70. Info: the README payload omits the fixture's `session_id: "fix-full"` key (render unaffected — session_id is not rendered); SUMMARY wording "verbatim" is slightly loose |
| 16 | Docker Sandboxes section explains why a kit is needed and documents local (`sbx run claude --kit`, existing-sandbox route) and remote (`git+https...#dir=kit` + kit.allowedSources note) | 03-02 (reconciled by 03-03) | ✓ VERIFIED (wording reconciled by design) | README.md:74 (`do not import`, symlinks cannot cross), :79, :82, :87, :90. The plan-02 `sbx kit add` sentence was replaced by the `sbx rm` + recreate instruction because the live probe showed sbx 0.39 refuses kit-add for kits with setup.startup — exactly the conditional branch plan 03 truth 4 / D-37 prescribed |
| 17 | The README's documented verify payload piped through the kit script yields exactly the two documented lines | 03-02 | ✓ VERIFIED | Payload extracted from README.md:64 -> `/bin/bash kit/files/home/.claude/statusline.sh` -> `Opus 5 (high) · myproject` / `10%/100k/1M · 50%/5h (now) · 15%/1w (now)`, 0 stderr bytes |
| 18 | `.planning/research/ARCHITECTURE.md` and `.planning/PROJECT.md` no longer claim sandboxes share host `~/.claude`; both name `kit/` | 03-02 | ✓ VERIFIED | ARCHITECTURE.md: `kit/spec.yaml` 1, kit script path 1; PROJECT.md: kit script path 1, `not imported` 1; no "sandboxes share" phrasing found |
| 19 | `tests/sandbox.sh` creates `statusline-kit-test` with `--kit "$PWD/kit"` and proves via `sbx exec` (fixed check names) script present/executable/byte-identical, statusLine == D-34 within 120 s, in-sandbox harness 0 failures, in-sandbox dumper installed == repo, host/sandbox `diff -r` empty, statusLine after stop/start, kit-add probe | 03-03 | ✓ VERIFIED | tests/sandbox.sh lines 145-270 implement every step with the mandated names; all 4 plan key_links found by `verify.key-links`; EVIDENCE.txt carries each PASS line. Documented deviation accepted: the kit-add probe is emitted as PASS/FAIL but excluded from CHECKS/FAILS (plan's own verify required `0 failures` while allowing `FAIL sbx kit add delivers`) |
| 20 | `tests/sandbox.sh` refuses with exit 2 when sandboxd is unreachable, removes only its two named sandboxes, keeps the primary by default, writes all lines to `tests/out/sandbox/EVIDENCE.txt` | 03-03 | ✓ VERIFIED | Stage order help(l.46) < `sbx ls` precheck (l.133) < trap (l.144); `--help` rc 0, `--bogus` rc 2, `bash -n` clean; `--all` count 0; every `sbx rm -f` targets `$NAME` or `$ADD_NAME` only; emit helper appends to `$EVID`. The daemon-unreachable exit-2 path was not exercised (calling `sbx ls` can auto-start sandboxd, which the verifier must not do) — code-inspected only |
| 21 | The live run's evidence is recorded: EVIDENCE.txt ends with `N checks, 0 failures`, PORT-01 diff empty for 7 fixtures, in-sandbox harness log ends `... checks, 0 failures`, SUMMARY pastes the lines | 03-03 | ✓ VERIFIED | Last line `11 checks, 0 failures`; `PASS PORT-01 ... (7 fixtures)`; run.log tail `126 checks, 0 failures`; 7 sandbox `.out` files; `diff -r` empty (re-run); SUMMARY 03-03 pastes the file verbatim (matches on-disk content) |
| 22 | README's Docker section matches observed behaviour (kit-add FAIL -> recreate instruction; restart PASS -> no project-scope settings note) | 03-03 | ✓ VERIFIED | `sbx kit add` in README = 0, `recreate` = 1, `.claude/settings.json` = 1 (user-scope snippet only); EVIDENCE: `FAIL sbx kit add delivers ... [probe, not counted]` + `PASS statusLine survives stop/start` + `INFO restart: canary survived`; README gates still hold (5 sections, 98 lines, no fable/f() |
| 23 | Nothing under the host `~/.claude` was created, modified, or re-pointed by the phase (D-46) | 03-01/02/03 | ✓ VERIFIED | `/bin/ls -l ~/.claude/statusline.sh` -> `-rwxr-xr-x@ 1 sv staff 9800 Aug 22 13:53` (pre-phase regular file, bytes identical to the kit script); `jq -c .statusLine ~/.claude/settings.json` -> `{"type":"command","command":"~/.claude/statusline.sh","padding":0}` (no refreshInterval) — identical to the before/after values recorded in all three SUMMARYs and to the CONTEXT.md Integration Points description |

**Score:** 21/23 truths verified (1 present, behavior-unverified: SC3; 1 human-only: SC1)

Deduplicated: plan 02 truth 8 (host UAT) == SC1/H1; plan 03 truth 5 (live check) == H2.

### Flagged Assumptions (from the PLANs) — verifier disposition

| Assumption | Disposition |
|-----------|-------------|
| PORT-01 "identical output" operationalized as byte-identical raw renders of the 7 fixtures host vs sandbox + full harness 0 failures in both environments (git matrix / latency compared by PASS/FAIL only) | ACCEPTED — the fixtures cover every render branch the harness pins; temp-repo SHAs and timings cannot be byte-compared |
| PORT-04 "symlink in both environments" satisfied on the sandbox side by the kit-delivered regular file (D-30: symlinks to host paths cannot cross into the sandbox) | ACCEPTED — host side additionally proven by the verifier's temp symlink -> kit script rendering all 7 fixtures byte-identically; the user's real `~/.claude` symlink is H1 |
| Exec-bit preservation by the engine (A5) | CONFIRMED live: `PASS kit script present and executable`; run.log `-rwxr-xr-x 1 agent agent ... /home/agent/.claude/statusline.sh` |
| `sbx exec` default user is `agent` (A4) | CONFIRMED live: `INFO sbx exec user: agent HOME=/home/agent` |
| Repository public for anonymous git+https kit access (research A6) | NOT VERIFIABLE offline — README remote route stays documented as an option; local `--kit` route is primary and proven |

### Prohibitions (judgment-tier — LLM-judge verdicts, NON-AUTHORITATIVE; human acknowledgement requested, see H3)

| Plan | Prohibition | Verdict | Evidence |
|------|-------------|---------|----------|
| 01 | MUST NOT change statusline.sh content (pure relocation, 100755) | not violated | `git show 64b3c1b:statusline.sh \| cmp -` rc 0; mode 100755 |
| 01 | Kit MUST NOT replace/truncate/rewrite settings.json wholesale — only `.statusLine` via atomic tmp+mv | not violated | kit/spec.yaml:39-45: pre-seed `{}` only when absent, `jq ... .statusLine = {...}` to tmp, `mv`; live: settings keys list preserved, canary survived restart |
| 01 | MUST NOT write/replace/re-point anything under host `~/.claude` | not violated | truth 23 evidence |
| 02 | README MUST NOT document a copy command that writes through an existing symlink | not violated | only `cp` line is `rm -f ... && cp ...` (README.md:41) with warning (:44) |
| 02 | README MUST NOT mention the Phase 4 weekly sub-segment | not violated | `fable` 0, `f(` 0 |
| 02 | MUST NOT write to `~/.claude/settings.json` or `~/.claude/statusline.sh` | not violated | truth 23 evidence |
| 03 | MUST NOT substitute a host-only run / plain docker / emulated Linux for the live sbx sandbox | not violated | EVIDENCE produced by `sbx create --kit` / `sbx exec` (exec user `agent`, `agent agent` ownership in run.log, sandbox-specific settings keys `bypassPermissionsModeAccepted` etc.) |
| 03 | MUST NOT remove/modify any sandbox other than `statusline-kit-test` / `statusline-kit-test-add`; no remove-everything `sbx rm` | not violated | all `sbx rm -f` calls target `$NAME`/`$ADD_NAME`; `--all` absent |
| 03 | MUST NOT write under host `~/.claude` during the sandbox run | not violated | truth 23 evidence; canary written only to `/home/agent/.claude/settings.json` inside the sandbox |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kit/spec.yaml` | sbx mixin kit manifest (D-30/32/33/34) | ✓ VERIFIED | 51 lines; `schemaVersion: "2"`; validate VALID; wired: consumed by `tests/sandbox.sh --kit`, README `--kit` |
| `kit/files/home/.claude/statusline.sh` | canonical script relocated unchanged | ✓ VERIFIED | 226 lines, 100755, `Source guard` present, byte-identical to 64b3c1b; wired: `SL=` in run.sh + render-fixtures.sh, kit static file, host install target |
| `tests/run.sh` | harness re-pointed + exec-bit check | ✓ VERIFIED | 126 checks, 0 failures; wired: invoked on host and inside sandbox (run.log) |
| `tests/render-fixtures.sh` | raw render dumper with diff -r | ✓ VERIFIED | 80 lines, executable, `diff -r` present; wired: invoked by tests/sandbox.sh on both sides |
| `.gitignore` | `tests/out/` ignored | ✓ VERIFIED | line 2 |
| `README.md` | install story (DOCS-01/02) | ✓ VERIFIED | 98 lines, 5 sections, `refreshInterval` present |
| `.planning/research/ARCHITECTURE.md` | kit layout | ✓ VERIFIED | contains `kit/` paths |
| `.planning/PROJECT.md` | installation model corrected | ✓ VERIFIED | contains kit path + `not imported` |
| `tests/sandbox.sh` | host-side sandbox orchestrator | ✓ VERIFIED | 270 lines, executable, `EVIDENCE.txt` referenced; wired to kit, run.sh, render-fixtures.sh, settings.json (4/4 key links) |
| `tests/out/sandbox/EVIDENCE.txt` | live evidence (gitignored) | ✓ VERIFIED | 21 lines, last `11 checks, 0 failures`, `checks, 0 failures` present |

`gsd-tools query verify.artifacts`: plan 01 5/5, plan 02 3/3, plan 03 3/3 — all passed.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| kit/spec.yaml | kit/files/home/.claude/statusline.sh | static file + startup chmod/statusLine.command | WIRED | tool: pattern found; live: script delivered + executable |
| tests/run.sh | kit script | `SL=kit/files/home/.claude/statusline.sh` | WIRED | line 13 |
| tests/render-fixtures.sh | `$HOME/.claude/statusline.sh` | installed-path render + diff -r | WIRED | lines 33, 56, 65 |
| README host one-liner | kit script | `ln -sf "$PWD/kit/..."` | WIRED (manual) | README.md:35 (tool could not parse descriptive `from:`; verified by grep) |
| README snippet | `~/.claude/statusline.sh` | `"refreshInterval": 60` | WIRED (manual) | README.md:52-54 |
| README Docker section | kit/spec.yaml | `--kit` | WIRED (manual) | `--kit` x3 (README.md:79, :82, :87) |
| tests/sandbox.sh | kit/spec.yaml | `sbx create ... --kit "$KIT"` | WIRED | line 157 |
| tests/sandbox.sh | tests/render-fixtures.sh | `sbx exec -e INSTALLED=... -e REQUIRE_INSTALLED=1` | WIRED | lines 192-193, 197 |
| tests/sandbox.sh | tests/run.sh | `sbx exec ... /bin/bash $PWD/tests/run.sh` | WIRED | line 185 |
| tests/sandbox.sh | /home/agent/.claude/settings.json | `jq -cS .statusLine` poll | WIRED | lines 116-124 |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| kit script render | line 1/2 segments | stdin JSON via jq (unchanged Phase 1-2 code) | yes — fixtures render expected values | ✓ FLOWING |
| tests/render-fixtures.sh | `*.out` bytes | actual script executions (repo + installed path) | yes — 7 non-empty files per side, diff clean | ✓ FLOWING |
| tests/sandbox.sh EVIDENCE.txt | PASS/FAIL lines | real `sbx exec` results via check_ok | yes — live run, sandbox-specific values recorded | ✓ FLOWING |
| kit startup merge | `.statusLine` | jq over existing settings.json | yes — observed merged object + preserved keys | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Kit validates offline | `sbx kit validate kit` | `VALID: kit (directory)` rc 0 | ✓ PASS |
| Harness green on host | `/bin/bash tests/run.sh` | rc 0, `126 checks, 0 failures`, `PASS exec bit` | ✓ PASS |
| Host render dump | `/bin/bash tests/render-fixtures.sh tests/out/host` | 7 renders, PASS installed == repo, rc 0 | ✓ PASS |
| Host vs sandbox byte identity | `diff -r tests/out/host/repo tests/out/sandbox/repo` (+ installed/) | empty, rc 0 (both) | ✓ PASS |
| Relocation byte-identical | `git show 64b3c1b:statusline.sh \| cmp - kit/...` | rc 0 | ✓ PASS |
| Git index mode | `git ls-files -s kit/files/home/.claude/statusline.sh` | `100755 ...` | ✓ PASS |
| README verify promise | README payload -> kit script, SGR stripped | the two documented lines, 0 stderr bytes | ✓ PASS |
| Symlink invocation (PORT-04 mechanism, no ~/.claude write) | temp `ln -sf` -> kit script, all 7 fixtures | bytes identical to repo renders | ✓ PASS |
| Dumper strictness | `REQUIRE_INSTALLED=1 INSTALLED=/nonexistent ...` / no-arg | rc 1 / rc 1 | ✓ PASS |
| sandbox.sh arg handling | `--help` / `--bogus` / `bash -n` | rc 0 / rc 2 / clean | ✓ PASS |
| README gates | wc -l, `^## ` count, fable, f( | 98 / 5 / 0 / 0 | ✓ PASS |
| Live sandbox run | `tests/sandbox.sh` | NOT re-run (orchestrator prohibition; sandboxd stopped) — recorded evidence inspected | ? SKIP (evidence accepted, see truth 2) |
| Commits exist | `verify.commits 923264f cf9bc74 c451d24 5cccf71 80358bd b172b21` | all 6 valid | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes exist in this project. The phase's probe equivalents are `tests/run.sh` (run: PASS) and `tests/render-fixtures.sh` (run: PASS); `tests/sandbox.sh` was intentionally not executed (creates/removes sandboxes; evidence file pre-exists and was inspected).

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| PORT-01 | 03-01, 03-03 | Identical output on macOS host and inside Docker Sandboxes | ✓ SATISFIED | 7/7 fixture renders byte-identical host vs sandbox (escape sequences included); harness `126 checks, 0 failures` in both; live TUI identity additionally routed to H2 |
| PORT-04 | 03-01, 03-03 | Works when invoked via a symlink from `~/.claude/statusline.sh`, verified in both environments | ✓ SATISFIED (host final state = H1) | Host: installed-path render == repo render; verifier temp-symlink -> kit script renders identically; sandbox: kit-delivered `/home/agent/.claude/statusline.sh` executable, byte-identical, renders identically (flagged assumption accepted, D-30); the user's actual `~/.claude` symlink is created in H1 |
| DOCS-01 | 03-02 | README describes what it shows (example layout) and the `ln -s` symlink command | ✓ SATISFIED | README.md:7-10, :16-28, :35 |
| DOCS-02 | 03-02 | README includes the statusLine snippet with refreshInterval | ✓ SATISFIED | README.md:48-59 (idle ticking behaviour itself = H1) |

Orphaned requirements: none — REQUIREMENTS.md maps exactly PORT-01, PORT-04, DOCS-01, DOCS-02 to Phase 3 (lines 113-116) and every one is claimed by a plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| kit/spec.yaml, tests/run.sh, tests/sandbox.sh | 42 / 44-45 / 217 | `XXXXXX` | ℹ️ Info (false positive) | mktemp templates, not debt markers |
| tests/run.sh | 186, 230 | `placeholder` | ℹ️ Info (false positive) | project term "hide-over-placeholder" |
| README.md | 64 | verify payload omits `session_id` present in tests/fixtures/full.json | ℹ️ Info | render identical; SUMMARY's "verbatim" is slightly loose |

No TBD/FIXME/TODO/HACK markers, no stubs, no empty implementations in any file modified by this phase.

### Warnings

1. **MVP-mode goal format.** ROADMAP Phase 3 has `Mode: mvp` but its goal is not a User Story (`user-story.validate` -> valid=false). Per the MVP guard the verifier would normally refuse; the orchestrator explicitly supplied the goal + 4 success criteria, and plan 01's objective carries the user story, so verification proceeded against the ROADMAP success criteria (the contract) with a User Flow Coverage table derived from the plan 01 story. Orchestrator/user decision: accept this, or run `/gsd mvp-phase 03` to set a User Story goal and re-verify.
2. **Plan 02 `key_links.from` are descriptive strings**, so `verify.key-links` could not resolve them (0/3 by tool); all three were verified manually by grep (table above).
3. **Live sandbox evidence was not re-executed** by the verifier (prohibited; sandboxd stopped). It was accepted on consistent multi-source evidence: gitignored EVIDENCE.txt/run.log/render.log/repo/installed written 13:42Z, sandbox-specific ownership and settings keys in the logs, byte-identical renders re-diffed on the host, commit b172b21. Re-runnable at any time with `/bin/bash tests/sandbox.sh`.

### Human Verification Required

1. **Host README install UAT** (03-02 Task 1 human-check, coverage D9; ROADMAP SC1 + SC3) — see frontmatter item 1.
2. **Live sandbox eyeball** (03-03 Task 3 human-check, coverage D8; ROADMAP SC2 live half) — see frontmatter item 2.
3. **Prohibition acknowledgement** (9 judgment-tier items; D-46 host state confirmable by the user) — see frontmatter item 3.

### Gaps Summary

No gaps. Every automated must-have is verified in the codebase and by re-running the real commands. Two items are inherently human (the host install the user performs under D-46 and the live TUI comparison in the sandbox); SC3's idle ticking is present (snippet + kit merge) but behaviour-unverified until the host UAT. The flagged assumptions (PORT-04 sandbox side via kit file; PORT-01 operationalization) are accepted with the evidence recorded above.

---

_Verified: 2026-08-22T15:21:15Z_
_Verifier: Claude (gsd-verifier)_
