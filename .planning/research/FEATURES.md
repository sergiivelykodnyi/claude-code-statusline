# Feature Research

**Domain:** Claude Code custom status line scripts (`statusLine` command)
**Researched:** 2026-08-21
**Confidence:** MEDIUM (official docs cross-checked with community sources; per-model weekly limit source is undocumented API, MEDIUM at best)

## Ecosystem Snapshot

The landscape splits into four tiers:

1. **Full frameworks** — [ccstatusline](https://github.com/sirmalloc/ccstatusline) (TypeScript/Ink, 40+ widgets, interactive config TUI, powerline themes, multi-line, per-model weekly usage incl. Fable)
2. **Powerline segment tools** — [claude-statusline-powerline](https://github.com/spences10/claude-statusline-powerline) / claude-powerline (Node, configurable segments, local SQLite usage DB, context warnings at 75%/90%)
3. **Cost trackers** — [ccusage statusline](https://ccusage.com/guide/statusline) (session/daily/block cost, burn rate $/hr, remaining block time; parses transcript JSONL + pricing tables)
4. **Single-file bash scripts** — gists and small repos ([jtbr gist](https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b), [ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline), [statuslin.es](https://statuslin.es/status-lines/quota) gallery) — jq-parse stdin, git porcelain, optionally curl the OAuth usage endpoint

This project is squarely tier 4: a fixed personal layout, single bash file, no config system.

**Critical data-source finding (resolves PROJECT.md's open question):** since Claude Code 2.1.x the stdin JSON includes `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` (0–100, may be fractional) and `resets_at` (Unix epoch seconds). Documented in the [official statusline docs](https://code.claude.com/docs/en/statusline). Caveats: appears only for Claude.ai Pro/Max subscribers, only after the first API response in a session, and each window may be independently absent. Also on stdin: `effort.level`, `context_window.used_percentage` / `context_window_size` / `total_input_tokens` / `total_output_tokens`, `model.display_name`, `workspace.current_dir`. **Not on stdin:** any per-model (Opus/Sonnet/Fable) weekly breakdown — that requires the undocumented `GET https://api.anthropic.com/api/oauth/usage` endpoint (fields like `seven_day_opus`), authenticated with the Claude Code OAuth token (macOS Keychain on host; `~/.claude/.credentials.json` on Linux/sandbox), typically cached ~180s to avoid rate-limiting. [MEDIUM confidence — cross-checked across three community sources, but the endpoint is undocumented and can change.]

## Feature Landscape

### Table Stakes (Users Expect These)

Every serious statusline tool ships these; a script missing them feels broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Model display name | The #1 reason people add a statusline (which model am I burning?) | LOW | `jq .model.display_name`; strip ` (1M context)` suffix with a parameter expansion |
| Current directory (basename) | Orientation across multiple sessions | LOW | `basename` of `.workspace.current_dir` |
| Git branch (only in repo) | Universal in shell prompts; users expect parity | LOW | `git symbolic-ref --short HEAD` or `branch --show-current`; suppress entirely outside a repo |
| Dirty marker (`*`) | Standard prompt convention | LOW | `git status --porcelain` non-empty (includes untracked); can be slow on huge repos — see Performance |
| Context usage % | The single most-watched number (compaction anxiety) | LOW | `.context_window.used_percentage` directly from stdin; do NOT recompute from tokens (docs warn values can differ from `/context`) |
| Context tokens / window size (shortened) | Users want absolute numbers, not just % | LOW | `total_input_tokens + total_output_tokens` and `context_window_size`; k/M shortening is simple integer math |
| 5h + weekly rate-limit % with reset countdown | Post-weekly-limits era, quota tracking is the top community use case (statuslin.es "quota" category dominates) | MEDIUM | `rate_limits.five_hour/.seven_day` on stdin; countdown = `resets_at - now`, formatted `d:h:m` with pure bash arithmetic (portable across BSD/GNU) |
| ANSI colorized output | Glanceability; every competitor does it | LOW | Raw escape codes via `printf`; Claude Code renders ANSI in the status row |
| Null-safe / hide-empty segments | Fields are absent before first API response; `rate_limits` absent for API-key users; git absent outside repos | LOW (crosscutting) | `jq -r '... // empty'` + conditional string building; this is a prerequisite for every optional segment |
| Fast, never-blocking execution | Script runs on every render; official docs explicitly warn about lag | MEDIUM (crosscutting) | Single jq invocation, minimal git calls, timeout/cache anything that touches network |

### Differentiators (Competitive Advantage / What Makes This Layout Worth Building)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Fable 5-specific weekly limit `f(%)` | The Fable weekly cap depletes independently and exhausting it silently downgrades the model; almost no bash script shows it (only ccstatusline-class tools do) | HIGH | Requires OAuth `api/oauth/usage` endpoint; token discovery differs host (Keychain) vs sandbox (`.credentials.json`); needs file cache with TTL (~180s) so it never blocks; must degrade to hidden segment on any failure |
| Reasoning effort display `(high)` | Newer stdin field; most older gists predate it; matters now that effort changes model behavior/cost | LOW | `.effort.level // empty`; hide when absent |
| Rich git sync state: `≡`/`≢`, `↓N ↑N`, `#N` stash | Goes beyond typical branch+dirty; tells push/pull/stash state at a glance (Cmder/posh-git heritage symbols) | MEDIUM | `≡/≢` from upstream existence; counts from `git rev-list --left-right --count @{upstream}...HEAD` (one call for both); stash via `git rev-list --count refs/stash 2>/dev/null`; must handle detached HEAD and no-upstream |
| Two-line box-drawing layout `╭─`/`╰─` | Clean visual grouping (session identity vs consumption); plain Unicode, no Nerd Font needed | LOW | Just printf two lines; docs confirm multi-line output is supported |
| Countdown formatting `(2h:50m)` / `(3d:5h:57m)` | Most gists print reset as wall-clock time; a countdown answers the actual question ("how long until I'm back?") | LOW | Pure integer division on epoch delta — deliberately avoids BSD/GNU `date -d`/`-r` divergence |
| Usage-colored thresholds | Color shifts (green→yellow→red) as context/limits fill; claude-powerline warns at 75%/90% | LOW | Ternary on percentage; cheap glanceability win |
| Identical host + Docker Sandbox behavior via one symlinked script | Nobody else targets this explicitly; sandboxes mount `~/.claude` so a symlink gives one source of truth | MEDIUM | Constraint, not code: avoid BSD/GNU-divergent flags; the `f()` credential source is the main host/sandbox difference |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Session cost ($) / burn rate | ccusage popularized it; feels informative | Meaningless on Max subscription (rate limits are the real currency); requires transcript JSONL parsing + pricing tables; not in target layout | Rate-limit percentages ARE the cost display for subscribers |
| Config system / themes / widget toggles | Every framework has one | This is a fixed personal layout; config = the entire complexity of ccstatusline for zero personal value | Edit the script; it's the config |
| Interactive setup TUI | ccstatusline's flagship feature | Requires Node/React/Ink — violates single-bash-file constraint | README one-liner symlink install |
| Usage database (SQLite) / historical analytics | claude-powerline tracks history | Statusline shows *now*; history belongs in `ccusage`/`/usage` | Run `ccusage` ad hoc when history is wanted |
| Transcript JSONL parsing (activity feed, tool status, cumulative tokens) | Richer live data | Fragile (format churns between CC versions), slow on long sessions, and stdin now provides the needed context fields natively | Use stdin `context_window` fields |
| Nerd Font powerline glyphs (``, arrows) | Prettier separators | Requires patched fonts on every environment incl. sandbox terminals | The chosen plain-Unicode symbols (`╭ ⎇ ≡ ↓ ↑ ·`) render everywhere |
| Background daemon / async refresh process | "Never block" taken to extreme | Process lifecycle management inside sandboxes; overkill | In-script TTL file cache for the one network call |
| Placeholder text for missing segments (`--`, `n/a`) | Layout stability | Visual noise; user explicitly chose hide-over-placeholder (PROJECT.md decision) | Hide segment and its separator entirely |
| Install script | Convention | User decision: out of scope; setup is one `ln -s` | Document in README |

## Feature Dependencies

```
Hide-empty segment logic (crosscutting)
    └──required-by──> every optional segment below

Model name ──────────┐
Effort display ──────┤──requires──> stdin JSON parse (jq)
Directory name ──────┤
Context segment ─────┤
5h/1w limit segments ┘
                        5h/1w segments ──also-require──> CC ≥ 2.1.x + Pro/Max sub
                        5h/1w segments ──require──> countdown formatter (epoch math)

Git branch ──requires──> repo detection (git rev-parse --is-inside-work-tree)
    ├── Dirty marker (*) ──requires──> git status --porcelain
    ├── ≡/≢ + ↓N ↑N ──require──> upstream detection (@{upstream})
    └── #N stash ──requires──> refs/stash count

f(%) Fable weekly ──requires──> OAuth usage endpoint call
    ├──requires──> token discovery (Keychain on macOS / .credentials.json in sandbox)
    ├──requires──> TTL file cache (never block render)
    └──enhanced-by──> hide-empty logic (graceful absence on any failure)

Countdown formatter ──constrained-by──> BSD/GNU portability (no date -d / date -r)
Color thresholds ──enhances──> context + rate-limit segments
```

### Dependency Notes

- **5h/1w segments require nothing external:** the biggest de-risking finding — `rate_limits` is on stdin since CC 2.1.x. No API call, no credentials, no cache needed for these two segments.
- **`f()` is the only feature with an external dependency:** undocumented OAuth endpoint + credential access that differs between the two target environments. It is the sole HIGH-complexity, HIGH-risk feature and should be isolated in its own phase with its own research flag. It must fail silent (hidden segment), never block (cache + short curl timeout), and never break the rest of the line.
- **Hide-empty is foundational:** `rate_limits` absent for API-key auth and before first response; `effort` absent on older versions; git absent outside repos. Build segment assembly as "append if non-empty" from day one.
- **Countdown formatting conflicts with naive `date` usage:** BSD `date -r`/`-j` vs GNU `date -d` diverge; pure bash arithmetic on `resets_at - $(date +%s)` (`date +%s` is portable) avoids the whole class of bugs.
- **Dirty marker conflicts with performance on large repos:** `git status --porcelain` is the slowest git call in the pipeline; acceptable for personal repos, but keep it to one invocation and reuse its output.

## MVP Definition

### Launch With (v1)

- [ ] stdin parse + segment assembler with hide-empty — foundation everything sits on
- [ ] Line 1: model (suffix-stripped), effort, directory — pure stdin, trivial
- [ ] Line 1: git branch, `*`, `≡/≢`, `↓N ↑N`, `#N` — pure local git, fast
- [ ] Line 2: context `pct/tokens/window` with k/M shortening — pure stdin
- [ ] Line 2: 5h and 1w `used%` + `(countdown)` — pure stdin (`rate_limits`)
- [ ] ANSI colors with usage thresholds
- [ ] Box-drawing two-line frame
- [ ] Verified identical output on macOS host and Docker Sandbox

### Add After Validation (v1.x)

- [ ] `f(%)` Fable weekly segment — trigger: v1 stable; needs its own research spike on the OAuth endpoint, Keychain vs credentials.json access in both environments, and TTL caching
- [ ] Color escalation tuning (thresholds, which segments shift) — trigger: real-world use feedback

### Future Consideration (v2+)

- [ ] Anything requiring config, transcript parsing, or extra dependencies — deliberately never (see anti-features)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Model + effort + dir | HIGH | LOW | P1 |
| Context pct/tokens/window | HIGH | LOW | P1 |
| 5h + 1w limits w/ countdown | HIGH | LOW–MEDIUM | P1 |
| Git branch + dirty | HIGH | LOW | P1 |
| Hide-empty logic | HIGH | LOW | P1 (foundation) |
| ANSI colors | MEDIUM | LOW | P1 |
| `≡/≢`, `↓↑`, stash | MEDIUM | MEDIUM | P1 (core of target layout) |
| Box-drawing layout | MEDIUM | LOW | P1 |
| `f(%)` Fable weekly | HIGH | HIGH | P2 (only external-dependency feature; isolate + research) |
| Color threshold tuning | LOW | LOW | P3 |

## Competitor Feature Analysis

| Feature | ccstatusline | ccusage statusline | claude-powerline | bash gists (jtbr, ohugonnot…) | Our Approach |
|---------|--------------|--------------------|------------------|-------------------------------|--------------|
| Model + effort | Yes (widgets) | Yes `Fable 5 (high)` | Yes | Usually model only | stdin, suffix-stripped, effort in parens |
| Git | Branch, ahead/behind, counts, PR/CI, worktrees | No | Branch + status symbols | Branch, sometimes dirty | Branch + `*` + `≡/≢` + `↓↑` + `#N`, nothing more |
| Context | %, bar, tokens, compaction counter | Tokens + % | % with 75/90% warnings | % or bar | `pct/tokens/window` compact triple |
| 5h/1w limits | Yes + reset timers + per-model weekly (incl. Fable) | Block cost/time (cost-framed) | Via usage DB | Newer ones: stdin `rate_limits`; older: OAuth endpoint | stdin `rate_limits` + countdown |
| Per-model weekly | Yes (usage API) | No | No | Rare (OAuth endpoint) | `f(%)` via OAuth endpoint, cached, fail-silent |
| Cost ($) | Optional widget | Core feature | Yes | Sometimes | Deliberately omitted |
| Theming/config | Full TUI, themes, powerline | CLI flags | JSON config | None (edit script) | None — script is the config |
| Runtime | Node/Bun | Node/Bun | Node | bash+jq | bash+jq (matches gist tier, keeps sandbox parity trivial) |

## Sources

- [Claude Code statusline docs](https://code.claude.com/docs/en/statusline) — stdin JSON schema incl. `rate_limits`, `effort`, `context_window`; absence rules; caching guidance [MEDIUM — official page fetched via web, corroborated by search results]
- [ccstatusline (GitHub)](https://github.com/sirmalloc/ccstatusline) — widget catalog incl. per-model weekly usage (Fable), block/weekly reset timers [MEDIUM]
- [ccusage statusline guide](https://ccusage.com/guide/statusline) and [repo docs](https://github.com/ccusage/ccusage/blob/main/docs/guide/statusline.md) — cost/burn-rate feature set [MEDIUM]
- [claude-statusline-powerline (GitHub)](https://github.com/spences10/claude-statusline-powerline) — segments, SQLite usage DB, context warnings [MEDIUM]
- [jtbr statusline gist](https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b) — OAuth `api/oauth/usage` endpoint, `user:profile` scope, Keychain vs `~/.claude/.credentials.json`, 180s cache, BSD/GNU date gotchas [MEDIUM — cross-checked]
- [statuslin.es quota gallery](https://statuslin.es/status-lines/quota) — community feature landscape; stdin rate-limit data as primary source, usage API as fallback [MEDIUM]
- [ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline), [tokn.watch on weekly limits](https://tokn.watch/blog/claude-weekly-limit/) — per-model weekly cap behavior (silent downgrade) [MEDIUM]

---
*Feature research for: Claude Code custom status line scripts*
*Researched: 2026-08-21*
