# Stack Research

**Domain:** Claude Code custom status line (two-line bash script, macOS + Docker Sandbox Linux)
**Researched:** 2026-08-21
**Confidence:** HIGH (stdin contract verified against official docs at code.claude.com AND the installed Claude Code v2.1.238 binary on 2026-08-21 — not training data)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| bash | **3.2-compatible syntax** (macOS ships 3.2.57; Linux has 4/5) | Script runtime | macOS `/bin/bash` is frozen at 3.2.57 (verified on host). Writing to the 3.2 subset is the only way one script behaves identically in both environments. Shebang: `#!/bin/bash` |
| jq | 1.6+ (host has 1.7.1) | Parse stdin JSON | Official docs' own examples use jq; both target environments have it (user-confirmed). Pure-bash JSON parsing is fragile — already a project decision |
| git | 2.22+ (host has 2.50.1) | Branch/dirty/ahead-behind/stash | `git status --porcelain=v2 --branch` (needs ≥2.11) gives everything line 1 needs in **one** ~12 ms process (measured on host repo) |
| Claude Code | ≥2.1.x (host has 2.1.238) | Data provider | `rate_limits` on stdin requires 2.1.x; `COLUMNS`/`LINES` env requires ≥2.1.153 |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| curl | any | Fetch model-specific weekly limit (the `f()` segment) from the OAuth usage API | Only for the `f()` segment — everything else comes from stdin. Must be cached + fail-silent (see below) |
| `security` (macOS built-in) | — | Read OAuth token from Keychain on the macOS host | macOS host stores credentials in Keychain item `"Claude Code-credentials"` (verified: `~/.claude/.credentials.json` is **absent** on this host, Keychain item exists) |
| `date +%s` + shell arithmetic | POSIX | Reset countdowns | `resets_at` is Unix epoch seconds; `$((resets_at - $(date +%s)))` then manual d/h/m formatting is 100% portable. **Never** use `date -d` (GNU-only) or `date -r` (BSD-only) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Mock-input testing | Test without a live session | `echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/x"},"context_window":{"used_percentage":25},"session_id":"t"}' | ./statusline.sh` — pattern from official docs |
| `claude --debug` | Debug a blank status line | Logs exit code + stderr of the first statusline invocation; also logs `Status line command skipped: workspace trust not accepted` |
| shellcheck (optional) | Catch bashisms/quoting bugs | Run with `--shell=bash`; treat SC2059/SC2086 warnings seriously in a script that evals jq output |

## The stdin JSON contract (verified 2026-08-21)

Verified against https://code.claude.com/docs/en/statusline (the old docs.claude.com URL 301-redirects there) and cross-checked against the payload-constructor code inside the v2.1.238 binary. Fields this project needs:

| Field | Type / values | Notes |
|-------|---------------|-------|
| `.model.display_name` | string | e.g. `"Opus"`; may carry suffixes like `(1M context)` — strip in script |
| `.effort.level` | `low`\|`medium`\|`high`\|`xhigh`\|`max` | **Absent** when model doesn't support effort. Live value, reflects mid-session `/effort` changes |
| `.workspace.current_dir` | string | Preferred over `.cwd` (same value) |
| `.context_window.total_input_tokens` | number | Sum of input + cache_creation + cache_read; `0` before first API response |
| `.context_window.context_window_size` | number | `200000` default, `1000000` for extended-context models |
| `.context_window.used_percentage` | number \| **null** | Pre-calculated, input-tokens-only formula; null early in session — use `// 0` or hide |
| `.rate_limits.five_hour.used_percentage` | number 0–100 | **Absent** until first API response; Pro/Max subscribers only |
| `.rate_limits.five_hour.resets_at` | number | Unix epoch seconds |
| `.rate_limits.seven_day.used_percentage` / `.resets_at` | same shape | Each window may be **independently absent** |
| `.session_id` | string | Use as cache-file key (stable per session, unique across sessions — official caching guidance) |

Other available fields (not needed now, useful later): `cost.*`, `exceeds_200k_tokens`, `fast_mode`, `thinking.enabled`, `output_style.name`, `vim.mode`, `agent.name`, `pr.*`, `worktree.*`, `workspace.repo.{host,owner,name}`, `version`, `transcript_path`, `prompt_id`.

**Absence vs null:** `rate_limits`, `effort`, `vim`, `pr`, `worktree` may be *missing entirely*; `context_window.used_percentage`/`current_usage` may be *null*. Use `// empty` for absence-means-hide and `// 0` for null-means-zero.

## Rate-limit data sources (the open research question — resolved)

1. **5h and 7d (all-models):** in the stdin JSON as `.rate_limits.five_hour` / `.rate_limits.seven_day` — no extra lookups needed. **Confidence: HIGH** (official docs + binary payload constructor both verified).

2. **Model-specific weekly (`f()` segment): NOT in the stdin JSON.** Verified in the v2.1.238 binary: the internal rate-limit state tracks windows named `seven_day_opus` and `seven_day_sonnet`, but the statusline payload constructor projects **only** `five_hour` and `seven_day` into stdin (the minified constructor literally builds `{...five_hour, ...seven_day}` and nothing else). **Confidence: HIGH** that it's absent today.

3. **Where community tools get it:** `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <accessToken>` (some tools add `anthropic-beta: oauth-2025-04-20` and `Content-Type: application/json`). The binary itself calls this endpoint (`fetchUtilization: GET /api/oauth/usage`, 5 s timeout). Response contains per-window objects keyed `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` (plus `seven_day_oauth_apps`, `overage`, `extra_usage`, `limits`), each with `utilization` and `resets_at`. **Confidence: MEDIUM** — undocumented/unofficial endpoint; window key for the current flagship model family should be confirmed at implementation time (historically `seven_day_opus`), and the `utilization` scale (0–1 vs 0–100) must be checked empirically: internally Claude Code multiplies its 0–1 `utilization` by 100 to produce stdin `used_percentage`.

4. **Token location differs per environment (verified):**
   - macOS host: Keychain item `"Claude Code-credentials"` → `security find-generic-password -s "Claude Code-credentials" -w | jq -r '.claudeAiOauth.accessToken'`. `.credentials.json` does **not** exist on the host.
   - Linux/Docker Sandbox: `~/.claude/.credentials.json` → `.claudeAiOauth.accessToken`. **Confidence: MEDIUM** for the sandbox path (community-standard; verify inside an actual sandbox in an early phase).

5. **Non-sources (ruled out):** `~/.claude/stats-cache.json` contains only activity/token aggregates (verified keys: `dailyActivity`, `modelUsage`, …) — no rate-limit windows. Transcript JSONL files do not carry rate-limit status. ccusage-style transcript accounting reconstructs *cost*, not official limit percentages — wrong tool for this job.

**Prescription for `f()`:** fetch the OAuth usage endpoint via curl with `--max-time 2`, cache the response to a session-keyed temp file with a TTL of ≥60 s, and hide the `f()` segment on any failure (missing token, network down, schema change). Never block the render: read cache first, refresh only when stale. The Keychain read on macOS can theoretically prompt; if it does, drop to cached/hidden rather than prompting repeatedly. This matches the project's hide-over-placeholder decision.

## Rendering facts (from official docs — HIGH confidence)

- **ANSI colors: confirmed supported.** Docs: "use ANSI escape codes like `\033[32m` for green". OSC 8 hyperlinks also work in supporting terminals.
- **Multi-line: confirmed.** Each `echo`/`printf` line renders as its own row — the two-line `╭─`/`╰─` layout is directly supported (box-drawing chars are plain UTF-8 output).
- Use `printf '%b'` (or `$'\033[...]'` literals) instead of `echo -e` — docs explicitly recommend this for cross-shell escape reliability.
- **Update model:** runs on session start/resume, new assistant message, `/compact` end, permission-mode change, vim toggle; debounced 300 ms; **in-flight scripts get cancelled** by newer triggers — another reason the script must be fast.
- **`refreshInterval` setting:** re-runs the script every N seconds (min 1) even when idle. **Recommended for this project** (e.g. `30`–`60`) because the reset countdowns are time-based and would otherwise freeze while the session idles.
- Terminal width: read `$COLUMNS` (set by Claude Code ≥2.1.153); `tput cols` does not work (stdout is captured, no tty).
- `statusLine.padding` (optional int) controls extra indent; script must be executable (`chmod +x`) and print to stdout; non-zero exit or empty output blanks the line.
- Workspace trust must be accepted or the statusline silently never runs.
- Config shape: `{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 60}}` in `~/.claude/settings.json`.

## jq patterns (prescriptive)

**One jq process, not ten.** Every `$(echo "$input" | jq ...)` costs a process spawn; the docs' per-field style is fine for demos but slow for a script that renders constantly. Extract everything in a single call with `@sh` quoting and eval:

```bash
input=$(cat)
eval "$(printf '%s' "$input" | jq -r '@sh "
  MODEL=\(.model.display_name // "")
  EFFORT=\(.effort.level // "")
  DIR=\(.workspace.current_dir // "")
  CTX_PCT=\(.context_window.used_percentage // "")
  CTX_TOK=\(.context_window.total_input_tokens // "")
  CTX_WIN=\(.context_window.context_window_size // "")
  FIVE_PCT=\(.rate_limits.five_hour.used_percentage // "")
  FIVE_RESET=\(.rate_limits.five_hour.resets_at // "")
  WEEK_PCT=\(.rate_limits.seven_day.used_percentage // "")
  WEEK_RESET=\(.rate_limits.seven_day.resets_at // "")
  SESSION_ID=\(.session_id // "")
"')"
```

- `@sh` shell-quotes every interpolation, making the `eval` safe against hostile directory names.
- `// ""` maps both *absent* and *null* to empty string; test `[ -n "$VAR" ]` to decide whether to render a segment (matches hide-over-placeholder).
- Avoid `@tsv` + `read`: tab is IFS whitespace in bash, so consecutive tabs from empty fields collapse and shift columns — a classic silent bug.
- Percentages can be floats (`23.5`); truncate with `${PCT%.*}` (pure bash, portable) rather than `printf '%.0f'` when you only need the integer part for comparisons.

## Bash 3.2 portability rules (macOS host is the constraint)

Verified host: GNU bash 3.2.57, BSD userland. **Do not use** (all bash 4+/GNU-only):

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `declare -A` (assoc arrays) | bash 4+ | plain vars / case statements |
| `${var,,}` `${var^^}` | bash 4+ | `tr '[:upper:]' '[:lower:]'` |
| `mapfile` / `readarray` | bash 4+ | `while read -r` loops |
| `${var:0:-1}` negative offsets | bash 4.2+ | `${var%?}` / `${var#?}` |
| `date -d @epoch` / `date --date` | GNU-only, fails on BSD | epoch arithmetic: `$((resets_at - $(date +%s)))`, format d/h/m yourself |
| `date -r epoch` | BSD-only, means "file mtime" on GNU | same as above |
| `stat -c` alone or `stat -f` alone | flags differ BSD/GNU | for cache staleness prefer `find "$f" -mmin ...` or the docs' dual-fallback (`stat -c %Y ... || stat -f %m ...`, Linux form first) |
| `sed -i` without arg quirks, `readlink -f` | BSD/GNU divergence | not needed in this script; `readlink -f` works on macOS ≥12.3 but avoid anyway |
| `echo -e` | inconsistent across shells; docs warn | `printf '%b'` or `$'\033[32m'` literals |
| `#!/usr/bin/env bash` assuming bash 5 | Docker image may resolve differently than host | `#!/bin/bash` + 3.2-safe syntax |

Safe everywhere: `$'...'` ANSI-C quoting, `printf -v`, `[[ ]]`, `(( ))`, `${var%...}`/`${var#...}`, indexed arrays, `local`.

## Fast git queries (prescriptive)

**One command supplies branch, upstream state, ahead/behind, dirty, and untracked** (measured 12 ms on host):

```bash
GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch --ignore-submodules 2>/dev/null
```

Parse from its output:
- `# branch.head <name>` → branch (`(detached)` when detached)
- `# branch.upstream <ref>` → present ⇒ `≡` (has upstream), absent ⇒ `≢`
- `# branch.ab +A -B` → A = ahead (`↑`), B = behind (`↓`)
- any non-`#` line (`1 `, `2 `, `u `, `? `) → dirty ⇒ `*`

Plus one cheap call for stashes:

```bash
git -C "$DIR" rev-list --walk-reflogs --count refs/stash 2>/dev/null   # prints count; fails cleanly when no stash
```

Rules:
- `GIT_OPTIONAL_LOCKS=0` — prevents the status run from taking index locks / writing the refreshed index; essential for a command that fires on every render while Claude itself runs git.
- `git -C "$DIR"` with `$DIR` from `.workspace.current_dir` — don't trust the script's own cwd.
- Detect not-a-repo by the status command failing (exit ≠ 0) and hide the whole `⎇` segment.
- The official docs recommend caching git output to `/tmp/statusline-git-cache-$SESSION_ID` with a ~5 s TTL for large repos. For this project's repo sizes a cache is optional; adopt it only if render lag appears (keep as a known lever, not day-one complexity).

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `git branch --show-current` + `git diff` + `git diff --cached` + `git ls-files -o` as separate calls | 4–6 process spawns per render | single `git status --porcelain=v2 --branch` |
| `git fetch` anywhere in the script | network on every render; blocks prompt | ahead/behind from `branch.ab` (vs last-fetched upstream — accepted semantics) |
| `git stash list | wc -l` | spawns 3 processes | `git rev-list --walk-reflogs --count refs/stash` |
| ccusage / ccstatusline / claude-powerline as dependencies | Node/Bun runtimes, config layers; project explicitly wants a self-contained bash script; ccusage reconstructs *cost* from transcripts, not official limit % | stdin `rate_limits` + optional OAuth usage endpoint |
| Scraping `transcript_path` or `~/.claude/stats-cache.json` for limits | neither contains rate-limit windows (verified) | stdin + OAuth usage endpoint |
| Blocking curl in the render path | statusline scripts get cancelled/blank on slowness | TTL cache file + `--max-time 2` + hide-on-failure |
| Refreshing the OAuth token yourself | Claude Code owns token refresh; racing it risks invalidating sessions | read-only token use; hide `f()` if expired |

## Stack Patterns by Variant

**If running on macOS host:**
- OAuth token via `security find-generic-password -s "Claude Code-credentials" -w`
- BSD userland: every portability rule above applies

**If running inside Docker Sandbox (Linux):**
- OAuth token via `~/.claude/.credentials.json` (`.claudeAiOauth.accessToken`) — verify file presence in an early phase; hide `f()` if absent
- Same script, same `#!/bin/bash`, no branching on OS except the token-lookup helper (try file first, then Keychain, else give up)

**If `rate_limits` absent (API-key auth, non-subscriber, or pre-first-response):**
- Hide both usage segments entirely (project decision: hide-over-placeholder)

## Version Compatibility

| Component | Requires | Notes |
|-----------|----------|-------|
| `rate_limits` on stdin | Claude Code ≥2.1.x, Pro/Max subscriber, after first API response | each window independently absent |
| `effort.level` on stdin | model must support effort parameter | absent otherwise — hide `(effort)` |
| `$COLUMNS` env | Claude Code ≥2.1.153 | host is 2.1.238 ✓ |
| `git status --porcelain=v2` | git ≥2.11 | host 2.50.1 ✓; any modern container ✓ |
| `git -C` | git ≥1.8.5 | universal |
| jq `@sh` | jq ≥1.5 | host 1.7.1 ✓ |
| Script syntax | bash 3.2 | the binding constraint (macOS) |

## Sources

- https://code.claude.com/docs/en/statusline — full page fetched 2026-08-21; complete stdin schema, ANSI/multi-line/OSC-8 support, update triggers + 300 ms debounce, `refreshInterval`, `COLUMNS`, caching guidance, trust requirement. **HIGH** (official, first-party, current)
- Claude Code v2.1.238 binary (`/Users/sv/.local/share/claude/versions/2.1.238`) string/code inspection — statusline payload constructor (only `five_hour`+`seven_day` projected), internal `seven_day_opus`/`seven_day_sonnet` windows, `GET /api/oauth/usage` call with 5 s timeout, `utilization*100` conversion. **HIGH** (primary evidence, exact installed version)
- Local host verification — bash 3.2.57, jq 1.7.1, git 2.50.1, Keychain item `"Claude Code-credentials"` present, `~/.claude/.credentials.json` absent, `stats-cache.json` keys, 12 ms porcelain-v2 timing. **HIGH** (measured)
- https://github.com/ohugonnot/claude-code-statusline — community bash statusline; confirms OAuth usage endpoint + `~/.claude/.credentials.json` (`claudeAiOauth.accessToken`) pattern and model-specific weekly quotas via API fallback. **MEDIUM** (community, corroborates binary findings)
- Web search corroboration (anthropics/claude-code issues #27915/#45133, community writeups) — history of `rate_limits` exposure; no `seven_day_opus` in stdin as of mid-2026. **MEDIUM**

---
*Stack research for: Claude Code custom status line (bash)*
*Researched: 2026-08-21*
