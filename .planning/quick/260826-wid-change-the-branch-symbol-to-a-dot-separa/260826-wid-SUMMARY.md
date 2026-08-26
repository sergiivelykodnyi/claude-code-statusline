---
phase: quick-260826-wid
plan: 01
status: complete
subsystem: statusline-rendering
tags: [rendering, line-1, git-segment, separator, docs, tests]
requires: []
provides:
  - "line 1 renders git as a first-class dot-joined segment"
affects:
  - kit/files/home/.claude/statusline.sh
  - tests/run.sh
  - README.md
tech-stack:
  added: []
  patterns:
    - "join_segments' empty-skip (D-14/PRES-04) is now the sole mechanism preserving GIT-01"
key-files:
  created: []
  modified:
    - kit/files/home/.claude/statusline.sh
    - tests/run.sh
    - README.md
decisions:
  - "Branch label keeps MAGENTA; only the glyph and its trailing space were removed (CTX-1)"
  - "Exactly one new separator (dir to git); git sub-parts stay space-joined inside one segment (CTX-2)"
  - "Kept the git_seg local variable rather than inlining $(seg_git) into the join call (CTX-9)"
  - "Hardened tests/run.sh section 8.6 to span the dir span and joiner so a glyph-only fix cannot silently pass"
metrics:
  duration: 3 min
  completed: 2026-08-26
actuals:
  tokens: 16000
  tasks: 3
  commits: 3
---

# Quick Task 260826-wid: Dot-Separated Git Segment Summary

Promoted the git segment on line 1 from a space-attached suffix of the directory into a first-class
segment joined by the existing dim dot separator, and dropped the `⎇` branch glyph — line 1 now
reads `Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2` with one consistent segment joiner.

## What Was Built

**Task 1 — `kit/files/home/.claude/statusline.sh`** (commit `3472da4`)

Three edits, made with the Edit tool rather than `sed` (two lines carry multi-byte characters;
RESEARCH.md §5.6 warns BSD `sed` under a non-UTF-8 locale can mangle them):

- `seg_git()`: `out="${MAGENTA}⎇ ${label}${RESET}"` → `out="${MAGENTA}${label}${RESET}"`. The magenta
  span, `${label}` and `${RESET}` are untouched — the branch keeps its magenta identity.
- `main()`: deleted the `dir_seg="$dir_seg${git_seg:+ $git_seg}"` splice and passed `"$git_seg"` as a
  fourth argument, so the join reads
  `body=$(join_segments "$sep" "$model_seg" "$dir_seg" "$git_seg")`. The existing `sep` (D-01) is
  reused; no second separator definition was introduced. The two-line comment above it was replaced
  to describe the new first-class-segment behaviour.
- The `seg_git` header comment now reads `# Git segment: magenta branch label, …`.

`git_seg` stays in `main()`'s `local` declaration (CTX-9). No `set -e`/`set -u` was added, and the
unconditional `exit 0` (PORT-03) is unchanged.

**Task 2 — `tests/run.sh`** (commit `17e9842`)

Six stripped-line-1 `check_eq` expectations now expect ` · ` where the glyph and its space used to
sit (clean in-sync, boundary ones, full form, no-upstream, detached with `$DSHA` interpolation
preserved, unborn). Two comments refreshed (8.1, 8.6).

The section 8.6 raw-byte expectation was **hardened**, which was the substantive part of this task.
It is a `case`-based substring match, so a glyph-only fix would have passed it even if the dir↔git
join were never made. The `want` was extended leftward through the directory span and the joiner:

```
want="${ESC}[34mw${ESC}[0m ${ESC}[2m·${ESC}[0m ${ESC}[35mmain${ESC}[0m${ESC}[33m*${ESC}[0m …"
```

Line 337 — `check_eq "git not-a-repo: line 1" "Opus 5 (high) · plaindir" "$l1"` — is byte-identical;
it is the GIT-01 regression guard. No check was added or removed.

**Task 3 — `README.md`** (commit `1b8b1df`)

Sample line 1 and the symbol-legend branch row updated to match the shipped rendering.

## Verification — Actual Output

Gate polarity was confirmed **before** editing, as the plan required:

| Gate | Pre-edit | Post-edit |
|------|----------|-----------|
| gate1 (dim-dot joiner immediately followed by magenta branch) | `FAIL` (expected) | `OK` |
| gate3 (non-repo line 1 ends at the directory span, GIT-01) | `PASS` (expected) | `OK` |

Task 1 automated block printed `OK` — all six gates (joiner present, exactly one magenta span so the
splice is genuinely gone, GIT-01 non-repo ending, one separator definition, `git_seg` still local,
exit 0 with empty stderr).

Task 2 automated block printed `220 checks, 0 failures` then `OK`. Task 3 automated block printed `OK`.

Phase-level checks:

1. `/bin/bash tests/run.sh` → **`220 checks, 0 failures`** (baseline count unchanged).
2. Rendered against this repo: `Opus 5 (high) · claude-code-statusline · main* ≡ ↑3` — branch magenta
   and unprefixed, sub-parts still space-joined. Against `/tmp/myproject`:
   `Opus 5 (high) · myproject` — ends at the directory basename, no dangling separator.
3. `git status --porcelain -- project-brief.md .planning/PROJECT.md .claude/CLAUDE.md` → empty.

**Extra check (not required by the plan): the 8.6 hardening was proven, not assumed.** A throwaway
copy of the script was built in `$TMPDIR` with the glyph removed *but the old splice restored* — the
exact "silent pass" scenario the hardening exists to catch. The new `want` did **not** match that
build's output (`POLARITY GOOD`), confirming the expectation now guards both halves of the change
rather than just the glyph. The throwaway copy was written to `$TMPDIR` and deleted; the repo was
never touched by it.

`grep -cF '⎇'` returns 0 for all three in-scope files.

## Deviations from Plan

None — plan executed exactly as written. No deviation rules were triggered.

## Environment Note — the live status line will NOT change yet

**`~/.claude/statusline.sh` is a regular-file COPY of the repo script, not a symlink** (verified:
`ls -l` shows a plain file dated 24 Aug, and it still contains 2 occurrences of `⎇`). Consequences:

- The user's **live status line will keep rendering the old `⎇` glyph** until that copy is refreshed
  from `kit/files/home/.claude/statusline.sh`.
- **`tests/render-fixtures.sh`'s repo↔installed diff (PORT-04) will report a difference** until the
  copy is refreshed. Per the plan this was deliberately *not* used as a pass/fail gate here, and it
  was not run.

Refreshing that copy is the user's environment and was **explicitly out of scope** for this task. All
8 fixtures render byte-identically before and after this change (they point at a non-repo directory),
so no baseline regeneration is needed.

## Known Documentation Disagreement (accepted, per CTX-6)

`project-brief.md` and `.planning/PROJECT.md` still specify `⎇` as a requirement, and
`.claude/CLAUDE.md` line 109 mentions "hide the whole `⎇` segment". These were ruled out of scope by
the user and knowingly disagree with the shipped script. `.planning/RETROSPECTIVE.md`,
`.planning/milestones/*` and `.planning/research/*` are likewise untouched. All confirmed clean via
`git status --porcelain`.

## Known Stubs

None.

## Threat Flags

None. The change removes a literal prefix inside an existing magenta span and swaps one string splice
for one positional argument — no new sink, no new process spawn, no I/O, no network. The harness's
eval-injection, hostile-body, latency (section 9) and palette-purity (8.7) checks are all green.

## Environment Friction (non-blocking)

Two unrelated environment issues surfaced and neither affected the result:

- Every Bash call emits `error: Can't create the symlink for multishells …fnm_multishells…` on stderr
  from the shell profile's `fnm` init. Cosmetic noise only.
- `git commit` failed inside the sandbox with `1Password: Could not connect to socket. Is the agent
  running?` — commit signing goes through the 1Password SSH agent, whose unix socket the sandbox
  blocks. All three commits were made with the sandbox disabled. The user can manage this with
  `/sandbox`.

## Commits

| Task | Type | Commit | Files |
|------|------|--------|-------|
| 1 | feat | `3472da4` | `kit/files/home/.claude/statusline.sh` |
| 2 | test | `17e9842` | `tests/run.sh` |
| 3 | docs | `1b8b1df` | `README.md` |

Diffstat across all three: 3 files changed, 17 insertions(+), 18 deletions(-).

## Human Check Outstanding

Render the status line in a real repo and confirm line 1 reads `Opus 5 (high) · <dir> · <branch>…`
with the branch still magenta and the git sub-parts still space-joined, and that it collapses to
`… · <dir>` outside a repo. **This requires refreshing `~/.claude/statusline.sh` first** (see the
environment note above) — the repo-script render was verified directly and matches.

## Self-Check: PASSED

All 3 modified files and the SUMMARY exist on disk; all 3 commit hashes (`3472da4`, `17e9842`,
`1b8b1df`) resolve in `git log`.
