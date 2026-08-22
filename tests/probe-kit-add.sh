#!/bin/bash
# tests/probe-kit-add.sh — D-37a install-only probe (quick task 260822-rbm).
#
# Phase 3 proved that sbx v0.39.0 refuses `sbx kit add` for any kit declaring
# setup.startup (the shipped kit/spec.yaml does: its statusLine merge runs at
# startup). This script builds a DISPOSABLE install-only variant of the kit
# (no setup.startup; the same jq merge moved into a second setup.install
# command) under gitignored tests/out/, validates it, and answers two live
# questions with PASS/FAIL lines in tests/out/kit-add-probe/EVIDENCE.txt:
#
#   Q-a  does `sbx kit add` land files/ + the install-time statusLine merge
#        on an EXISTING sandbox (created without the kit)?
#   Q-b  does an install-time merge survive the platform's late create-time
#        seed of /home/agent/.claude/settings.json (and a stop/start)?
#
# Either answer is valid evidence; a follow-up task decides from the
# `INFO verdict:` line whether kit/spec.yaml switches to install-only.
#
# Runs on the macOS HOST only: bash 3.2-safe, BSD/GNU-neutral. Needs `sbx`
# (Docker Sandboxes CLI, v0.39.0) and a reachable sandboxd (Docker Desktop
# running). It never starts Docker itself.
#
# Usage: /bin/bash tests/probe-kit-add.sh [--build-only] [--keep] [--help]
#   --build-only  build + validate the scratch kit, write evidence, exit
#                 WITHOUT creating any sandbox
#   --keep        keep the two probe sandboxes at exit (default: remove them)
#   --help        print this usage and exit 0 (before any sbx call)
#   (no NAME argument: the sandbox names are fixed — see safety below)
#
# Exit status: 0 = the probe ran to completion and every infrastructure check
# passed (the Q-a / Q-b answers live in the `INFO verdict:` line and may be
# PASS or FAIL either way); 1 = an infrastructure check failed (kit validate,
# the no-kit create, the Q-a baseline); 2 = usage error or sbx / sandboxd
# unavailable.
#
# Safety: only the two script-owned sandboxes (statusline-kit-test-addonly
# and statusline-kit-test-installonly) are ever created or removed; the
# remove-everything form of `sbx rm` is never used; nothing under kit/,
# README.md or the host ~/.claude is written (D-46); the scratch kit and the
# evidence live under gitignored tests/out/ only.

# --- 1. Argument parsing (first: no cd, no mkdir, no sbx, no trap yet) -----

usage() {
  printf 'Usage: /bin/bash tests/probe-kit-add.sh [--build-only] [--keep] [--help]\n'
  printf '  --build-only  build + validate the scratch install-only kit, write evidence, exit (no sandbox)\n'
  printf '  --keep        keep the two probe sandboxes at exit (default: remove them)\n'
  printf '  --help        print this usage and exit 0\n'
  printf 'Sandbox names are fixed: statusline-kit-test-addonly, statusline-kit-test-installonly.\n'
  printf 'Needs: sbx (Docker Sandboxes CLI) and a running sandboxd / Docker Desktop.\n'
}

BUILD_ONLY=0
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)    usage; exit 0 ;;
    --build-only) BUILD_ONLY=1 ;;
    --keep)       KEEP=1 ;;
    *)            usage >&2; exit 2 ;;
  esac
  shift
done

# --- 2. Preamble: constants and helpers (still no sbx calls) ---------------

cd "$(dirname "$0")/.." || exit 1
KIT_SRC="$PWD/kit"
OUT=tests/out/kit-add-probe
SCRATCH="$PWD/$OUT/kit-installonly"          # absolute: sbx resolves it on the host
EVID=$OUT/EVIDENCE.txt
ADD_NAME=statusline-kit-test-addonly         # Q-a: created WITHOUT kit, then sbx kit add
INST_NAME=statusline-kit-test-installonly    # Q-b: created WITH the scratch kit
# D-34: the documented statusLine object, in sorted-key compact form so a
# `jq -cS` read compares equal regardless of key order.
EXPECT_SL='{"command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60,"type":"command"}'
SBX_SL=/home/agent/.claude/statusline.sh      # kit-delivered script (D-30)
SBX_SETTINGS=/home/agent/.claude/settings.json
SBX_MARKER=/home/agent/.claude/.installonly-probe

CHECKS=0
FAILS=0

# emit LINE... — every PASS/FAIL/INFO line and the summary go to stdout AND
# are appended to the evidence file (created in stage 4, before any check).
emit() {
  printf '%s\n' "$*"
  printf '%s\n' "$*" >> "$EVID"
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
# sandbox first, so this also serves as the restart in the Q-b stop/start leg.
sx() { sbx exec "$@"; }

# wait_statusline SANDBOX — poll up to 120 x 1 s until the sandbox's
# settings.json carries exactly the D-34 object (sbx exec may have to start
# the sandbox first). Returns 0 on match, 1 on timeout; last value in WAIT_GOT.
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

# wait_seed SANDBOX — poll up to 120 x 1 s until the platform's create-time
# seed of settings.json has landed (themeId is a seed-only key). 0 = seen.
wait_seed() {
  local i=0
  while [ "$i" -lt 120 ]; do
    if sx "$1" grep -q themeId "$SBX_SETTINGS" > /dev/null 2>&1; then return 0; fi
    sleep 1
    i=$(( i + 1 ))
  done
  return 1
}

# script_ok SANDBOX — 0 iff the kit-delivered script is executable AND
# byte-identical to the repo file (the workspace is bind-mounted at the same
# absolute path inside the sandbox, as tests/sandbox.sh 5.5 relies on).
script_ok() {
  sx "$1" test -x "$SBX_SL" > /dev/null 2>&1 || return 1
  sx "$1" cmp -s "$SBX_SL" "$PWD/kit/files/home/.claude/statusline.sh" > /dev/null 2>&1 || return 1
  return 0
}

# --- 3. Prechecks (the first sbx calls; before the evidence dir and trap) --

if ! command -v sbx > /dev/null 2>&1; then
  printf 'ERROR: sbx not found — install Docker Sandboxes (sbx) first\n' >&2
  exit 2
fi
# sbx ls auto-starts sandboxd and fails fast when it cannot reach it; never
# start Docker from here. --build-only needs no daemon.
if [ "$BUILD_ONLY" -eq 0 ] && ! sbx ls > /dev/null 2>&1; then
  printf 'ERROR: sandboxd not reachable — start Docker Desktop (or: sbx daemon start) and retry\n' >&2
  exit 2
fi

# --- 4. Evidence dir + cleanup trap (only after the prechecks passed) ------

mkdir -p "$OUT" || exit 1
: > "$EVID"
# Both probe sandboxes are ours to remove — exactly these two names, nothing
# else, ever. --keep leaves them for manual inspection; --build-only never
# creates them.
if [ "$BUILD_ONLY" -eq 0 ] && [ "$KEEP" -eq 0 ]; then
  trap 'sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true; sbx rm -f "$INST_NAME" > /dev/null 2>&1 || true' EXIT
fi

SBX_VER=$(sbx version 2>/dev/null | head -n 1)
emit "INFO probe-kit-add.sh start: $(date -u +%Y-%m-%dT%H:%M:%SZ) repo=$PWD scratch=$SCRATCH sbx=${SBX_VER:-<unknown>}"

# --- 5. Scratch install-only kit: build + validate --------------------------

# Disposable, fixed path under gitignored tests/out/ — never under kit/.
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/files/home/.claude" || exit 1
cp "$KIT_SRC/files/home/.claude/statusline.sh" "$SCRATCH/files/home/.claude/statusline.sh" || exit 1
chmod 0755 "$SCRATCH/files/home/.claude/statusline.sh"

# Install entry 1 (D-33 guard) and the jq merge / chmod / chown lines are the
# HEAD kit/spec.yaml text moved from setup.startup into setup.install; the
# marker file records whether files/ had already landed when install ran
# and which user ran it. Every chmod/chown is tolerant so a files-after-
# install ordering or a non-root install user can never abort `sbx create`
# — the end-state checks and the INFO ls -ln line surface such cases.
cat > "$SCRATCH/spec.yaml" << 'EOF'
# DISPOSABLE install-only PROBE variant of kit/spec.yaml, built by
# tests/probe-kit-add.sh (D-37a). NOT the shipped kit: no setup.startup; the
# statusLine merge runs as a second setup.install command instead.
schemaVersion: "2"
kind: mixin
name: claude-code-status-line-installonly
version: "1.0.0"
displayName: Claude Code Status Line (install-only probe)
description: Probe variant — ships ~/.claude/statusline.sh and merges the statusLine key at install time only (no startup hook).
requires:
  agent: claude
setup:
  install:
    - command: command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends jq git)
      description: Guard the script's dependencies (jq, git) — no-op on the claude-code base image (D-33)
    - command: |
        set -e
        H=/home/agent
        S=$H/.claude/settings.json
        mkdir -p "$H/.claude"
        if [ -e "$H/.claude/statusline.sh" ]; then s=yes; else s=no; fi
        printf 'script_at_install=%s install_user=%s\n' "$s" "$(id -un)" > "$H/.claude/.installonly-probe"
        [ -f "$S" ] || printf '{}\n' > "$S"
        tmp=$(mktemp "$H/.claude/.settings.XXXXXX")
        jq -n 'try (input) catch {} | (if type=="object" then . else {} end) | .statusLine = {type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}' "$S" > "$tmp"
        mv "$tmp" "$S"
        chmod 0755 "$H/.claude/statusline.sh" || true
        chown agent:agent "$H/.claude" "$S" || true
        chown agent:agent "$H/.claude/statusline.sh" || true
      description: Install-time statusLine merge (D-37a install-only probe)
EOF

VALIDATE_OUT=$(sbx kit validate "$SCRATCH" 2>&1); rc=$?
check_ok "kit validate: sbx kit validate <scratch install-only kit>" $rc
if [ "$rc" -ne 0 ]; then
  emit "INFO kit validate output: $VALIDATE_OUT"
  emit "$CHECKS checks, $FAILS failures"
  exit 1
fi

if [ "$BUILD_ONLY" -eq 1 ]; then
  emit "INFO build-only: scratch kit at $SCRATCH"
  emit "$CHECKS checks, $FAILS failures"
  [ "$FAILS" -eq 0 ]
  exit $?
fi

# --- 6. Q-a: sbx kit add on an EXISTING sandbox (created without a kit) ----

QA=FAIL; QA_REASON=not-run
sbx rm -f "$ADD_NAME" > /dev/null 2>&1 || true
CREATE_OUT=$(sbx create --name "$ADD_NAME" claude "$PWD" 2>&1); rc=$?
check_ok "Q-a: sandbox created WITHOUT kit: $ADD_NAME" $rc
if [ "$rc" -ne 0 ]; then
  emit "INFO Q-a: sbx create output: $CREATE_OUT"
else
  # Baseline: no kit script and no statusLine before kit add.
  if sx "$ADD_NAME" test -e "$SBX_SL" > /dev/null 2>&1; then b_script=present; else b_script=absent; fi
  b_sl=$(sx "$ADD_NAME" jq -c .statusLine "$SBX_SETTINGS" 2>/dev/null)
  if sx "$ADD_NAME" grep -q themeId "$SBX_SETTINGS" > /dev/null 2>&1; then b_seed=yes; else b_seed=no; fi
  rb=1
  if [ "$b_script" = absent ] && { [ -z "$b_sl" ] || [ "$b_sl" = null ]; }; then rb=0; fi
  check_ok "Q-a baseline: no kit script and no statusLine before kit add" $rb
  emit "INFO Q-a baseline: script=$b_script statusLine=${b_sl:-<none>} seed(themeId)=$b_seed"

  ADD_OUT=$(sbx kit add "$ADD_NAME" "$SCRATCH" 2>&1); rc_a=$?
  emit "INFO Q-a: sbx kit add rc=$rc_a output: $ADD_OUT"
  if [ "$rc_a" -ne 0 ]; then
    QA_REASON=kit-add-rc
  else
    WAIT_GOT=""
    wait_statusline "$ADD_NAME"; ra_sl=$?
    emit "INFO Q-a: .statusLine after kit add: ${WAIT_GOT:-<none>}"
    emit "INFO Q-a: settings.json keys after kit add: $(sx "$ADD_NAME" jq -c keys "$SBX_SETTINGS" 2>&1)"
    script_ok "$ADD_NAME"; ra_f=$?
    emit "INFO Q-a: kit script after kit add: $(sx "$ADD_NAME" ls -ln "$SBX_SL" 2>&1)"
    emit "INFO Q-a: marker: $(sx "$ADD_NAME" cat "$SBX_MARKER" 2>&1)"
    if [ "$ra_sl" -eq 0 ] && [ "$ra_f" -eq 0 ]; then
      QA=PASS; QA_REASON=""
    elif [ "$ra_sl" -ne 0 ]; then
      QA_REASON=no-merge
    else
      QA_REASON=no-script
    fi
  fi
fi
if [ "$QA" = PASS ]; then
  emit "PASS Q-a: sbx kit add lands files/ + install-time statusLine merge on an existing sandbox (D-37a) [probe, not counted]"
else
  emit "FAIL Q-a: sbx kit add lands files/ + install-time statusLine merge on an existing sandbox (D-37a) [probe, not counted] reason=$QA_REASON"
fi

# --- 7. Q-b: install-time merge vs the create-time seed (and stop/start) ---

QB=FAIL; QB_REASON=create-rc
sbx rm -f "$INST_NAME" > /dev/null 2>&1 || true
INST_CREATE=$(sbx create --name "$INST_NAME" claude "$PWD" --kit "$SCRATCH" 2>&1); rc_c=$?
emit "INFO Q-b: sbx create --kit rc=$rc_c"
if [ "$rc_c" -ne 0 ]; then
  emit "INFO Q-b: sbx create output: $INST_CREATE"
else
  wait_seed "$INST_NAME"; rb_seed=$?
  if [ "$rb_seed" -eq 0 ]; then emit "INFO Q-b: platform seed (themeId) observed: yes"; else emit "INFO Q-b: platform seed (themeId) observed: no"; fi
  # Evaluated AFTER the seed was seen, so a match proves the merge coexists
  # with the seed rather than merely preceding it.
  WAIT_GOT=""
  wait_statusline "$INST_NAME"; rb_sl=$?
  emit "INFO Q-b: observed .statusLine after first start: ${WAIT_GOT:-<none>}"
  emit "INFO Q-b: settings.json keys: $(sx "$INST_NAME" jq -c keys "$SBX_SETTINGS" 2>&1)"
  script_ok "$INST_NAME"; rb_f=$?
  emit "INFO Q-b: marker: $(sx "$INST_NAME" cat "$SBX_MARKER" 2>&1)"
  emit "INFO Q-b: ownership: $(sx "$INST_NAME" ls -ln "$SBX_SETTINGS" "$SBX_SL" 2>&1)"
  # Restart leg: stop, then sbx exec (via wait_statusline) starts it again.
  sbx stop "$INST_NAME" > /dev/null 2>&1
  WAIT_GOT=""
  wait_statusline "$INST_NAME"; rb_rs=$?
  emit "INFO Q-b: .statusLine after stop/start: ${WAIT_GOT:-<none>}"
  if [ "$rb_seed" -eq 0 ] && [ "$rb_sl" -eq 0 ] && [ "$rb_f" -eq 0 ] && [ "$rb_rs" -eq 0 ]; then
    QB=PASS; QB_REASON=""
  elif [ "$rb_seed" -ne 0 ]; then
    QB_REASON=no-seed
  elif [ "$rb_sl" -ne 0 ]; then
    QB_REASON=no-merge
  elif [ "$rb_f" -ne 0 ]; then
    QB_REASON=no-script
  else
    QB_REASON=lost-on-restart
  fi
fi
if [ "$QB" = PASS ]; then
  emit "PASS Q-b: install-time statusLine merge survives the create-time seed and stop/start (D-37a) [probe, not counted]"
else
  emit "FAIL Q-b: install-time statusLine merge survives the create-time seed and stop/start (D-37a) [probe, not counted] reason=$QB_REASON"
fi

# --- 8. Verdicts + recommendation + summary (summary is the LAST line) -----

emit "INFO verdict: Q-a=$QA Q-b=$QB (D-37a install-only probe, sbx ${SBX_VER:-<unknown>})"
if [ "$QA" = PASS ] && [ "$QB" = PASS ]; then
  emit "INFO recommendation: switch kit/spec.yaml to install-only in a FOLLOW-UP task and restore the README sbx kit add sentence"
else
  emit "INFO recommendation: keep the startup-based kit; README unchanged"
fi
if [ "$KEEP" -eq 1 ]; then
  emit "INFO probe sandboxes kept (--keep): $ADD_NAME $INST_NAME — remove with: sbx rm -f $ADD_NAME ; sbx rm -f $INST_NAME"
fi
emit "$CHECKS checks, $FAILS failures"
[ "$FAILS" -eq 0 ]
