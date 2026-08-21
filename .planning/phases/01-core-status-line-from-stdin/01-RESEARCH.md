# Phase 1: Core Status Line from Stdin - Research

**Researched:** 2026-08-21
**Domain:** bash 3.2 statusline script — stdin JSON parsing, ANSI-16 rendering, pure-bash formatting
**Confidence:** HIGH (stdin contract verified in project research 2026-08-21; every prescribed bash/jq construct executed and verified under the host's actual `/bin/bash` 3.2.57 + jq 1.7.1 this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Colors & thresholds
- **D-01:** Dim frame, colored data — `╭─`/`╰─` frame and ` · ` separators dim/gray so chrome recedes; data segments carry the color.
- **D-02:** All colors MUST remain readable on both light and dark terminal themes — use the ANSI named 16-color palette (theme-remapped by the terminal), never hard-coded 256-color or truecolor values. This was an explicit user constraint.
- **D-03:** Usage thresholds: normal below 70%, warning at ≥70%, critical at ≥90% — same cutoffs for context and both rate-limit windows.
- **D-04:** Threshold color sequence is green → yellow → red (always colored, including healthy green).
- **D-05:** Only the percentage number changes color at thresholds; the rest of the segment (labels, countdown) keeps its normal styling.
- **D-06:** Line-1 identity colors: model name cyan, directory blue, effort dim/default.

#### Number formatting
- **D-07:** Percentages truncate to integer (23.7 → `23%`) — pure-bash `${PCT%.*}`, no decimals.
- **D-08:** Shortened token numbers: one decimal when the scaled value is below 10 units (`1.5M`), integer otherwise (`147k`, `200k`); drop a trailing `.0` (`1M`, not `1.0M`).
- **D-09:** Countdowns drop leading zero units: `3d:5h:57m`, `2h:50m`, `50m`, and `<1m` under one minute.
- **D-10:** A reset time already in the past renders as `(now)` — signals the window rolled over and the next render will refresh.

#### Empty-state rendering
- **D-11:** Line 2 always prints, even with zero segments — a bare `╰─` keeps the box shape stable across renders.
- **D-12:** Context segment shows `0%/0/200k` (zero usage + known window size) when `used_percentage` is null/0 early in a session — it never pops in later. This is a deliberate exception to hide-over-placeholder, scoped to the context segment only.
- **D-13:** Worst-case line 1 (malformed/empty stdin, jq failure): render `╭─` plus the directory basename from `$PWD` as fallback; line 2 is a bare `╰─`; exit 0 regardless.
- **D-14:** Line 2 joins only the segments that are present with ` · `, never emitting dangling separators; order is always context → 5h → 1w.

#### Width & truncation
- **D-15:** No width logic at all — the line wraps naturally in narrow terminals. No `$COLUMNS` measurement, no truncation, no segment dropping.
- **D-16:** Directory basename renders in full, never shortened.

### Claude's Discretion
- Exact ANSI escape sequences and the code structure for color helpers (within the ANSI-16 + bash 3.2 constraints).
- Exact dim styling implementation (SGR 2 vs bright-black) — pick whatever stays visible on light themes, per D-02.
- jq extraction structure (single-pass `@sh` eval per the project's prescriptive patterns).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESH-01 | Model display name with `(1M context)`-style suffix stripped | `${MODEL%% (*}` strips any first parenthesized suffix — verified on bash 3.2 (see Code Examples §2) |
| SESH-02 | Reasoning effort in parentheses, hidden when absent | `.effort.level // ""` maps absent→empty; `[ -n "$EFFORT" ]` gates the render (verified, §1) |
| SESH-03 | Directory basename | `${DIR##*/}` pure-bash basename; `$PWD` fallback per D-13 |
| CTX-01 | Context as `pct/used_tokens/window_size` from stdin `context_window` | Fields verified in stdin contract (STACK.md); D-12 zero-state handling documented below |
| CTX-02 | k/M-shortened numbers | `shorten_num` pure-integer implementation verified against all D-08 cases (§3) |
| LIM-01 | 5-hour segment `pct/5h (countdown)` from `rate_limits.five_hour` | stdin fields verified; countdown from `resets_at - now` epoch math (§4) |
| LIM-02 | Weekly segment `pct/1w (countdown)` from `rate_limits.seven_day` | Same shape; independently absent — hide via empty-var gate |
| LIM-03 | Countdowns via pure epoch arithmetic, `d:h:m`/`h:m` format | `fmt_duration` verified against all D-09/D-10 cases (§4) |
| LIM-04 | Rate-limit segments hidden when stdin fields absent | `// ""` sentinel + conditional render — verified absent-field payload produces empty vars (§1) |
| PRES-01 | Two-line `╭─`/`╰─` frame | Multi-line stdout confirmed supported (official docs, STACK.md); UTF-8 box chars pass through as bytes (§5) |
| PRES-02 | ANSI-colorized segments | `$'\033[...]'` literals verified on bash 3.2; ANSI-16 palette per D-02 |
| PRES-03 | Threshold colors normal→warning→critical | `pct_color` on truncated integer, cutoffs 70/90 per D-03/D-04/D-05 |
| PRES-04 | Empty segments hidden with their separators | `join_segments` append-if-non-empty verified — no dangling ` · ` (§5) |
| PORT-03 | Never stderr noise / non-zero exit; degrade to hidden segments | jq failure modes measured (§1); no `set -e`; `2>/dev/null` on jq; unconditional `exit 0` |
</phase_requirements>

## Summary

This phase is fully de-risked. The stdin JSON contract was verified against official docs and the installed Claude Code 2.1.238 binary in project research (2026-08-21, same day). What remained was to prove the exact bash 3.2 constructs the plan will prescribe — since macOS `/bin/bash` 3.2.57 is the binding constraint and a bash-4 idiom fails at *parse* time, blanking the whole line. Every construct was executed this session under the real `/bin/bash` 3.2.57 and jq 1.7.1: the single-pass `@sh` eval (including a shell-injection probe with a hostile directory name — safe), absent/null field mapping, malformed/empty stdin behavior, float truncation, suffix stripping, and complete reference implementations of `shorten_num` and `fmt_duration` matching decisions D-07..D-10 case-by-case.

Two implementation-level findings refine the project research. First, **jq's failure modes split in a way D-13 must handle**: malformed JSON makes jq exit non-zero (exit 5 observed) with stderr noise, but *empty* stdin makes jq exit **0 with no output** — so the fallback trigger cannot be "jq failed"; it must be "the eval left `MODEL` and `DIR` empty." Second, **prefer `$'\033[...]'` byte literals + `printf '%s\n'` over `printf '%b'`**: with real escape bytes already stored in color constants, `%b` is unnecessary — and `%b` would interpret backslash sequences inside *data* (a directory literally named `foo\nbar` would corrupt the line). This keeps untrusted strings inert.

**Primary recommendation:** Build one self-contained `statusline.sh` in the layer order helpers → ingestion → renderers → assembler (per ARCHITECTURE.md), using the verified code patterns below verbatim, a fixture set of ≥6 mock payloads as the test harness, and the empty-var-based D-13 fallback. No packages, no network, no git — 1 jq process + 1 `date +%s` are the only subprocesses.

## Architectural Responsibility Map

This is a single-file script; tiers are internal layers (from ARCHITECTURE.md), not deployment tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Read stdin once, extract all fields | Ingestion (1 jq + eval) | — | Single subprocess; `@sh` quoting makes eval injection-safe (verified) |
| Number/duration/percent formatting | Pure helpers | — | Zero I/O, testable standalone, shared by all line-2 segments |
| Color constants + threshold color | Pure helpers (palette) | — | Defined once as `$'\033[...]'` byte literals; `pct_color` maps int→color |
| Per-segment formatting + hide-on-empty | Segment renderers | — | One function per segment; emit `""` when data absent (PRES-04) |
| Frame, separators, joining, output | Assembler | — | Owns D-11/D-13/D-14; `printf '%s\n'` to stdout; unconditional `exit 0` |
| Worst-case fallback (D-13) | Assembler | Ingestion | Triggered by empty `MODEL`+`DIR` after eval, not by jq exit code |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 3.2-compatible syntax; host `/bin/bash` is 3.2.57 [VERIFIED: `bash --version` this session] | Script runtime | Binding constraint (CLAUDE.md); `#!/bin/bash` shebang |
| jq | 1.7.1 on host [VERIFIED: `jq --version` this session] | Single-pass stdin JSON extraction | Project decision; both environments have it (user-confirmed) |
| `date +%s` | POSIX | Current epoch for countdowns | Only portable date operation; all else is shell arithmetic |

### Supporting

None. This phase deliberately uses no git, no curl, no credentials, no cache files.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@sh` eval extraction | `@tsv` + `IFS read` | Rejected — tab-collapse silently shifts columns on empty fields (CLAUDE.md prescriptive pattern; CONTEXT locks `@sh` eval) |
| `printf '%s\n'` with `$'\033'` literals | `printf '%b\n'` with `\033` text | `%b` interprets backslashes in interpolated *data* (hostile dir names); byte literals + `%s` keep data inert — recommended |
| Pure-bash `shorten_num` | `numfmt --to=si` | `numfmt` is GNU-only — violates portability |

**Installation:** nothing to install — all tools pre-exist in both target environments.

## Package Legitimacy Audit

No external packages are installed in this phase (bash + pre-existing system tools only).

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Claude Code render event (debounced 300ms; cancels in-flight runs)
        │ stdin: JSON payload
        ▼
input=$(cat) ──► one `jq -r '@sh "..."'` (2>/dev/null) ──► eval ──► scalar vars
        │                                                    MODEL EFFORT DIR
        │   jq fails (malformed) → eval of "" → vars empty   CTX_* P5_* P7_*
        ▼
   [ -n "$MODEL" ] || [ -n "$DIR" ] ?
        │ yes                                │ no (D-13 worst case)
        ▼                                    ▼
 segment renderers (pure)              LINE1="╭─ ${PWD##*/}"
   seg_model_effort  seg_dir           LINE2="╰─"
   seg_context  seg_5h  seg_1w
        │ each emits "" when its data is absent
        ▼
 assembler: join_segments " · " (skips empties, D-14)
   LINE1="╭─ <model(effort)> · <dir>"     (dim frame, D-01)
   LINE2="╰─ <ctx> · <5h> · <1w>"         (bare ╰─ if all empty, D-11)
        ▼
 printf '%s\n' "$LINE1"; printf '%s\n' "$LINE2"; exit 0   (PORT-03)
```

### Recommended Project Structure

```
statusline.sh          # the only source file, repo root, chmod +x
tests/
├── fixtures/          # mock stdin payloads (see Fixture Set below)
│   ├── full.json
│   ├── no-effort.json
│   ├── no-rate-limits.json
│   ├── only-five-hour.json
│   ├── null-context.json
│   ├── empty.json         (zero bytes)
│   └── malformed.json     (not JSON)
```

Internal section order in `statusline.sh` (each layer only calls layers above it):
1. shebang `#!/bin/bash` + comment header (no `set -e` — Pitfall 6)
2. ANSI palette constants (`$'\033[...]'` byte literals)
3. Pure helpers: `shorten_num`, `fmt_duration`, `pct_color`, `join_segments`
4. Ingestion: `input=$(cat)`; single jq `@sh` eval
5. Segment renderers: `seg_model_effort`, `seg_dir`, `seg_context`, `seg_5h`, `seg_1w`
6. Assembler + output + `exit 0`

### Pattern 1: Single-pass `@sh` eval ingestion (locked by CONTEXT)

**What:** One jq process emits shell assignments; `@sh` quotes every interpolated value; eval populates plain vars.
**When to use:** Always — the only stdin read.
**Verified this session** (bash 3.2.57 + jq 1.7.1): hostile dir name `"/Users/x/my project; $(touch /tmp/pwned)"` did **not** execute — `@sh` quoting held. Absent fields (`.effort`, `.rate_limits`) and null `used_percentage` all mapped to `''` via `// ""`.

```bash
# Source: project STACK.md pattern, executed verbatim under /bin/bash 3.2.57 this session
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
```

**Critical failure-mode facts** [VERIFIED: measured this session]:
- Malformed input (`not json`): jq exits **5**, prints to stderr → `2>/dev/null` mandatory; `$vars` is empty; `eval ""` is a harmless no-op.
- **Empty stdin: jq exits 0 with zero output** — so "jq succeeded" does NOT mean "vars populated". The D-13 fallback trigger must be `[ -z "$MODEL" ] && [ -z "$DIR" ]` (vars empty after eval), never the jq exit code.

### Pattern 2: Byte-literal ANSI palette + `printf '%s'` output

**What:** Store real escape bytes in constants via ANSI-C quoting; assemble lines as plain strings; print with `%s`.
**Why not `%b`:** `%b` re-interprets backslash sequences in *data* — a directory literally containing `\n` or `\033` text would corrupt the line. With byte literals, `%s` emits identical bytes and data stays inert. (`$'...'` quoting is bash 3.2-safe — verified this session; `od` dump confirmed real `\033` bytes and UTF-8 box chars in the assembled string.)

```bash
# ANSI named-16 palette only (D-02) — theme-remapped by the terminal
RESET=$'\033[0m'
DIM=$'\033[2m'      # SGR 2 faint — recommended dim (see discretion note below)
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
CYAN=$'\033[36m'
...
printf '%s\n' "$LINE1"
printf '%s\n' "$LINE2"
exit 0
```

**Dim-styling recommendation (Claude's discretion, D-02):** use **SGR 2 (`\033[2m`)** applied to the default foreground, not bright-black (`\033[90m`). Rationale: SGR 2 dims *whatever the theme's foreground is*, so it adapts to light and dark automatically; terminals lacking faint support degrade to normal text (readable, just not dim). Bright-black is palette-slot 8, which some light themes map to a light gray with poor contrast on white. [ASSUMED — SGR 2 support in iTerm2/Terminal.app/VS Code terminal is common knowledge but not verified per-terminal this session; the degrade path is safe either way]

### Pattern 3: Threshold coloring on the truncated integer (D-03/D-04/D-05/D-07)

**What:** Truncate the (possibly float) percentage first, then compare — so the displayed number and its color always agree (89.9 shows `89%` in yellow, not red).

```bash
# pct_color INT -> echoes color code; caller wraps ONLY the number (D-05)
pct_color() {
  if [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}
pct=${P5_PCT%.*}          # "50.9" -> "50"; "50" -> "50"  [VERIFIED this session]
[ -z "$pct" ] && pct=0    # guard before arithmetic comparison
```

### Pattern 4: Hide-when-empty assembly (D-11/D-14, PRES-04)

```bash
# Verified this session: join ' · ' 'a' '' 'b' -> "a · b"; all-empty -> ""
join_segments() {
  local sep="$1" out="" part; shift
  for part in "$@"; do
    [ -n "$part" ] && out="${out:+$out$sep}$part"
  done
  printf '%s' "$out"
}
```

Line 2 renders `"╰─"` plus a leading space + joined segments only when the join is non-empty — a bare `╰─` otherwise (D-11). Keep the dim frame/separator styling per D-01: color the `╭─`/`╰─` and embed the ` · ` separator pre-dimmed inside `sep` (e.g. `sep="${RESET} ${DIM}·${RESET} "`), so separators recede with the frame.

### Pattern 5: Line-1 extensibility seam for Phase 2

Line 1 = `╭─ ` + `seg_model_effort` + ` · ` + `seg_dir` (+ future git). Per the project brief, dir and git are **space-separated** (`myproject ⎇ main* ≡`), not ` · `-separated — keep `seg_dir` as its own variable so Phase 2 appends `" $GIT_SEG"` after it without touching the joiner.

### Anti-Patterns to Avoid

- **`set -e` or `set -u`:** an absent field or failed probe kills the script mid-render → blank line (PORT-03). Handle failures explicitly; end with unconditional `exit 0`.
- **Testing jq's exit code as the fallback trigger:** empty stdin exits 0 with no output [VERIFIED] — test the resulting variables instead.
- **`echo -e` / `printf '%b'` on strings containing data:** escape-interpretation of untrusted content; use byte-literal constants + `%s`.
- **Per-field jq calls:** 10+ subprocess spawns; the single-pass eval is locked by CONTEXT anyway.
- **`date -d` / `date -r` / `numfmt` / `bc`:** GNU/BSD divergence — all formatting is pure shell arithmetic (verified implementations below).
- **Segment scaffolds filled later** (`%/5h` with no number): render a segment only when its gate variable is non-empty.
- **Forgetting the trailing `$RESET`:** end each line with reset so a cancelled render never bleeds color into the prompt.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | bash string surgery on `$input` | jq single-pass `@sh` eval | Locked project decision; pure-bash JSON parsing is fragile |
| Shell-safe quoting of JSON values | manual escaping | jq `@sh` | Verified injection-safe this session; manual escaping is a CVE factory |
| Epoch → local time | `date -d @...` / `date -r ...` | pure arithmetic on `resets_at - $(date +%s)` | GNU/BSD `date` flags are mutually incompatible (Pitfall 4) |
| SI number shortening | `numfmt` | verified `shorten_num` below | `numfmt` is GNU coreutils-only |
| basename | `basename` subprocess | `${DIR##*/}` / `${PWD##*/}` | Zero-cost parameter expansion; one fewer fork |

**Key insight:** in this domain the danger is inverted — the temptation is to reach for *convenient platform tools* (`date -d`, `numfmt`, `echo -e`) that silently break on the other OS. The pure-bash helpers are small, and all three are now verified working on the strictest target (bash 3.2.57).

## Common Pitfalls

(Phase-relevant subset of `.planning/research/PITFALLS.md` — that file remains canonical; new session findings marked.)

### Pitfall 1: Empty stdin ≠ jq failure (NEW — refines D-13)
**What goes wrong:** The D-13 fallback is wired to jq's exit code; empty stdin passes (exit 0, no output) and the script renders a frame with no content instead of the `$PWD` fallback.
**How to avoid:** Trigger fallback on `[ -z "$MODEL" ] && [ -z "$DIR" ]` after the eval. [VERIFIED: measured this session — empty stdin → jq exit 0, 0 output lines; malformed → exit 5 + stderr]
**Warning signs:** `printf '' | ./statusline.sh` prints `╭─ ` with no directory name.

### Pitfall 2: Float percentages corrupt integer comparisons
**What goes wrong:** `used_percentage` arrives as `50.9`; `[ "$P5_PCT" -ge 90 ]` errors (`integer expression expected`) → stderr noise → potential blank line.
**How to avoid:** Truncate first (`${PCT%.*}` — verified: `23.7`→`23`, `23`→`23`, `0.4`→`0`), guard empty→`0` before any `-ge`.
**Warning signs:** stderr output when piping the full fixture.

### Pitfall 3: `null` prints as the literal string "null"
**What goes wrong:** Unguarded `jq -r '.x'` prints `null` → renders `null%/5h`.
**How to avoid:** Every extraction carries `// ""` (verified: null `used_percentage` → empty string through `@sh`). Renderers gate on `[ -n "$var" ]`.
**Warning signs:** the word `null` anywhere in output for the null-context fixture.

### Pitfall 4: Context segment popping in/out violates D-12
**What goes wrong:** Treating empty `CTX_PCT` like the rate-limit segments hides context early in a session; it then "pops in" after the first response.
**How to avoid:** Context is the one segment with a zero-state: when `CTX_PCT`/`CTX_TOK` are empty but `CTX_WIN` is known, render `0%/0/<win>` (green). Hide only if `CTX_WIN` itself is empty (see Open Questions).
**Warning signs:** context segment absent for the null-context fixture.

### Pitfall 5: bash-4 idioms parse-fail on macOS
**What goes wrong:** One `${var,,}` or `declare -A` and `/bin/bash` aborts at parse time — whole line blank on the host only.
**How to avoid:** 3.2 subset per CLAUDE.md table. Gate: `/bin/bash -n statusline.sh` must pass and the fixture run must succeed under `/bin/bash` explicitly (both done for every construct prescribed here).
**Warning signs:** works via `bash` (Homebrew 5.x) but not `/bin/bash`.

### Pitfall 6: Color bleed / missing reset
**What goes wrong:** A cancelled in-flight render leaves the terminal mid-SGR; subsequent UI text renders dim or colored.
**How to avoid:** Every color open is paired with `$RESET`; both lines end in `$RESET`.
**Warning signs:** prompt text rendered in the last segment's color.

### Pitfall 7: Renders blocked by stdin read in manual testing
**What goes wrong:** Running `./statusline.sh` with no pipe blocks on `cat` forever — looks like a hang.
**How to avoid:** Not a code bug (Claude Code always pipes stdin); document that all manual runs use `< fixture.json` or a pipe.

## Code Examples

All examples below were **executed under `/bin/bash` 3.2.57 (macOS host) this session** with the shown outputs — they are safe to lift into the plan verbatim.

### §1 Ingestion + failure modes — see Pattern 1 above
Outputs observed: hostile dir extracted intact without execution; absent `.effort`/`.rate_limits` → empty vars; null `used_percentage` → empty; malformed stdin → jq exit 5 (stderr suppressed), vars empty; empty stdin → jq exit 0, zero output, vars empty.

### §2 Model suffix strip + basename (SESH-01, SESH-03)
```bash
# [VERIFIED: bash 3.2.57] — strips from the FIRST " (" to end (handles multi-suffix)
# "Opus 5 (1M context)" -> "Opus 5"; "Fable 5" -> "Fable 5";
# "Sonnet (beta) (1M context)" -> "Sonnet"
model=${MODEL%% (*}
dirname=${DIR##*/}          # basename without a subprocess
[ -z "$dirname" ] && dirname=${PWD##*/}   # D-13 fallback source
```

### §3 `shorten_num` — exact D-08 semantics (CTX-02)
```bash
# [VERIFIED: bash 3.2.57] outputs: 0->0  999->999  1000->1k  1500->1.5k
#   9950->9.9k  10000->10k  100000->100k  147000->147k  200000->200k
#   999999->999k  1000000->1M  1500000->1.5M  12300000->12M
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
```
Note the truncation semantics (consistent with D-07): `999999` → `999k` (not rounded to `1M`), `9950` → `9.9k` (not `10k`).

### §4 `fmt_duration` — exact D-09/D-10 semantics (LIM-03)
```bash
# [VERIFIED: bash 3.2.57] outputs: -5->now  0->now  30-><1m  59-><1m  60->1m
#   3000->50m  10200->2h:50m  273420->3d:3h:57m  262800->3d:1h:0m  90061->1d:1h:1m
fmt_duration() {
  local delta=$1 d h m
  if [ "$delta" -le 0 ]; then printf 'now'; return; fi      # D-10 (caller adds parens)
  if [ "$delta" -lt 60 ]; then printf '<1m'; return; fi
  d=$(( delta / 86400 )); h=$(( delta % 86400 / 3600 )); m=$(( delta % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%sd:%sh:%sm' "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then printf '%sh:%sm' "$h" "$m"
  else printf '%sm' "$m"; fi
}
# usage: delta=$(( P5_RST - $(date +%s) ))   — one `date +%s` call, reuse for both windows
```
Only *leading* zero units drop (D-09): `262800s` → `3d:1h:0m` keeps the inner/trailing zeros.

### §5 `join_segments` + output — see Pattern 4/2 above
Verified: skips empties, no dangling separators; assembled line byte-dump shows real `\033` escapes and 3-byte UTF-8 `╭`/`─`.

### Fixture Set (test harness — official mock-input pattern)
Minimum fixtures the plan should create, mapped to success criteria:
1. `full.json` — everything present, floats in percentages (`10.4`, `50.9`), 1M window → success criterion 1
2. `no-effort.json` — `.effort` absent → SESH-02 hide
3. `no-rate-limits.json` — `.rate_limits` absent → LIM-04, line 2 = context only
4. `only-five-hour.json` — `.seven_day` absent (independently-absent case)
5. `null-context.json` — `used_percentage: null`, `total_input_tokens: 0` → D-12 `0%/0/200k`
6. `empty.json` (zero bytes) and `malformed.json` (`not json`) → D-13 fallback, exit 0, no stderr
Threshold fixtures (criterion 2): variants with pct 69/70/90 to see green/yellow/red boundaries.
Verification command shape: `./statusline.sh < tests/fixtures/X.json; echo "exit=$?"` plus `2>&1 >/dev/null | wc -c` = 0 for the no-stderr check.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OAuth usage API / transcript parsing for limits | stdin `rate_limits.five_hour`/`.seven_day` | Claude Code 2.1.x | This phase needs zero network/credentials |
| Per-field jq extraction (docs' pedagogical style) | single-pass `@sh` eval | community consensus | 1 subprocess instead of 10+ |
| `echo -e` for ANSI | `$'\033'` literals (+`%s`) or `printf '%b'` | official docs guidance | reliable escapes; this research further narrows to `%s` + literals |

**Deprecated/outdated:** nothing phase-relevant; the stdin contract was re-verified against the installed 2.1.238 binary on 2026-08-21 (project STACK.md).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SGR 2 (faint) renders visibly-but-dim in the user's actual terminals (light & dark themes); unsupported terminals degrade to normal weight | Pattern 2 (dim styling) | Cosmetic only — frame renders undimmed or insufficiently dim; one-constant swap to `\033[90m` if the user dislikes it. Verify visually at first live render |
| A2 | `context_window.context_window_size` is always present when the `context_window` object exists (so D-12's "known window size" is effectively always known) | Pitfall 4 / Open Q1 | Context segment would hide in a rare payload shape; contract (STACK.md, binary-verified) documents the field with a 200000 default — LOW risk |

## Open Questions

1. **Context segment when `context_window_size` itself is absent/empty**
   - What we know: D-12 mandates `0%/0/200k` when usage is null/zero "+ known window size"; the verified contract says the field is always emitted (200000 default).
   - What's unclear: behavior if a future payload omits the whole `context_window` object while the JSON is otherwise valid.
   - Recommendation: render the context segment only when `CTX_WIN` is non-empty; otherwise it hides (falls back to general PRES-04 behavior). Cheap, honors D-12's own wording, no placeholder invented.

2. **Should thresholds color the context percentage identically at `0%`?**
   - What we know: D-04 says always colored including healthy green; D-12's zero state is just usage=0.
   - Recommendation: yes — `0%` renders green via the same `pct_color` path; no special casing.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/bash` 3.2-compatible | script runtime | ✓ | 3.2.57(1) arm64-apple-darwin25 [VERIFIED this session] | — |
| jq | ingestion | ✓ | 1.7.1 [VERIFIED this session] | — (hard project dependency, user-confirmed both envs) |
| `date +%s` | countdowns | ✓ | POSIX built-in behavior | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none. (git/curl/Keychain are later-phase concerns.)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no credentials in this phase (OAuth is Phase 4) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | jq `@sh` quoting of every interpolated value before `eval`; numeric guards before arithmetic; data printed via `%s` (never `%b`/`echo -e`) |
| V6 Cryptography | no | — |

### Known Threat Patterns for bash + eval-of-jq

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection via hostile directory/model strings through `eval` | Elevation of privilege | jq `@sh` shell-quotes every interpolation — **empirically probed this session** with `"; $(touch /tmp/pwned)"` in the dir name: not executed. Never interpolate raw JSON into the eval string outside `@sh` |
| Escape-sequence injection via data containing `\033`/backslash text | Tampering (terminal state) | Print data with `printf '%s'`; escape bytes exist only in palette constants |
| Arithmetic injection (`[ "$x" -ge 90 ]` with non-numeric `$x`) | DoS (blank line) | Truncate + empty-guard before every comparison; `2>/dev/null` is a backstop, not the fix |
| stderr/exit-code leakage blanking the UI | DoS | No `set -e`; `2>/dev/null` on jq; single unconditional `exit 0` |

Note: CLAUDE.md's stack table says "never `eval`" in the generic security row while the project's own prescriptive jq pattern (also CLAUDE.md, and locked in CONTEXT "Claude's Discretion") mandates the `@sh` eval. These are consistent when read precisely: `@sh`-quoted eval is the sanctioned form; any *other* eval or unquoted expansion remains forbidden.

## Project Constraints (from CLAUDE.md)

- bash **3.2-compatible syntax**, shebang `#!/bin/bash` (never `#!/usr/bin/env bash` assuming bash 5)
- Full avoid-list is binding: no `declare -A`, `${var,,}`/`${var^^}`, `mapfile`, negative substring offsets, `date -d`/`date -r`, bare `stat -c`/`stat -f`, `sed -i`, `readlink -f`, `echo -e`
- jq patterns: `@sh`-quoted single-pass extraction; `// ""` for absent/null; no `@tsv`+`read`; truncate floats with `${PCT%.*}`
- `printf '%b'` or `$'\033[...]'` literals for escapes (this research recommends the literals + `%s` variant)
- Performance: status line runs every render — must never block the prompt (this phase: 1 jq + 1 `date +%s` subprocesses total)
- Portability: identical behavior on macOS (BSD) and Docker Sandbox Linux (GNU)
- No blocking network in render path; hide-over-placeholder for missing data
- GSD workflow enforcement: file changes go through GSD commands

## Sources

### Primary (HIGH confidence)
- Local execution under `/bin/bash` 3.2.57 + jq 1.7.1, this session (2026-08-21) — every code example in this file ran with the outputs shown, including the `@sh` injection probe and jq failure-mode measurements
- `.planning/research/STACK.md` (2026-08-21) — stdin contract verified against official docs + installed 2.1.238 binary; portability rules; rendering facts
- https://code.claude.com/docs/en/statusline — via STACK.md (fetched same day): ANSI/multi-line support, exit/output contract, mock-input testing pattern

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — layer structure, build order, hide-when-empty assembly
- `.planning/research/PITFALLS.md` — failure-mode catalogue (phase-relevant subset restated above)
- `.planning/research/FEATURES.md` — table-stakes/differentiator framing

### Tertiary (LOW confidence)
- SGR 2 (faint) terminal-support breadth — training knowledge, flagged A1

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; versions measured on host this session
- Architecture: HIGH — locked by CONTEXT + project ARCHITECTURE.md; only refinements added (empty-stdin trigger, `%s`-over-`%b`)
- Pitfalls: HIGH — dominant risks (bash 3.2, jq failure modes, injection) empirically tested; residual risk is cosmetic (A1)

**Research date:** 2026-08-21
**Valid until:** ~2026-09-20 for the stdin contract (Claude Code releases frequently — re-capture a live payload if a major version lands); the bash/jq findings are stable indefinitely
