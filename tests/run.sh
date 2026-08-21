#!/bin/bash
# tests/run.sh — never-fail regression harness for statusline.sh.
# One command proves the whole Phase 1 contract: helper tables, all fixture
# states, exit/stderr silence, threshold colors, palette purity, and
# eval-injection safety. bash 3.2-safe (runs on the macOS host /bin/bash).
#
# Usage: /bin/bash tests/run.sh
# Prints one PASS/FAIL line per check; exits non-zero if any check failed.

cd "$(dirname "$0")/.." || exit 1
SL=statusline.sh

CHECKS=0
FAILS=0
ESC=$(printf '\033')

# ANSI-strip helper — BSD/GNU-portable sed on a real escape byte.
strip_ansi() { sed "s/${ESC}\[[0-9;]*m//g"; }

# check_eq NAME EXPECTED ACTUAL
check_eq() {
  CHECKS=$(( CHECKS + 1 ))
  if [ "$2" = "$3" ]; then
    printf 'PASS %s\n' "$1"
  else
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

# check_ok NAME STATUS (0 = pass)
check_ok() {
  CHECKS=$(( CHECKS + 1 ))
  if [ "$2" -eq 0 ]; then
    printf 'PASS %s\n' "$1"
  else
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL %s\n' "$1"
  fi
}

ERRTMP=$(mktemp "${TMPDIR:-/tmp}/statusline-test.XXXXXX") || exit 1
trap 'rm -f "$ERRTMP"' EXIT

# --- 1. Syntax gate ---------------------------------------------------------

/bin/bash -n "$SL" 2>/dev/null
check_ok "syntax: /bin/bash -n $SL" $?

# --- 2. Helper unit tables (source guard keeps main from running) -----------

# Sourcing statusline.sh gives us its palette constants and pure helpers;
# its BASH_SOURCE guard keeps main (cat/exit) from running when sourced.
# shellcheck disable=SC1090
. "./$SL" < /dev/null

# shorten_num — full D-08 table (truncation, one decimal below 10 units).
for pair in 0:0 999:999 1000:1k 1500:1.5k 9950:9.9k 10000:10k 100000:100k \
            147000:147k 200000:200k 999999:999k 1000000:1M 1500000:1.5M \
            12300000:12M; do
  n=${pair%%:*}; want=${pair#*:}
  check_eq "shorten_num $n -> $want" "$want" "$(shorten_num "$n")"
done

# fmt_duration — full D-09/D-10 table (leading zero units drop, past -> now).
for pair in -5:now 0:now '30:<1m' '59:<1m' 60:1m 3000:50m 10200:2h:50m \
            273420:3d:3h:57m 262800:3d:1h:0m 90061:1d:1h:1m; do
  n=${pair%%:*}; want=${pair#*:}
  check_eq "fmt_duration $n -> $want" "$want" "$(fmt_duration "$n")"
done

# pct_color — 69/70/89/90 boundary quartet (D-03/D-04, PRES-03).
check_eq "pct_color 69 -> GREEN"  "$GREEN"  "$(pct_color 69)"
check_eq "pct_color 70 -> YELLOW" "$YELLOW" "$(pct_color 70)"
check_eq "pct_color 89 -> YELLOW" "$YELLOW" "$(pct_color 89)"
check_eq "pct_color 90 -> RED"    "$RED"    "$(pct_color 90)"

# join_segments — skips empties, empty for all-empty (D-14, PRES-04).
check_eq "join_segments skips empty parts" "a|b" "$(join_segments "|" a "" b)"
check_eq "join_segments all-empty -> empty" "" "$(join_segments "|" "" "" "")"

# --- 3. End-to-end fixture loop ---------------------------------------------

# run_fixture NAME EXPECTED_L1 EXPECTED_L2 — asserts exit 0, zero stderr
# bytes, and both ANSI-stripped lines (Fixture Matrix, 01-02-PLAN.md).
run_fixture() {
  local f=$1 e1=$2 e2=$3 out rc errbytes l1 l2
  out=$(/bin/bash "$SL" < "tests/fixtures/$f.json" 2>"$ERRTMP"); rc=$?
  errbytes=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
  check_eq "$f: exit code" "0" "$rc"
  check_eq "$f: stderr bytes" "0" "$errbytes"
  l1=$(printf '%s\n' "$out" | strip_ansi | sed -n 1p)
  l2=$(printf '%s\n' "$out" | strip_ansi | sed -n 2p)
  check_eq "$f: line 1" "$e1" "$l1"
  check_eq "$f: line 2" "$e2" "$l2"
}

HERE=${PWD##*/}   # D-13 fallback renders the harness's own PWD basename

run_fixture full           "Opus 5 (high) · myproject" "10%/100k/1M · 50%/5h (now) · 15%/1w (now)"
run_fixture no-effort      "Opus 5 · myproject"        "10%/100k/1M · 50%/5h (now) · 15%/1w (now)"
run_fixture no-rate-limits "Opus 5 (high) · myproject" "10%/100k/1M"
run_fixture only-five-hour "Opus 5 (high) · myproject" "10%/100k/1M · 50%/5h (now)"
run_fixture null-context   "Opus 5 (high) · myproject" "0%/0/200k"
run_fixture empty          "$HERE"                     ""
run_fixture malformed      "$HERE"                     ""

# D-22 two-line invariant: an empty line 2 is a printed blank line, not a
# missing line — line-equality above cannot tell those apart, wc -l can.
check_eq "empty: exactly 2 output lines (D-22)" "2" \
  "$(/bin/bash "$SL" < tests/fixtures/empty.json | wc -l | tr -d '[:space:]')"

# --- 4. Live countdown ------------------------------------------------------

now=$(date +%s)
l2=$(jq --argjson t5 $(( now + 10230 )) --argjson t7 $(( now + 273450 )) \
      '.rate_limits.five_hour.resets_at = $t5 | .rate_limits.seven_day.resets_at = $t7' \
      tests/fixtures/full.json | /bin/bash "$SL" | strip_ansi | sed -n 2p)
case "$l2" in *"(2h:50m)"*"(3d:3h:57m)"*) r=0;; *) r=1;; esac
check_ok "live countdown: (2h:50m) and (3d:3h:57m) in '$l2'" $r

# --- 5. Threshold color bytes (D-05: label/countdown outside colored span) --

for spec in 69.9:32:69 70:33:70 89.9:33:89 90:31:90; do
  p=${spec%%:*}; rest=${spec#*:}; code=${rest%%:*}; num=${rest#*:}
  raw=$(jq --argjson p "$p" '.rate_limits.five_hour.used_percentage = $p' \
        tests/fixtures/full.json | /bin/bash "$SL")
  want="${ESC}[${code}m${num}%${ESC}[0m/5h"
  case "$raw" in *"$want"*) r=0;; *) r=1;; esac
  check_ok "threshold bytes: pct $p -> SGR ${code}m before ${num}%, reset before /5h" $r
done

# --- 6. Palette purity (D-02: named-16 set only) ----------------------------

r=0
for s in $(/bin/bash "$SL" < tests/fixtures/full.json \
             | grep -o "${ESC}\[[0-9;]*m" | sed "s/${ESC}\[//" | sort -u); do
  case " 0m 2m 31m 32m 33m 34m 35m 36m " in
    *" $s "*) ;;
    *) r=1; printf '  unexpected SGR sequence: %s\n' "$s" ;;
  esac
done
check_ok "palette purity: only 0m/2m/31m/32m/33m/34m/35m/36m in output" $r

# --- 7. Injection probe (T-01-01 regression) --------------------------------

rm -f tests/.pwned
jq '.workspace.current_dir = "/tmp/x; $(touch tests/.pwned)"' \
   tests/fixtures/full.json | /bin/bash "$SL" > /dev/null 2>&1
rc=$?
check_eq "injection probe: exit code" "0" "$rc"
[ ! -e tests/.pwned ]
check_ok "injection probe: tests/.pwned not created" $?
rm -f tests/.pwned

# --- 8. Optional shellcheck advisory (never fails the harness) --------------

if command -v shellcheck > /dev/null 2>&1; then
  printf 'INFO shellcheck advisory (non-failing):\n'
  shellcheck --shell=bash "$SL" || true
else
  printf 'INFO shellcheck not installed — advisory skipped (accepted default)\n'
fi

# --- Result -----------------------------------------------------------------

printf '%d checks, %d failures\n' "$CHECKS" "$FAILS"
[ "$FAILS" -eq 0 ]
