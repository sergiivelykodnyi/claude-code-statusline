---
status: testing
phase: 02-git-segment
source: [02-VERIFICATION.md]
started: 2026-08-22T10:30:00Z
updated: 2026-08-22T10:30:00Z
---

## Current Test

number: 1
name: Live-terminal color legibility of the full-form git segment (light + dark themes)
expected: |
  Render the full-form git segment in a live terminal on both a light and a dark theme and read line 1 at a glance.
  Every marker is legible and distinguishable: magenta branch, yellow dirty `*`, green `≡` / red `≢`, yellow `↓N`, green `↑N`, dim `#N` — no marker washes out against either background.
awaiting: user response

## Tests

### 1. Live-terminal color legibility of the full-form git segment (light + dark themes)
expected: Render the full-form git segment in a live terminal on both a light and a dark theme and read line 1 at a glance. Every marker is legible and distinguishable: magenta branch, yellow dirty `*`, green `≡` / red `≢`, yellow `↓N`, green `↑N`, dim `#N` — no marker washes out against either background. (Plan 01 D5, human_judgment: true; carried forward unchanged from both previous verifications; unaffected by 02-03/02-04.)
result: [pending]

### 2. Judgment-tier prohibition sign-off (02-01 + 02-04)
expected: Sign off the four judgment-tier prohibitions — 02-01: no network in the render path; no repository mutation during render. 02-04: never execute a command derived from a stdin value; no second jq / second primary git status / network call added. Review the evidence column in the Prohibitions table of 02-VERIFICATION.md. Each prohibition holds. Evidence: grep `git .*fetch|curl` = 0; all 3 git calls are read-only (status/rev-parse/rev-list) and carry GIT_OPTIONAL_LOCKS=0; every @sh-ingested field is type-guarded (3 `strings`, 7 `uint`, 0 bare) and 13 live array/structural payloads executed nothing; non-comment `jq -r` = 1, `porcelain=v2` = 1. (Verifier verdict is evidence-backed but flagged `unverified-prohibition — human review recommended`; never a silent pass.)
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
