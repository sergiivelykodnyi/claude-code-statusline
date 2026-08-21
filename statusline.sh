#!/bin/bash
# statusline.sh — two-line framed Claude Code status line.
# Reads the Claude Code JSON payload on stdin, prints two ANSI-colorized
# lines to stdout, always exits 0. bash 3.2-compatible (macOS /bin/bash).
# No set -e / set -u: an aborting probe would blank the whole line.

# --- ANSI named-16 palette (D-02: theme-remapped colors only) ---------------
RESET=$'\033[0m'
DIM=$'\033[2m'      # SGR 2 faint — adapts to light/dark themes (D-02)
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
CYAN=$'\033[36m'

# --- Pure helpers -----------------------------------------------------------

# shorten_num N -> k/M-shortened number (D-08: one decimal below 10 scaled
# units, trailing .0 dropped, truncation not rounding).
shorten_num() {
  local n=$1 u div t i f
  if [ "$n" -ge 1000000 ]; then u=M; div=1000000
  elif [ "$n" -ge 1000 ]; then u=k; div=1000
  else printf '%s' "$n"; return; fi
  t=$(( n * 10 / div ))                       # scaled value x10, truncated
  if [ "$t" -lt 100 ]; then                   # below 10 units -> one decimal
    i=$(( t / 10 )); f=$(( t % 10 ))
    if [ "$f" -eq 0 ]; then printf '%s%s' "$i" "$u"       # drop trailing .0
    else printf '%s.%s%s' "$i" "$f" "$u"; fi
  else
    printf '%s%s' $(( n / div )) "$u"         # >=10 units -> integer
  fi
}

# pct_color INT -> echoes the threshold color; caller wraps ONLY the number
# (D-03/D-04/D-05: green below 70, yellow at >=70, red at >=90).
pct_color() {
  if [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# join_segments SEP PARTS... -> parts joined by SEP, empties skipped
# (D-14/PRES-04: never a dangling separator).
join_segments() {
  local sep="$1" out="" part; shift
  for part in "$@"; do
    [ -n "$part" ] && out="${out:+$out$sep}$part"
  done
  printf '%s' "$out"
}

# --- Segment renderers (each echoes its segment or the empty string) --------

# Model name (suffix-stripped, cyan) + optional dim effort (SESH-01/02, D-06).
seg_model_effort() {
  [ -n "$MODEL" ] || return 0
  local name=${MODEL%% (*}                    # "Opus 5 (1M context)" -> "Opus 5"
  local out="${CYAN}${name}${RESET}"
  [ -n "$EFFORT" ] && out="${out} ${DIM}(${EFFORT})${RESET}"
  printf '%s' "$out"
}

# Directory basename in blue, full length, PWD fallback (SESH-03, D-13, D-16).
seg_dir() {
  local d=${DIR##*/}
  [ -z "$d" ] && d=${PWD##*/}
  printf '%s' "${BLUE}${d}${RESET}"
}

# Context usage pct/tokens/window; renders only when the window size is
# known (CTX-01/02, D-05, D-07, PRES-03).
seg_context() {
  [ -n "$CTX_WIN" ] || return 0
  local pct=${CTX_PCT%.*} tok=$CTX_TOK
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  [ -z "$tok" ] && tok=0
  printf '%s%s%s%%/%s/%s' "$(pct_color "$pct")" "$pct" "$RESET" \
    "$(shorten_num "$tok")" "$(shorten_num "$CTX_WIN")"
}

# --- Main -------------------------------------------------------------------

main() {
  # Ingestion: one jq pass, @sh-quoted, // "" on every field. Do not branch
  # on jq's exit code (empty stdin exits 0 with no output).
  local input vars sep model_seg dir_seg body
  input=$(cat)
  vars=$(printf '%s' "$input" | jq -r '@sh "
    MODEL=\(.model.display_name // "")
    EFFORT=\(.effort.level // "")
    DIR=\(.workspace.current_dir // "")
    CTX_PCT=\(.context_window.used_percentage // "")
    CTX_TOK=\(.context_window.total_input_tokens // "")
    CTX_WIN=\(.context_window.context_window_size // "")
    P5_PCT=\(.rate_limits.five_hour.used_percentage // "")
    P5_RST=\(.rate_limits.five_hour.resets_at // "")
    P7_PCT=\(.rate_limits.seven_day.used_percentage // "")
    P7_RST=\(.rate_limits.seven_day.resets_at // "")
  " ' 2>/dev/null)
  eval "$vars"

  sep=" ${DIM}·${RESET} "                     # dim separator (D-01)

  model_seg=$(seg_model_effort)
  dir_seg=$(seg_dir)
  # Phase 2 seam: the git segment appends to dir_seg with a plain space
  # (dir_seg="$dir_seg $git_seg") before this join.
  body=$(join_segments "$sep" "$model_seg" "$dir_seg")
  LINE1="${DIM}╭─${RESET}${body:+ $body}${RESET}"

  body=$(join_segments "$sep" "$(seg_context)")
  if [ -n "$body" ]; then
    LINE2="${DIM}╰─${RESET} ${body}${RESET}"
  else
    LINE2="${DIM}╰─${RESET}"                  # bare bottom frame (D-11)
  fi

  printf '%s\n' "$LINE1"
  printf '%s\n' "$LINE2"
  exit 0                                      # unconditional (PORT-03)
}

# Source guard: run only when executed, so a test harness can source the
# helpers without triggering cat/exit (bash 3.2-safe).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi
