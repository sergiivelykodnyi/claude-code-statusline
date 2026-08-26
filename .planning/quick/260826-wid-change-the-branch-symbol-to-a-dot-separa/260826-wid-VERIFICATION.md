---
phase: quick-260826-wid
verified: 2026-08-26T21:15:00Z
status: human_needed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Refresh ~/.claude/statusline.sh from kit/files/home/.claude/statusline.sh, then render the status line in a real terminal inside a git repo."
    expected: "Line 1 reads `Opus 5 (high) · <dir> · <branch>…` — the dim `·` sits between directory and branch, the branch is magenta with no glyph, and `* ≡ ↓N ↑N #N` remain space-joined to it. Outside a repo it collapses to `… · <dir>` with no trailing separator."
    why_human: "Byte-level rendering is fully verified programmatically (see below); what remains is subjective visual acceptance of the `·` at the user's terminal font/theme, and it only becomes visible after the user refreshes their installed copy — explicitly out of scope for this task."
---

# Quick Task 260826-wid: Dot-Separated Git Segment — Verification Report

**Task Goal:** Change the branch symbol `⎇` to the dot separator ` · ` so Git becomes a separate line-1 segment.
**Verified:** 2026-08-26
**Status:** human_needed (all automated must-haves verified; one visual acceptance item outstanding)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Line 1 renders `<model> · <dir> · <branch>…` — branch joined by the dim dot, still MAGENTA, no glyph prefix | ✓ VERIFIED | Rendered against this repo. Raw bytes: `^[[34mclaude-code-statusline^[[0m ^[[2m·^[[0m ^[[35mmain^[[0m^[[33m*^[[0m …`. SGR-35 (magenta) intact, dim-dot joiner immediately precedes the label, `grep -F '⎇'` on the output returns no match. |
| 2 | Git sub-parts stay space-joined inside one git segment — exactly ONE new separator introduced | ✓ VERIFIED | Line 1 contains exactly **2** dim-dot separators (model↔dir, dir↔git); pre-change it had 1. Sub-parts render as `main* ≡ ↑3` with plain spaces. Exactly **1** magenta span on line 1, proving the old splice is gone (no double-render). |
| 3 | Outside a git repo, line 1 ends at the directory basename with no dangling separator (GIT-01) | ✓ VERIFIED | Rendered against `/tmp/myproject`: `^[[36mOpus 5^[[0m ^[[2m(high)^[[0m ^[[2m·^[[0m ^[[34mmyproject^[[0m^[[0m` — terminates at the blue directory span. Test `git not-a-repo: line 1` PASS. |
| 4 | `/bin/bash tests/run.sh` reports `220 checks, 0 failures` | ✓ VERIFIED | Suite executed by the verifier: final line `220 checks, 0 failures`. Baseline check count unchanged. |
| 5 | tests/run.sh section 8.6 now fails if the dir↔git dot join is missing (no longer a glyph-only substring match) | ✓ VERIFIED | **Mutation-tested independently.** Built a throwaway copy with the glyph removed but the old splice restored (the exact silent-pass scenario); its line 1 renders `…^[[34m…^[[0m ^[[35mmain…` with a plain space. The hardened `want` fragment did **not** match it (POLARITY GOOD), while it does match the real script (SANITY OK). |
| 6 | statusline.sh exits 0 with 0 bytes on stderr (never-fail contract) | ✓ VERIFIED | In-repo: `exit=0 stderr_bytes=0`. Non-repo: `exit=0 stderr_bytes=0`. `bash -n` syntax check passes under `/bin/bash` 3.2.57. |
| 7 | README's sample line and symbol legend match the shipped rendering | ✓ VERIFIED | README:8 = `Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2`, matching test 8.3's exact-equality expectation. Legend row is now `` | `main` | Current branch … `` . `grep '⎇' README.md` → no match. |

**Score:** 7/7 truths verified (0 present, behavior-unverified)

Every behavior-dependent truth (1, 2, 3, 5, 6) was confirmed by actually running the script or the
suite in this verifier's own process — none rests on symbol presence alone.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kit/files/home/.claude/statusline.sh` | Glyph removed, splice deleted, git passed as 4th join argument | ✓ VERIFIED | 11 lines changed. `:139` comment refreshed, `:173` → `out="${MAGENTA}${label}${RESET}"`, `:410-412` splice replaced by the 4th argument. Executable, syntax-clean, wired via `main()`. |
| `tests/run.sh` | Six expectations updated, 8.6 hardened, 337 untouched | ✓ VERIFIED | 20 lines changed (10+/10−). All six stripped-line-1 expectations now expect ` · `; 8.6 `want` extended leftward through the dir span and joiner. |
| `README.md` | Sample line + legend row match rendering | ✓ VERIFIED | 4 lines changed (2+/2−). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `main()` | `join_segments` | `"$git_seg"` as 4th argument | ✓ WIRED | `statusline.sh:412`: `body=$(join_segments "$sep" "$model_seg" "$dir_seg" "$git_seg")`. |
| `main()` | (old splice) | `dir_seg="$dir_seg${git_seg:+ $git_seg}"` | ✓ REMOVED | `grep -n 'dir_seg'` returns only `:379` (local), `:408` (assign), `:412` (join arg). The splice is gone — confirmed behaviorally by the single-magenta-span count. |
| `join_segments` | GIT-01 | `[ -n "$part" ]` empty-skip | ✓ WIRED | `statusline.sh:116`. Sole mechanism preserving GIT-01; proven by the non-repo render terminating at the directory span. |
| `sep` (D-01) | line 1 join | single definition, reused | ✓ VERIFIED | `grep -cF 'sep=" ${DIM}·${RESET} "'` = **1** (line 405). The only other `sep=` is `join_segments`' positional parameter `local sep="$1"` (line 114), which is a function argument binding, not a second separator definition. |
| `tests/run.sh:415` | dir↔git joiner | `want` spans the joiner | ✓ WIRED | Mutation test (truth 5) proves the guard is live, not decorative. |
| `tests/run.sh:337` | GIT-01 regression guard | byte-identical | ✓ UNCHANGED | Absent from `git diff 413c800..HEAD -- tests/run.sh`. Only the *comment* at :333 changed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `seg_git()` | `label` | `git status --porcelain=v2 --branch` → `# branch.head` | Yes — rendered `main` matches `git rev-parse --abbrev-ref HEAD` | ✓ FLOWING |
| `main()` | `git_seg` | `$(seg_git)` command substitution | Yes — flows into `join_segments` positional args | ✓ FLOWING |
| `main()` | `LINE1` | `join_segments` output + `$RESET` | Yes — printed to stdout | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| In-repo line 1 carries the dim-dot joiner before a magenta branch | render `full.json` with `current_dir=$PWD`, `grep -qF $'\033[2m·\033[0m \033[35m'"$BR"` | match | ✓ PASS |
| Git segment rendered exactly once (splice deleted) | count `\033[35m` occurrences on line 1 | `1` | ✓ PASS |
| GIT-01 — non-repo line 1 ends at directory span | render with `current_dir=/tmp/myproject`, case-match tail | matches `…\033[34mmyproject\033[0m\033[0m` | ✓ PASS |
| Separator defined exactly once (D-01) | `grep -cF 'sep=" ${DIM}·${RESET} "'` | `1` | ✓ PASS |
| `git_seg` retained in `main()`'s locals (CTX-9) | `grep -cF 'local input vars sep model_seg dir_seg git_seg body'` | `1` | ✓ PASS |
| Never-fail contract, non-repo | run, capture `$?` and stderr size | `exit=0 stderr_bytes=0` | ✓ PASS |
| Never-fail contract, in-repo | run, capture `$?` and stderr size | `exit=0 stderr_bytes=0` | ✓ PASS |
| bash 3.2 syntax validity | `/bin/bash -n kit/files/home/.claude/statusline.sh` | clean (bash 3.2.57) | ✓ PASS |
| Full regression suite | `/bin/bash tests/run.sh` | `220 checks, 0 failures` | ✓ PASS |
| 8.6 hardening polarity (anti-silent-pass) | mutant with glyph removed + splice restored vs. hardened `want` | no match on mutant, match on real script | ✓ PASS |
| Out-of-scope docs untouched | `git diff --name-only 413c800..HEAD` | exactly `README.md`, `kit/files/home/.claude/statusline.sh`, `tests/run.sh` | ✓ PASS |

Named git checks all reported PASS by name in the suite output: `git not-a-repo: line 1`,
`git clean in-sync: line 1`, `git boundary ones: line 1`, `git full form: line 1`,
`git no-upstream verbatim branch: line 1`, `git detached: line 1`, `git unborn: line 1`,
`git color bytes: dim · joiner, magenta branch, yellow *, green ≡, yellow ↓2, green ↑3, dim #2`.

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` exist in this repo and the plan declares none.
`tests/run.sh` is the project's regression harness and was executed (see above).

### Requirements Coverage

`.planning/REQUIREMENTS.md` was removed with the v1.0 milestone archive (commit `413c800`), so the
IDs declared in the plan frontmatter are cross-referenced against their in-repo definitions
(comments in `statusline.sh` and assertions in `tests/run.sh`).

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GIT-01 | 260826-wid-PLAN | Git segment hidden entirely outside a repo, no dangling separator | ✓ SATISFIED | Non-repo render ends at the directory span; guard at `tests/run.sh:337` unchanged and PASS. |
| D-01 | 260826-wid-PLAN | Single dim dot separator `" ${DIM}·${RESET} "` | ✓ SATISFIED | Exactly one definition at `statusline.sh:405`, reused for both lines. |
| D-14 | 260826-wid-PLAN | `join_segments` skips empty parts (hide-over-placeholder) | ✓ SATISFIED | `statusline.sh:116` `[ -n "$part" ]`; now the sole mechanism upholding GIT-01, proven behaviorally. |

No orphaned requirements — the plan's `requirements: [GIT-01, D-01, D-14]` are fully accounted for.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `kit/files/home/.claude/statusline.sh` | 163 | Comment `# defensive: never render a bare glyph` — wording is now stale (there is no glyph; the guard prevents an empty magenta span) | ℹ️ Info | Cosmetic only. The guard itself is correct and load-bearing. CTX-7 gave comment updates to Claude's discretion and the plan mandated only line 139. |

No `TBD`, `FIXME`, `XXX`, `HACK`, `TODO` or `PLACEHOLDER` markers in any modified file. The
`XXXXXX` hits in `statusline.sh:293` and `tests/run.sh:51-52` are `mktemp` templates, not debt
markers. No stubs, no empty implementations, no hardcoded-empty data introduced.

### Cross-Check Against SUMMARY.md Claims

| SUMMARY claim | Independently confirmed? |
|---------------|--------------------------|
| `220 checks, 0 failures` | Yes — suite re-run by the verifier |
| Splice deleted, 4th argument added | Yes — read from source and proven by the single-magenta-span count |
| Branch keeps MAGENTA | Yes — SGR-35 present in raw output |
| Exactly one new separator; sub-parts space-joined | Yes — 2 dim dots on line 1, sub-parts space-joined in raw bytes |
| `tests/run.sh:337` byte-identical | Yes — absent from `git diff` |
| 8.6 hardening proven, not assumed | Yes — verifier ran its own independent mutation test |
| Diffstat `3 files changed, 17 insertions(+), 18 deletions(-)` | Yes — `git diff --shortstat 413c800..HEAD` matches exactly |
| Commits `3472da4`, `17e9842`, `1b8b1df` resolve | Yes — all three in `git log` |

No SUMMARY claim was found to overstate the codebase state.

### Human Verification Required

#### 1. Live-terminal visual acceptance of the dot-joined git segment

**Test:** Refresh `~/.claude/statusline.sh` from `kit/files/home/.claude/statusline.sh`, then render the status line in a real terminal inside a git repo, and again in a non-repo directory.
**Expected:** Line 1 reads `Opus 5 (high) · <dir> · <branch>…` — the dim `·` sits between directory and branch, the branch is magenta with no glyph, and `* ≡ ↓N ↑N #N` remain space-joined to it. Outside a repo it collapses to `… · <dir>` with no trailing separator.
**Why human:** The byte-level rendering is fully verified above; what remains is subjective visual acceptance of the `·` at the user's terminal font/theme. It also only becomes visible after the user refreshes their installed copy.

### Known and Accepted (not gaps)

- **`~/.claude/statusline.sh` is a stale regular-file copy** still containing 2 occurrences of `⎇`. Refreshing it is the user's environment and was explicitly out of scope. `tests/render-fixtures.sh`'s repo↔installed diff (PORT-04) will report a difference until it is refreshed — deliberately not used as a gate.
- **`project-brief.md` and `.planning/PROJECT.md` still specify `⎇`** and now disagree with the shipped script. Recorded as an explicit user decision in CONTEXT.md. Confirmed untouched, along with `.claude/CLAUDE.md`, `.planning/RETROSPECTIVE.md`, `.planning/milestones/*` and `.planning/research/*`.

### Gaps Summary

No gaps. All seven must-have truths hold in the codebase with runtime evidence, both key links are
correctly wired (git added as a fourth join argument, old splice removed), the GIT-01 regression
guard is byte-identical, exactly one separator definition exists, the regression suite is green at
its unchanged 220-check baseline, and the change is confined to the three in-scope files.

The section 8.6 hardening — the part most likely to have been claimed but not delivered — was
independently mutation-tested and genuinely fails the glyph-only scenario it exists to catch.

Status is `human_needed` rather than `passed` solely because the plan carries a `<human-check>` for
visual confirmation in a live terminal, which cannot be discharged programmatically.

---

_Verified: 2026-08-26_
_Verifier: Claude (gsd-verifier)_
