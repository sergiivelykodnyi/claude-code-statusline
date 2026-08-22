#!/bin/bash
# tests/run.sh — never-fail regression harness for statusline.sh.
# One command proves the whole contract: helper tables, all fixture states,
# exit/stderr silence, threshold colors, palette purity, eval-injection
# safety, and the git-state matrix against real temp repos. bash 3.2-safe
# (runs on the macOS host /bin/bash).
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
TESTTMP=$(mktemp -d "${TMPDIR:-/tmp}/statusline-git.XXXXXX") || exit 1
trap 'rm -f "$ERRTMP"; rm -rf "$TESTTMP"' EXIT

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

# 7.2 Arithmetic-reachable numeric fields (CR-01 regression). A string of
# the form x[$(cmd)] reaching a $(( )) sink is command-substituted as an
# array subscript by bash 3.2.57 — so these MUST run under /bin/bash (the
# host 3.2), where newer bash would hide the defect. The jq numeric guard
# at the ingestion boundary must empty the field before it gets there.
for spec in 'five_hour resets_at:.rate_limits.five_hour.resets_at' \
            'seven_day resets_at:.rate_limits.seven_day.resets_at' \
            'context_window total_input_tokens:.context_window.total_input_tokens' \
            'context_window context_window_size:.context_window.context_window_size' \
            'context_window used_percentage:.context_window.used_percentage'; do
  label=${spec%%:*}; path=${spec#*:}
  rm -f tests/.pwned
  jq "$path = \"x[\$(touch tests/.pwned)]\"" \
     tests/fixtures/full.json | /bin/bash "$SL" > /dev/null 2>&1
  rc=$?
  check_eq "injection probe: $label exit code" "0" "$rc"
  [ ! -e tests/.pwned ]
  check_ok "injection probe: $label tests/.pwned not created" $?
done
rm -f tests/.pwned

# 7.3 Non-numeric numeric field (WR-02): must render hide-over-placeholder
# (empty CTX_TOK -> 0) with zero stderr — no 'integer expression expected'.
out=$(jq '.context_window.total_input_tokens = "abc"' tests/fixtures/full.json \
        | /bin/bash "$SL" 2>"$ERRTMP")
errbytes=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
check_eq "non-numeric probe: total_input_tokens stderr bytes" "0" "$errbytes"
check_eq "non-numeric probe: total_input_tokens line 1" "Opus 5 (high) · myproject" \
  "$(printf '%s\n' "$out" | strip_ansi | sed -n 1p)"
check_eq "non-numeric probe: total_input_tokens line 2" "10%/0/1M · 50%/5h (now) · 15%/1w (now)" \
  "$(printf '%s\n' "$out" | strip_ansi | sed -n 2p)"

# --- 8. Git-state matrix (GIT-01..06, D-17..D-27) ----------------------------
# Real temp repos under $TESTTMP, built hermetically with a config-isolated
# git wrapper so host config (gpgsign, hooks, init.defaultBranch) cannot
# leak in. The rendered script itself keeps calling plain git, as it does
# in production.

# tgit: repo-building git with host/global config isolated.
tgit() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"; }

# mk_repo NAME -> path of an isolated repo pinned to main (portable pin via
# symbolic-ref, no init -b version dependency) with its own identity.
mk_repo() {
  local r="$TESTTMP/$1"
  mkdir "$r" || return 1
  tgit -C "$r" init -q
  tgit -C "$r" symbolic-ref HEAD refs/heads/main
  tgit -C "$r" config user.email test@example.com
  tgit -C "$r" config user.name Test
  printf '%s\n' "$r"
}

# git_render DIR — full.json with workspace.current_dir pointed at DIR,
# piped through the script; mirrors run_fixture's capture discipline into
# globals GR_OUT / GR_RC / GR_ERRBYTES.
git_render() {
  GR_OUT=$(jq --arg d "$1" '.workspace.current_dir = $d' tests/fixtures/full.json \
             | /bin/bash "$SL" 2>"$ERRTMP"); GR_RC=$?
  GR_ERRBYTES=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
}

# git_line1 DIR -> ANSI-stripped line 1 for that directory. Runs in a
# command substitution, so callers needing GR_RC/GR_ERRBYTES/GR_OUT must
# call git_render directly instead.
git_line1() {
  git_render "$1"
  printf '%s\n' "$GR_OUT" | strip_ansi | sed -n 1p
}

# 8.1 not-a-repo: segment and its joiner space entirely absent (GIT-01).
mkdir "$TESTTMP/plaindir"
git_render "$TESTTMP/plaindir"
l1=$(printf '%s\n' "$GR_OUT" | strip_ansi | sed -n 1p)
check_eq "git not-a-repo: line 1" "Opus 5 (high) · plaindir" "$l1"
check_eq "git not-a-repo: exit code" "0" "$GR_RC"
check_eq "git not-a-repo: stderr bytes" "0" "$GR_ERRBYTES"

# 8.2 progressive repo w: clean in-sync -> boundary ones -> full form.
tgit init -q --bare "$TESTTMP/remote.git"
tgit -C "$TESTTMP/remote.git" symbolic-ref HEAD refs/heads/main
W=$(mk_repo w)
echo one > "$W/f"
tgit -C "$W" add f
tgit -C "$W" commit -q -m c1
tgit -C "$W" remote add origin "$TESTTMP/remote.git"
tgit -C "$W" push -q -u origin main 2>/dev/null

# clean in-sync: no dirty star, no counter tokens at zero (GIT-04/GIT-05
# boundary low side, D-27).
check_eq "git clean in-sync: line 1" "Opus 5 (high) · w ⎇ main ≡" "$(git_line1 "$W")"

# boundary ones: exactly one behind / one ahead / one stash all render
# (GIT-04/GIT-05 boundary high side, D-27).
tgit clone -q "$TESTTMP/remote.git" "$TESTTMP/w2" 2>/dev/null
tgit -C "$TESTTMP/w2" config user.email test2@example.com
tgit -C "$TESTTMP/w2" config user.name Test2
tgit -C "$TESTTMP/w2" commit -q --allow-empty -m r1
tgit -C "$TESTTMP/w2" push -q origin main 2>/dev/null
tgit -C "$W" fetch -q origin
tgit -C "$W" commit -q --allow-empty -m l1
echo two > "$W/f"
tgit -C "$W" stash push -q
check_eq "git boundary ones: line 1" "Opus 5 (high) · w ⎇ main ≡ ↓1 ↑1 #1" "$(git_line1 "$W")"

# full form: behind 2, ahead 3, 2 stashes, untracked file -> dirty star
# (roadmap criterion 1).
tgit -C "$TESTTMP/w2" commit -q --allow-empty -m r2
tgit -C "$TESTTMP/w2" push -q origin main 2>/dev/null
tgit -C "$W" fetch -q origin
tgit -C "$W" commit -q --allow-empty -m l2
tgit -C "$W" commit -q --allow-empty -m l3
echo three > "$W/f"
tgit -C "$W" stash push -q
touch "$W/untracked"
git_render "$W"
FULL_RAW=$GR_OUT
l1=$(printf '%s\n' "$FULL_RAW" | strip_ansi | sed -n 1p)
check_eq "git full form: line 1" "Opus 5 (high) · w ⎇ main* ≡ ↓2 ↑3 #2" "$l1"
check_eq "git full form: exit code" "0" "$GR_RC"
check_eq "git full form: stderr bytes" "0" "$GR_ERRBYTES"

# 8.3 no-upstream with a slashed branch name rendered byte-verbatim
# (GIT-02 encoding edge, GIT-03 red-glyph state).
NB=$(mk_repo noup)
tgit -C "$NB" checkout -q -b feature/x-1
echo x > "$NB/f"
tgit -C "$NB" add f
tgit -C "$NB" commit -q -m c1
git_render "$NB"
NOUP_RAW=$GR_OUT
l1=$(printf '%s\n' "$NOUP_RAW" | strip_ansi | sed -n 1p)
check_eq "git no-upstream verbatim branch: line 1" \
  "Opus 5 (high) · noup ⎇ feature/x-1 ≢" "$l1"

# 8.4 detached HEAD: short SHA label, sync symbol hidden entirely
# (D-24/D-25 — exact equality proves no glyph and no star).
DT=$(mk_repo det)
echo a > "$DT/f"; tgit -C "$DT" add f; tgit -C "$DT" commit -q -m c1
echo b > "$DT/f"; tgit -C "$DT" add f; tgit -C "$DT" commit -q -m c2
tgit -C "$DT" checkout -q --detach HEAD~1
DSHA=$(tgit -C "$DT" rev-parse --short HEAD)
check_eq "git detached: line 1" "Opus 5 (high) · det ⎇ $DSHA" "$(git_line1 "$DT")"

# 8.5 unborn branch (no commits) with one untracked file (D-26).
UB=$(mk_repo unborn)
touch "$UB/f"
check_eq "git unborn: line 1" "Opus 5 (high) · unborn ⎇ main* ≢" "$(git_line1 "$UB")"

# 8.6 marker color bytes (D-17..D-20) — must match seg_git's composition
# exactly: magenta branch span incl. glyph, yellow star, green has-upstream
# glyph, whole-token yellow behind / green ahead / dim stash.
want="${ESC}[35m⎇ main${ESC}[0m${ESC}[33m*${ESC}[0m ${ESC}[32m≡${ESC}[0m ${ESC}[33m↓2${ESC}[0m ${ESC}[32m↑3${ESC}[0m ${ESC}[2m#2${ESC}[0m"
case "$FULL_RAW" in *"$want"*) r=0;; *) r=1;; esac
check_ok "git color bytes: magenta branch, yellow *, green ≡, yellow ↓2, green ↑3, dim #2" $r

# red no-upstream glyph — the user's explicit choice (D-19).
want="${ESC}[31m≢${ESC}[0m"
case "$NOUP_RAW" in *"$want"*) r=0;; *) r=1;; esac
check_ok "git color bytes: red ≢ on no-upstream (D-19)" $r

# 8.7 palette purity over the git render — section 6 runs on a non-repo
# fixture and never sees magenta; this pass exercises the git colors.
r=0
for s in $(printf '%s\n' "$FULL_RAW" \
             | grep -o "${ESC}\[[0-9;]*m" | sed "s/${ESC}\[//" | sort -u); do
  case " 0m 2m 31m 32m 33m 34m 35m 36m " in
    *" $s "*) ;;
    *) r=1; printf '  unexpected SGR sequence: %s\n' "$s" ;;
  esac
done
check_ok "git palette purity: full-form render only 0m/2m/31m/32m/33m/34m/35m/36m" $r

# --- 9. Render latency budget (PORT-02, D-28/D-29) ---------------------------
# 10 sequential uncached full renders must fit in 2 wall-clock seconds:
# that bounds the average at <=200ms per render — well under the ~300ms
# debounce (roadmap criterion 4) — while whole-second date +%s granularity
# (BSD/GNU portable; no GNU-only nanosecond format) plus ~0.5s actual keeps
# the check flake-proof on slow CI. The payload is materialized once so jq
# cost outside the script is not measured: the measured unit is exactly one
# full render (1 jq pass inside the script + the git calls). Each render
# does real uncached git work against the full-form repo (D-29) — no cache,
# no warm-up, no skip logic: a genuinely slow script must fail here.
LATENCY_PAYLOAD="$TESTTMP/latency.json"
jq --arg d "$W" '.workspace.current_dir = $d' tests/fixtures/full.json > "$LATENCY_PAYLOAD"
t0=$(date +%s)
for i in 1 2 3 4 5 6 7 8 9 10; do
  /bin/bash "$SL" < "$LATENCY_PAYLOAD" > /dev/null 2>&1
done
t1=$(date +%s)
elapsed=$(( t1 - t0 ))
[ "$elapsed" -le 2 ]
check_ok "latency: 10 full renders in ${elapsed}s (budget 2s)" $?

# --- 10. Optional shellcheck advisory (never fails the harness) --------------

if command -v shellcheck > /dev/null 2>&1; then
  printf 'INFO shellcheck advisory (non-failing):\n'
  shellcheck --shell=bash "$SL" || true
else
  printf 'INFO shellcheck not installed — advisory skipped (accepted default)\n'
fi

# --- Result -----------------------------------------------------------------

printf '%d checks, %d failures\n' "$CHECKS" "$FAILS"
[ "$FAILS" -eq 0 ]
