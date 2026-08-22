---
phase: 03-install-dual-environment-validation
reviewed: 2026-08-22T15:23:10Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - .gitignore
  - README.md
  - kit/files/home/.claude/statusline.sh
  - kit/spec.yaml
  - tests/render-fixtures.sh
  - tests/run.sh
  - tests/sandbox.sh
findings:
  critical: 1
  warning: 3
  info: 6
  total: 10
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-22T15:23:10Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the Phase 3 install/packaging deliverables: the sbx mixin kit (`kit/spec.yaml`), the relocated script, the two new test helpers (`tests/render-fixtures.sh`, `tests/sandbox.sh`), the `tests/run.sh` re-point, the README and `.gitignore`.

Verification performed (read-only): `git show 64b3c1b:statusline.sh | cmp - kit/files/home/.claude/statusline.sh` — **identical**, index mode 100755, so the script content was not re-audited (Phase 2 review stands); only its new location / exec-bit aspects were checked. `/bin/bash -n` clean on all four scripts; `shellcheck --shell=bash` reports only SC2319/SC2194/SC2034 advisories in `tests/run.sh` (the `check_ok ... $?` idiom works as written — `$?` is expanded before the call); `/bin/bash tests/run.sh` → `126 checks, 0 failures`; `sbx kit validate kit` → `VALID`; `sbx exec --help` confirms the `-e` flag placement used in `tests/sandbox.sh` 5.8; `sbx rm --help` confirms removal "cannot be undone". The kit's jq merge expression was exercised against empty / invalid / array / null / multi-document / string inputs on jq 1.7.1 and produced a valid object with the four-key `statusLine` in every case. All scripts stay inside the bash 3.2 / BSD-GNU-neutral subset (no `declare -A`, `mapfile`, `${var,,}`, `date -d/-r`, `readlink -f`, `sed -i`, `echo -e`); the only GNU/root-specific code is the `setup.startup` shell inside `kit/spec.yaml`, as allowed.

Key concerns: `tests/sandbox.sh` force-removes whatever sandbox name it is handed (irreversible, no guard) — contrary to the stated contract that it only ever removes `statusline-kit-test` / `statusline-kit-test-add`; the D-32 stop/start probe can pass vacuously; stale `tests/out/*/installed` directories can produce a false PORT-04 FAIL; and the root-run startup hook in `kit/spec.yaml` follows agent-controlled symlinks when it `chmod`s / `chown`s / pre-seeds.

## Critical Issues

### CR-01: `tests/sandbox.sh` irreversibly force-removes any user-supplied sandbox name with no guard

**File:** `tests/sandbox.sh:55`, `tests/sandbox.sh:156`, `tests/sandbox.sh:236`, `tests/sandbox.sh:257`, `tests/sandbox.sh:263`, `tests/sandbox.sh:144`
**Issue:** `NAME` is an arbitrary positional argument (line 55 only supplies the default). Line 156 then runs `sbx rm -f "$NAME"` unconditionally *before* anything is created ("always start clean"), and lines 144/236/257 do the same for `"$NAME-add"`. `sbx rm` is documented as "This action cannot be undone" (stops the sandbox, removes the container, deletes sandbox state including kit-owned volumes such as agent session state). A user who runs `tests/sandbox.sh claude-myproject` — the natural reading of "NAME sandbox name" in `usage()` — loses that sandbox (and `claude-myproject-add` if it exists) with no prompt, no existence check, and no warning in the usage text. The header's own contract (lines 27-28) and the phase requirement ("must only ever remove the sandboxes named `statusline-kit-test` / `statusline-kit-test-add`") are violated as soon as a NAME is passed. If `sbx create` then fails (rc≠0, line 159-163) the script exits having destroyed the old sandbox and created nothing.
**Fix:** Constrain the destructive surface to names this script owns, e.g.:
```bash
[ -n "$NAME" ] || NAME=statusline-kit-test
case "$NAME" in
  statusline-kit-test|statusline-kit-test-*) ;;
  *) printf 'ERROR: NAME must be statusline-kit-test or statusline-kit-test-<suffix> (this script force-removes NAME and NAME-add)\n' >&2; exit 2 ;;
esac
```
and/or refuse to proceed when a sandbox with that name already exists unless an explicit `--force` was given:
```bash
if sbx ls 2>/dev/null | grep -q "^$NAME[[:space:]]" && [ "$FORCE" -ne 1 ]; then
  printf 'ERROR: sandbox %s already exists; pass --force to remove and recreate it\n' "$NAME" >&2; exit 2
fi
```
Also document in `usage()` that NAME and NAME-add are removed.

## Warnings

### WR-01: D-32 "survives stop/start" check passes vacuously if `sbx stop` fails

**File:** `tests/sandbox.sh:219-221`
**Issue:** `sbx stop "$NAME" > /dev/null 2>&1` discards its exit status and nothing verifies the sandbox actually stopped. If `stop` fails (daemon hiccup, sandbox already stopped, CLI change), `wait_statusline` immediately finds the unchanged `statusLine` and the script emits `PASS statusLine survives stop/start (D-32)` without any restart having occurred — the one behaviour this check exists to prove (the startup reconcile re-running) was never exercised.
**Fix:** Capture and assert the stop, and fold it into the check:
```bash
sbx stop "$NAME" > /dev/null 2>&1; rc_stop=$?
check_ok "sandbox stopped before restart probe (D-32)" $rc_stop
wait_statusline "$NAME"; r=$?
[ "$rc_stop" -eq 0 ] || r=1
check_ok "statusLine survives stop/start (D-32)" $r
```
Optionally confirm via `sbx ls` that the status reads stopped before calling `sx` again.

### WR-02: Stale `installed/` evidence directory yields a false PORT-04 FAIL (or masks a skip)

**File:** `tests/render-fixtures.sh:39-46`, `tests/sandbox.sh:206-211`
**Issue:** `render-fixtures.sh` creates `$OUT/installed` only when `$INSTALLED` is executable, and on a later run where it is not (symlink removed, mode lost) it clears `"$OUT/installed"/*.out` but leaves the now-empty directory in place. `tests/out/` is persistent and gitignored, so that empty directory survives. `tests/sandbox.sh` then decides "both sides have an installed half" purely on `[ -d ... ]` (line 206) and runs `diff -r` between an empty host dir and a populated sandbox dir → `FAIL PORT-04: host vs sandbox installed-path renders byte-identical`, while 5.9 just reported `PASS render dump on host`. The failure message points at a render difference that does not exist; the intended outcome per line 210 was the INFO skip.
**Fix:** In `render-fixtures.sh`, remove the stale subdirectory when the installed half is skipped (still never touching `$OUT` itself):
```bash
if [ -x "$INSTALLED" ]; then
  mkdir -p "$OUT/installed" || exit 1; have_installed=1
else
  rm -f "$OUT/installed"/*.out; rmdir "$OUT/installed" 2>/dev/null || true
fi
```
and/or in `sandbox.sh` gate on content rather than directory presence (e.g. `[ -n "$(/bin/ls "$OUT_HOST/installed" 2>/dev/null)" ]` or a `for f in "$dir"/*.out; do [ -e "$f" ] ...` count like 5.10 already does for `repo/`).

### WR-03: Root startup hook follows symlinks inside the agent-writable `~/.claude`

**File:** `kit/spec.yaml:39`, `kit/spec.yaml:47`, `kit/spec.yaml:49`
**Issue:** The `setup.startup` command runs as root (`user: "0"`) every start and operates on paths the `agent` user fully controls: `[ -f "$S" ] || printf '{}\n' > "$S"` (a dangling symlink at `settings.json` makes root create a file at an arbitrary target), `chmod 0755 "$H/.claude/statusline.sh"` and `chown agent:agent ... "$H/.claude/statusline.sh"` (both follow symlinks — if `statusline.sh` is replaced by a symlink, root re-modes/re-owns the *target*). Impact inside the sandbox is bounded because the research notes the base image already grants `agent` sudo, so this is a hardening/robustness gap rather than a net-new privilege escalation — but it is also an accidental-damage path (e.g. a user who symlinks `~/.claude/statusline.sh` inside the sandbox at a workspace file gets that file `chown`ed/`chmod`ed by root on every start). The threat register entry T-03-03 ("no sandbox-runtime input is interpolated") misses that the *paths* are runtime-controlled. Additionally the guards are inconsistent: `chmod` is `|| true` (tolerating an absent file) but the following `chown` on the same path is not, so under `set -e` an absent/unreadable `statusline.sh` aborts the hook with a non-zero status after the merge has already been applied.
**Fix:** Operate only on regular, non-symlink files and keep the guard consistent:
```sh
SL=$H/.claude/statusline.sh
[ -L "$S" ] && rm -f "$S"                 # never write through a link as root
[ -f "$S" ] || printf '{}\n' > "$S"
...
if [ -f "$SL" ] && [ ! -L "$SL" ]; then chmod 0755 "$SL"; chown agent:agent "$SL"; fi
chown -h agent:agent "$H/.claude" "$S"
```
(`chown -h` is GNU coreutils, acceptable in this Linux-only block.)

## Info

### IN-01: Temp file leak and mode change in the startup merge

**File:** `kit/spec.yaml:42-45`
**Issue:** `mktemp` creates `$H/.claude/.settings.XXXXXX` with mode 0600; if `jq` fails (missing, future grammar change) `set -e` aborts and the temp file is left behind — one more `.settings.*` per start with no cleanup `trap`. When the merge succeeds, `mv` makes `settings.json` mode 0600 root-owned until the `chown` two lines later (fine functionally, but it silently changes the platform-seeded 0644 mode).
**Fix:** `trap 'rm -f "$tmp"' EXIT` right after `mktemp`, and `chmod 0644 "$tmp"` before the `mv` if the seeded mode should be preserved.

### IN-02: `try (input) catch {}` parse-error handling verified on jq 1.7.1 only

**File:** `kit/spec.yaml:44`
**Issue:** The invalid-JSON branch (T-03-02) was verified here on jq 1.7.1 (host) and is relied on for the sandbox's jq, whose version is not recorded anywhere in `tests/out/sandbox/*` (Debian bookworm / Ubuntu 22.04 images ship 1.6). The sandbox evidence only exercised the valid-object path.
**Fix:** Emit `jq --version` into EVIDENCE.txt from `tests/sandbox.sh` (one `sx "$NAME" jq --version` INFO line), or make the pre-seed version-independent: `jq -e 'type=="object"' "$S" >/dev/null 2>&1 || printf '{}\n' > "$S"` before the merge.

### IN-03: `render-fixtures.sh` resolves a relative OUTDIR against the repo root, not the caller's cwd

**File:** `tests/render-fixtures.sh:30-32`
**Issue:** `cd "$(dirname "$0")/.."` happens before `OUT=${1:?...}` is used, so `tests/render-fixtures.sh out` run from `tests/` writes `<repo>/out/`, not `tests/out/`. Works for `tests/sandbox.sh` (which cds to the repo root first) but is undocumented in the usage header.
**Fix:** Either document "OUTDIR is relative to the repo root" in the header, or resolve it first: `case "$1" in /*) OUT=$1 ;; *) OUT=$PWD/$1 ;; esac` before the `cd`.

### IN-04: Informational probe is emitted with a literal `FAIL` prefix in a zero-failure run

**File:** `tests/sandbox.sh:250`, `tests/sandbox.sh:258`
**Issue:** The current EVIDENCE.txt contains `FAIL sbx kit add delivers ...` followed by `11 checks, 0 failures`. Anything that greps `^FAIL` (CI log scanners, a future `run.sh`-style consumer, a human skimming) sees a failure that the summary denies. The "[probe, not counted]" suffix mitigates but does not remove the ambiguity.
**Fix:** Use a distinct vocabulary for probes, e.g. `PROBE-PASS` / `PROBE-FAIL` (or `INFO probe kit-add: FAIL ...`), keeping PASS/FAIL reserved for counted checks.

### IN-05: Installed-path advisory silently skips a dangling symlink

**File:** `tests/run.sh:426-428`
**Issue:** `[ -e "$HOME/.claude/statusline.sh" ]` follows the symlink, so a dangling link (e.g. the README `ln -sf` run from the wrong directory, or a repo moved after linking) prints nothing — exactly the case where an INFO line would be most useful.
**Fix:** `if [ -e "$f" ] || [ -L "$f" ]; then printf 'INFO installed: %s\n' "$(ls -l "$f")"; fi` (and `[ -e ] || printf 'INFO installed: DANGLING symlink'`).

### IN-06: Startup hook couples to the undocumented `themeId` seed key (up to 60 s delay per start)

**File:** `kit/spec.yaml:37`
**Issue:** The wait loop polls for the literal `themeId` to detect the platform seed. If a future sbx/Claude Code version seeds a different key set, every sandbox start pays the full 60 s before the merge runs (documented as "delays, never blocks", but a 60 s start-up penalty on every boot would be hard to diagnose from inside the sandbox).
**Fix:** Acceptable as designed; consider also accepting any non-empty JSON object with ≥1 key as "seeded" (`jq -e 'type=="object" and length>0' "$S"`), and/or log the elapsed wait so the penalty is visible in `sbx` startup logs.

---

_Reviewed: 2026-08-22T15:23:10Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
