# Claude Code Status Line

## What This Is

A custom `statusline.sh` for Claude Code that renders a two-line status line showing the session at a glance: model name and reasoning effort, current directory, rich git status (branch, dirty state, sync state, ahead/behind, stashes) on line one; context-window usage and 5-hour / weekly rate-limit usage with reset countdowns on line two. It works identically on the user's host machine (macOS) — installed by symlinking `kit/files/home/.claude/statusline.sh` into `~/.claude` — and inside Docker Sandboxes, where the repo's `kit/` sbx mixin kit delivers the same file and merges the `statusLine` setting at every start.

## Core Value

One glance at the terminal tells you everything about the session: which model at which effort, where you are in git, and how much context and rate limit you have left before things reset.

## Target Layout

```text
model_name (effort) · current_dir_name · current_git_branch branch_status ahead behind stash
context_usage_pct/context_usage_tokens/window_size · usage_pct/5h (when_reset) · usage_pct/1w (when_reset) · Fable fable_pct/1w (fable_reset)
```

Whole example:

```text
Opus 5 (high) · myproject · main* ↓2 ↑3 #2
10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)
```

> Layout correction (Phase 2): the `╭─ `/`╰─ ` frame prefixes from the original design are removed — Phase 1 shipped with them; Phase 2 drops them.

> Layout correction (Phase 4): the Fable weekly value is a separate last segment with its own countdown — `· Fable 74%/1w (2d:4h:30m)` — instead of the in-segment form the original brief described.

Segment definitions:

- `model_name` — model display name with any `(1M context)` suffix stripped (e.g. `Opus 5`, not `Opus 5 (1M context)`)
- `(effort)` — current reasoning effort, e.g. `(high)`
- `current_dir_name` — basename of the directory Claude is running in
- `branch` — current git branch, rendered as its own segment, only when inside a git repo
- `branch_status` — `*` appended to branch name when there are changes or untracked files; the sync state is one mutually exclusive token: `≡` means in sync (upstream present AND ahead=behind=0), `≢` means no upstream, and the `↓N`/`↑N` arrows replace the glyph otherwise (detached: the magenta short-SHA label is the marker, no token)
- `↓N` — commits on the remote not yet pulled (incoming)
- `↑N` — local commits not yet pushed (outgoing)
- `#N` — number of stashes
- Context: `used%/used_tokens/window` with shortened numbers (`100k`, `1M`)
- 5h limit: `used%/5h (reset countdown)`
- Weekly limit: `used%/1w (reset countdown)`
- Fable weekly: `Fable used%/1w (reset countdown)` — the Fable 5-specific weekly limit, rendered last on line 2 with its own countdown (Phase 4)

## Requirements

### Validated

- ✓ Line 1 renders model name (suffix-stripped), effort, and directory name — v1.0 (Phase 1)
- ✓ Line 2 renders context usage as percent / shortened tokens / shortened window size — v1.0 (Phase 1)
- ✓ Line 2 renders 5h rate-limit usage percent with reset countdown — v1.0 (Phase 1)
- ✓ Line 2 renders weekly rate-limit usage percent with reset countdown — v1.0 (Phase 1) (Fable weekly segment added in Phase 4)
- ✓ Stdin-derived segments with no data are hidden entirely, and the script never fails (exit 0, zero stderr, line 1 always renders) — v1.0 (Phase 1)
- ✓ Output is colorized with ANSI colors, thresholds shift green/yellow/red — v1.0 (Phase 1)
- ✓ Line 1 renders git branch with dirty marker, remote-sync symbol, ahead/behind counts, and stash count when in a git repo — v1.0 (Phase 2)
- ✓ Segments with no data are hidden entirely (no git segment outside git repos, no `#0`, no `↓0`/`↑0`) — v1.0 (Phase 2)
- ✓ Frame prefixes `╭─ `/`╰─ ` removed; both lines render bare (layout correction) — v1.0 (Phase 2)
- ✓ Script works on macOS host and inside Docker Sandboxes — v1.0 (Phase 3) (126-check harness green in both; 7 fixture renders byte-identical host vs sandbox; live `claude` eyeball in both environments passed UAT)
- ✓ README briefly describes what the status line shows and the symlink command that installs `statusline.sh` into `~/.claude` — v1.0 (Phase 3) (plus the `settings.json` snippet with `refreshInterval 60` and the Docker Sandboxes kit route)
- ✓ Line 2 additionally renders the Fable 5 weekly percent and reset countdown as a separate `Fable pct/1w (countdown)` segment, last on line 2 — v1.0 (Phase 4) (OAuth usage endpoint behind a 5-min 0600 cache with 1 h grace, fail-silent hide; harness 126 → 220 checks green on host and in the kit sandbox; live sandbox evidence `12 checks, 0 failures`; UAT 3/3 in both environments)

### Active

Candidates for the next milestone (not yet committed — `/gsd-new-milestone` decides):

- [ ] Fable fetch hardening: failure backoff on repeated endpoint errors, `curl -q`, token guard, §5.13 assert (04-REVIEW.md WR-01..04 / 04-SECURITY.md T-04-19/20)
- [ ] Color-threshold tuning from real-world use (PRES-05, deferred from v1)
- [ ] Prefer stdin `rate_limits.model_scoped` for the Fable bucket once Claude Code projects it (stdin-first branch exists, untested against live data)
- [ ] Re-probe `sbx kit add` on the next sbx release (`tests/probe-kit-add.sh`); flip the README recreate sentence if it lands

### Out of Scope

- Install script — README documents the manual `ln -s` command instead; user preference
- Placeholder rendering for missing segments — user chose hide-over-placeholder for a clean line
- Support for shells/OS beyond bash on macOS + Docker Sandbox Linux — only the two target environments matter

## Current State

**Shipped:** v1.0 MVP on 2026-08-23 — 4 phases, 13 plans, 29 tasks, 108 commits over 3 days. See `.planning/MILESTONES.md` and `milestones/v1.0-ROADMAP.md`.

- `kit/files/home/.claude/statusline.sh` — 432 lines, bash 3.2, one jq `@sh` pass, all 10 stdin fields type-guarded; renders model/effort/dir + git on line 1, context · 5h · 1w · Fable weekly on line 2
- `tests/run.sh` — 220 hermetic checks (fixtures, git-state matrix, latency budget, security probes proven to bite); `tests/sandbox.sh` — 12 live Docker Sandbox checks; `tests/render-fixtures.sh` byte-diff; `tests/probe-kit-add.sh`
- `kit/spec.yaml` — sbx mixin kit: delivers the script + idempotent startup `statusLine` merge
- README covers host `ln -sf` install, settings snippet (`refreshInterval` 60), sandbox kit route, Fable segment
- Known follow-ups: Fable fetch backoff (WR-01..04), `sbx kit add` blocked on sbx v0.39.0, PRES-05 threshold tuning

## Next Milestone Goals

Not yet defined — run `/gsd-new-milestone`. The Active list above holds the candidates carried out of v1.0.

## Context

- Claude Code invokes the status line command with a JSON payload on stdin (model, workspace, context_window, rate_limits.five_hour / seven_day); the script parses it with one `jq` pass. The Fable weekly bucket is not on stdin yet — it comes from `GET /api/oauth/usage` behind a cache (resolved in Phase 4).
- The repo contains `project-brief.md` (historical brief, left untouched; layout corrections are recorded here and in the roadmap) and design notes committed as docs.
- Installation model: this repo is the source of truth. On the host, `kit/files/home/.claude/statusline.sh` is symlinked to `~/.claude/statusline.sh`. Docker Sandboxes do not import the host `~/.claude` (user-level config is not imported and symlinks to host paths cannot be followed), so the `kit/` sbx mixin kit installs the same file there and merges the `statusLine` setting at every start.

## Constraints

- **Dependencies**: `jq`, `git`, and standard Unix tools may be assumed — user confirmed both environments have them
- **Portability**: must behave identically on macOS (BSD userland) and Docker Sandbox Linux (GNU userland) — avoid flags that differ between the two
- **Performance**: status line runs on every render; git and data lookups must be fast and never block the prompt

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Depend on jq (no pure-bash fallback) | Both target environments have it; parsing JSON in bash is fragile | ✓ Good — single `@sh`-quoted jq pass proved safe (injection probe) and simple |
| Hide empty segments instead of placeholders | Cleaner line; layout stability not valued | ✓ Good — hide gates fell out of Plan 01's structure for free; Plan 02 needed zero script changes |
| ANSI-colorized output | Better glanceability (e.g. usage color can shift as limits fill) | ✓ Good — SGR 2 faint frame + 7-code palette confirmed readable in light and dark themes (UAT) |
| ↓ = incoming (pull needed), ↑ = outgoing (push needed) | Confirmed with user against brief's wording | ✓ Applied — `↓N` behind (yellow) / `↑N` ahead (green) from `branch.ab`, hidden at zero (Phase 2) |
| README-only install (symlink command), no install script | User preference; setup is a one-liner | ✓ Applied — `ln -sf` one-liner + `rm -f && cp` variant with overwrite warning; host UAT passed following only the README (Phase 3) |
| Research the rate-limit data source before committing to one | Not part of the basic stdin payload; reliability unknown | ✓ Resolved — stdin `rate_limits.five_hour`/`.seven_day` covers 5h/1w; only the Fable weekly segment needs the OAuth endpoint (Phase 4) |
| Threshold color spans `NN%` only, reset before labels | Resolved plan action-text/verify contradiction in favor of the binding verify | ✓ Applied identically at all three percentage sites (Phase 1) |
| SGR 2 (faint) for frame/separators | Theme-adaptive dim per D-02 without hardcoding a gray | ✓ Confirmed readable on light and dark themes (Phase 1 UAT) |
| One `git status --porcelain=v2 --branch` + stash `rev-list`, all under `GIT_OPTIONAL_LOCKS=0`, uncached | One read-only ~12 ms process per render; never takes index locks while Claude itself runs git | ✓ 10 full renders ≤ 2 s budget (measured 0–1 s); session cache kept as a documented lever only (Phase 2) |
| Semantic per-marker git colors spanning the whole token (magenta branch — magenta short SHA when detached, unchanged; yellow `*`; one mutually exclusive sync token: green `≡` in-sync, red `≢` no-upstream, yellow `↓N` behind-only, blue `↑N` ahead-only, both arrows red when diverged; cyan `#N`) | Glanceability — each marker reads as one colored unit; sync color encodes severity (quick task 260906-w19) | ✓ Legible on light and dark themes (Phase 2 UAT); sync merge shipped 2026-09-06 |
| Type-guard all 10 stdin fields inside the single jq `@sh` program (`strings` on MODEL/EFFORT/DIR, `uint` = numbers→floor→0≤n<1e15 on the 7 numerics) | jq `@sh` quotes each array element as its own eval word (array-payload RCE, CR-02); string `resets_at` reached `$(( ))` (CR-01); floats/exponents leaked stderr | ✓ Both RCEs closed at one choke point, one jq pass preserved, renders byte-identical; 14/14 threats closed in 02-SECURITY.md (Phase 2) |
| Every new harness security probe must be proven to bite against the pre-fix script | A probe that cannot fail is false assurance (02-VERIFICATION CR-02 was missed by string-only probes) | ✓ Convention established; suite 82 → 125 checks with recorded pre-fix failure sets (Phase 2) |
| Canonical script lives at `kit/files/home/.claude/statusline.sh`; sandboxes get it via an sbx mixin kit (`kit/spec.yaml`), not a shared `~/.claude` | Docker Sandboxes import neither host `~/.claude` nor host symlinks; a kit is the only route that lands the file at `/home/agent/.claude` | ✓ Pure `git mv` (100755 preserved); kit validated offline and live — `tests/sandbox.sh` 11 checks / 0 failures (Phase 3) |
| Sandbox `statusLine` wiring = root `setup.startup` idempotent jq merge of only `.statusLine` after the platform seed (`themeId` wait, atomic tmp+mv, chmod 0755, non-recursive chown) | The engine seeds `settings.json` late at create time and would overwrite an install-time merge; startup reconcile survives both create and restart | ✓ Merge present after first start and survives stop/start (restart probe canary kept); every other key preserved (Phase 3) |
| Existing sandboxes: `sbx rm` + recreate with `--kit`, not `sbx kit add` | sbx v0.39.0 refuses `kit add` for kits declaring `setup.startup` (observed; "does not yet apply") | ✓ README documents recreate; `tests/sandbox.sh` re-probes kit-add on every run; quick task 260822-rbm proved an install-only kit is refused too (`files/` not applied by kit-add) but its install-time merge survives the seed — only the kit-add flow blocks (Phase 3) |
| Cross-environment evidence = raw fixture renders dumped under gitignored `tests/out/<env>/` and compared with POSIX `diff -r` | Byte-for-byte proof of PORT-01 without screenshots or human eyeballing | ✓ `diff -r` empty for all 7 fixtures host vs sandbox (Phase 3) |
| Fable usage is a separate last line-2 peer segment `Fable NN%/1w (countdown)` (D-51), not `f(pct)` inside the weekly segment | The Fable bucket has its own reset time; a peer segment keeps every other segment byte-identical and the layout readable | ✓ Shipped; REQUIREMENTS/PROJECT/ROADMAP/README reconciled in 04-04 (Phase 4) |
| Fable source order: stdin `rate_limits.model_scoped` (empty today) → 300 s TTL cache → `GET /api/oauth/usage` via `curl -K -` with a read-only token (credentials file → Keychain, `expiresAt` pre-check) → 3600 s grace → hidden | Never block or blank the line; Claude Code owns token refresh; stdin wins the moment the binary projects the bucket | ✓ Live renders on host and in the kit sandbox (`Fable 90%/1w (1d:18h:32m)` in 1 s); every failure branch hides with exit 0 / 0 stderr (Phase 4) |
| Shared per-user cache `~/.claude/statusline-usage-cache.json`, 0600 via `mktemp`+`mv -f`, negative results cached; `STATUSLINE_NO_FABLE` kill switch exported by the harness and dumper | Hermetic tests (no Keychain, no network, no `~/.claude` writes) and a cache that is safe under concurrent renders | ✓ Harness 220/0 hermetic; D-46 before/after identical through the live sandbox run (Phase 4) |
| Live sandbox evidence is re-runnable (`tests/sandbox.sh` §5.13, presence-only credentials probe) and gated on a human Docker Desktop action — never faked | Evidence must come from a real sandboxd; the token is never read or printed by the probe | ✓ `tests/out/sandbox/EVIDENCE.txt` 12/0, harness-in-sandbox 220/0, PORT-01 8/8 byte-identical (Phase 4) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-23 after v1.0 milestone*
