#!/bin/bash
# statusline.sh — two-line flush-left Claude Code status line (D-21: frameless).
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
MAGENTA=$'\033[35m'
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

# fmt_duration DELTA_SECONDS -> countdown text (D-09/D-10: only leading zero
# units drop, past resets print "now" — caller adds the parens).
fmt_duration() {
  local delta=$1 d h m
  if [ "$delta" -le 0 ]; then printf 'now'; return; fi      # D-10
  if [ "$delta" -lt 60 ]; then printf '<1m'; return; fi
  d=$(( delta / 86400 )); h=$(( delta % 86400 / 3600 )); m=$(( delta % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%sd:%sh:%sm' "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then printf '%sh:%sm' "$h" "$m"
  else printf '%sm' "$m"; fi
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

# Git segment: magenta "⎇ branch", yellow dirty star, green/red sync symbol,
# yellow behind / green ahead counts, dim stash count — hidden entirely
# outside a repo (GIT-01..05, D-17..D-20, D-24..D-27). One primary status
# call parsed below, plus one stash count; all read-only and lock-free via
# GIT_OPTIONAL_LOCKS=0, uncached per D-29 (PORT-02).
seg_git() {
  [ -n "$DIR" ] || return 0                   # stdin workspace dir only, never $PWD
  local status line label upstream=0 detached=0 dirty=0 ahead=0 behind=0 ab stash sha out
  status=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch 2>/dev/null) || return 0
  # bash-3.2-safe parse: here-string keeps the loop in this shell (a pipe
  # would fork a subshell and lose every variable set inside it).
  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*)     label=${line#'# branch.head '} ;;
      '# branch.upstream '*) upstream=1 ;;
      '# branch.ab '*)                        # "+A -B" -> ahead A, behind B
        ab=${line#'# branch.ab '}
        ahead=${ab%% *};  ahead=${ahead#+}
        behind=${ab##* }; behind=${behind#-} ;;
      '#'*) ;;                                # other headers (branch.oid, ...)
      '') ;;
      *) dirty=1 ;;                           # any entry line -> dirty (GIT-02)
    esac
  done <<< "$status"
  [ -n "$label" ] || return 0                 # defensive: never render a bare glyph
  [ -z "$ahead" ]  && ahead=0                 # guard empties before arithmetic
  [ -z "$behind" ] && behind=0
  if [ "$label" = '(detached)' ]; then        # D-24: short SHA as the label
    detached=1
    sha=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
    [ -n "$sha" ] && label=$sha               # fallback: keep the literal, never empty
  fi
  stash=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" rev-list --walk-reflogs --count refs/stash 2>/dev/null)
  [ -z "$stash" ] && stash=0                  # no stash ref -> 0
  out="${MAGENTA}⎇ ${label}${RESET}"
  [ "$dirty" -eq 1 ] && out="${out}${YELLOW}*${RESET}"
  if [ "$detached" -eq 0 ]; then              # D-25: no sync symbol when detached
    if [ "$upstream" -eq 1 ]; then out="${out} ${GREEN}≡${RESET}"
    else out="${out} ${RED}≢${RESET}"; fi     # red is the user's explicit choice (D-19)
  fi
  [ "$behind" -gt 0 ] && out="${out} ${YELLOW}↓${behind}${RESET}"
  [ "$ahead" -gt 0 ]  && out="${out} ${GREEN}↑${ahead}${RESET}"
  [ "$stash" -gt 0 ]  && out="${out} ${DIM}#${stash}${RESET}"
  printf '%s' "$out"
}

# Context usage pct/tokens/window; renders only when the window size is
# known (CTX-01/02, D-05, D-07, PRES-03).
seg_context() {
  [ -n "$CTX_WIN" ] || return 0
  local pct=${CTX_PCT%.*} tok=$CTX_TOK
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  [ -z "$tok" ] && tok=0
  printf '%s%s%%%s/%s/%s' "$(pct_color "$pct")" "$pct" "$RESET" \
    "$(shorten_num "$tok")" "$(shorten_num "$CTX_WIN")"
}

# 5-hour rate-limit segment pct/5h (countdown) (LIM-01, D-05, D-07, D-09/D-10).
seg_5h() {
  [ -n "$P5_PCT" ] || return 0
  local pct=${P5_PCT%.*} out
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  out="$(pct_color "$pct")${pct}%${RESET}/5h"
  [ -n "$P5_RST" ] && out="${out} ($(fmt_duration $(( P5_RST - NOW ))))"
  printf '%s' "$out"
}

# Weekly rate-limit segment pct/1w (countdown) (LIM-02, D-05, D-07, D-09/D-10).
seg_1w() {
  [ -n "$P7_PCT" ] || return 0
  local pct=${P7_PCT%.*} out
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  out="$(pct_color "$pct")${pct}%${RESET}/1w"
  [ -n "$P7_RST" ] && out="${out} ($(fmt_duration $(( P7_RST - NOW ))))"
  printf '%s' "$out"
}

# --- Main -------------------------------------------------------------------

main() {
  # Ingestion: one jq pass, @sh-quoted, // "" on every field, plus a type
  # guard on every field. The 3 string fields carry a string type guard: a
  # non-string (array, object, number, bool) becomes the empty string, so a
  # JSON array can never fan out into multiple eval words (@sh quotes each
  # array element as its own word, which eval would run as a command). The
  # 7 numeric fields carry a numeric type guard: a non-number (string,
  # object, ...) becomes the empty string and is skipped by the hide-on-empty
  # gates below, so untrusted stdin can never reach the $(( )) arithmetic
  # sinks (bash 3.2 command-substitutes an array subscript there). Every
  # assignment eval sees is therefore exactly one quoted word or empty. Do
  # not branch on jq's exit code (empty stdin exits 0 with no output).
  local input vars sep model_seg dir_seg git_seg body NOW LINE1 LINE2
  input=$(cat)
  vars=$(printf '%s' "$input" | jq -r '@sh "
    MODEL=\(.model.display_name // "" | strings // "")
    EFFORT=\(.effort.level // "" | strings // "")
    DIR=\(.workspace.current_dir // "" | strings // "")
    CTX_PCT=\(.context_window.used_percentage // "" | numbers // "")
    CTX_TOK=\(.context_window.total_input_tokens // "" | numbers // "")
    CTX_WIN=\(.context_window.context_window_size // "" | numbers // "")
    P5_PCT=\(.rate_limits.five_hour.used_percentage // "" | numbers // "")
    P5_RST=\(.rate_limits.five_hour.resets_at // "" | numbers // "")
    P7_PCT=\(.rate_limits.seven_day.used_percentage // "" | numbers // "")
    P7_RST=\(.rate_limits.seven_day.resets_at // "" | numbers // "")
  " ' 2>/dev/null)
  eval "$vars"

  NOW=$(date +%s)                             # single date call, reused for both windows (LIM-03)

  sep=" ${DIM}·${RESET} "                     # dim separator (D-01)

  model_seg=$(seg_model_effort)
  dir_seg=$(seg_dir)
  git_seg=$(seg_git)
  # Phase 2: the git segment is attached to the directory with a plain
  # space; empty outside a repo, so no trailing space leaks (GIT-01).
  dir_seg="$dir_seg${git_seg:+ $git_seg}"
  body=$(join_segments "$sep" "$model_seg" "$dir_seg")
  LINE1="${body}${RESET}"

  body=$(join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)")
  if [ -n "$body" ]; then
    LINE2="${body}${RESET}"
  else
    LINE2=""                                  # blank second line (D-22)
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
