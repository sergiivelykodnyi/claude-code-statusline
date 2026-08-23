# Phase 2: Git Segment - Context

**Gathered:** 2026-08-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 adds the git segment to line 1 — `⎇ branch* ≡/≢ ↓N ↑N #N` (branch, dirty marker, upstream sync symbol, ahead/behind counts, stash count) — correct in every repo state (clean, dirty, detached HEAD, no-upstream, unborn/empty repo, not-a-repo), within the render-latency budget (PORT-02). It also applies the layout correction: the `╭─ `/`╰─ ` frame prefixes from Phase 1 are removed, with all other segments, separators, and colors unchanged. Requirements: GIT-01..06, PORT-02. Excludes: install/README (Phase 3), Fable `f()` segment (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Git segment colors (semantic per-marker)
- **D-17:** The git segment uses semantic per-marker coloring — each marker is colored by what it signals, not one uniform segment color. Chosen for maximal glanceability per the project's core value.
- **D-18:** Branch name and the `⎇` glyph render in **magenta** — the only unclaimed strong ANSI-16 color (cyan=model, blue=dir; green/yellow/red carry threshold/state semantics).
- **D-19:** State markers: dirty `*` = **yellow**, `≡` (has upstream) = **green**, `≢` (no upstream) = **red**. User explicitly chose this hybrid — red is intentionally used for the no-upstream state even though Phase 1 reserved red for critical usage thresholds.
- **D-20:** Counts: `↓N` (behind) = **yellow**, `↑N` (ahead) = **green**, `#N` (stashes) = **dim**.
- All colors remain ANSI named-16 only, per D-02 (light/dark theme portability — hard requirement).

### Frame removal (layout correction)
- **D-21:** The `╭─ ` and `╰─ ` frame prefixes are removed; both lines render flush-left. Supersedes the frame aspects of Phase 1's D-11/D-13.
- **D-22:** When line 2 has zero segments, print a **blank second line** — output is always exactly two lines, so the layout never jumps between renders (preserves D-11's stability goal without the frame).
- **D-23:** Worst-case fallback (malformed/empty stdin, jq failure): line 1 is the bare blue directory basename from `$PWD`; line 2 is blank; exit 0 (updates D-13).

### Edge-state display
- **D-24:** Detached HEAD shows the short (7-char) commit SHA in the branch position, e.g. `⎇ a1b2c3d` — obtained via `git rev-parse --short HEAD` (one extra cheap call, accepted). Not the literal `(detached)`.
- **D-25:** In detached HEAD, the sync symbol (`≡`/`≢`) is **hidden entirely** — the upstream concept doesn't apply to a detached commit, and a red `≢` during rebase/bisect would be false alarm.
- **D-26:** Unborn branch (empty repo, no commits): render the branch name porcelain reports as usual, with `≢` (and `*` when files are staged/untracked) — no special case.
- **D-27:** `↓N`/`↑N` render only when porcelain reports `branch.ab` and the value is nonzero; `#N` only when stash count > 0; zero-value counters never appear (GIT-04/05, roadmap criterion 3).

### Latency verification (PORT-02)
- **D-28:** `tests/run.sh` gains a timed assertion: a full render against a real-repo fixture must complete under a hard threshold (generous enough to avoid flakiness, well under the 300ms debounce). Regression-proof as Phases 3–4 grow the script.
- **D-29:** Git lookups stay **uncached** — two fast git calls per render (~15ms total) are well within budget for the target repo sizes. The session-keyed TTL cache from official docs remains a documented future lever, not day-one complexity.

### Claude's Discretion
- Whether threshold/marker color spans symbol+number together or separately (e.g. all of `↓2` yellow vs just the arrow).
- Exact latency threshold value and portable timing mechanism in `tests/run.sh` (must work on BSD and GNU userland).
- porcelain v2 parsing structure within the prescriptive constraints (single primary `git status --porcelain=v2 --branch` call, `GIT_OPTIONAL_LOCKS=0`, `git -C "$DIR"`, stash via `git rev-list --walk-reflogs --count refs/stash`).
- How the git segment attaches to line 1 (the marked seam at `statusline.sh:141` — appended to `dir_seg` with a plain space).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Layout & requirements
- `project-brief.md` — authoritative target layout, git symbol definitions (`⎇ main* ≡ ↓2 ↑3 #2`), whole-line examples
- `.planning/REQUIREMENTS.md` — GIT-01..06 and PORT-02 (the 7 requirements this phase covers)

### Verified technical facts (research)
- `.planning/research/STACK.md` — porcelain v2 field mapping (`# branch.head`, `# branch.upstream`, `# branch.ab`, non-`#` lines ⇒ dirty), `GIT_OPTIONAL_LOCKS=0`, stash counting, bash 3.2 portability rules, what NOT to use
- `.planning/research/PITFALLS.md` — known failure modes to design against
- `.planning/research/ARCHITECTURE.md` — intended script structure and segment assembly approach

### Existing code (Phase 1 output — the modification target)
- `statusline.sh` — the script this phase extends; git seam marked at the line-1 assembly comment ("Phase 2 seam")
- `tests/run.sh` + `tests/fixtures/*.json` — the never-fail test harness this phase extends with git states and the timed latency assertion

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `join_segments` (statusline.sh): separator-joining with empty-skip — git segment just returns `""` outside a repo and the seam handles hiding
- Color constants (`RESET/DIM/RED/GREEN/YELLOW/BLUE/CYAN`): add `MAGENTA=$'\033[35m'` alongside — same ANSI-16 pattern
- Segment-renderer pattern (`seg_*` functions echo their segment or empty string): the git segment should be another `seg_git`-style renderer
- `tests/run.sh` + fixture JSON files: extend with git-state scenarios (temp repos) and the latency assertion

### Established Patterns
- bash 3.2-compatible syntax, `#!/bin/bash` shebang (macOS constraint)
- Single jq pass with `@sh`-quoted eval; `// ""` absent/null mapping
- `printf '%b'`/`$'\033[...]'` literals, never `echo -e`
- Never-fail contract: no `set -e`/`set -u`, unconditional `exit 0`, nothing on stderr
- Source guard at bottom allows the test harness to source helpers without executing `main`

### Integration Points
- Git segment attaches at the marked seam in `main()` (`statusline.sh:141`): `dir_seg="$dir_seg $git_seg"` before the line-1 join
- Frame removal touches the `LINE1=`/`LINE2=` assembly and the D-11/D-13 fallback branches in `main()`
- Directory for git queries comes from `$DIR` (stdin `.workspace.current_dir`), falling back to `$PWD` — use `git -C`

</code_context>

<specifics>
## Specific Ideas

- Full-state example the segment must match: `⎇ main* ≡ ↓2 ↑3 #2` with magenta branch, yellow `*`, green `≡`, red `≢`, yellow `↓`, green `↑`, dim `#`.
- Detached example: `⎇ a1b2c3d #2` — short SHA, no sync symbol.
- The user explicitly accepts red on `≢` as a second meaning for red beyond critical thresholds — do not "fix" this back to yellow.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Git Segment*
*Context gathered: 2026-08-21*
