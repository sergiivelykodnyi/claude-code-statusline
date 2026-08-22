# Requirements: Claude Code Status Line

**Defined:** 2026-08-21
**Core Value:** One glance at the terminal tells you everything about the session: which model at which effort, where you are in git, and how much context and rate limit you have left before things reset.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Session Info (Line 1)

- [x] **SESH-01**: Status line shows the model display name with any `(1M context)`-style suffix stripped (e.g. `Opus 5`)
- [x] **SESH-02**: Status line shows the current reasoning effort in parentheses (e.g. `(high)`), hidden when the model doesn't report effort
- [x] **SESH-03**: Status line shows the basename of the directory Claude is running in

### Git Status (Line 1)

- [x] **GIT-01**: In a git repo, status line shows the current branch prefixed with `⎇`; outside a repo the whole git segment is hidden
- [x] **GIT-02**: Branch name gets a `*` suffix when the working tree has changes or untracked files
- [x] **GIT-03**: Status line shows `≡` when the branch has an upstream, `≢` when it has none
- [x] **GIT-04**: Status line shows `↓N` for commits on the remote not yet pulled and `↑N` for local commits not yet pushed, hidden when zero
- [x] **GIT-05**: Status line shows `#N` for the stash count, hidden when zero
- [x] **GIT-06**: Git segment renders correctly (or degrades to hidden parts) in edge states: clean repo, dirty repo, detached HEAD, branch with no upstream, not a repo

### Context Usage (Line 2)

- [x] **CTX-01**: Status line shows context usage as `pct/used_tokens/window_size` (e.g. `10%/100k/1M`) using stdin `context_window` fields
- [x] **CTX-02**: Token and window numbers are shortened with k/M units (e.g. `100k`, `1M`)

### Rate Limits (Line 2)

- [x] **LIM-01**: Status line shows 5-hour limit usage as `pct/5h` with a reset countdown (e.g. `50%/5h (2h:50m)`) from stdin `rate_limits.five_hour`
- [x] **LIM-02**: Status line shows weekly limit usage as `pct/1w` with a reset countdown (e.g. `15%/1w (3d:5h:57m)`) from stdin `rate_limits.seven_day`
- [x] **LIM-03**: Reset countdowns are computed with pure epoch arithmetic (no `date -d`/`date -v`) and formatted as `d:h:m` / `h:m`
- [x] **LIM-04**: Rate-limit segments are hidden when the corresponding stdin fields are absent (API-key auth, pre-first-response, older Claude Code)

### Fable Weekly (Line 2)

- [ ] **FAB-01**: Status line shows the Fable 5-specific weekly usage as a separate `Fable pct/1w (countdown)` segment rendered last on line 2, with its own reset countdown (e.g. `15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)`) — layout correction (Phase 4): supersedes the brief's in-segment notation
- [ ] **FAB-02**: Fable weekly data is fetched from the OAuth usage endpoint with the Claude Code OAuth token, discovered from macOS Keychain on the host and `~/.claude/.credentials.json` in Docker Sandboxes
- [ ] **FAB-03**: The Fable fetch is cached with a TTL and uses a short curl timeout so it never blocks rendering
- [ ] **FAB-04**: On any failure (no credentials, endpoint change, timeout, offline), the Fable segment is hidden and the rest of the line renders normally

### Presentation

- [x] **PRES-01**: Output is a two-line layout framed with `╭─` / `╰─` box-drawing characters
- [x] **PRES-02**: Segments are ANSI-colorized
- [x] **PRES-03**: Context and rate-limit percentages shift color as usage grows (normal → warning → critical thresholds)
- [x] **PRES-04**: Segments with no data are hidden entirely, including their separators — no placeholders

### Portability & Robustness

- [x] **PORT-01**: The script produces identical output on macOS host (bash 3.2, BSD userland) and inside Docker Sandboxes (Linux, GNU userland)
- [x] **PORT-02**: The script completes fast enough that Claude Code never blanks the line (well under the ~300ms debounce), using a single jq pass and a single primary git status call
- [x] **PORT-03**: The script never emits stderr noise or non-zero exits that would blank the status line; missing fields and errors degrade to hidden segments
- [x] **PORT-04**: The script works when invoked via a symlink from `~/.claude/statusline.sh`, verified in both environments

### Documentation

- [x] **DOCS-01**: README briefly describes what the status line shows (with the example layout) and the `ln -s` command that symlinks `statusline.sh` into `~/.claude`
- [x] **DOCS-02**: README includes the `settings.json` `statusLine` snippet (with `refreshInterval` so countdowns tick while idle)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Presentation

- **PRES-05**: Color threshold tuning based on real-world use feedback

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Session cost ($) / burn rate | Meaningless on Max subscription; rate limits are the real currency; requires transcript parsing |
| Config system / themes / setup TUI | Fixed personal layout — the script is the config |
| Usage database / historical analytics | Statusline shows *now*; history belongs to `ccusage` / `/usage` |
| Transcript JSONL parsing | Fragile across Claude Code versions; stdin provides needed fields natively |
| Nerd Font glyphs | Requires patched fonts everywhere; plain Unicode renders in both environments |
| Background daemon / async refresh | Overkill; in-script TTL cache covers the one network call |
| Placeholder text for missing segments | User chose hide-over-placeholder |
| Install script | User preference — README documents the one-liner symlink |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SESH-01 | Phase 1 | Complete |
| SESH-02 | Phase 1 | Complete |
| SESH-03 | Phase 1 | Complete |
| CTX-01 | Phase 1 | Complete |
| CTX-02 | Phase 1 | Complete |
| LIM-01 | Phase 1 | Complete |
| LIM-02 | Phase 1 | Complete |
| LIM-03 | Phase 1 | Complete |
| LIM-04 | Phase 1 | Complete |
| PRES-01 | Phase 1 | Complete |
| PRES-02 | Phase 1 | Complete |
| PRES-03 | Phase 1 | Complete |
| PRES-04 | Phase 1 | Complete |
| PORT-03 | Phase 1 | Complete |
| GIT-01 | Phase 2 | Complete |
| GIT-02 | Phase 2 | Complete |
| GIT-03 | Phase 2 | Complete |
| GIT-04 | Phase 2 | Complete |
| GIT-05 | Phase 2 | Complete |
| GIT-06 | Phase 2 | Complete |
| PORT-02 | Phase 2 | Complete |
| PORT-01 | Phase 3 | Complete |
| PORT-04 | Phase 3 | Complete |
| DOCS-01 | Phase 3 | Complete |
| DOCS-02 | Phase 3 | Complete |
| FAB-01 | Phase 4 | Pending |
| FAB-02 | Phase 4 | Pending |
| FAB-03 | Phase 4 | Pending |
| FAB-04 | Phase 4 | Pending |

**Coverage:**

- v1 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-21*
*Last updated: 2026-08-21 after roadmap creation (traceability populated; corrected v1 count from 25 to 29)*
