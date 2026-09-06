# Quick Task 260906-w19: Merge git sync indicators into one mutually exclusive subsegment - Research

**Researched:** 2026-09-06
**Domain:** bash statusline rendering (single-file change + tests + docs)
**Confidence:** HIGH — all findings from reading the repo files this session

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Detached → the short commit hash label IS the indicator, colored **red** (was magenta); no sync glyph.
- No-upstream (not detached) → keep today's red `≢`.
- Ahead AND behind → show both arrows with counts, e.g. `↓1 ↑2`, all **red**; keep existing order (behind first, then ahead).
- Behind only → **yellow** `↓B`. Ahead only → **blue** `↑A`. In sync (upstream, ahead=0, behind=0) → **green** `≡`.
- Stash `#N` → **cyan** (was dim).

### Claude's Discretion
- Exact ordering/spacing within the subsegment; keeping the existing `↓N ↑N` order.
- Dirty star (`*` yellow) and non-detached branch label color (magenta) stay unchanged.
- Update tests/fixtures, README legend, and spec docs if they encode the old colors/behavior.

### Deferred Ideas (OUT OF SCOPE)
None recorded.
</user_constraints>

## Summary

The change is confined to `seg_git` in `kit/files/home/.claude/statusline.sh` (lines 139–183), plus test assertions in `tests/run.sh` (section 8) and three docs (README.md, project-brief.md, .planning/PROJECT.md) + the spec table in `.claude/CLAUDE.md`. Key behavioral consequence the planner must not miss: making the states mutually exclusive **changes plain-text output**, not just colors — `≡` disappears whenever `↓`/`↑` render, so three exact-equality text assertions in `run.sh` break, not only the byte-color ones. Fixture JSONs and `render-fixtures.sh` are unaffected (fixtures point `current_dir` at `/tmp/myproject`, not a repo, so no git segment renders there).

**Primary recommendation:** Replace the current independent `≡/≢` + `↓` + `↑` appends with one bash-3.2-safe if/elif chain implementing the 6 mutually exclusive states from CONTEXT, change `${DIM}#` to `${CYAN}#`, and render the detached label with `$RED` instead of `$MAGENTA`; then update `run.sh` sections 8.2/8.6 and the four docs.

## Current Implementation (verified this session)

`[VERIFIED: kit/files/home/.claude/statusline.sh:173-182]` — the exact code to replace:

```bash
out="${MAGENTA}${label}${RESET}"
[ "$dirty" -eq 1 ] && out="${out}${YELLOW}*${RESET}"
if [ "$detached" -eq 0 ]; then              # D-25: no sync symbol when detached
  if [ "$upstream" -eq 1 ]; then out="${out} ${GREEN}≡${RESET}"
  else out="${out} ${RED}≢${RESET}"; fi     # red is the user's explicit choice (D-19)
fi
[ "$behind" -gt 0 ] && out="${out} ${YELLOW}↓${behind}${RESET}"
[ "$ahead" -gt 0 ]  && out="${out} ${GREEN}↑${ahead}${RESET}"
[ "$stash" -gt 0 ]  && out="${out} ${DIM}#${stash}${RESET}"
```

Facts that make the edit easy:

- `RED`, `GREEN`, `YELLOW`, `BLUE`, `MAGENTA`, `CYAN`, `DIM` are all already defined at the top of the script `[VERIFIED: statusline.sh:26-33]` — quote: `BLUE=$'\033[34m'`, `CYAN=$'\033[36m'`. No new variables needed. BLUE is currently used only for the directory segment, CYAN only for the model name — reusing them in git is a semantic overlap the user accepted implicitly by choosing these colors.
- `detached=1` is already computed and `label` already holds the short SHA when detached `[VERIFIED: statusline.sh:166-170]`. The only detached change is `MAGENTA` → `RED` on the label span — but note the label assignment is shared with the branch case, so the color pick must branch: e.g. `if [ "$detached" -eq 1 ]; then out="${RED}${label}${RESET}"; else out="${MAGENTA}${label}${RESET}"; fi`.
- `ahead`/`behind` are guarded to integers before arithmetic `[VERIFIED: statusline.sh:164-165]`; `[ "$ahead" -gt 0 ]` style tests are safe as-is.
- The whole function is composed with plain string appends and if/elif — no bash-4 features needed for the new chain.

### Suggested new sync block (drop-in, bash 3.2-safe)

```bash
out=...label span (red when detached, magenta otherwise)...
[ "$dirty" -eq 1 ] && out="${out}${YELLOW}*${RESET}"
if [ "$detached" -eq 0 ]; then
  if [ "$upstream" -eq 0 ]; then           out="${out} ${RED}≢${RESET}"
  elif [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
                                           out="${out} ${RED}↓${behind}${RESET} ${RED}↑${ahead}${RESET}"
  elif [ "$behind" -gt 0 ]; then           out="${out} ${YELLOW}↓${behind}${RESET}"
  elif [ "$ahead" -gt 0 ]; then            out="${out} ${BLUE}↑${ahead}${RESET}"
  else                                     out="${out} ${GREEN}≡${RESET}"
  fi
fi
[ "$stash" -gt 0 ] && out="${out} ${CYAN}#${stash}${RESET}"
```

Discretion note: per-token coloring (`${RED}↓2${RESET} ${RED}↑3${RESET}` — two spans with a plain space between) matches the existing whole-token color convention asserted by the byte tests; a single red span covering both arrows would also satisfy the spec but breaks the established "each marker is one colored unit" pattern (PROJECT.md line 115).

## Test Impact (tests/run.sh, section 8)

`[VERIFIED: tests/run.sh:330-434]` — assertions that break and how:

| Line | Assertion | Old expected | New expected |
|------|-----------|--------------|--------------|
| 353 | `git clean in-sync: line 1` (plain text) | `... main ≡` | **unchanged** (in-sync still shows `≡`) |
| 366 | `git boundary ones: line 1` (plain text) | `... main ≡ ↓1 ↑1 #1` | `... main ↓1 ↑1 #1` — `≡` gone (mutually exclusive) |
| 381 | `git full form: line 1` (plain text) | `... main* ≡ ↓2 ↑3 #2` | `... main* ↓2 ↑3 #2` |
| 415-417 | `git color bytes` (full form, raw ANSI) | `${ESC}[32m≡` present; `${ESC}[33m↓2`, `${ESC}[32m↑3`, `${ESC}[2m#2` | drop `≡` span; `${ESC}[31m↓2${ESC}[0m ${ESC}[31m↑3` (both red — full form is ahead+behind); `${ESC}[36m#2` (cyan) |
| 420-422 | red `≢` byte check | `${ESC}[31m≢` | **unchanged** |
| 396, 405, 410 | no-upstream / detached / unborn plain text | — | **unchanged** (glyphs/text identical; only colors changed) |
| 427-434 | git palette purity whitelist | `0m 2m 31m 32m 33m 34m 35m 36m` | **unchanged** — 36m (cyan) and 34m (blue) already whitelisted |

Coverage gaps worth closing while touching the tests (all states now carry distinct colors but only full-form + `≢` have byte checks):
- No byte assertion exists for the detached label color (magenta today) — add one for `${ESC}[31m$DSHA` (red) at the 8.4 detached scenario.
- No scenario exercises behind-only (yellow) or ahead-only (blue) in isolation. The existing repos make this cheap: repo `W` passes through an ahead-only state at line 363 (before the behind commit exists) — but simplest is two small byte checks on intermediate renders or one new tiny repo pair. Planner's call; plain-text coverage of the counts already exists.

`tests/render-fixtures.sh` and `tests/fixtures/*.json`: **no changes** — fixtures set `workspace.current_dir` to `/tmp/myproject` (verified via `jq` on `full.json`), which is not a repo, so the git segment never renders in fixture dumps.

## Docs Impact

| File | What encodes old behavior | Change |
|------|---------------------------|--------|
| `README.md:8` | example line `main* ≡ ↓2 ↑3 #2` | drop `≡` → `main* ↓2 ↑3 #2` |
| `README.md:23` | legend row `≡ / ≢ — Branch has / has no upstream` | rework: `≡` = in sync with upstream (green); `≢` = no upstream (red); shown mutually exclusively with the arrows |
| `README.md:24-26` | `↓2` / `↑3` / `#2` rows | optionally add colors: behind yellow, ahead blue, both red when combined; stash cyan; detached SHA red |
| `project-brief.md:17-20,30` | `main* ≡` semantics + example `main* ≡ ↓2 ↑3 #2` | same rework as README |
| `.planning/PROJECT.md:21,35,115` | example line; `branch_status` prose; "Semantic per-marker git colors (magenta branch, yellow `*`/`↓N`, green `≡`/`↑N`, red `≢`, dim `#N`)" | update all three spots |
| `.claude/CLAUDE.md:104` | `# branch.upstream <ref> → present ⇒ ≡, absent ⇒ ≢` | update the mapping note (upstream present now means `≡` only when ahead=behind=0) |

Precedent: quick task 260827-02m updated exactly these "three live spec docs" (README, project-brief, PROJECT.md/CLAUDE.md) for the branch-glyph drop — follow the same commit pattern.

## Superseded Decisions

`[VERIFIED: .planning/milestones/v1.0-phases/02-git-segment/02-CONTEXT.md:19,29-30]`:

- **D-19** — "dirty `*` yellow, `≡` green, `≢` red" — *partially superseded*: `*` yellow and `≢` red survive; `≡` green survives but now only in the in-sync state; the yellow-`↓`/green-`↑` scheme (D-17/D-18 area, byte-asserted in 02-02-PLAN.md) is replaced by yellow/blue/red-pair.
- **D-24** — detached shows short SHA as the label — *kept*, but the color moves magenta → red.
- **D-25** — sync symbol hidden entirely when detached — *kept and generalized*: sync states are now mutually exclusive everywhere.
- Dim stash (part of the D-20 color set) — superseded by cyan.

Milestone archive files under `.planning/milestones/` are historical records — do **not** edit them; note supersession in the quick-task SUMMARY instead.

## Common Pitfalls

1. **Forgetting the plain-text change.** The `≡`-hidden-when-arrows-shown rule changes stripped output; updating only the ANSI byte test at run.sh:415 leaves 366/381 failing. Update all of 366, 381, 415.
2. **Test names carry color descriptions.** run.sh:417 check name says "yellow ↓2, green ↑3, dim #2" — rename to match the new colors so a future reader isn't misled.
3. **Detached label color must branch.** Line 173 colors the label unconditionally magenta; the red-when-detached pick has to happen after `detached` is known (it is — `detached` is set at line 168 before line 173 executes).
4. **Unborn branch (`(initial)` head, no upstream)** falls into the `≢` state — unchanged behavior, run.sh:410 confirms; don't accidentally route it into the ahead/behind arithmetic (ahead/behind are 0 there, guards at 164-165 hold).
5. **Comment block above `seg_git` (lines 139-143)** describes "green/red sync symbol, yellow behind / green ahead counts, dim stash" — update the comment with the code or the file self-documents wrongly.

## Sources

- `kit/files/home/.claude/statusline.sh` — read in full this session. HIGH
- `tests/run.sh:330-434` — read this session. HIGH
- `tests/render-fixtures.sh`, `tests/fixtures/full.json` — read/queried this session. HIGH
- `README.md`, `project-brief.md`, `.planning/PROJECT.md`, `.claude/CLAUDE.md` — grepped + read relevant lines this session. HIGH
- `.planning/milestones/v1.0-phases/02-git-segment/02-CONTEXT.md` — D-19/D-24/D-25 verbatim. HIGH

## Assumptions Log

None — all claims verified against repo files this session.
