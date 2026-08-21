# Claude Code Status Line

## What This Is

A custom `statusline.sh` for Claude Code that renders a two-line, box-drawing status line showing the session at a glance: model name and reasoning effort, current directory, rich git status (branch, dirty state, sync state, ahead/behind, stashes) on line one; context-window usage and 5-hour / weekly rate-limit usage with reset countdowns on line two. It must work identically on the user's host machine (macOS) and inside Docker Sandboxes, installed by symlinking into `~/.claude`.

## Core Value

One glance at the terminal tells you everything about the session: which model at which effort, where you are in git, and how much context and rate limit you have left before things reset.

## Target Layout

```text
╭─ model_name (effort) · current_dir_name ⎇ current_git_branch branch_status ahead behind stash
╰─ context_usage_pct/context_usage_tokens/window_size · usage_pct/5h (when_reset) · usage_pct/1w f(usage_pct) (when_reset)
```

Whole example:

```text
╭─ Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2
╰─ 10%/100k/1M · 50%/1w (2h:50m) · 15%/1w f(60%) (3d:5h:57m)
```

Segment definitions:

- `model_name` — model display name with any `(1M context)` suffix stripped (e.g. `Opus 5`, not `Opus 5 (1M context)`)
- `(effort)` — current reasoning effort, e.g. `(high)`
- `current_dir_name` — basename of the directory Claude is running in
- `⎇ branch` — current git branch, only when inside a git repo
- `branch_status` — `*` appended to branch name when there are changes or untracked files; `≡` when the branch is pushed to a remote, `≢` when it has no upstream
- `↓N` — commits on the remote not yet pulled (incoming)
- `↑N` — local commits not yet pushed (outgoing)
- `#N` — number of stashes
- Context: `used%/used_tokens/window` with shortened numbers (`100k`, `1M`)
- 5h limit: `used%/5h (reset countdown)`
- Weekly limit: `used%/1w f(fable_used%) (reset countdown)` — `f()` is the Fable 5-specific weekly limit

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Line 1 renders model name (suffix-stripped), effort, and directory name
- [ ] Line 1 renders git branch with dirty marker, remote-sync symbol, ahead/behind counts, and stash count when in a git repo
- [ ] Line 2 renders context usage as percent / shortened tokens / shortened window size
- [ ] Line 2 renders 5h rate-limit usage percent with reset countdown
- [ ] Line 2 renders weekly rate-limit usage percent, Fable 5 weekly percent as `f()`, with reset countdown
- [ ] Segments with no data are hidden entirely (no `⎇` outside git repos, no `#0`, no usage segment when unavailable)
- [ ] Output is colorized with ANSI colors
- [ ] Script works on macOS host and inside Docker Sandboxes
- [ ] README briefly describes what the status line shows and the symlink command that installs `statusline.sh` into `~/.claude`

### Out of Scope

- Install script — README documents the manual `ln -s` command instead; user preference
- Placeholder rendering for missing segments — user chose hide-over-placeholder for a clean line
- Support for shells/OS beyond bash on macOS + Docker Sandbox Linux — only the two target environments matter

## Context

- Claude Code invokes the status line command with a JSON payload on stdin (model, workspace, etc.); the script parses it with `jq`.
- The 5h / weekly rate-limit percentages and reset times are not obviously part of the basic stdin payload — the reliable source (newer stdin fields, local `~/.claude` data files, or an API call) is an open research question.
- The repo already contains `project-brief.md` and design notes committed as docs.
- Installation model: this repo is the source of truth; `statusline.sh` is symlinked to `~/.claude/statusline.sh` so both host and sandboxes (which mount/share `~/.claude`) pick it up.

## Constraints

- **Dependencies**: `jq`, `git`, and standard Unix tools may be assumed — user confirmed both environments have them
- **Portability**: must behave identically on macOS (BSD userland) and Docker Sandbox Linux (GNU userland) — avoid flags that differ between the two
- **Performance**: status line runs on every render; git and data lookups must be fast and never block the prompt

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Depend on jq (no pure-bash fallback) | Both target environments have it; parsing JSON in bash is fragile | — Pending |
| Hide empty segments instead of placeholders | Cleaner line; layout stability not valued | — Pending |
| ANSI-colorized output | Better glanceability (e.g. usage color can shift as limits fill) | — Pending |
| ↓ = incoming (pull needed), ↑ = outgoing (push needed) | Confirmed with user against brief's wording | — Pending |
| README-only install (symlink command), no install script | User preference; setup is a one-liner | — Pending |
| Research the rate-limit data source before committing to one | Not part of the basic stdin payload; reliability unknown | — Pending |

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
*Last updated: 2026-08-21 after initialization*
