# Phase 3: Install & Dual-Environment Validation - Pattern Map

**Mapped:** 2026-08-22
**Files analyzed:** 8 (4 new, 3 modified, 1 relocated)
**Analogs found:** 6 / 8 (2 files have no in-repo analog: `kit/spec.yaml`, `README.md` body — planner uses RESEARCH.md Pattern 1 / Code Examples for those)

The codebase is tiny: one script (`statusline.sh`, 226 lines), one harness (`tests/run.sh`, 419 lines), seven JSON fixtures, `project-brief.md`, `.gitignore` (one line), and `.claude/CLAUDE.md`. There is no README, no YAML, no `kit/` directory yet. Every shell pattern to copy lives in `tests/run.sh` and `statusline.sh`; every prose/tone pattern lives in `project-brief.md` and the CLAUDE.md "Development Tools" table.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `kit/files/home/.claude/statusline.sh` (relocated via `git mv`, **content unchanged**) | script (renderer) | request-response (stdin JSON → 2 stdout lines) | itself — `statusline.sh` | exact (same file) |
| `kit/spec.yaml` (new) | config (sbx mixin kit manifest) | batch (install once) + event-driven (startup every start) | **none in repo** — use RESEARCH.md §Pattern 1 verbatim (grammar verified on `sbx` v0.39.0) | no analog |
| `tests/run.sh` (modified: `SL=` path, new exec-bit check, optional INFO line) | test harness | batch (fixture → assert) | itself — `check_ok` / section-1 syntax gate / section-10 INFO advisory | exact |
| `tests/render-fixtures.sh` (new) | test helper (render dumper) | file-I/O (fixture → raw bytes on disk) | `tests/run.sh` — header, `cd`, `SL`, `run_fixture` loop, `mktemp` usage | role-match (same conventions, different output sink) |
| `tests/sandbox.sh` (optional new) | test helper (orchestrator around `sbx`) | batch (create → exec → diff → rm) | `tests/run.sh` — header/`cd`/`check_ok`/trap cleanup; `tgit` wrapper style for a thin CLI wrapper | role-match |
| `README.md` (new) | docs | — | `project-brief.md` (tone, fenced two-line example, bullet legend) + CLAUDE.md "Development Tools" table (mock-input command) + RESEARCH.md §Code Examples (install/snippet/verify) | role-match (tone/structure only) |
| `.gitignore` (modified: add `tests/out/`) | config | — | `.gitignore` itself (`.gsd/` one-entry style) | exact |
| `.planning/research/ARCHITECTURE.md` (optional layout note update, lines 70-81 / 251) | docs | — | itself | exact |

## Pattern Assignments

### `kit/files/home/.claude/statusline.sh` (script, relocated)

**Analog:** `statusline.sh` — it is the same file. Planner action is `git mv statusline.sh kit/files/home/.claude/statusline.sh` (mode `100755` in the index today — verified `git ls-files -s`). **No content edits.** Two properties that make the move safe and must stay true:

**Self-contained / no `$0`-relative paths** — the script never references its own location; running through `~/.claude/statusline.sh` (symlink or copy) behaves identically. Source guard at the bottom (lines 222-226):
```bash
# Source guard: run only when executed, so a test harness can source the
# helpers without triggering cat/exit (bash 3.2-safe).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi
```
Under a symlink both sides are the link path → `main` still runs; when sourced by the harness (`. "./$SL"`) it does not.

**Never-fail contract** (lines 1-5, 217-219) — the contract the README verify command and the kit's `chmod 0755` insurance exist to protect:
```bash
#!/bin/bash
# ... always exits 0. bash 3.2-compatible (macOS /bin/bash).
# No set -e / set -u: an aborting probe would blank the whole line.
...
  printf '%s\n' "$LINE1"
  printf '%s\n' "$LINE2"
  exit 0                                      # unconditional (PORT-03)
```

**Deterministic fixture rendering** (why byte-diff works, lines 147, 157): `resets_at: 0` → `fmt_duration $(( 0 - NOW ))` → `now` forever; `seg_dir` (lines 78-82) falls back to `${PWD##*/}` for `empty`/`malformed` — identical host/sandbox because the workspace is mounted at the same absolute path.

---

### `kit/spec.yaml` (config, no analog)

No YAML or kit file exists in the repo. Copy RESEARCH.md §Pattern 1 "Example (recommended `kit/spec.yaml`)" verbatim, then run `sbx kit validate ./kit` (works offline). Non-negotiable grammar facts (verified on v0.39.0): `schemaVersion: "2"`, `setup.install[].command` is a **string**, `setup.startup[].command` is a **string array** `["sh","-c","…"]`, `user: "0"` for the startup reconcile, `requires.agent: claude`.

Conventions to carry over from the repo's shell style into the inline `sh -c` block:
- Comment every non-obvious line with the decision ID it serves (house style seen throughout `statusline.sh`, e.g. `# D-10`, `# unconditional (PORT-03)`), e.g. `# D-32: merge only .statusLine after the platform seed`.
- `tmp=$(mktemp …)` + `mv` atomic write mirrors the harness's `mktemp` discipline (`tests/run.sh:43-45`). GNU `mktemp -p` is acceptable here only because `setup.*` runs on Linux; anything host-side must use the portable `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` form from the harness.
- The merged object must be byte-for-byte D-34: `{type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}`.

---

### `tests/run.sh` (test harness, modified)

**Analog:** itself. Three small edits, each copying an existing in-file pattern.

**1. Re-point `SL`** (line 12):
```bash
cd "$(dirname "$0")/.." || exit 1
SL=statusline.sh
```
→ `SL=kit/files/home/.claude/statusline.sh`. Everything downstream (`/bin/bash -n "$SL"` line 49, `. "./$SL"` line 57, `/bin/bash "$SL" < …` in `run_fixture` line 90 and ~15 other sites) uses `$SL` and needs no change. Grep confirmation: `grep -n 'statusline.sh' tests/run.sh` should show only the header comment (line 2) and line 12 as literal mentions.

**2. New exec-bit check** — copy the section-1 syntax-gate shape (lines 47-50), which is the house idiom for "run a predicate, feed `$?` to `check_ok`":
```bash
# --- 1. Syntax gate ---------------------------------------------------------

/bin/bash -n "$SL" 2>/dev/null
check_ok "syntax: /bin/bash -n $SL" $?
```
New check directly below it (bites on mode loss, e.g. `core.fileMode=false` checkout):
```bash
[ -x "$SL" ]
check_ok "exec bit: $SL is executable" $?
```
`check_ok` definition (lines 32-41) — increments `CHECKS`/`FAILS`, prints `PASS`/`FAIL name`:
```bash
check_ok() {
  CHECKS=$(( CHECKS + 1 ))
  if [ "$2" -eq 0 ]; then
    printf 'PASS %s\n' "$1"
  else
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL %s\n' "$1"
  fi
}
```
Harness convention (Phase 2): show the new check bites — `chmod -x` the script, observe FAIL, `chmod +x`, observe PASS — before committing.

**3. Optional installed-path INFO line** — copy the section-10 advisory shape (lines 409-414): never fails the harness, prints `INFO …`:
```bash
if command -v shellcheck > /dev/null 2>&1; then
  printf 'INFO shellcheck advisory (non-failing):\n'
  shellcheck --shell=bash "$SL" || true
else
  printf 'INFO shellcheck not installed — advisory skipped (accepted default)\n'
fi
```
→ e.g. `[ -e "$HOME/.claude/statusline.sh" ] && printf 'INFO installed: %s\n' "$(ls -l "$HOME/.claude/statusline.sh")"`. Keep it advisory so the harness stays hermetic in the sandbox (where the kit may or may not have landed the file yet).

**Also update** the header comment (line 2, `regression harness for statusline.sh`) to mention the new path, and the shellcheck advisory can additionally lint the new `tests/*.sh` if desired (`shellcheck --shell=bash "$SL" tests/render-fixtures.sh || true`).

---

### `tests/render-fixtures.sh` (test helper, file-I/O)

**Analog:** `tests/run.sh` — copy its header, preamble, and fixture-loop discipline; swap the assertion sink for raw file output. RESEARCH.md §Code Examples has a sketch; the excerpts below are the in-repo source of each idiom.

**Header + preamble pattern** (lines 1-12) — shebang `#!/bin/bash`, purpose comment, usage line, `cd` to repo root, `SL`:
```bash
#!/bin/bash
# tests/run.sh — never-fail regression harness for statusline.sh.
# ...bash 3.2-safe (runs on the macOS host /bin/bash).
#
# Usage: /bin/bash tests/run.sh
# Prints one PASS/FAIL line per check; exits non-zero if any check failed.

cd "$(dirname "$0")/.." || exit 1
SL=statusline.sh
```
→ new file: `SL=kit/files/home/.claude/statusline.sh`; `OUT=${1:?usage: tests/render-fixtures.sh OUTDIR}`.

**Fixture invocation pattern** (`run_fixture`, lines 88-98) — always invoke via `/bin/bash "$SL" < "tests/fixtures/$f.json"`, capture stderr to a file, never via `./statusline.sh`:
```bash
run_fixture() {
  local f=$1 e1=$2 e2=$3 out rc errbytes l1 l2
  out=$(/bin/bash "$SL" < "tests/fixtures/$f.json" 2>"$ERRTMP"); rc=$?
  errbytes=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
  ...
}
```
→ new file writes raw bytes instead of capturing: `/bin/bash "$SL" < "$f" > "$OUT/repo/$n.out" 2>/dev/null`. Do **not** strip ANSI — the byte diff must include color codes (PORT-01 is "identical output").

**Fixture enumeration** — `run_fixture` is called by name (lines 102-108); the new script should glob `tests/fixtures/*.json` and derive the name with bash-3.2-safe parameter expansion (same style as `n=${pair%%:*}` on line 63 / `HERE=${PWD##*/}` line 100):
```bash
for f in tests/fixtures/*.json; do
  n=${f##*/}; n=${n%.json}
  ...
done
```

**Installed-path render (PORT-04 within one env)** — guard with `[ -x "$HOME/.claude/statusline.sh" ]` (mirrors the hide-when-absent gates `[ -n "$X" ] || return 0` used throughout `statusline.sh`), write to `$OUT/installed/$n.out`, then `diff -r "$OUT/repo" "$OUT/installed"` (POSIX, identical BSD/GNU). Exit status of the script should reflect the diff (unlike `statusline.sh`, helpers may exit non-zero — `tests/run.sh` line 419 `[ "$FAILS" -eq 0 ]` is the precedent).

**Portability rules that bind this file** (CLAUDE.md): bash 3.2 subset, `#!/bin/bash`, no `mapfile`/`declare -A`/`${var,,}`, `mktemp "${TMPDIR:-/tmp}/x.XXXXXX"` form only (line 43), `diff`/`cmp` not `sha256sum` (macOS has it at `/sbin` but the name/format differs — `cksum` if a checksum is ever needed), no `date -d`/`-r`, no `readlink -f`, no `sed -i`.

---

### `tests/sandbox.sh` (optional test helper, orchestrator)

**Analog:** `tests/run.sh` — preamble + `check_ok` + `trap` cleanup + thin wrapper function style. Commands come from RESEARCH.md §Pattern 4.

**Cleanup-on-exit pattern** (lines 43-45) — create resources, register `trap … EXIT` immediately:
```bash
ERRTMP=$(mktemp "${TMPDIR:-/tmp}/statusline-test.XXXXXX") || exit 1
TESTTMP=$(mktemp -d "${TMPDIR:-/tmp}/statusline-git.XXXXXX") || exit 1
trap 'rm -f "$ERRTMP"; rm -rf "$TESTTMP"' EXIT
```
→ `trap 'sbx rm -f "$NAME" >/dev/null 2>&1' EXIT` only if the script owns the sandbox; if the user wants the sandbox kept for the live eyeball (`sbx run --name sl-test`), make removal an explicit flag rather than automatic.

**Thin wrapper function** (line 252) — one-line function that pins environment for a CLI:
```bash
tgit() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"; }
```
→ e.g. `sx() { sbx exec "$NAME" "$@"; }`.

**Evidence checks** — reuse `check_eq`/`check_ok` (lines 21-41) and the final summary line (lines 418-419):
```bash
printf '%d checks, %d failures\n' "$CHECKS" "$FAILS"
[ "$FAILS" -eq 0 ]
```
Suggested checks: `sbx exec NAME test -x ~/.claude/statusline.sh`; `sbx exec NAME jq -c .statusLine ~/.claude/settings.json` equals the D-34 object; in-sandbox `tests/run.sh` summary line ends in `0 failures`; `diff -r tests/out/host/repo tests/out/sandbox/repo` exit 0. Runs **on the host only** (needs `sbx`), so host portability rules apply; `sbx daemon status` precheck with a clear message (daemon was stopped during research).

---

### `README.md` (docs, new)

**Analog (tone/structure):** `project-brief.md` — terse, a fenced `text` block for the two-line example, bullet/ table legend with glyph examples. Copy its example block shape (lines 29-32) **minus the `f(60%)` token** (D-41) and with the current `/5h` label (the brief has a typo `50%/1w` on the 5h segment):
```text
Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2
10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)
```
Legend entries to adapt from the brief's bullets (lines 13-24) into one compact table: `⎇ branch`, `*` dirty, `≡`/`≢` has/no upstream, `↓N` behind, `↑N` ahead, `#N` stashes, `pct/tokens/window`, `pct/5h (reset)`, `pct/1w (reset)`. Note the brief's ahead/behind wording is swapped relative to the implementation (`↓` = behind, `↑` = ahead per `statusline.sh:124-125`) — README must follow the code.

**Install / snippet / verify blocks:** copy verbatim from RESEARCH.md §Code Examples ("README host install", "README settings snippet", "README verify command"). Load-bearing details already verified there: `ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh`; cp variant must be `rm -f ~/.claude/statusline.sh && cp …` (BSD `cp` writes through a symlink) + D-36 warning; snippet is the exact D-34 JSON with `"padding": 0, "refreshInterval": 60`; verify payload is the `tests/fixtures/full.json` body (`resets_at: 0` → `(now)`), expected output `Opus 5 (high) · myproject` / `10%/100k/1M · 50%/5h (now) · 15%/1w (now)` (these strings are pinned by `tests/run.sh:102`).

**Mock-input command style:** CLAUDE.md "Development Tools" row — `echo '{…}' | ./statusline.sh` one-liner; README uses `~/.claude/statusline.sh` as the target so the same command works host and sandbox (D-38).

**Sandbox section:** RESEARCH.md §Pattern 4 commands; real GitHub repo name is `claude-code-statusline` (not the CONTEXT.md spelling); `sbx kit add` sentence is conditional on UAT (RESEARCH Open Question 1); `kit.allowedSources` note for `git+https`.

Structure per D-40: What it shows → Symbol legend → Install on host → Install in Docker Sandboxes → Requirements. ~60–80 lines, no Development section.

---

### `.gitignore` (config, modified)

**Analog:** itself — entire file today is one line:
```
.gsd/
```
→ append `tests/out/` (render-dump output directory written by both host and sandbox runs).

---

## Shared Patterns

### Shell file conventions (apply to `tests/render-fixtures.sh`, `tests/sandbox.sh`, any edits to `tests/run.sh`)
**Source:** `tests/run.sh` lines 1-19, 43-45; `statusline.sh` lines 1-5; CLAUDE.md "Bash 3.2 portability rules"
```bash
#!/bin/bash
# <path> — <one-line purpose>. bash 3.2-safe (runs on the macOS host /bin/bash).
#
# Usage: /bin/bash tests/<name>.sh [ARGS]

cd "$(dirname "$0")/.." || exit 1
SL=kit/files/home/.claude/statusline.sh
ESC=$(printf '\033')
strip_ansi() { sed "s/${ESC}\[[0-9;]*m//g"; }      # only if stripping is needed — NOT for byte diffs
```
- Invoke the script as `/bin/bash "$SL"` (never `./$SL`, never `bash` from PATH) so the host's 3.2 interpreter is what gets exercised.
- Temp files: `mktemp "${TMPDIR:-/tmp}/statusline-X.XXXXXX"` + `trap … EXIT`.
- Comparisons: `diff -r` / `cmp` (POSIX). Never `date -d`/`-r`, `stat -c`/`-f` alone, `sed -i`, `readlink -f`, `echo -e`, `mapfile`, `declare -A`, `${var,,}`.
- Cross-env output goes **inside the repo** (`tests/out/<env>/…`, gitignored) because `$TMPDIR` differs between host (`/tmp/claude-501`) and sandbox (unset).

### Check/assert vocabulary (apply to every new harness-style script)
**Source:** `tests/run.sh` lines 14-41, 418-419
```bash
CHECKS=0
FAILS=0
check_eq() { CHECKS=$(( CHECKS + 1 )); if [ "$2" = "$3" ]; then printf 'PASS %s\n' "$1"; else FAILS=$(( FAILS + 1 )); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi; }
check_ok() { CHECKS=$(( CHECKS + 1 )); if [ "$2" -eq 0 ]; then printf 'PASS %s\n' "$1"; else FAILS=$(( FAILS + 1 )); printf 'FAIL %s\n' "$1"; fi; }
...
printf '%d checks, %d failures\n' "$CHECKS" "$FAILS"
[ "$FAILS" -eq 0 ]
```
Advisory (never-failing) output uses the `INFO …` prefix (line 410-413).

### Never-fail vs may-fail split
**Source:** `statusline.sh` lines 5, 219 vs `tests/run.sh` line 419
- The **script** (relocated, unchanged) always exits 0, no `set -e/-u`, nothing on stderr — the kit's `chmod 0755` and the README verify step protect this contract, they don't change it.
- **Helpers/harness** may `exit 1` / `|| exit 1` on setup failures and return the check status at the end — that is the existing precedent and what CI/sandbox evidence needs.
- The kit's inline `sh -c` (Linux-only, root) uses `set -e` + `|| true` on the optional `chmod` per RESEARCH Pattern 1 — a third, different regime; keep each file's regime explicit in its header comment.

### Decision-ID comments
**Source:** every function in `statusline.sh` (e.g. lines 36-37, 88, 219) and section headers in `tests/run.sh` (e.g. line 245 `# --- 8. Git-state matrix (GIT-01..06, D-17..D-27)`)
New files and the kit's shell block should tag lines/sections with the D-xx / PORT-xx / DOCS-xx they implement (`# D-32`, `# PORT-04`, `# D-39`).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `kit/spec.yaml` | config (sbx kit manifest) | batch + event-driven | No YAML/kit/config files exist in the repo; use RESEARCH.md §Pattern 1 (grammar verified with `sbx kit validate` v0.39.0) and validate locally |
| `README.md` (install/sandbox prose) | docs | — | No README exists; `project-brief.md` covers tone and the example/legend only — install, snippet, sandbox, verify sections come from RESEARCH.md §Code Examples / §Pattern 4 |

## Metadata

**Analog search scope:** repo root, `tests/`, `tests/fixtures/`, `.claude/`, `.planning/research/ARCHITECTURE.md` (layout lines), `.planning/phases/02-git-segment/02-PATTERNS.md` (format precedent)
**Files scanned:** 13 tracked non-planning files (all read) + 3 planning/reference docs
**Pattern extraction date:** 2026-08-22
