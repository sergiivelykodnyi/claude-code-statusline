---
status: complete
phase: 03-install-dual-environment-validation
source: [03-VERIFICATION.md]
started: 2026-08-22T15:25:02Z
updated: 2026-08-22T16:29:05Z
---

## Current Test

[testing complete]

## Tests

### 1. Host README install UAT (ln -sf + settings snippet + idle countdowns)
expected: Following ONLY README.md "Install on the host" (ln -sf one-liner, merge the statusLine JSON with refreshInterval 60 into ~/.claude/settings.json keeping your other keys), then starting `claude` in this repo and sending one message: the two-line status line renders — line 1 model + effort, claude-code-status-line, ⎇ main with live git markers; line 2 context usage and the 5h/1w segments with countdowns. Leaving the session idle ≥ 2 minutes, the countdown values change (refreshInterval 60 re-renders). `ls -l ~/.claude/statusline.sh` shows a symlink whose target ends in /kit/files/home/.claude/statusline.sh (ROADMAP SC1 + SC3, D-35, D-46).
result: pass

### 2. Live sandbox eyeball (statusline-kit-test)
expected: With Docker Desktop running, from this repo's root `sbx run --name statusline-kit-test` (recreate with `sbx run claude . --kit "$PWD/kit"` if it is gone), accept any trust prompt, send one short message: two flush-left lines identical in layout, glyphs and colors to a host `claude` session in the same repo — no blank line, no "Permission denied", no placeholder. `sbx exec statusline-kit-test jq .statusLine /home/agent/.claude/settings.json` shows type command / command ~/.claude/statusline.sh / padding 0 / refreshInterval 60 (ROADMAP SC2, D-34, D-39).
result: pass

### 3. Acknowledge prohibition verdicts and untouched host ~/.claude (D-46)
expected: All 9 judgment-tier prohibitions across plans 03-01..03-03 hold (verifier verdict: not violated, with deterministic evidence). On your machine, BEFORE applying the README, `ls -l ~/.claude/statusline.sh` still shows the pre-phase regular file (-rwxr-xr-x 9800 bytes) and `jq -c .statusLine ~/.claude/settings.json` still lacks refreshInterval — proving no Phase 3 agent wrote under ~/.claude.
result: pass

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
