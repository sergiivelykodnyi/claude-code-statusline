#!/bin/bash
# tests/sandbox.sh — host-side orchestrator for the sandbox half of D-39:
# creates a Docker Sandbox from this repo with the kit in kit/, proves the
# kit-delivered script and the merged statusLine settings inside it, runs the
# full harness and the raw render dumper in the sandbox, diffs the sandbox
# renders byte-for-byte against the host renders (PORT-01, PORT-04), probes
# the stop/start (D-32) and `sbx kit add` (D-37a) behaviours, and writes every
# PASS/FAIL/INFO line plus the summary to tests/out/sandbox/EVIDENCE.txt.
#
# Runs on the macOS HOST only: bash 3.2-safe, BSD/GNU-neutral. Needs `sbx`
# (Docker Sandboxes CLI, v0.39.0) and a reachable sandboxd (Docker Desktop
# running). It never starts Docker itself.
#
# Usage: /bin/bash tests/sandbox.sh [--rm] [--help] [NAME]
#   NAME    sandbox name (default: statusline-kit-test); the kit-add probe
#           sandbox is <NAME>-add
#   --rm    remove the primary sandbox at the end (default: keep it so the
#           live check can attach with `sbx run --name <NAME>`)
#   --help  print this usage and exit 0 (before any sbx call)
#
# Exit status: 0 when every check passed; 1 when any check failed; 2 on a
# usage error or when sbx / sandboxd is unavailable (helpers may exit
# non-zero — only statusline.sh itself is never-fail). The `sbx kit add`
# probe (D-37a) is informational: it is reported as a PASS/FAIL line but not
# counted in the summary — the README follows whichever answer it gives.
#
# Only the two sandboxes this script names (NAME and NAME-add) are ever
# removed; the remove-everything form of `sbx rm` is never used (T-03-10).
# Evidence lives under tests/out/ (gitignored, same absolute path on host and
# in the sandbox) — never under $TMPDIR, which differs per environment.

# --- 1. Argument parsing (first: no cd, no mkdir, no sbx, no trap yet) -----

usage() {
  printf 'Usage: /bin/bash tests/sandbox.sh [--rm] [--help] [NAME]\n'
  printf '  NAME    sandbox name (default: statusline-kit-test); probe sandbox is <NAME>-add\n'
  printf '  --rm    remove the primary sandbox at the end (default: keep it for the live check)\n'
  printf '  --help  print this usage and exit 0\n'
  printf 'Needs: sbx (Docker Sandboxes CLI) and a running sandboxd / Docker Desktop.\n'
}

RM=0
NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --rm)      RM=1 ;;
    --*)       usage >&2; exit 2 ;;
    *)
      if [ -n "$NAME" ]; then usage >&2; exit 2; fi
      NAME=$1 ;;
  esac
  shift
done
[ -n "$NAME" ] || NAME=statusline-kit-test

# --- 2. Preamble: constants and helpers (still no sbx calls) ---------------

cd "$(dirname "$0")/.." || exit 1
KIT="$PWD/kit"
OUT_HOST=tests/out/host
OUT_SBX=tests/out/sandbox
EVID=$OUT_SBX/EVIDENCE.txt
ADD_NAME="$NAME-add"
# D-34: the documented statusLine object, in sorted-key compact form so a
# `jq -cS` read compares equal regardless of key order.
EXPECT_SL='{"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}'
SBX_SL=/home/agent/.claude/statusline.sh      # kit-delivered script (D-30)
SBX_SETTINGS=/home/agent/.claude/settings.json

CHECKS=0
FAILS=0

# emit LINE... — every PASS/FAIL/INFO line and the summary go to stdout AND
# are appended to the evidence file (created in stage 4, before any check).
emit() {
  printf '%s\n' "$*"
  printf '%s\n' "$*" >> "$EVID"
}

# check_eq NAME EXPECTED ACTUAL — tests/run.sh vocabulary, routed via emit.
check_eq() {
  CHECKS=$(( CHECKS + 1 ))
  if [ "$2" = "$3" ]; then
    emit "PASS $1"
  else
    FAILS=$(( FAILS + 1 ))
    emit "FAIL $1"
    emit "  expected: $2"
    emit "  actual:   $3"
  fi
}

# check_ok NAME STATUS (0 = pass)
check_ok() {
  CHECKS=$(( CHECKS + 1 ))
  if [ "$2" -eq 0 ]; then
    emit "PASS $1"
  else
    FAILS=$(( FAILS + 1 ))
    emit "FAIL $1"
  fi
}

# sx SANDBOX CMD... — thin wrapper (tgit style): sbx exec starts a stopped
# sandbox first, so this also serves as the restart in the D-32 probe.
sx() { sbx exec "$@"; }

# wait_statusline SANDBOX — poll up to 120 x 1 s until the sandbox's
# settings.json carries exactly the D-34 object (the kit's own startup poll
# waits up to 60 s for the platform seed, and sbx exec may have to start the
# sandbox first). Returns 0 on match, 1 on timeout; last value in WAIT_GOT.
wait_statusline() {
  local i=0
  WAIT_GOT=""
  while [ "$i" -lt 120 ]; do
    WAIT_GOT=$(sx "$1" jq -cS .statusLine "$SBX_SETTINGS" 2>/dev/null)
    if [ "$WAIT_GOT" = "$EXPECT_SL" ]; then return 0; fi
    sleep 1
    i=$(( i + 1 ))
  done
  return 1
}

# --- 3. Prechecks (the first sbx calls; before the evidence dir and trap) --

if ! command -v sbx > /dev/null 2>&1; then
  printf 'ERROR: sbx not found — install Docker Sandboxes (sbx) first\n' >&2
  exit 2
fi
# sbx ls auto-starts sandboxd and fails fast when it cannot reach it; never
# start Docker from here (Pitfall 7).
if ! sbx ls > /dev/null 2>&1; then
  printf 'ERROR: sandboxd not reachable — start Docker Desktop (or: sbx daemon start) and retry\n' >&2
  exit 2
fi

# --- 4. Evidence dir + cleanup trap (only after both prechecks passed) -----

mkdir -p "$OUT_SBX" || exit 1
: > "$EVID"
# The probe sandbox is always ours to remove; the primary one only with --rm
# (handled explicitly at the end, never by the trap).
trap 'sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true' EXIT

emit "INFO sandbox.sh start: $(date -u +%Y-%m-%dT%H:%M:%SZ) repo=$PWD kit=$KIT name=$NAME"

# --- 5. Sequence ------------------------------------------------------------

# 5.1 Kit validity (offline, D-30).
sbx kit validate "$KIT" > /dev/null 2>&1
check_ok "kit validate: sbx kit validate kit" $?

# 5.2 Fresh primary sandbox created WITH the kit — creation is the only
# moment --kit applies (D-39). The name is ours: always start clean.
sbx rm -f "$NAME" > /dev/null 2>&1 || true
CREATE_OUT=$(sbx create --name "$NAME" claude "$PWD" --kit "$KIT" 2>&1); rc=$?
check_ok "sandbox created with kit: $NAME" $rc
if [ "$rc" -ne 0 ]; then
  emit "INFO sbx create output: $CREATE_OUT"
  emit "$CHECKS checks, $FAILS failures"
  exit 1
fi

# 5.3 statusLine merged by the kit's startup reconcile (D-32/D-34).
wait_statusline "$NAME"
check_ok "statusLine merged after first start (D-32/D-34)" $?
emit "INFO observed .statusLine: $(sx "$NAME" jq -cS .statusLine "$SBX_SETTINGS" 2>&1)"
emit "INFO settings.json keys: $(sx "$NAME" jq -c 'keys' "$SBX_SETTINGS" 2>&1)"

# 5.4 Kit script present + executable (D-30, Pitfall 4).
sx "$NAME" test -x "$SBX_SL"
check_ok "kit script present and executable: $SBX_SL" $?

# 5.5 Byte-identical to the repo file — the workspace is mounted at the same
# absolute path inside the sandbox (PORT-04).
sx "$NAME" cmp -s "$SBX_SL" "$PWD/kit/files/home/.claude/statusline.sh"
check_ok "kit script byte-identical to repo file" $?

# 5.6 Record the exec user and HOME (research A4).
# shellcheck disable=SC2016  # $HOME must expand INSIDE the sandbox
emit "INFO sbx exec user: $(sx "$NAME" id -un 2>&1) HOME=$(sx "$NAME" sh -c 'echo "$HOME"' 2>&1)"

# 5.7 Full harness inside the sandbox (D-39) — summary line asserted.
sx "$NAME" /bin/bash "$PWD/tests/run.sh" > "$OUT_SBX/run.log" 2>&1; rc=$?
last=$(tail -n 1 "$OUT_SBX/run.log")
case "$last" in *"checks, 0 failures") r=0 ;; *) r=1 ;; esac
[ "$rc" -eq 0 ] || r=1
check_ok "harness in sandbox: $last" $r

# 5.8 Raw render dump inside the sandbox through the kit-delivered path
# (PORT-04 sandbox half); strict — the installed path must be there.
sx -e INSTALLED=/home/agent/.claude/statusline.sh -e REQUIRE_INSTALLED=1 "$NAME" \
  /bin/bash "$PWD/tests/render-fixtures.sh" "$OUT_SBX" > "$OUT_SBX/render.log" 2>&1
check_ok "render dump in sandbox: installed == repo (PORT-04 sandbox half)" $?

# 5.9 Same dump on the host (PORT-04 host half).
/bin/bash tests/render-fixtures.sh "$OUT_HOST" > /dev/null 2>&1
check_ok "render dump on host (PORT-04 host half)" $?

# 5.10 Host vs sandbox byte diff — the PORT-01 proof (D-39).
n_fix=0
for f in "$OUT_SBX"/repo/*.out; do [ -e "$f" ] && n_fix=$(( n_fix + 1 )); done
diff -r "$OUT_HOST/repo" "$OUT_SBX/repo" > /dev/null 2>&1
check_ok "PORT-01: host vs sandbox fixture renders byte-identical ($n_fix fixtures)" $?
if [ -d "$OUT_HOST/installed" ] && [ -d "$OUT_SBX/installed" ]; then
  diff -r "$OUT_HOST/installed" "$OUT_SBX/installed" > /dev/null 2>&1
  check_ok "PORT-04: host vs sandbox installed-path renders byte-identical" $?
else
  emit "INFO installed-path dirs not present on both sides — cross-env installed diff skipped"
fi

# 5.11 Restart probe (research OQ2, D-32): canary key written INSIDE the
# sandbox only (never the host ~/.claude — D-46), then stop + restart via
# sbx exec, then the startup reconcile must have left/re-applied statusLine.
# shellcheck disable=SC2016  # $S/$t expand INSIDE the sandbox shell
sx "$NAME" sh -c 'S=/home/agent/.claude/settings.json; t=$(mktemp /home/agent/.claude/.canary.XXXXXX) && jq ".statuslineKitCanary = 1" "$S" > "$t" && mv "$t" "$S"' > /dev/null 2>&1
emit "INFO canary written before stop: $(sx "$NAME" jq -c .statuslineKitCanary "$SBX_SETTINGS" 2>&1)"
sbx stop "$NAME" > /dev/null 2>&1
wait_statusline "$NAME"
check_ok "statusLine survives stop/start (D-32)" $?
canary=$(sx "$NAME" jq -c .statuslineKitCanary "$SBX_SETTINGS" 2>/dev/null)
if [ "$canary" = "1" ]; then
  emit "INFO restart: canary survived — other keys preserved across stop/start; statusLine re-merged idempotently"
else
  emit "INFO restart: canary gone (value: ${canary:-<none>}) — settings.json re-seeded by the engine; startup merge re-applied statusLine"
fi

# 5.12 Kit-add probe (research OQ1, D-37a): does a sandbox created WITHOUT
# the kit receive the script and the statusLine merge after `sbx kit add`?
# This is a research PROBE, not a portability check: either answer is valid
# and the README follows it (PASS -> the `sbx kit add` sentence stands;
# FAIL -> document `sbx rm` + recreate with --kit). It is reported as a
# PASS/FAIL line for the record but NOT counted in the summary, so the
# summary line certifies only the PORT-01 / PORT-04 / D-32 checks above.
sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true
ADD_CREATE=$(sbx create --name "$ADD_NAME" claude "$PWD" 2>&1); rc_c=$?
ADD_OUT=""; rc_a=1; r=1; WAIT_GOT=""
if [ "$rc_c" -eq 0 ]; then
  ADD_OUT=$(sbx kit add "$ADD_NAME" "$KIT" 2>&1); rc_a=$?
  if [ "$rc_a" -eq 0 ] && wait_statusline "$ADD_NAME" && sx "$ADD_NAME" test -x "$SBX_SL"; then
    r=0
  fi
fi
if [ "$r" -eq 0 ]; then
  KITADD=PASS
  emit "PASS sbx kit add delivers kit files + startup merge to an existing sandbox (D-37a) [probe, not counted]"
else
  KITADD=FAIL
  emit "FAIL sbx kit add delivers kit files + startup merge to an existing sandbox (D-37a) [probe, not counted — README documents sbx rm + recreate]"
  [ "$rc_c" -eq 0 ] || emit "INFO kit-add probe: sbx create (no kit) failed: $ADD_CREATE"
  emit "INFO kit-add probe: sbx kit add rc=$rc_a output: $ADD_OUT"
  # Only meaningful when `sbx kit add` itself succeeded and the add-sandbox
  # was actually polled; otherwise WAIT_GOT would be stale or empty.
  [ "$rc_a" -eq 0 ] && emit "INFO kit-add probe: .statusLine after add: ${WAIT_GOT:-<none>}"
fi
sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true
emit "INFO probes (not counted): kit-add=$KITADD (D-37a)"

# --- 6. Primary sandbox disposition + summary (summary is the LAST line) ----

if [ "$RM" -eq 1 ]; then
  sbx rm -f "$NAME" > /dev/null 2>&1
  emit "INFO sandbox $NAME removed (--rm)"
else
  emit "INFO sandbox $NAME kept for the live check: sbx run --name $NAME  (remove with: sbx rm -f $NAME)"
fi
emit "$CHECKS checks, $FAILS failures"
[ "$FAILS" -eq 0 ]
