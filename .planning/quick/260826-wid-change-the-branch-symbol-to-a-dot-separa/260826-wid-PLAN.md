---
phase: quick-260826-wid
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - kit/files/home/.claude/statusline.sh
  - tests/run.sh
  - README.md
autonomous: true
requirements: [GIT-01, D-01, D-14]

estimate:
  tokens: 34000
  raw_tokens: 17000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "In a git repo, line 1 renders `<model> · <dir> · <branch>…` — the branch label is joined to the directory by the dim dot separator, is still MAGENTA, and carries no glyph prefix"
    - "Git sub-parts (`*`, `≡`/`≢`, `↓N`, `↑N`, `#N`) stay space-joined to the branch inside one git segment — exactly one new separator is introduced"
    - "Outside a git repo, line 1 still ends at the directory basename with no dangling separator (GIT-01 preserved)"
    - "`/bin/bash tests/run.sh` reports `220 checks, 0 failures` (unchanged check count)"
    - "tests/run.sh section 8.6 raw-ANSI expectation now fails if the dir↔git dot join is missing — it is no longer a glyph-only substring match that could silently pass"
    - "statusline.sh still exits 0 and writes 0 bytes to stderr outside a repo (never-fail contract)"
    - "README's sample line and symbol legend match the shipped rendering"
  artifacts:
    - kit/files/home/.claude/statusline.sh
    - tests/run.sh
    - README.md
  key_links:
    - "main() must BOTH pass `\"$git_seg\"` as a 4th argument to join_segments AND delete the `dir_seg=\"$dir_seg${git_seg:+ $git_seg}\"` splice — keeping both renders the git segment twice"
    - "join_segments' `[ -n \"$part\" ]` empty-skip (D-14/PRES-04) is the sole mechanism preserving GIT-01 once git becomes its own argument"
    - "The single `sep=\" ${DIM}·${RESET} \"` definition (D-01) is reused — a second separator definition must not be introduced"
    - "tests/run.sh:415 `want` must span the dir↔git joiner, otherwise its substring match passes a glyph-only fix"
    - "tests/run.sh:337 not-a-repo assertion must stay byte-identical — it is the GIT-01 regression guard"
---

<objective>
Promote the git segment on line 1 from a space-attached suffix of the directory into a first-class
segment joined by the existing dim dot separator, and drop the branch glyph prefix.

Current: `Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2`
Target:  `Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2`

Purpose: line 1 gets one consistent segment joiner, and the rarer 3-byte glyph is replaced by the
`·` already proven on both lines. Git keeps its magenta identity and its internal space-joined
structure.

Output: three edited files — `kit/files/home/.claude/statusline.sh` (the rendering change),
`tests/run.sh` (regression expectations, hardened so they cannot silently pass), `README.md` (docs).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/260826-wid-change-the-branch-symbol-to-a-dot-separa/260826-wid-CONTEXT.md
@.planning/quick/260826-wid-change-the-branch-symbol-to-a-dot-separa/260826-wid-RESEARCH.md
@.claude/CLAUDE.md

Binding project rules for this edit: bash 3.2-compatible syntax only; no `set -e`/`set -u` added;
hide-over-placeholder for empty segments. RESEARCH.md carries every edit point with verified line
numbers and verbatim before/after strings — use them directly, do not re-derive.

Pitfall (RESEARCH.md §5.6): prefer the Edit tool over `sed`/`perl` in-place for the lines containing
multi-byte characters; BSD `sed` under a non-UTF-8 locale can mangle them.
</context>

<source_audit>
## Multi-Source Coverage Audit

No ROADMAP goal or REQUIREMENTS.md apply (quick task). Sources are CONTEXT.md (locked decisions) and
RESEARCH.md (verified edit points).

| ID | Source item | Covered by |
|----|-------------|-----------|
| CTX-1 | Branch keeps MAGENTA; only the glyph + its trailing space are removed | Task 1 |
| CTX-2 | Exactly ONE dot separator added (dir↔git); git sub-parts stay space-joined | Task 1 |
| CTX-3 | Delete the `dir_seg="$dir_seg${git_seg:+ $git_seg}"` splice; pass `"$git_seg"` to join_segments | Task 1 |
| CTX-4 | Reuse the existing `sep` (D-01) — no second separator definition | Task 1 (count gate) |
| CTX-5 | Docs in scope: README.md and tests/run.sh only | Tasks 2, 3 |
| CTX-6 | project-brief.md, .planning/PROJECT.md, archived .planning/* out of scope | All tasks — `files_modified` is exactly the 3 in-scope files |
| CTX-7 | Discretion: refresh the segment header comment at statusline.sh:139 | Task 1 |
| CTX-8 | Discretion: README symbol-row wording | Task 3 |
| CTX-9 | Discretion: keep or inline `git_seg` → decision: KEEP the local variable | Task 1 |
| R-1 | statusline.sh:173 glyph removal | Task 1 |
| R-2 | statusline.sh:410-413 comment + splice + 4th argument | Task 1 |
| R-3 | statusline.sh:139 comment refresh | Task 1 |
| R-4 | Keep `git_seg` in the `local` list at statusline.sh:379 | Task 1 (gate) |
| R-5 | Seven glyph sites in tests/run.sh (353, 366, 381, 396, 405, 410, 415) | Task 2 |
| R-6 | Extend the :415 `want` through the joiner (anti-silent-pass) | Task 2 |
| R-7 | tests/run.sh:337 must not change (GIT-01 guard) | Task 2 (gate) |
| R-8 | Cosmetic comment refreshes at tests/run.sh:333, 413 | Task 2 |
| R-9 | README.md:8 sample line, README.md:20 symbol row | Task 3 |
| R-10 | `~/.claude/statusline.sh` is a regular-file COPY, not a symlink | Noted in `<verification>`; re-installing is the user's environment — explicitly OUT of scope |
| R-11 | `tests/render-fixtures.sh` (PORT-04) diffs repo↔installed and will report a difference until the user re-copies | Noted in `<verification>` — deliberately NOT used as a gate |

No MISSING items. No gaps. Nothing is deferred beyond the out-of-scope docs the user already ruled out.
</source_audit>

<tasks>

<task type="tracer">
  <name>Task 1: Render git as its own dot-joined line-1 segment</name>
  <files>kit/files/home/.claude/statusline.sh</files>
  <precondition>The repo working tree is a git repo on a named branch — `git rev-parse --abbrev-ref HEAD` prints a branch name, not `HEAD`. The end-to-end render gate below matches that branch name inside the magenta span; on a detached HEAD it would compare against a SHA instead. Halt and report if unmet.</precondition>
  <reversibility rating="reversible">Three-line text edit in one script with a full byte-level regression harness behind it; `git revert` restores the previous rendering exactly.</reversibility>
  <action>
Make three edits, all in `kit/files/home/.claude/statusline.sh`, using the Edit tool (not sed — two of these lines contain multi-byte characters, RESEARCH.md §5.6).

1. Line 173, inside `seg_git()`: change `out="${MAGENTA}⎇ ${label}${RESET}"` to `out="${MAGENTA}${label}${RESET}"`. Remove the glyph AND its single trailing space, nothing else — the magenta span, `${label}`, and `${RESET}` are unchanged, and the branch stays MAGENTA per CTX-1. Do not touch the dirty-star, sync-glyph, ahead/behind or stash composition further down `seg_git()`: those sub-parts stay space-joined inside the one git segment (CTX-2).

2. Lines 410-413, inside `main()`: delete the splice line `dir_seg="$dir_seg${git_seg:+ $git_seg}"` entirely, and add `"$git_seg"` as a fourth argument so the join reads `body=$(join_segments "$sep" "$model_seg" "$dir_seg" "$git_seg")`. Deleting the splice is mandatory — leaving it alongside the new argument renders the git segment twice (RESEARCH.md §5.2). Replace the two-line comment above it (currently describing the Phase 2 plain-space attachment) with: `# Git is a first-class line-1 segment joined by the dim dot; join_segments` / `# skips it when empty, so outside a repo no separator leaks (GIT-01/D-14).` Reuse the `sep` already defined at line 405 (D-01/CTX-4) — do NOT add a second separator definition.

3. Line 139, the `seg_git` header comment: change its first line so it reads `# Git segment: magenta branch label, yellow dirty star, green/red sync symbol,`. Leave the remaining four comment lines untouched.

Keep `git_seg` in the `local` declaration at line 379 (CTX-9 decision: keep the variable — it matches the `model_seg`/`dir_seg` style and keeps the diff to three lines). Do not inline `$(seg_git)` into the join call.

Nothing else in the script changes: `seg_dir()`, `join_segments()`, `LINE1="${body}${RESET}"`, the line-2 join, and the unconditional `exit 0` all stay as-is. Do not add `set -e` or `set -u` (never-fail contract, RESEARCH.md §5.7). The script does no width math anywhere, so removing a 3-byte character cannot shift any layout logic.
  </action>
  <verify>
    <automated>
cd "$(git rev-parse --show-toplevel)"
BR=$(git rev-parse --abbrev-ref HEAD)
L1=$(jq --arg d "$PWD" '.workspace.current_dir=$d' tests/fixtures/full.json | /bin/bash kit/files/home/.claude/statusline.sh | sed -n 1p)
printf '%s' "$L1" | grep -qF $'\033[2m\xc2\xb7\033[0m \033[35m'"$BR" || { echo "FAIL gate1: dim-dot joiner immediately followed by the magenta branch label not found (glyph still present, or splice not replaced by the 4th join_segments arg)"; exit 1; }
[ "$(printf '%s' "$L1" | grep -oF $'\033[35m' | grep -c .)" = "1" ] || { echo "FAIL gate2: git segment rendered more than once — the old splice was not deleted"; exit 1; }
N1=$(jq '.workspace.current_dir="/tmp/myproject"' tests/fixtures/full.json | /bin/bash kit/files/home/.claude/statusline.sh | sed -n 1p)
case "$N1" in *$'\033[34mmyproject\033[0m\033[0m') : ;; *) echo "FAIL gate3: non-repo line 1 does not end at the directory span — a separator is dangling (GIT-01 broken)"; exit 1;; esac
[ "$(grep -cF 'sep=" ${DIM}·${RESET} "' kit/files/home/.claude/statusline.sh)" = "1" ] || { echo "FAIL gate4: separator is not defined exactly once (D-01)"; exit 1; }
[ "$(grep -cF 'local input vars sep model_seg dir_seg git_seg body' kit/files/home/.claude/statusline.sh)" = "1" ] || { echo "FAIL gate5: git_seg dropped from main()'s local declaration"; exit 1; }
jq '.workspace.current_dir="/tmp/myproject"' tests/fixtures/full.json | /bin/bash kit/files/home/.claude/statusline.sh >/dev/null 2>"$TMPDIR/qt-err"; RC=$?
[ "$RC" = "0" ] && [ ! -s "$TMPDIR/qt-err" ] || { echo "FAIL gate6: never-fail contract broken (exit $RC / non-empty stderr)"; exit 1; }
echo "OK"
    </automated>
  </verify>
  <done>Rendering against this repo, line 1 shows the directory and the branch joined by the dim `·`, with the branch label magenta and unprefixed, and the git sub-parts still space-joined. Rendering against a non-repo directory, line 1 ends at the directory basename with no trailing separator, exit code 0 and empty stderr. Exactly one separator definition and one magenta span remain.</done>
</task>

<task type="auto">
  <name>Task 2: Update and harden the git regression expectations</name>
  <files>tests/run.sh</files>
  <action>
Update the seven expectation sites in section 8 of `tests/run.sh` (verbatim old/new pairs in RESEARCH.md §3 — line numbers 353, 366, 381, 396, 405, 410, 415 verified against the current file). In each of the six stripped-line-1 `check_eq` expectations, the plain space between the directory name and the branch becomes ` · ` and the glyph plus its trailing space go away: line 353 becomes `"Opus 5 (high) · w · main ≡"`, line 366 `"Opus 5 (high) · w · main ≡ ↓1 ↑1 #1"`, line 381 `"Opus 5 (high) · w · main* ≡ ↓2 ↑3 #2"`, line 396 `"Opus 5 (high) · noup · feature/x-1 ≢"`, line 405 `"Opus 5 (high) · det · $DSHA"` (keep the `$DSHA` interpolation), line 410 `"Opus 5 (high) · unborn · main* ≢"`.

Line 415 is the one that matters most. It is a `case`-based SUBSTRING match on the raw bytes, so a minimal glyph-only fix there would pass even if the dir↔git join were never made (RESEARCH.md §3). Extend the expectation leftward through the directory span and the joiner so it actually guards both halves of the change:
`want="${ESC}[34mw${ESC}[0m ${ESC}[2m·${ESC}[0m ${ESC}[35mmain${ESC}[0m${ESC}[33m*${ESC}[0m ${ESC}[32m≡${ESC}[0m ${ESC}[33m↓2${ESC}[0m ${ESC}[32m↑3${ESC}[0m ${ESC}[2m#2${ESC}[0m"`
(`${ESC}[34mw${ESC}[0m` is seg_dir's output for the `w` fixture repo; the joiner expands to space, SGR-2, `·`, SGR-0, space.) Widen the check label on line 416 to mention the dim dot joiner, e.g. `"git color bytes: dim · joiner, magenta branch, yellow *, green ≡, yellow ↓2, green ↑3, dim #2"`.

Refresh two comments: line 333 so it reads `# 8.1 not-a-repo: segment and its dot joiner entirely absent (GIT-01).`, and line 413 so it no longer claims the magenta span includes a glyph — `# exactly: dim dot joiner, magenta branch span, yellow star, green has-upstream`.

Do NOT touch line 337, `check_eq "git not-a-repo: line 1" "Opus 5 (high) · plaindir" "$l1"` — that assertion is the GIT-01 regression guard proving the join change left no dangling separator, and it must stay byte-identical (RESEARCH.md §3). Do not add or remove any check: the suite must still report 220 checks. Leave the fixture expectations (lines 149-153), the section 8.7 palette-purity loop, section 9 latency, section 10 shellcheck, and all line-2/Fable checks untouched — all fixtures point at a non-repo directory, so their renders are byte-identical before and after this change.
  </action>
  <verify>
    <automated>
cd "$(git rev-parse --show-toplevel)"
[ "$(grep -cF 'check_eq "git not-a-repo: line 1" "Opus 5 (high) · plaindir" "$l1"' tests/run.sh)" = "1" ] || { echo "FAIL: the GIT-01 not-a-repo guard at tests/run.sh:337 was modified"; exit 1; }
grep -qF 'want="${ESC}[34mw${ESC}[0m ${ESC}[2m·${ESC}[0m ${ESC}[35mmain${ESC}[0m' tests/run.sh || { echo "FAIL: section 8.6 want does not span the dir-to-git dim dot joiner — it would silently pass a glyph-only fix"; exit 1; }
OUT=$(/bin/bash tests/run.sh); printf '%s\n' "$OUT" | tail -1
printf '%s\n' "$OUT" | tail -1 | grep -qF '220 checks, 0 failures' || { echo "FAIL: suite not green at the 220-check baseline"; exit 1; }
echo "OK"
    </automated>
  </verify>
  <done>`/bin/bash tests/run.sh` prints `220 checks, 0 failures`. The section 8.6 raw-byte expectation spans the directory span, the dim dot joiner and the magenta branch, so it fails if either half of Task 1 is reverted. The not-a-repo assertion is unchanged.</done>
</task>

<task type="auto">
  <name>Task 3: Align README with the shipped rendering</name>
  <files>README.md</files>
  <action>
Two edits in `README.md` (RESEARCH.md §6). Line 8, the sample inside the "What it shows" fenced block, becomes `Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2`. Line 20, the symbol legend row, drops the glyph from its token cell so it reads `| `main` | Current branch (short SHA when detached) — the whole git segment is hidden outside a repo |` (wording is discretionary per CTX-8; keep the meaning cell as-is).

Nothing else in README.md changes: line 12's "segments with no data … disappear together with their separators" is still accurate (now literally true for git too), and the "Verify without a live session" expected output uses `/tmp/myproject`, a non-repo, so its two expected lines are unaffected.

Per CTX-6, do not touch `project-brief.md`, `.planning/PROJECT.md`, `.claude/CLAUDE.md`, or any archived `.planning/` document — they knowingly keep the old spec and that disagreement is accepted.
  </action>
  <verify>
    <automated>
cd "$(git rev-parse --show-toplevel)"
grep -qF 'Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2' README.md || { echo "FAIL: README sample line does not match the new rendering"; exit 1; }
grep -qF '| `main` | Current branch' README.md || { echo "FAIL: README symbol legend row not updated"; exit 1; }
[ -z "$(git status --porcelain -- project-brief.md .planning/PROJECT.md .claude/CLAUDE.md .planning/RETROSPECTIVE.md .planning/milestones .planning/research)" ] || { echo "FAIL: an out-of-scope document was modified"; exit 1; }
echo "OK"
    </automated>
  </verify>
  <done>README's sample line and symbol legend match what the script now renders, and every out-of-scope document (project-brief.md, .planning/PROJECT.md, .claude/CLAUDE.md, and the archived .planning/ material) is untouched.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| git repo → status line | A branch name (attacker-influenceable in a hostile clone) is read from `git status --porcelain=v2` and rendered on line 1 |
| stdin JSON → status line | Claude Code supplies the session payload; parsed by jq and bound via `@sh` |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QT260826-01 | Tampering | `seg_git()` branch label rendering (statusline.sh:173) | low | accept | Pre-existing and unchanged by this edit: the label is emitted through `printf '%s' "$out"` (no format-string exposure) and is never `eval`'d. Removing a literal prefix from inside the magenta span adds no new sink. The harness's eval-injection and hostile-body checks stay green (Task 2 gate). |
| T-QT260826-02 | Denial of Service | `main()` line-1 join path | low | accept | The change removes one string splice and adds one positional argument to an existing loop — no new process spawn, no new I/O, no network. Section 9's latency budget check remains green (Task 2 gate). |
| T-QT260826-SC | Tampering | npm/pip/cargo installs | n/a | accept | No packages are installed or added. Dependencies (`bash`, `git`, `jq`) are pre-existing and project-confirmed, so the package-legitimacy gate does not apply (RESEARCH.md, Package Legitimacy Audit). |

ASVS L1, render-only change: no auth, session, access-control or crypto code is touched; the Fable
OAuth path is not modified. No blocking security checkpoint required.
</threat_model>

<verification>
Phase-level checks after all three tasks:

1. `/bin/bash tests/run.sh` → `220 checks, 0 failures` (baseline measured pre-change: 220/0).
2. Manual eyeball of the new line 1:
   `jq --arg d "$PWD" '.workspace.current_dir=$d' tests/fixtures/full.json | /bin/bash kit/files/home/.claude/statusline.sh`
3. `git status --porcelain -- project-brief.md .planning/PROJECT.md .claude/CLAUDE.md` is empty — no
   out-of-scope document drifted. (Do not gate on a whole-tree `git diff --name-only` count: the
   executor legitimately writes `.planning/` artifacts during the run.)

<human-check>Render the status line in a real repo and confirm line 1 reads `Opus 5 (high) · <dir> · <branch>…` with the branch still magenta and the git sub-parts still space-joined, and that it collapses to `… · <dir>` outside a repo.</human-check>

Notes — deliberately NOT gates:
- `~/.claude/statusline.sh` is a regular-file COPY of the repo script, not a symlink (RESEARCH.md §5.1).
  The live status line will keep showing the old rendering until the user refreshes that copy.
  Re-installing is the user's environment, explicitly out of scope for this task — surface it in the summary.
- Do not run `tests/render-fixtures.sh` as a pass/fail gate: its repo↔installed diff (PORT-04) will
  report a difference until that copy is refreshed. All 8 fixtures were proven to render byte-identically
  before and after this change (they point at a non-repo directory), so no baseline regeneration is needed.
</verification>

<success_criteria>
- Line 1 renders git as its own segment joined by the existing dim `·`, with a magenta, unprefixed branch label.
- Exactly one new separator is introduced; git sub-parts remain space-joined.
- Outside a repo, line 1 is unchanged — no dangling separator, exit 0, empty stderr (GIT-01 intact).
- `/bin/bash tests/run.sh` reports `220 checks, 0 failures`.
- The section 8.6 raw-byte expectation now fails if the dir↔git join is missing.
- README matches the shipped rendering; no out-of-scope document is touched.
</success_criteria>

<output>
Create `.planning/quick/260826-wid-change-the-branch-symbol-to-a-dot-separa/260826-wid-SUMMARY.md` when done.
Note in the summary that `~/.claude/statusline.sh` is a copy and needs a refresh by the user before the
live status line reflects the change.
</output>
