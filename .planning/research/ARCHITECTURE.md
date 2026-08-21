# Architecture Research

**Domain:** Claude Code custom status line (single-file bash script)
**Researched:** 2026-08-21
**Confidence:** MEDIUM-HIGH (stdin schema and update model verified against official Claude Code docs + multiple community implementations; the `f()` per-model weekly data source is the one LOW-confidence area)

## Standard Architecture

A robust `statusline.sh` is a **pipeline in a single file**: ingest once → collect once → render per segment → assemble with hide-when-empty → print two lines. Everything is a bash function in one script; "component" below means "function group," not "module."

### System Overview

```
                    Claude Code (invokes on every render event,
                    debounced 300ms, cancels in-flight runs)
                                   │ stdin: JSON payload
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 1. INGESTION                                                        │
│    input=$(cat)  →  ONE jq pass  →  bash variables                  │
│    (model, effort, dir, session_id, context_window.*, rate_limits.*)│
├─────────────────────────────────────────────────────────────────────┤
│ 2. HELPERS (pure functions, no I/O)                                 │
│    ┌──────────────┐ ┌───────────────┐ ┌───────────────────────┐     │
│    │ ANSI palette │ │ shorten_num   │ │ fmt_duration          │     │
│    │ (constants)  │ │ (100k / 1M)   │ │ (secs → 3d:5h:57m)    │     │
│    └──────────────┘ └───────────────┘ └───────────────────────┘     │
│    ┌──────────────────────────────────────────────┐                 │
│    │ portability shims: file_mtime() (stat GNU→BSD)│                │
│    │ now=$(date +%s) — epoch math only, no date -d │                │
│    └──────────────────────────────────────────────┘                 │
├─────────────────────────────────────────────────────────────────────┤
│ 3. DATA COLLECTORS (the only impure layer besides ingestion)        │
│    ┌────────────────────────────┐  ┌─────────────────────────────┐  │
│    │ git collector              │  │ f() weekly adapter (OPEN Q) │  │
│    │ one `git status            │  │ per-model weekly % — NOT in │  │
│    │  --porcelain=v2 --branch`  │  │ stdin; OAuth usage API or   │  │
│    │ + stash count              │  │ future stdin field; own     │  │
│    │ [optional 5s TTL cache]    │  │ cache file + hide on miss   │  │
│    └────────────────────────────┘  └─────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│ 4. SEGMENT RENDERERS (one function per segment, emit "" when empty) │
│    seg_model_effort  seg_dir  seg_git  seg_context  seg_5h  seg_1w  │
├─────────────────────────────────────────────────────────────────────┤
│ 5. ASSEMBLER                                                        │
│    join non-empty segments with " · " / spaces; prefix ╭─ / ╰─      │
│    two printf '%b' lines → stdout                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Ingestion | Read stdin exactly once; extract ALL needed JSON fields in a single `jq` invocation | `input=$(cat)`; one `jq -r` program emitting `@tsv` (or one field per line with `// ""` sentinels), read into vars with `IFS=$'\t' read -r` |
| ANSI palette | Color constants, defined once | `RESET=$'\033[0m'`, dim/cyan/green/yellow/red vars; threshold→color helper `pct_color()` for usage segments |
| `shorten_num` | `100000 → 100k`, `1000000 → 1M` | Pure bash integer math (`$((n/1000))k`), no `bc`/`numfmt` (numfmt is GNU-only) |
| `fmt_duration` | `resets_at - now` seconds → `2h:50m` / `3d:5h:57m` | Pure bash integer math on epoch delta; **never** `date -d`/`date -j` (GNU/BSD divergence) |
| `file_mtime` shim | Portable cache-age check | `stat -c %Y "$f" 2>/dev/null || stat -f %m "$f"` — GNU form **first** (documented ordering: on Linux, the BSD form pollutes stdout before failing) |
| git collector | Branch, dirty `*`, upstream `≡`/`≢`, ahead `↑`/behind `↓`, stash `#N` | Single `git --no-optional-locks -C "$DIR" status --porcelain=v2 --branch` parse + `git rev-list --count refs/stash` (or `stash list \| wc -l`); local refs only, zero network |
| f() weekly adapter | Fable-5-specific weekly % — the one datum not on stdin | Isolated function `get_model_weekly_pct()`; cache file + TTL; returns `""` on any failure so the sub-segment hides |
| Segment renderers | Format one segment or emit empty string | One function each; renderer never fetches data — reads vars set by ingestion/collectors |
| Assembler | Hide-when-empty joining, line prefixes, final output | Append-if-non-empty pattern; `printf '%b\n'` (more portable than `echo -e`) |

## Recommended Project Structure

Single file. Order sections top-to-bottom so each layer only calls things defined above it:

```
statusline.sh
├── 1. shebang + strict-ish header    # #!/usr/bin/env bash; guard: exit 0 silently on any fatal error
├── 2. ANSI color constants
├── 3. pure helpers                   # shorten_num, fmt_duration, pct_color
├── 4. portability shims              # file_mtime
├── 5. ingestion                      # input=$(cat); single jq → vars
├── 6. collectors                     # collect_git (opt. cached), get_model_weekly_pct
├── 7. segment renderers              # seg_model_effort … seg_1w
├── 8. assembler + output             # build LINE1/LINE2, printf
README.md                             # what it shows + ln -s install command
tests/ (optional)                     # mock-JSON fixtures piped in: echo '{...}' | ./statusline.sh
```

### Structure Rationale

- **Helpers before collectors before renderers:** bash resolves functions at call time, but this ordering makes the data-flow direction readable and keeps renderers trivially unit-testable by piping mock JSON (the officially documented test method).
- **Renderers never do I/O:** all subprocess cost is concentrated in ingestion (1 jq) + git collector (1–2 git calls), making the <300ms budget auditable at a glance.

## Architectural Patterns

### Pattern 1: Single-pass jq extraction

**What:** One `jq` process extracts every field; bash never re-parses `$input`.
**When to use:** Always. The official docs' examples spawn one `jq` per field (6–10 processes); community consensus and the performance budget favor one.
**Trade-offs:** Slightly denser jq program; `@tsv` breaks if a value contains a tab (paths realistically don't — acceptable).

```bash
input=$(cat)
IFS=$'\t' read -r MODEL EFFORT DIR SESSION_ID CTX_USED CTX_SIZE CTX_PCT \
  P5H_PCT P5H_RESET P7D_PCT P7D_RESET <<EOF
$(jq -r '[
  (.model.display_name // ""),
  (.effort.level // ""),
  (.workspace.current_dir // .cwd // ""),
  (.session_id // ""),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 0),
  (.context_window.used_percentage // "" | tostring),
  (.rate_limits.five_hour.used_percentage // "" | tostring),
  (.rate_limits.five_hour.resets_at // "" | tostring),
  (.rate_limits.seven_day.used_percentage // "" | tostring),
  (.rate_limits.seven_day.resets_at // "" | tostring)
] | @tsv' <<<"$input")
EOF
```

Empty-string sentinels (`// ""`) encode "field absent" → renderers translate that into hidden segments. `rate_limits` is absent for API-key auth and before the first API response — this must be the *normal* path, not an error path.

### Pattern 2: One-call git collection via porcelain v2

**What:** A single `git status --porcelain=v2 --branch` yields branch name, upstream existence, ahead/behind counts, and dirty state; only stash count needs a second call.
**When to use:** Always inside a repo. `--porcelain=v2` output is a stable scripting API, identical on macOS/Linux git.
**Trade-offs:** Slightly more parsing than `git branch --show-current` + `git diff` × 2 + `git rev-list` (4+ processes); vastly cheaper and immune to localized output.

```bash
collect_git() {
  local out
  out=$(git --no-optional-locks -C "$DIR" status --porcelain=v2 --branch 2>/dev/null) || return 0
  BRANCH=$(sed -n 's/^# branch.head //p' <<<"$out")            # "(detached)" possible
  AB=$(sed -n 's/^# branch.ab //p' <<<"$out")                  # "+3 -2" → ahead 3, behind 2
  HAS_UPSTREAM=$(grep -c '^# branch.upstream ' <<<"$out")      # 0/1 → ≢ / ≡
  DIRTY=$(grep -c '^[12u?]' <<<"$out")                         # changed/untracked entries
  STASHES=$(git -C "$DIR" rev-list --count refs/stash 2>/dev/null || echo 0)
}
```

`--no-optional-locks` matters: without it, `git status` may take the index lock and race with git commands Claude itself is running in the session. `-C "$DIR"` (the stdin `workspace.current_dir`) rather than relying on the script's own cwd.

### Pattern 3: Hide-when-empty assembly

**What:** Each renderer returns `""` when its data is absent; the assembler appends only non-empty parts with separators.
**When to use:** Always — it is a stated project requirement (no `⎇` outside repos, no `#0`, no usage segment without `rate_limits`).
**Trade-offs:** Layout shifts as segments appear/disappear; the project explicitly accepts this.

```bash
join_segments() {  # join_segments " · " "$a" "$b" ...
  local sep="$1" out="" part; shift
  for part in "$@"; do
    [ -n "$part" ] && out="${out:+$out$sep}$part"
  done
  printf '%s' "$out"
}
LINE1="╭─ $(join_segments " · " "$(seg_model_effort)" "$(seg_dir_git)")"
LINE2="╰─ $(join_segments " · " "$(seg_context)" "$(seg_5h)" "$(seg_1w)")"
printf '%b\n%b\n' "$LINE1" "$LINE2"
```

### Pattern 4: Session-keyed temp-file cache with mtime TTL (apply only if needed)

**What:** Write collector output to `${TMPDIR:-/tmp}/statusline-git-cache-$SESSION_ID`; re-collect only when the file is missing or older than ~5s.
**When to use:** Only if measured git time is slow (large repos). For this project's typical repos, the 1–2 git calls above run in single-digit milliseconds — **skip the cache initially** and add it behind the collector boundary if profiling demands it. The official docs document exactly this pattern for when it's needed.
**Trade-offs:** Adds the stat portability shim and staleness (git state up to TTL old). Key by `session_id` from stdin, **never** `$$` (changes every invocation, defeats the cache — an officially documented gotcha).

## Data Flow

### Render Flow (every invocation)

```
Claude Code event (assistant msg, /compact, session start, refreshInterval)
    ↓ (300ms debounce; cancels in-flight script)
stdin JSON ──cat──▶ $input ──single jq──▶ scalar vars (MODEL, EFFORT, DIR,
    CTX_*, P5H_*, P7D_*, SESSION_ID)
                                   │
        DIR ──▶ git collector ─────┤ (BRANCH, DIRTY, AB, HAS_UPSTREAM, STASHES)
        [opt: cache file r/w]      │
        f() adapter ───────────────┤ (MODEL_WEEKLY_PCT or "")
        [own cache file, TTL ~300s]│
                                   ▼
                     segment renderers (pure formatting,
                     call shorten_num / fmt_duration / pct_color)
                                   ▼
                     assembler (hide-empty join, ╭─/╰─ prefixes)
                                   ▼
                     stdout: exactly 2 lines ──▶ Claude Code displays verbatim
```

Direction is strictly one-way: **ingestion/collectors → variables → renderers → assembler → stdout**. Renderers never reach back to stdin or spawn processes; collectors never format.

### Key Data Flows

1. **Model/effort/context/rate-limits:** entirely from stdin JSON — zero subprocesses beyond the one jq. `resets_at` (epoch seconds) − `$(date +%s)` → `fmt_duration` → countdown string. Model name suffix-strip (`(1M context)`) is a renderer concern: `${MODEL% (1M context)}` or a `sed` in the jq pass.
2. **Git:** stdin gives `workspace.current_dir` → collector runs local-only git reads → renderer maps to `⎇ main* ≡ ↓2 ↑3 #2`. Note the mapping: porcelain `branch.ab "+A -B"` → `A` = outgoing `↑`, `B` = incoming `↓` (per the project's confirmed semantics).
3. **f() weekly Fable %:** the only externally-sourced datum. stdin `rate_limits` carries only `five_hour` and `seven_day` (all-models). Per-model weekly (`seven_day_opus`-style) exists only via the undocumented OAuth endpoint (`/api/oauth/usage`, credentials from `~/.claude/.credentials.json`) — community scripts cache its response to a JSON file with ~300s TTL and file locking; at least one guide reports the endpoint deprecated/unstable. **Architectural response:** hide the seam behind `get_model_weekly_pct()`; first probe stdin for a model-specific window (`jq '.rate_limits | keys'` defensively — newer CC versions may add it), fall back to the cached OAuth call only if that phase's research validates it, otherwise return `""` and let hide-when-empty absorb it.

## Scaling Considerations

Scaling here is repo size and invocation frequency, not users:

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Typical repos (<10k files) | No cache; 1 jq + 2 git calls; total well under 50ms |
| Large repos (slow `git status`) | Enable Pattern 4 cache (5s TTL, session-keyed); keep `--no-optional-locks` |
| Any external/API data (f() segment) | Never in the hot path: separate cache file, long TTL (~300s), locking if concurrent sessions share it, always-hide on failure |

### Scaling Priorities

1. **First bottleneck:** process count (each subprocess ≈ fork+exec). Fixed by single-pass jq and porcelain-v2 collection — this is why the architecture concentrates I/O in two functions.
2. **Second bottleneck:** `git status` in big worktrees. Fixed by the documented temp-file cache; do not pre-build it — add when measured.
3. **Hard ceiling:** Claude Code cancels in-flight scripts on the next trigger and blanks/stales the line on slow scripts. Treat ~300ms as the absolute budget; network calls in the render path are architecturally forbidden.

## Anti-Patterns

### Anti-Pattern 1: jq-per-field extraction

**What people do:** `MODEL=$(echo "$input" | jq …)`, `DIR=$(echo "$input" | jq …)` × 10 (the official examples do this for pedagogy).
**Why it's wrong:** 10+ subprocess spawns per render; the dominant cost of the whole script.
**Do this instead:** Pattern 1 — one jq emitting `@tsv`, one `read`.

### Anti-Pattern 2: `$$`-keyed or unkeyed cache files

**What people do:** `/tmp/statusline-cache-$$` or a single shared `/tmp/statusline-cache`.
**Why it's wrong:** `$$` changes every invocation (cache never hits); a shared file makes concurrent sessions in different repos read each other's git state.
**Do this instead:** Key by stdin `session_id` (stable per session, unique across sessions) — officially documented.

### Anti-Pattern 3: GNU-or-BSD-only commands

**What people do:** `date -d @${resets_at}`, `numfmt --to=si`, `stat -c` alone, `sed -i` variants, `${var,,}` (bash 4+ — macOS ships bash 3.2).
**Why it's wrong:** Breaks silently on the other platform; the script must be byte-identical on macOS host and Docker Sandbox Linux.
**Do this instead:** Epoch-only arithmetic (`date +%s` is universal) with pure-bash duration/number formatting; the GNU-first `stat` fallback shim; `#!/usr/bin/env bash` with bash-3.2-safe constructs.

### Anti-Pattern 4: Treating missing data as an error

**What people do:** Print `--`/`0%` placeholders, or let `set -e` + an absent `rate_limits` kill the script (blank status line).
**Why it's wrong:** `rate_limits`, `effort`, `used_percentage`, `current_usage` are all *legitimately* absent/null at defined times (pre-first-response, API-key auth, post-`/compact`). Non-zero exit or empty stdout blanks the entire line.
**Do this instead:** `// ""` sentinels in jq, hide-when-empty assembly, and a top-level guarantee that the script always exits 0 with printable output.

### Anti-Pattern 5: `echo -e` for ANSI output

**What people do:** `echo -e "${GREEN}…"`.
**Why it's wrong:** Escape handling varies by shell/platform; official docs recommend against it for OSC/ANSI reliability.
**Do this instead:** `printf '%b\n'`, or store real escape bytes via `$'\033[32m'`.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Claude Code host | stdin JSON in, stdout lines out; configured via `statusLine.command` in `~/.claude/settings.json` | Runs on events, 300ms debounce, cancellation; `COLUMNS`/`LINES` env give terminal width (v2.1.153+); test with `echo '{…}' \| ./statusline.sh` |
| Local git | Read-only local commands, `--no-optional-locks`, `-C "$DIR"` | Never `git fetch` — ↓/↑ reflect last-known remote refs |
| OAuth usage API (f() only) | Isolated adapter + cache file + TTL; hide on failure | Undocumented, reported deprecated; validate in its own phase before building |
| Filesystem (`~/.claude`) | Repo is source of truth; `ln -s` into `~/.claude/statusline.sh`; sandboxes share `~/.claude` mount | Same file must run on both platforms — no build/install step |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| ingestion → renderers | global scalar vars, `""` = absent | Single writer (ingestion), renderers read-only |
| collectors → renderers | global vars set by `collect_git` / `get_model_weekly_pct` | Only impure layer besides ingestion; cacheable behind the function boundary without touching renderers |
| renderers → assembler | function stdout (segment string or empty) | Hide-when-empty contract lives entirely in the assembler |
| f() adapter ↔ data source | function seam | Data source can flip (stdin field ↔ OAuth API ↔ removed) without touching `seg_1w` rendering |

## Suggested Build Order

Dependencies drive the order — helpers have none, segments need ingestion, f() needs research:

1. **Skeleton + ingestion:** shebang, `input=$(cat)`, single-pass jq, mock-JSON test harness. Everything depends on this.
2. **Pure helpers:** ANSI palette, `shorten_num`, `fmt_duration`, `pct_color` — zero dependencies, testable standalone, needed by every line-2 segment.
3. **Line 1 core:** `seg_model_effort` (with suffix strip) + `seg_dir` + assembler with hide-when-empty join. First visible end-to-end result.
4. **Line 2 stdin segments:** `seg_context` (pct/tokens/window via `shorten_num`), `seg_5h`, `seg_1w` all-models part (pct + `fmt_duration` countdown). Pure stdin — no new I/O.
5. **Git collector + `seg_git`:** porcelain-v2 parse, symbols, stash count; verify hide behavior outside repos and detached HEAD.
6. **Portability pass:** run identical fixtures on macOS and in a Docker Sandbox; add the `stat` shim only if/when caching lands.
7. **f() adapter (flagged for phase research):** probe stdin for a model-specific window; research the OAuth endpoint's current viability; implement behind the seam with its own cache — or ship with the sub-segment hidden.
8. **(Conditional) git cache:** only if step 6 profiling shows git latency; the collector boundary means this bolts on without refactoring.

Roadmap implication: steps 1–4 are one low-risk phase (stdin-only, fully mockable); step 5 is a second phase (real git states to verify); step 7 is the only phase needing deeper research and should be last and optional-by-design.

## Sources

- [Official Claude Code statusline docs](https://code.claude.com/docs/en/statusline) — full stdin schema (incl. `rate_limits`, `effort.level`, `context_window`), update/debounce/cancellation model, caching example, stat-ordering gotcha, testing method. Confidence per seam classification: MEDIUM (webfetch, cross-verified); treated as authoritative vendor documentation.
- [ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline) — bash reference implementation: OAuth usage API for weekly quotas, `~/.claude/usage-exact.json` cache with locking, 300s TTL. MEDIUM (verified websearch).
- [Statusline gotchas gist (patyearone)](https://gist.github.com/patyearone/7c753ef536a49839c400efaf640e17de) — confirms stdin `rate_limits` carries only `five_hour`/`seven_day`; OAuth `/api/oauth/usage` approach called deprecated. MEDIUM.
- [Claude Lab statusline guide](https://claudelab.net/en/articles/claude-code/claude-code-statusline-rate-limits-customization), [wmedia.es usage-limit statusline](https://wmedia.es/en/tips/claude-code-usage-limit-status-line), [voitanos/andrewconnell guide](https://www.voitanos.io/blog/claude-code-cli-statusline/) — corroborate rate-limit field availability (v2.1+, Pro/Max only, post-first-response) and `seven_day_opus`/`seven_day_sonnet` living in the usage API, not stdin. MEDIUM (multiple independent sources agree).
- Porcelain-v2 git collection, `--no-optional-locks`, epoch-only date math: standard prompt-tooling practice (starship/git-prompt lineage) verified against git documentation semantics. MEDIUM.

---
*Architecture research for: Claude Code custom status line (bash)*
*Researched: 2026-08-21*
