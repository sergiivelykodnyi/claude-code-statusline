---
status: testing
phase: 04-fable-weekly-f-segment
source: [04-VERIFICATION.md]
started: 2026-08-23T00:08:48Z
updated: 2026-08-23T00:08:48Z
---

## Current Test

number: 1
name: Host live check (roadmap SC1)
expected: |
  Prerequisite: ~/.claude/statusline.sh is currently a content-identical REGULAR-FILE COPY of kit/files/home/.claude/statusline.sh (mtime Aug 23 02:59 +0300, not a symlink). Re-run the README install line (`ln -sf <repo>/kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh`) so future repo changes propagate, then start `claude` in this repo, send one short message and look at line 2.
  Line 2 ends with `· Fable NN%/1w (Nd:Nh:Nm)` — dim `Fable`, number green/yellow/red by threshold, `/1w` and countdown plain — and keeps rendering instantly on later messages (one fetch per 5 minutes, cached 0600 at ~/.claude/statusline-usage-cache.json). ~/.claude/settings.json statusLine stays {"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}. Also confirm YOU made the 02:59 copy of statusline.sh (if not, an agent breached D-46 — report it).
awaiting: user response

## Tests

### 1. Host live check (roadmap SC1)
expected: Prerequisite: re-run the README `ln -sf` line (~/.claude/statusline.sh is a content-identical regular-file copy dated Aug 23 02:59, not a symlink). Start `claude` in this repo, send one short message. Line 2 ends with `· Fable NN%/1w (Nd:Nh:Nm)` (dim label, number green/yellow/red by threshold, `/1w` and countdown plain), renders instantly on later messages (5-minute cache, 0600 at ~/.claude/statusline-usage-cache.json); ~/.claude/settings.json statusLine object unchanged. Confirm the 02:59 copy was your own action (otherwise an agent breached D-46).
result: [pending]

### 2. Sandbox live check (roadmap SC2)
expected: With Docker Desktop running: `sbx run --name statusline-kit-test` (left running by tests/sandbox.sh; recreate with `sbx run claude . --kit "$PWD/kit"` if gone), accept any trust prompt, send one short message. Same two-line status line with `· Fable NN%/1w (…)` last on line 2 (the sandbox has its own /home/agent/.claude/.credentials.json — §5.13 rendered `· Fable 90%/1w (1d:18h:32m)` in 1 s); if the sandbox has no credentials, line 2 renders normally without the segment.
result: [pending]

### 3. Judgment-tier prohibitions review
expected: Review the LLM-judge table in 04-VERIFICATION.md (16 prohibitions across plans 01-04, all judged HOLD with code evidence: no credential write path, no -H/--header, no background/&/sleep/retry, no proxy value, no token in fixtures/docs, docs-only commits for 04-04, sandbox probe is presence-only). Human agrees each prohibition holds; otherwise flag the item for a follow-up.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
