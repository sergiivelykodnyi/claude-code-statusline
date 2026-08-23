# Phase 2: Git Segment - Pattern Map

**Mapped:** 2026-08-21
**Files analyzed:** 2 modified (no new source files)
**Analogs found:** 2 / 2 (all analogs are in-file — this phase extends Phase 1 code)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `statusline.sh` — add `seg_git()`, `MAGENTA`, frame removal in `main()` | segment renderer (utility) | transform (subprocess output → colored string) | `seg_5h()` / `seg_model_effort()` in same file | exact |
| `tests/run.sh` — git-state scenarios + timed latency assertion | test | batch (fixture → assert) | `run_fixture()` + section structure in same file | exact |
| `tests/fixtures/` — possibly new temp-repo setup (git states can't be JSON fixtures) | test fixture | file-I/O | `tests/fixtures/full.json` pattern (for stdin) + inline `jq` mutation pattern (`tests/run.sh:111-113`, `:143-144`) | role-match |

No external analogs exist — the codebase is one script + one harness. Every pattern to copy lives in these two files.

## Pattern Assignments

### `statusline.sh` — `seg_git()` (segment renderer, transform)

**Analog:** `statusline.sh` — the `seg_*` family, esp. `seg_5h()` (lines 95-102) for conditional sub-parts and `seg_model_effort()` (lines 68-74) for multi-color composition.

**Palette constant pattern** (lines 8-14) — add `MAGENTA` in the same block, same style:
```bash
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
CYAN=$'\033[36m'
# add: MAGENTA=$'\033[35m'   (D-18)
```
Note: the palette-purity test (`tests/run.sh:129-138`) whitelists SGR codes — `35m` must be added to the ` 0m 2m 31m ... ` case string there.

**Renderer contract** (from `seg_5h`, lines 95-102): echo segment or empty string, guard with `[ -n ... ] || return 0`, build conditional sub-parts by appending to `out`:
```bash
seg_5h() {
  [ -n "$P5_PCT" ] || return 0
  local pct=${P5_PCT%.*} out
  [ -z "$pct" ] && pct=0
  out="$(pct_color "$pct")${pct}%${RESET}/5h"
  [ -n "$P5_RST" ] && out="${out} ($(fmt_duration $(( P5_RST - NOW ))))"
  printf '%s' "$out"
}
```
`seg_git` follows the same shape: bail early (empty output) when `git -C "$DIR" status --porcelain=v2 --branch` fails (not-a-repo, GIT hidden per D-27/join_segments skip); otherwise append markers conditionally.

**Multi-color composition** (from `seg_model_effort`, lines 70-73) — per-marker colors with `${RESET}` after each colored span:
```bash
local out="${CYAN}${name}${RESET}"
[ -n "$EFFORT" ] && out="${out} ${DIM}(${EFFORT})${RESET}"
```
Apply with D-17..D-20 colors: `${MAGENTA}⎇ branch${RESET}`, `${YELLOW}*${RESET}`, `${GREEN}≡${RESET}`/`${RED}≢${RESET}`, `${YELLOW}↓N${RESET}`, `${GREEN}↑N${RESET}`, `${DIM}#N${RESET}`.

**Git query pattern** (prescriptive, from CLAUDE.md / STACK.md — no in-repo instance yet):
```bash
GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch 2>/dev/null
# parse: "# branch.head <name>", "# branch.upstream ..." presence, "# branch.ab +A -B",
# any non-# line => dirty
GIT_OPTIONAL_LOCKS=0 git -C "$DIR" rev-list --walk-reflogs --count refs/stash 2>/dev/null
# detached only: git -C "$DIR" rev-parse --short HEAD  (D-24)
```
Parse with a bash-3.2-safe `while read -r` loop over the porcelain output (no `mapfile`, no assoc arrays — see CLAUDE.md portability table). Redirect all git stderr to `/dev/null` (never-fail contract: nothing on stderr).

**Bash-3.2 conditional-marker style** (from `seg_context`, lines 87-89 — guard empties before arithmetic):
```bash
local pct=${CTX_PCT%.*} tok=$CTX_TOK
[ -z "$pct" ] && pct=0
```
Same defensive style applies to ahead/behind counts parsed from `branch.ab` before `[ "$n" -gt 0 ]` tests (D-27: zero-value counters never render).

**Integration seam** (lines 139-151 in `main()`) — the marked attach point and the frame lines to change:
```bash
dir_seg=$(seg_dir)
# Phase 2 seam: the git segment appends to dir_seg with a plain space
# (dir_seg="$dir_seg $git_seg") before this join.
body=$(join_segments "$sep" "$model_seg" "$dir_seg")
LINE1="${DIM}╭─${RESET}${body:+ $body}${RESET}"
...
LINE2="${DIM}╰─${RESET} ${body}${RESET}"
...
LINE2="${DIM}╰─${RESET}"
```
Frame removal (D-21/D-22/D-23): drop the `${DIM}╭─${RESET} ` / `${DIM}╰─${RESET} ` prefixes; empty line 2 becomes a literal blank line (`LINE2=""` still printed via `printf '%s\n'` — the existing two-`printf` epilogue at lines 153-155 already guarantees exactly two lines). Note: appending the git segment as `dir_seg="$dir_seg${git_seg:+ $git_seg}"` avoids a trailing space when outside a repo.

---

### `tests/run.sh` — git-state scenarios + latency assertion (test, batch)

**Analog:** same file — copy the section-comment + counter structure.

**Check helpers to reuse as-is** (lines 21-40): `check_eq NAME EXPECTED ACTUAL` and `check_ok NAME STATUS` maintain `CHECKS`/`FAILS`; every new assertion goes through these.

**Fixture-run pattern** (lines 86-96) — exit 0, zero stderr bytes, ANSI-stripped line assertions:
```bash
out=$(/bin/bash "$SL" < "tests/fixtures/$f.json" 2>"$ERRTMP"); rc=$?
errbytes=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
check_eq "$f: exit code" "0" "$rc"
check_eq "$f: stderr bytes" "0" "$errbytes"
l1=$(printf '%s\n' "$out" | strip_ansi | sed -n 1p)
```
Git-state tests need a variant: create a temp repo (`mktemp -d`, `git init`, commits/stash as needed), then feed a jq-mutated fixture pointing `.workspace.current_dir` at it — the mutation pattern already exists at lines 111-113 and 143-144:
```bash
jq '.workspace.current_dir = "/tmp/x; $(touch tests/.pwned)"' \
   tests/fixtures/full.json | /bin/bash "$SL" > /dev/null 2>&1
```
Adapt with `--arg d "$TMPREPO"` and `.workspace.current_dir = $d`.

**Temp-file lifecycle pattern** (lines 42-43) — extend the same trap for temp repos:
```bash
ERRTMP=$(mktemp "${TMPDIR:-/tmp}/statusline-test.XXXXXX") || exit 1
trap 'rm -f "$ERRTMP"' EXIT
```

**Portable ANSI strip / raw-byte assertions** (lines 15-18, 119-126): `strip_ansi()` for text assertions; the `case "$raw" in *"$want"*)` byte-match pattern for asserting exact color codes on git markers (e.g. `${ESC}[35m` before the branch name).

**Latency assertion (D-28)** — no existing timing pattern; must be BSD/GNU portable. `date +%s%N` is GNU-only; portable options are whole-second bounding with `date +%s`, or better `perl -MTime::HiRes=time -e 'print time'` / running N iterations and bounding total seconds. Claude's discretion per CONTEXT.md; keep it inside the `check_ok` framework and generous vs. the 300 ms debounce.

**Line-expectation updates:** every existing `run_fixture` expectation (lines 100-106) currently includes `╭─ `/`╰─` — frame removal requires rewriting all of them (e.g. `"Opus 5 (high) · myproject"`, `""` for blank line 2). Palette-purity whitelist (line 134) gains `35m`.

---

## Shared Patterns

### Never-fail contract
**Source:** `statusline.sh` header comment (lines 1-5) and `main()` epilogue (lines 153-155)
**Apply to:** all new code in `statusline.sh`
- No `set -e`/`set -u`; unconditional `exit 0`; all subprocess stderr to `/dev/null`; empty output preferred over error text.

### Hide-over-placeholder via `join_segments`
**Source:** `statusline.sh:57-63`
**Apply to:** `seg_git` and every marker inside it
```bash
join_segments() {
  local sep="$1" out="" part; shift
  for part in "$@"; do
    [ -n "$part" ] && out="${out:+$out$sep}$part"
  done
  printf '%s' "$out"
}
```
Return `""` outside a repo; conditionally append each marker only when nonempty/nonzero.

### Bash 3.2 portability
**Source:** whole codebase + CLAUDE.md table
**Apply to:** everything — `while read -r` parsing, `${var%.*}` truncation, no `date -d`/`date -r`, `printf '%b'`/`$'\033[..]'` literals, `#!/bin/bash`.

### Source guard for testability
**Source:** `statusline.sh:160-162`
```bash
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi
```
Keep intact so `tests/run.sh:55` can source and unit-test `seg_git`'s parse helpers directly (extract porcelain parsing into a pure helper if unit tables are wanted, matching the `shorten_num`/`fmt_duration` unit-table style at lines 57-70).

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|--------------|------|-----------|--------|
| Temp-git-repo test setup | test fixture | file-I/O | No existing tests create repos; JSON fixtures can't encode git state. Follow the `mktemp` + trap pattern (`tests/run.sh:42-43`) plus jq `--arg` fixture mutation (lines 111-113). |
| Timed latency assertion | test | batch | No timing code exists; must be BSD/GNU portable (Claude's discretion per D-28). |

## Metadata

**Analog search scope:** entire repo (`statusline.sh`, `tests/run.sh`, `tests/fixtures/*.json` — 9 files total)
**Files scanned:** 3 read in full
**Pattern extraction date:** 2026-08-21
