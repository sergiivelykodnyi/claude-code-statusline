# Project Research Summary

**Project:** claude-code-status-line
**Domain:** Claude Code custom status line (single-file bash script, macOS host + Docker Sandbox Linux)
**Researched:** 2026-08-21
**Confidence:** HIGH (stdin contract verified against official docs AND the installed Claude Code v2.1.238 binary; only the `f()` per-model weekly data source is MEDIUM)

## Executive Summary

This is a tier-4 statusline tool: a fixed personal two-line layout in a single self-contained bash script, deliberately rejecting the config-heavy Node frameworks (ccstatusline, claude-powerline) that dominate the ecosystem. Experts build these as a strict one-way pipeline: read stdin once, extract every JSON field in a single jq pass, collect git state in one `git status --porcelain=v2 --branch` call, render segments as pure functions that emit empty strings when data is absent, and assemble with hide-when-empty joining. The entire script must complete well under ~300ms because Claude Code cancels in-flight runs and blanks the line on non-zero exit or empty output.

The single biggest de-risking finding: **the 5-hour and weekly rate limits are on stdin** (`rate_limits.five_hour` / `.seven_day` with `used_percentage` and `resets_at`) since Claude Code 2.1.x — no API call, credentials, or cache needed for the two main usage segments. This resolves PROJECT.md's open question for everything except the model-specific weekly `f()` segment, which is verifiably **not** in the stdin payload (confirmed by binary inspection) and requires the undocumented `GET /api/oauth/usage` endpoint with OAuth token discovery that differs per platform (macOS Keychain vs `~/.claude/.credentials.json`). `f()` is the sole high-risk feature and must be isolated behind a function seam, cached with a TTL, and fail-silent.

The two risks that could invalidate design decisions are (a) the symlink-install assumption inside Docker Sandboxes — a host-absolute symlink may dangle in the container, blanking the line with no error — and (b) the `f()` data source. Both are cheap to validate empirically and expensive to discover late; both deserve early spikes. Everything else is portability discipline: write to the bash 3.2 subset (macOS `/bin/bash` is frozen at 3.2.57), never use `date -d`/`date -r` (pure epoch arithmetic for countdowns), and guard every field for absence/null with a fixture suite.

## Key Findings

### Recommended Stack

Bash (3.2-compatible syntax, `#!/bin/bash`) + jq 1.6+ + git >=2.22, all present in both target environments. Curl only for the optional `f()` segment. The stdin JSON contract is fully verified against docs and the installed v2.1.238 binary.

**Core technologies:**
- bash 3.2 subset: script runtime — the only way one script behaves identically on macOS host and Linux sandbox
- jq (single-pass `@sh`/`@tsv` extraction): stdin parsing — one process instead of ten; `// ""` sentinels map absent/null to hidden segments
- `git status --porcelain=v2 --branch` with `GIT_OPTIONAL_LOCKS=0`: branch/dirty/ahead-behind/upstream in one ~12ms call; stash via `rev-list --count refs/stash`
- Pure epoch arithmetic (`$((resets_at - $(date +%s)))`): countdowns — sidesteps the entire BSD/GNU `date` divergence class
- `refreshInterval: 30-60` in settings: keeps reset countdowns ticking while idle

### Expected Features

**Must have (table stakes):**
- Model name (suffix-stripped) + effort level + directory — pure stdin
- Git branch, dirty `*`, `≡/≢`, `↓N ↑N`, `#N` stash — pure local git
- Context `pct/tokens/window` with k/M shortening — pure stdin
- 5h + weekly `used%` with `(countdown)` — pure stdin `rate_limits`
- ANSI colors with usage thresholds; two-line box-drawing frame
- Hide-empty segment logic — foundational, everything depends on it

**Should have (competitive):**
- `f(%)` Fable-specific weekly limit — almost no bash script has it; requires OAuth usage endpoint (isolate, cache, fail-silent)
- Identical host + Docker Sandbox behavior via one symlinked script

**Defer (v2+ / never):**
- Cost display, config system, TUI, SQLite history, transcript parsing, Nerd Fonts, daemons — all explicit anti-features for this project

### Architecture Approach

Single file, layered top-to-bottom: ANSI constants → pure helpers (`shorten_num`, `fmt_duration`, `pct_color`) → ingestion (one jq) → collectors (git, `f()` adapter) → segment renderers (pure, emit `""` when empty) → assembler (hide-when-empty join, `╭─`/`╰─` prefixes, `printf '%b'`). Renderers never do I/O; all subprocess cost is concentrated in ingestion + collectors, making the latency budget auditable. The `f()` adapter hides its data source behind `get_model_weekly_pct()` so the source can flip (stdin field ↔ OAuth API ↔ removed) without touching rendering. No `set -e`; unconditional `exit 0` with at least line 1 always printed.

**Major components:**
1. Ingestion — single-pass jq extraction into scalar vars with absence sentinels
2. Git collector — one porcelain-v2 call + stash count, `-C "$DIR"` from stdin
3. Segment renderers + assembler — pure formatting, hide-when-empty contract
4. `f()` weekly adapter — the only external-dependency component; cached, TTL'd, fail-silent

### Critical Pitfalls

1. **Slow renders blank the line** — single jq, max 2-3 git calls, never network in render path; ~150ms budget
2. **`f()` has no documented data source** — dump the live payload first, then treat the OAuth endpoint as a research-flagged, cached, hide-on-failure fallback; never couple it to the main rate-limit segments
3. **bash 3.2 / BSD-GNU divergence** — no `declare -A`, `${var,,}`, `mapfile`, `date -d/-r`, bare `stat`; shellcheck + dual-environment smoke test as gates
4. **Schema absence/null drift** — `rate_limits` absent pre-first-response and for API-key auth; `used_percentage` can be null or float; build a fixture suite (full, no-rate-limits, null-context, no-effort, no-git) from day one
5. **Symlink dangles in Docker Sandbox** — the highest-risk unvalidated assumption; verify `ls -L ~/.claude/statusline.sh` resolves inside an actual sandbox early

## Implications for Roadmap

### Phase 1: Foundation + stdin segments
**Rationale:** Everything depends on ingestion, hide-empty assembly, and portability rules; all line-1 identity and line-2 usage segments are pure stdin — fully mockable, zero external risk.
**Delivers:** Skeleton, single-pass jq, pure helpers (colors, `shorten_num`, `fmt_duration`), model/effort/dir segments, context segment, 5h + weekly segments with countdowns, fixture suite, error contract (always exit 0, always print line 1).
**Addresses:** All P1 stdin features from FEATURES.md.
**Avoids:** Pitfalls 1, 3, 4, 5, 6 (perf, bash 3.2, BSD/GNU, schema drift, exit contract).

### Phase 2: Git segment
**Rationale:** Real git states need live verification, not just fixtures; it is the main stderr/edge-state producer.
**Delivers:** Porcelain-v2 collector, `⎇ branch* ≡/≢ ↓N ↑N #N` rendering, with the five edge states (no repo, clean/dirty, detached, no-upstream, empty repo) as explicit acceptance criteria.
**Uses:** `git status --porcelain=v2 --branch`, `GIT_OPTIONAL_LOCKS=0`, `-C "$DIR"`.
**Avoids:** Pitfalls 6, 7.

### Phase 3: Install + dual-environment validation
**Rationale:** The sandbox-symlink assumption can invalidate the whole install story — validate before polishing.
**Delivers:** `~/.claude/settings.json` config with `refreshInterval`, symlink install, README, verified identical rendering on macOS host and inside a live Docker Sandbox (including workspace trust), 80-column check.
**Avoids:** Pitfalls 8, 9.

### Phase 4: `f()` Fable weekly segment (optional-by-design)
**Rationale:** The only feature with an external, undocumented dependency; must not risk phases 1-3. Ship happily without it — hide-empty absorbs its absence.
**Delivers:** Payload probe (check if newer CC versions added a model-specific window to stdin), OAuth `/api/oauth/usage` fetch with per-platform token discovery (Keychain vs `.credentials.json`), TTL cache (>=60-300s), `--max-time 2`, hide-on-any-failure.
**Avoids:** Pitfall 2; security mistakes (never log token, 0600 cache).

### Phase Ordering Rationale

- Stdin-only work first: fully testable with mock payloads, builds the foundation every segment reuses.
- Git second: local-only but stateful; needs real repos, not just fixtures.
- Environment validation third and early relative to `f()`: the sandbox assumption is the project's riskiest, and validating it may change the install story (copy vs symlink).
- `f()` last and isolated: highest complexity, lowest necessity, cleanly severable behind the adapter seam.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (`f()` segment):** undocumented endpoint; confirm current window key (`seven_day_opus` vs newer naming), `utilization` scale (0-1 vs 0-100), and sandbox `.credentials.json` presence at implementation time.

Phases with standard patterns (skip research-phase):
- **Phase 1:** stdin schema fully verified against docs + binary; jq/bash patterns prescribed in STACK.md/ARCHITECTURE.md.
- **Phase 2:** porcelain-v2 is a stable, documented scripting API.
- **Phase 3:** mostly empirical verification, not research — the sandbox check is a spike step inside the phase, not a separate research pass.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against official docs AND installed v2.1.238 binary + host measurements |
| Features | MEDIUM-HIGH | Official docs + multiple community sources; per-model weekly source is MEDIUM |
| Architecture | MEDIUM-HIGH | Patterns cross-verified; `f()` adapter seam is the one LOW-confidence area |
| Pitfalls | MEDIUM-HIGH | Official docs corroborate most; sandbox `~/.claude` sharing is LOW (single forum report) |

**Overall confidence:** HIGH for everything shippable in v1 (phases 1-3); MEDIUM for the `f()` segment.

### Gaps to Address

- **Docker Sandbox symlink/`~/.claude` mount behavior:** unvalidated — verify empirically in Phase 3 before finalizing the README install story.
- **OAuth usage endpoint stability and schema:** undocumented, reported unstable — re-verify window keys and `utilization` scale during Phase 4 planning; design assumes hide-on-failure regardless.
- **Sandbox credential file presence (`~/.claude/.credentials.json`):** community-standard but unverified in an actual sandbox — check in Phase 3/4.
- **`utilization` scale (0-1 vs 0-100):** binary multiplies by 100 internally; confirm empirically before rendering `f(%)`.

## Sources

### Primary (HIGH confidence)
- https://code.claude.com/docs/en/statusline — full stdin schema, ANSI/multi-line support, update/debounce/cancellation model, `refreshInterval`, caching guidance, trust requirement
- Claude Code v2.1.238 binary inspection — statusline payload constructor (only `five_hour`+`seven_day` projected), internal `seven_day_opus`/`seven_day_sonnet` windows, `GET /api/oauth/usage` call
- Local host verification — bash 3.2.57, jq 1.7.1, git 2.50.1, Keychain credential item, 12ms porcelain-v2 timing

### Secondary (MEDIUM confidence)
- ohugonnot/claude-code-statusline, jtbr gist — OAuth usage endpoint pattern, token discovery, ~180-300s caching
- ccstatusline, ccusage, claude-powerline, statuslin.es — feature landscape and competitor analysis
- patyearone gotchas gist, claudelab.net, wmedia.es, voitanos.io — rate-limit field availability corroboration

### Tertiary (LOW confidence)
- Docker Community Forums report of sandbox missing user-level `~/.claude` config — validate empirically
- OAuth endpoint deprecation reports — single-source; design for graceful absence

---
*Research completed: 2026-08-21*
*Ready for roadmap: yes*
