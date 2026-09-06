#!/bin/bash
# statusline.sh — two-line flush-left Claude Code status line (D-21: frameless).
# Reads the Claude Code JSON payload on stdin, prints two ANSI-colorized
# lines to stdout, always exits 0. bash 3.2-compatible (macOS /bin/bash).
# No set -e / set -u: an aborting probe would blank the whole line.
#
# Env inputs (Fable weekly segment, FAB-01..04 — D-64/D-65; defaults are the
# production values, the overrides exist for tests and opt-out):
#   STATUSLINE_NO_FABLE          non-empty -> kill switch: no credential read,
#                                no network, Fable segment hidden (D-64)
#   STATUSLINE_USAGE_URL         OAuth usage endpoint
#                                (default: https://api.anthropic.com/api/oauth/usage)
#   STATUSLINE_CREDENTIALS_FILE  credentials JSON (.claudeAiOauth.accessToken)
#                                (default: $HOME/.claude/.credentials.json, then
#                                the macOS Keychain item "Claude Code-credentials");
#                                when set explicitly it is the ONLY source — no
#                                Keychain fallback, so tests stay deterministic
#   STATUSLINE_USAGE_CACHE       shared per-user cache file, 0600, written
#                                atomically; TTL 300 s (D-56), stale-while-error
#                                grace 3600 s (D-58)
#                                (default: $HOME/.claude/statusline-usage-cache.json)
#   STATUSLINE_CURL_MAX_TIME     curl --max-time in seconds (default: 2; test
#                                knob, D-59)

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

# iso_to_epoch ISO -> epoch seconds, or "" when unparseable (D-54). Accepts
# YYYY-MM-DDTHH:MM:SS[.frac][Z|±HH:MM|±HHMM|<none>=UTC]; days-from-civil
# (Hinnant) in pure arithmetic: proleptic Gregorian, BSD/GNU-neutral, no
# date(1) at all. Prints nothing and returns 0 on any unparseable input.
iso_to_epoch() {
  local s=$1 y m d H M S rest sign oh om off era yoe doy doe days
  case "$s" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][Tt][0-9][0-9]:[0-9][0-9]:[0-9][0-9]*) ;;
    *) return 0 ;;
  esac
  y=${s:0:4}; m=${s:5:2}; d=${s:8:2}; H=${s:11:2}; M=${s:14:2}; S=${s:17:2}
  rest=${s:19}
  if [ "${rest:0:1}" = "." ]; then                 # drop fractional seconds
    rest=${rest#.}
    while [ -n "$rest" ]; do case "$rest" in [0-9]*) rest=${rest#?} ;; *) break ;; esac; done
  fi
  off=0
  case "$rest" in
    ''|Z|z) ;;
    [+-][0-9][0-9]:[0-9][0-9]) sign=${rest:0:1}; oh=${rest:1:2}; om=${rest:4:2}
      off=$(( 10#$oh * 3600 + 10#$om * 60 )); [ "$sign" = "+" ] && off=$(( -off )) ;;
    [+-][0-9][0-9][0-9][0-9]) sign=${rest:0:1}; oh=${rest:1:2}; om=${rest:3:2}
      off=$(( 10#$oh * 3600 + 10#$om * 60 )); [ "$sign" = "+" ] && off=$(( -off )) ;;
    *) return 0 ;;
  esac
  y=$(( 10#$y )); m=$(( 10#$m )); d=$(( 10#$d )); H=$(( 10#$H )); M=$(( 10#$M )); S=$(( 10#$S ))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] && [ "$d" -le 31 ] \
    && [ "$H" -le 23 ] && [ "$M" -le 59 ] && [ "$S" -le 60 ] || return 0
  [ "$m" -le 2 ] && y=$(( y - 1 ))
  era=$(( y / 400 )); yoe=$(( y - era * 400 ))
  if [ "$m" -gt 2 ]; then doy=$(( (153 * (m - 3) + 2) / 5 + d - 1 ))
  else doy=$(( (153 * (m + 9) + 2) / 5 + d - 1 )); fi
  doe=$(( yoe * 365 + yoe / 4 - yoe / 100 + doy ))
  days=$(( era * 146097 + doe - 719468 ))
  printf '%s' $(( days * 86400 + H * 3600 + M * 60 + S + off ))
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

# Git segment: magenta branch label (magenta short SHA when detached — the
# label IS the detached marker, no sync glyph; D-24/D-25), yellow dirty star,
# then ONE mutually exclusive sync token: green ≡ in-sync (upstream, ahead=
# behind=0) / blue ↑N ahead-only / yellow ↓N behind-only / red ↓B ↑A when
# diverged / red ≢ no-upstream (D-19); cyan stash count. Hidden entirely
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
  out="${MAGENTA}${label}${RESET}"
  [ "$dirty" -eq 1 ] && out="${out}${YELLOW}*${RESET}"
  if [ "$detached" -eq 0 ]; then              # D-25: no sync token when detached (SHA label is the marker)
    if [ "$upstream" -eq 0 ]; then            # no upstream — red is the user's explicit choice (D-19)
      out="${out} ${RED}≢${RESET}"
    elif [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
      out="${out} ${RED}↓${behind}${RESET} ${RED}↑${ahead}${RESET}"  # diverged: both red, per-token spans
    elif [ "$behind" -gt 0 ]; then
      out="${out} ${YELLOW}↓${behind}${RESET}"
    elif [ "$ahead" -gt 0 ]; then
      out="${out} ${BLUE}↑${ahead}${RESET}"
    else
      out="${out} ${GREEN}≡${RESET}"          # in sync: upstream present, ahead=behind=0
    fi
  fi
  [ "$stash" -gt 0 ] && out="${out} ${CYAN}#${stash}${RESET}"
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

# Fable weekly segment "Fable pct/1w (countdown)" — a full peer rendered last
# on line 2: dim literal label, threshold colour on the number only, "/1w"
# and its own reset countdown plain; hidden (with its separator) whenever the
# collector found no value (FAB-01, D-51, D-53, D-54, D-55).
seg_fable() {
  [ -n "$FAB_PCT" ] || return 0
  local pct=${FAB_PCT%.*} out
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  out="${DIM}Fable${RESET} $(pct_color "$pct")${pct}%${RESET}/1w"
  [ -n "$FAB_RST" ] && out="${out} ($(fmt_duration $(( FAB_RST - NOW ))))"
  printf '%s' "$out"
}

# --- Fable weekly adapter (FAB-01..04, D-47..D-65) --------------------------
# One collector behind one seam: kill switch -> stdin model_scoped (D-48) ->
# fresh TTL cache (D-56/D-57) -> one bounded curl with the OAuth token
# (D-59..D-62) -> atomic 0600 cache write, negative results included (D-49)
# -> stale-while-error grace (D-58) -> hidden. Every failure path leaves
# FAB_PCT empty, so seg_fable hides and nothing else on the line changes
# (FAB-04). No background work, no retries, no sleeps.
FAB_TTL=300                                   # cache freshness, seconds (D-56)
FAB_GRACE=3600                                # stale-while-error window, seconds (D-58)
FAB_MAXTIME=${STATUSLINE_CURL_MAX_TIME:-2}    # curl --max-time, seconds (D-59)
FAB_URL=${STATUSLINE_USAGE_URL:-https://api.anthropic.com/api/oauth/usage}
FAB_CACHE=${STATUSLINE_USAGE_CACHE:-$HOME/.claude/statusline-usage-cache.json}  # absolute path (D-57, D-65)

# get_token -> prints the OAuth access token or nothing (D-60, D-62). Source
# order: $STATUSLINE_CREDENTIALS_FILE when set (this file only), else
# $HOME/.claude/.credentials.json, else the macOS Keychain item. One guarded
# jq program per source: the token must be a non-empty string and, when
# .claudeAiOauth.expiresAt is a number (epoch ms), still in the future —
# a missing or non-numeric expiresAt never blocks. Any non-empty string is a
# token (the sandbox proxy credential is short). Read-only: the token is
# never refreshed, never printed, never stored; read only when a fetch is
# actually needed.
get_token() {
  local f=${STATUSLINE_CREDENTIALS_FILE:-} t
  local prog='.claudeAiOauth? // {} | objects
    | (.accessToken? // "" | strings // "") as $t
    | (.expiresAt? | numbers // (($now + 1) * 1000)) as $e
    | select($t != "" and ($e / 1000) > $now) | $t'
  if [ -n "$f" ]; then                        # explicit file: the only source
    t=$(jq -r --argjson now "$NOW" "$prog" "$f" 2>/dev/null)
  else
    t=$(jq -r --argjson now "$NOW" "$prog" "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [ -z "$t" ] && command -v security >/dev/null 2>&1; then
      t=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
          | jq -r --argjson now "$NOW" "$prog" 2>/dev/null)
    fi
  fi
  printf '%s' "$t"
}

# read_cache -> C_AT C_PCT C_RST from $FAB_CACHE, "" when absent or unusable
# (D-57). A separate guarded jq program with the same uint guard as the stdin
# pass: a garbage / hostile cache parses to empties, and eval only ever sees
# one quoted word per assignment.
read_cache() {
  local v
  C_AT=""; C_PCT=""; C_RST=""
  [ -r "$FAB_CACHE" ] || return 0
  v=$(jq -r 'def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
             @sh "C_AT=\(.fetched_at // "" | uint) C_PCT=\(.pct // "" | uint) C_RST=\(.resets_at // "" | uint)"' \
        "$FAB_CACHE" 2>/dev/null)
  eval "$v"                                   # empty on non-JSON -> all stay ""
}

# write_cache PCT RST -> atomic 0600 write of {"fetched_at","pct","resets_at"}
# (D-57): mktemp template in the cache's own directory (0600 by default on
# BSD and GNU — no umask dance) + mv -f, so a concurrent reader sees the old
# or the new complete file and a symlink is replaced, never followed. Empty
# PCT/RST become JSON null (negative result, D-49). The body was fetched into
# a variable first, so the temp file lives for microseconds and a render
# cancelled mid-curl leaves no orphan.
write_cache() {
  local tmp
  mkdir -p "${FAB_CACHE%/*}" 2>/dev/null
  tmp=$(mktemp "${FAB_CACHE%/*}/.usage.XXXXXX" 2>/dev/null) || return 1
  printf '{"fetched_at":%s,"pct":%s,"resets_at":%s}\n' "$NOW" "${1:-null}" "${2:-null}" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$FAB_CACHE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# fetch_usage -> 0 with F_PCT / F_RST_ISO set (both may be "" = the endpoint
# answered but has no Fable bucket), 1 on any failure: no curl, no token,
# curl error / non-2xx / timeout, empty or non-JSON body (D-59, D-62,
# FAB-02). The three headers reach curl as a -K - config on stdin from a
# builtin printf, so the token never enters any process argv; TLS
# verification and the proxy environment are left untouched (the sandbox
# egress rides HTTPS_PROXY). The body is parsed by a separate guarded jq
# program: first limits[] entry of kind weekly_scoped whose
# scope.model.display_name starts with "fable", case-insensitive (D-47,
# D-50); percent is already 0-100, no scaling.
fetch_usage() {
  local tok body v
  F_PCT=""; F_RST_ISO=""
  command -v curl >/dev/null 2>&1 || return 1
  tok=$(get_token)
  [ -n "$tok" ] || return 1
  body=$(printf 'header = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\nheader = "Content-Type: application/json"\n' "$tok" \
         | curl -s -f --max-time "$FAB_MAXTIME" -K - "$FAB_URL" 2>/dev/null) || return 1
  [ -n "$body" ] || return 1
  v=$(printf '%s' "$body" | jq -r '
    def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
    ( [ .limits? // [] | arrays[]? | objects
        | select(.kind == "weekly_scoped"
                 and ((.scope?.model?.display_name? // "" | strings // "") | ascii_downcase | startswith("fable"))) ]
      | first // {} ) as $b
    | @sh "F_PCT=\($b.percent // "" | uint) F_RST_ISO=\($b.resets_at // "" | strings // "")"' 2>/dev/null)
  [ -n "$v" ] || return 1                     # non-JSON body -> no output -> failure
  eval "$v"
}

# get_fable_weekly -> FAB_PCT / FAB_RST (epoch) or "" (D-48, D-55, D-58,
# D-59, D-64). Called directly in main's shell (never inside $(...)) so
# seg_fable sees the result by dynamic scope. Order: kill switch -> stdin
# model_scoped (no cache, no network) -> fresh cache (a fresh negative entry
# serves "" -> hidden, no network) -> fetch + cache write -> stale-while-error
# grace -> hidden.
get_fable_weekly() {
  FAB_PCT=""; FAB_RST=""
  [ -n "${STATUSLINE_NO_FABLE:-}" ] && return 0   # D-64: nothing else runs
  if [ -n "$FAB_SI_PCT" ]; then               # D-48: stdin first
    FAB_PCT=$FAB_SI_PCT; FAB_RST=$(iso_to_epoch "$FAB_SI_RST"); return 0
  fi
  read_cache
  if [ -n "$C_AT" ] && [ $(( NOW - C_AT )) -lt "$FAB_TTL" ]; then
    FAB_PCT=$C_PCT; FAB_RST=$C_RST; return 0  # fresh hit, negative included
  fi
  if fetch_usage; then
    FAB_PCT=$F_PCT; FAB_RST=$(iso_to_epoch "$F_RST_ISO")
    write_cache "$FAB_PCT" "$FAB_RST"; return 0  # negative result cached too (D-49)
  fi
  if [ -n "$C_AT" ] && [ $(( NOW - C_AT )) -lt "$FAB_GRACE" ]; then
    FAB_PCT=$C_PCT; FAB_RST=$C_RST            # D-58: stale-while-error
  fi
  return 0
}

# --- Main -------------------------------------------------------------------

main() {
  # Ingestion: one jq pass, @sh-quoted, // "" on every field, plus a type
  # guard on every field (12 @sh-ingested fields). The 4 string fields
  # (MODEL, EFFORT, DIR, FAB_SI_RST) carry a string type guard: a
  # non-string (array, object, number, bool) becomes the empty string, so a
  # JSON array can never fan out into multiple eval words (@sh quotes each
  # array element as its own word, which eval would run as a command). The
  # 8 numeric fields (CTX_*, P5_*, P7_*, FAB_SI_PCT) are canonicalized to
  # bounded non-negative integers: a
  # non-number (string, object, ...) becomes the empty string and is skipped
  # by the hide-on-empty gates below, so untrusted stdin can never reach the
  # $(( )) arithmetic sinks (bash 3.2 command-substitutes an array subscript
  # there); a well-typed float / exponent number is floored and anything
  # negative, nan, or at or above 1e15 is dropped, so the $(( )) and [ -ge ]
  # integer sinks never see an unparseable or overflowing token (23.5 -> 23,
  # 1e2 -> 100, 1e100 -> empty). Every assignment eval sees is therefore
  # exactly one quoted word or empty. Do not branch on jq's exit code (empty
  # stdin exits 0 with no output). The FAB_SI_* pair is the stdin-first probe
  # (D-48, D-50): the first rate_limits.model_scoped[] entry whose
  # display_name starts with "fable" (case-insensitive); utilization is
  # already 0-100 (no scaling), resets_at is an ISO string converted by
  # iso_to_epoch in get_fable_weekly. The binding sits before the @sh string
  # because @sh applies to the whole program output; absent today -> empty.
  local input vars sep model_seg dir_seg git_seg body NOW LINE1 LINE2 FAB_PCT FAB_RST
  input=$(cat)
  vars=$(printf '%s' "$input" | jq -r '
    def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
    ( [ .rate_limits.model_scoped? // [] | arrays[]? | objects
        | select((.display_name? // "" | strings // "") | ascii_downcase | startswith("fable")) ]
      | first // {} ) as $ms |
    @sh "
    MODEL=\(.model.display_name // "" | strings // "")
    EFFORT=\(.effort.level // "" | strings // "")
    DIR=\(.workspace.current_dir // "" | strings // "")
    CTX_PCT=\(.context_window.used_percentage // "" | uint)
    CTX_TOK=\(.context_window.total_input_tokens // "" | uint)
    CTX_WIN=\(.context_window.context_window_size // "" | uint)
    P5_PCT=\(.rate_limits.five_hour.used_percentage // "" | uint)
    P5_RST=\(.rate_limits.five_hour.resets_at // "" | uint)
    P7_PCT=\(.rate_limits.seven_day.used_percentage // "" | uint)
    P7_RST=\(.rate_limits.seven_day.resets_at // "" | uint)
    FAB_SI_PCT=\($ms.utilization // "" | uint)
    FAB_SI_RST=\($ms.resets_at // "" | strings // "")
  " ' 2>/dev/null)
  eval "$vars"

  NOW=$(date +%s)                             # single date call, reused for both windows (LIM-03)
  get_fable_weekly                            # in main's shell: sets FAB_PCT / FAB_RST for seg_fable

  sep=" ${DIM}·${RESET} "                     # dim separator (D-01)

  model_seg=$(seg_model_effort)
  dir_seg=$(seg_dir)
  git_seg=$(seg_git)
  # Git is a first-class line-1 segment joined by the dim dot; join_segments
  # skips it when empty, so outside a repo no separator leaks (GIT-01/D-14).
  body=$(join_segments "$sep" "$model_seg" "$dir_seg" "$git_seg")
  LINE1="${body}${RESET}"

  body=$(join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)" "$(seg_fable)")  # Fable last (D-51)
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
