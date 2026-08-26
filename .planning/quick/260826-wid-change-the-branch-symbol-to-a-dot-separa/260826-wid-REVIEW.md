---
phase: quick-260826-wid-change-the-branch-symbol-to-a-dot-separator
reviewed: 2026-08-26T20:54:17Z
depth: quick
files_reviewed: 3
files_reviewed_list:
  - README.md
  - kit/files/home/.claude/statusline.sh
  - tests/run.sh
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Quick 260826-wid: Code Review Report

**Reviewed:** 2026-08-26T20:54:17Z
**Depth:** quick
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three commits (3472da4, 17e9842, 1b8b1df) remove the `⎇ ` glyph from `seg_git` and promote the
git segment from a space-attached suffix of the directory segment to a first-class line-1 segment
joined by the existing dim-dot separator. The code delta is three lines in `statusline.sh` plus
string updates in `tests/run.sh` and `README.md`.

Verified against the five review concerns raised in the brief:

- **bash 3.2:** clean. No new constructs; `/bin/bash -n` parses under the host's 3.2.57, the whole
  suite runs under `/bin/bash` 3.2.57 (220 checks, 0 failures), and a grep for the banned-construct
  table (`declare -A`, `${var,,}`/`${var^^}`, `mapfile`/`readarray`, `date -d`/`date -r`, negative
  substring offsets) returns nothing.
- **Quoting/word-splitting:** clean and strictly improved. `join_segments "$sep" "$model_seg"
  "$dir_seg" "$git_seg"` quotes every argument, and removing `${git_seg:+ $git_seg}` deletes the
  only unquoted expansion on the line-1 path. `join_segments` tests `[ -n "$part" ]` quoted and
  builds via assignment, so no field splitting is reachable.
- **ANSI/RESET on line 1:** correct. Every `seg_*` return path terminates with `${RESET}`, the
  separator is self-closing (`" ${DIM}·${RESET} "`), and no color spans the new joiner. The
  trailing `${RESET}` appended in `LINE1` is redundant (IN-04) but harmless; the palette-purity
  scan in section 8.7 still sees only the whitelisted SGR codes.
- **Test integrity:** the expectation changes were **not** loosened. All of 8.1–8.5 remain exact
  `check_eq` equality on the ANSI-stripped line, which catches a re-introduced glyph, a reordered
  segment, or a dangling separator. Test 8.6 was *strengthened*: the old raw-byte `want` started at
  `ESC[35m⎇ main`, the new one prefixes `ESC[34mw ESC[0m ESC[2m·ESC[0m` and so now asserts the
  dir→separator→branch byte adjacency and the magenta span containing exactly `main`.
- **No dangling separator:** holds in every state that has a visible directory — not-a-repo, clean,
  dirty, detached, unborn, no-upstream all verified by the passing exact-equality tests. It does
  **not** hold in the one state where `seg_dir` emits a zero-width segment (WR-01).

No Critical findings. Three Warnings; the two behavioral ones (WR-01, WR-02) are pre-existing bugs
in `statusline.sh` that this change exposes or slightly worsens rather than introduces, and both
were reproduced against the shipped script.

## Warnings

### WR-01: `join_segments`' emptiness test is byte-based, so a zero-width directory segment produces a visible dangling `·`

**File:** `kit/files/home/.claude/statusline.sh:133-137` (with `:412`)
**Issue:** `seg_dir` always `printf`s at least `${BLUE}${RESET}` — a non-empty *byte* string with
zero *display* width. When `${DIR##*/}` and `${PWD##*/}` are both empty (i.e. `workspace.current_dir`
is `/` and the process cwd is `/`, which is the normal cwd for some container entrypoints),
`join_segments` sees a non-empty part and emits its separator anyway. Reproduced against the shipped
script:

```
$ cd / && printf '%s' '{"model":{"display_name":"M"},"workspace":{"current_dir":"/"}}' \
    | /bin/bash kit/files/home/.claude/statusline.sh | sed -n 1p | cat -v
^[[36mM^[[0m ^[[2m·^[[0m ^[[34m^[[0m^[[0m      # renders as: "M · " — trailing dot, no directory
```

This is pre-existing, but the change makes the failure mode worse in the repo case: `/` is a git
repo in some sandbox images, and the old layout attached the branch to the (invisible) directory
with a plain space (`M ·  main`), whereas the new layout inserts a second dot (`M ·  · main`).
The D-14/PRES-04 "never a dangling separator" invariant is asserted only through visible-text
equality tests that never exercise this state, so nothing in `tests/run.sh` catches it.

**Fix:** make the segment genuinely empty (or genuinely non-empty) rather than color-only:

```bash
seg_dir() {
  local d=${DIR##*/}
  [ -z "$d" ] && d=${PWD##*/}
  [ -z "$d" ] && d=/                          # root has no basename — show the slash
  printf '%s' "${BLUE}${d}${RESET}"
}
```

Add a regression check alongside 8.1, e.g. a fixture with `current_dir` `/` asserting line 1 has no
trailing separator.

### WR-02: a branch literally named `(detached)` is misrendered as a short SHA and loses its sync marker

**File:** `kit/files/home/.claude/statusline.sh:166-170`
**Issue:** Detachment is inferred from the *string value* of `# branch.head`, which
`git status --porcelain=v2` does not escape or disambiguate. Git permits `(` and `)` in ref names,
so a real branch named `(detached)` sets `detached=1`: the branch label is replaced by the short
SHA (D-24) and the `≡`/`≢` upstream marker is suppressed entirely (D-25). Reproduced:

```
$ git checkout -q -b '(detached)'
$ git status --porcelain=v2 --branch | sed -n 2p
# branch.head (detached)
$ ... | statusline.sh | sed -n 1p | cat -v
^[[36mM^[[0m ^[[2m·^[[0m ^[[34mdetbr^[[0m ^[[2m·^[[0m ^[[35m7e4498f^[[0m^[[0m
```

The user is told they are on a detached HEAD with no upstream information when they are on a normal
branch. Pre-existing (not introduced by this diff), but it lives in the exact function the diff
touches and the branch-label path is now the segment's leading token, so it is squarely in scope.

**Fix:** decide detachment from git's own answer instead of a string compare — one extra process
only on the ambiguous label:

```bash
if [ "$label" = '(detached)' ] \
   && ! GIT_OPTIONAL_LOCKS=0 git -C "$DIR" symbolic-ref -q HEAD >/dev/null 2>&1; then
  detached=1
  sha=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
  [ -n "$sha" ] && label=$sha
fi
```

### WR-03: user-visible rendering changed but `kit/spec.yaml` still declares `version: "1.0.0"`

**File:** `kit/spec.yaml:13`
**Issue:** The kit ships `files/home/.claude/statusline.sh` into Docker Sandboxes and is consumed
remotely via `--kit "git+https://…#dir=kit"`, optionally pinned with `#ref=<tag-or-commit>`
(README "Install in Docker Sandboxes"). The rendered line-1 format changed while the kit's declared
semantic version did not, so two different renderings now ship as `claude-code-status-line 1.0.0`.
Any sbx-side caching or version comparison keyed on `name+version` cannot distinguish them, and a
user reporting "my sandbox still shows the old glyph" has no version to check. The three commits
touched README, tests and the script but no version metadata.

**Fix:** bump `version: "1.1.0"` in `kit/spec.yaml` as part of any change to the shipped script's
output, and tag the repo so `#ref=` pinning has something to point at.

## Info

### IN-01: `project-brief.md` still mandates the removed `⎇` prefix in four places

**File:** `project-brief.md:8,16,17,30`
**Issue:** The tracked brief at the repo root still specifies "it should show the current branch
name with the symbol `⎇` as a prefix" and shows `Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2` as
the whole example. README was updated by 1b8b1df; the brief was not, so the repo now contains a
requirements document that the shipped script contradicts. (The brief is already stale in other
respects — it specifies the superseded `f(60%)` Fable format — which suggests it is treated as a
frozen historical document; that intent is nowhere stated in the file.)
**Fix:** either add a one-line header marking it as the frozen original brief superseded by
`.planning/`, or update lines 8/16/17/30 to the dot-joined form.

### IN-02: stale `⎇` reference in project instructions

**File:** `.claude/CLAUDE.md:109`
**Issue:** "Detect not-a-repo by the status command failing (exit ≠ 0) and hide the whole `⎇`
segment." The glyph no longer exists, so the sentence points at a token future readers (and agents
loading CLAUDE.md) cannot find in the code.
**Fix:** reword to "hide the whole git segment".

### IN-03: README symbol legend documents a bare `main` token but never documents the `·` separator

**File:** `README.md:8,20`
**Issue:** After the change the legend reads `| myproject | Basename of the working directory |`
immediately followed by `| main | Current branch … |`, while the example line is
`Opus 5 (high) · myproject · main* ≡ …`. The legend has no row for `·` at all, so a reader has no
way to tell that `myproject · main` is dir-then-branch rather than a two-part path or two
directories — the glyph previously carried that disambiguation for free.
**Fix:** add a legend row for the separator, e.g. `| · | Segment separator — the segment and its
separator disappear together when there is no data |`, which also documents the line-2 behaviour
already described in prose at line 12.

### IN-04: redundant trailing `${RESET}` on line 1 (and line 2)

**File:** `kit/files/home/.claude/statusline.sh:413,417`
**Issue:** `LINE1="${body}${RESET}"` appends a reset that every segment renderer already emitted,
producing a literal `ESC[0mESC[0m` at end of line on every render (visible in the `cat -v` output
above). Harmless — 8.7's palette scan whitelists `0m` — but it is dead output and makes raw-byte
assertions read oddly.
**Fix:** drop the append (`LINE1="$body"`), or keep it and note in the comment that it is
belt-and-braces for a future segment that forgets to reset.

### IN-05: `seg_dir` falls back to `$PWD` but `seg_git` deliberately does not

**File:** `kit/files/home/.claude/statusline.sh:135` vs `:145`
**Issue:** With an empty `workspace.current_dir`, `seg_dir` renders the process cwd's basename while
`seg_git` returns early ("stdin workspace dir only, never `$PWD`"). Line 1 then names a directory
that *is* a repo while showing no branch — see `run_fixture empty "$HERE" ""` in `tests/run.sh:154`,
which passes from inside this repository. The asymmetry is a deliberate decision (D-13/D-16) but is
more noticeable now that git is a sibling top-level segment sharing the same separator rather than a
suffix of the directory token.
**Fix:** none required; consider a one-line comment at `:135` cross-referencing `:145` so the
asymmetry reads as intentional.

### IN-06: raw-byte assertion in 8.6 hardcodes the fixture directory name

**File:** `tests/run.sh:415`
**Issue:** `want="${ESC}[34mw${ESC}[0m …"` embeds the literal `w` from `W=$(mk_repo w)`. Renaming the
fixture repo breaks the assertion with an opaque "color bytes" failure rather than a name mismatch.
**Fix:** interpolate instead — `want="${ESC}[34m${W##*/}${ESC}[0m ${ESC}[2m·${ESC}[0m …"`.

---

_Reviewed: 2026-08-26T20:54:17Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_
