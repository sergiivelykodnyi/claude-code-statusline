# Pitfalls Research

**Domain:** Custom Claude Code statusline script (bash, macOS host + Docker Sandbox Linux)
**Researched:** 2026-08-21
**Confidence:** MEDIUM-HIGH (stdin schema and render behavior verified against official Claude Code docs and cross-checked with community projects; model-specific weekly limit source is LOW confidence — undocumented)

## Critical Pitfalls

### Pitfall 1: Slow git/data work blocks or blanks every render

**What goes wrong:**
The script runs on every assistant message (debounced at 300ms). Official docs state: slow scripts block the status line from updating, and **if a new update triggers while the script is still running, Claude Code cancels the in-flight script** — so a slow script doesn't just lag, it produces a stale or blank line. Multiple sequential `git` subprocesses (branch, diff, diff --cached, ls-files, rev-list, stash list) each add fork+exec cost; in large repos `git diff`/`git status` alone can take hundreds of ms.

**Why it happens:**
Developers write the script like a `.bashrc` prompt function — one command per segment — and test it in a tiny repo where everything is instant.

**How to avoid:**
- Collect branch, dirty state, upstream, and ahead/behind from **one** call: `git status --porcelain=v2 --branch` (gives `branch.head`, `branch.upstream`, `branch.ab +N -N`, and file entries for the dirty `*` marker). Add `git rev-parse --git-dir` as the cheap gate and `git stash list | wc -l` (or `git rev-list --walk-reflogs --count refs/stash`) — 3 git calls total, all local.
- Use `git --no-optional-locks` so renders never contend with Claude Code's own git operations on the index.
- **Never** run `git fetch` or any network call in the render path. `↓N` must come from the already-fetched local tracking ref (`branch.ab` counts against `@{u}` — no network needed).
- One `jq` invocation extracting all stdin fields at once (e.g., `jq -r '[...] | @tsv'`), not one `jq` per field.
- If a cache is ever added, key it by `session_id` from stdin — `$$` changes every invocation and defeats the cache (documented gotcha).

**Warning signs:**
Status line visibly lags behind messages; line intermittently goes blank during rapid tool use; `time ./statusline.sh < mock.json` exceeds ~100-150ms in a large repo.

**Phase to address:**
Core script phase (architecture decision: single-pass git, single-pass jq). Verify with a timing budget in the verification phase.

---

### Pitfall 2: The `f()` model-specific weekly limit has no documented data source

**What goes wrong:**
The official stdin schema provides only `rate_limits.five_hour` and `rate_limits.seven_day` (`used_percentage`, `resets_at`). There is **no model-specific weekly field** (the Fable/Opus weekly quota shown in `/usage`). Community statuslines that show it call the **undocumented** `https://api.anthropic.com/api/oauth/usage` endpoint with an OAuth token read from `~/.claude/.credentials.json` — an endpoint that "could change without notice," rate-limits aggressive callers, and on macOS the credential may live in the Keychain rather than that file (LOW confidence), making the fallback platform-asymmetric. Doing this call inline also violates Pitfall 1.

**Why it happens:**
The target layout (`f(60%)`) was designed from what `/usage` displays, assuming all of it reaches the statusline stdin. It doesn't.

**How to avoid:**
- First, empirically dump the real stdin payload (`cat > /tmp/payload.json` as the statusline command) on the current Claude Code version — undocumented fields sometimes exist before documentation.
- If absent: either (a) drop `f()` gracefully (segments-hide-when-missing is already a project decision), or (b) implement the OAuth endpoint fallback as a **cached, TTL'd (≥300s), failure-tolerant** lookup that never blocks a render and never surfaces an error into the line.
- Treat option (b) as its own research-flagged phase; do not couple the main rate-limit segment to it.

**Warning signs:**
`jq '.rate_limits'` on a captured payload shows only `five_hour`/`seven_day`; `.credentials.json` missing on macOS; f() value diverges from `/usage`.

**Phase to address:**
Rate-limit segment phase — **flag for deeper research** (this is the project's acknowledged open question in PROJECT.md).

---

### Pitfall 3: macOS bash 3.2 vs Linux bash 5 feature mismatch

**What goes wrong:**
`#!/bin/bash` on macOS is bash 3.2.57 (2007, GPLv2 freeze). Scripts using `declare -A` (associative arrays), `${var,,}` / `${var^^}` (case conversion), `mapfile`/`readarray`, `${var: -1}` negative offsets in older forms, or `[[ =~ ]]` with quoted patterns behave differently or die with syntax errors — often at *parse* time, so the whole line goes blank. `#!/usr/bin/env bash` may pick up Homebrew bash 5 on the host, but that only hides the problem until the same file runs under a different bash in the sandbox or on a machine without Homebrew bash.

**Why it happens:**
Developers write and test in one environment; bash-4+ idioms are muscle memory; the failure is invisible until the other environment renders nothing.

**How to avoid:**
Commit to the **bash 3.2 subset** as a hard style rule: indexed arrays only, `tr '[:upper:]' '[:lower:]'` for case, `while read` loops instead of mapfile. Lint with `shellcheck -s bash` and smoke-test under both `/bin/bash` (macOS 3.2) and a Linux container's bash before calling any phase done.

**Warning signs:**
`bash -n statusline.sh` under `/bin/bash` on macOS reports syntax errors; script works on host but renders blank in sandbox (or vice versa).

**Phase to address:**
Foundation phase (establish the rule + shellcheck); verification phase (dual-environment smoke test).

---

### Pitfall 4: BSD vs GNU userland divergence (`date`, `stat`, `sed`, `wc`)

**What goes wrong:**
The reset-countdown segment is the classic trap: GNU `date -d @epoch` fails on macOS; BSD `date -r epoch` / `-v+2H` fail on Linux. `stat -f %m` (BSD) vs `stat -c %Y` (GNU) — with a nasty documented ordering bug: on Linux, `stat -f` **prints a filesystem report to stdout before failing**, so a `stat -f || stat -c` fallback captures garbage into command substitution; the GNU form must be tried first. `sed -i` needs `''` on BSD; BSD `wc -l` pads output with spaces (breaks numeric comparison unless piped through `tr -d ' '`).

**Why it happens:**
Both commands "exist" on both platforms with incompatible flags, so nothing fails until the code path runs on the other OS.

**How to avoid:**
- **Countdowns need no `date` parsing at all**: `resets_at` is epoch seconds; compute `delta=$((resets_at - $(date +%s)))` and format `d:h:m` with pure integer arithmetic. `date +%s` is portable.
- Avoid `stat` and `sed -i` entirely in the render path (no cache file → no `stat`; string edits via bash parameter expansion or `sed` without `-i`).
- Any unavoidable `wc -l` gets `| tr -d ' '`.

**Warning signs:**
`(2h:50m)` renders as empty/garbage on one platform; shell arithmetic errors like `syntax error in expression` from captured stat/filesystem noise.

**Phase to address:**
Foundation phase (portability rules); rate-limit phase (epoch-arithmetic countdown).

---

### Pitfall 5: Schema absence/null drift breaks segments or corrupts arithmetic

**What goes wrong:**
Per official docs: `rate_limits` is **absent** for non-Pro/Max accounts and until the first API response of a session; `five_hour` and `seven_day` may be **independently absent**; `context_window.used_percentage` may be `null` early in a session and is a **float** (`23.5`) — feeding it to bash integer arithmetic (`[ "$PCT" -ge 90 ]`) errors out; `current_usage` becomes `null` again right after `/compact`; `effort` is absent when the model doesn't support it. An unguarded `jq -r '.rate_limits.five_hour.used_percentage'` prints the literal string `null`, which then renders as `null%/5h` or kills a comparison. Older/newer Claude Code versions add and remove fields (rate limits only exist ≥ v2.1.x).

**Why it happens:**
Testing happens mid-session on a Max plan where every field is populated; the empty-session, first-render, post-compact, and free-plan states are never exercised.

**How to avoid:**
- Every extraction uses `// empty` (for hide-on-absent, matching the project's hide-empty-segments decision) or `// 0` (for arithmetic), and floats are truncated (`| floor` in jq, or `cut -d. -f1`).
- Segment rendering is conditional on non-empty variables — never print a segment scaffold and fill it later.
- Build a **fixture set** of mock payloads: full, no-rate-limits, null-context, no-effort, no-git — and test the script against all of them (`./statusline.sh < fixtures/no-rate-limits.json`).

**Warning signs:**
Literal `null` or `%` with no number in output; `integer expression expected` errors; segments flicker between renders at session start.

**Phase to address:**
Parsing/foundation phase (guards + fixtures); every segment phase inherits the fixtures.

---

### Pitfall 6: stderr noise, non-zero exit, or empty output blanks the status line

**What goes wrong:**
Official docs: scripts that exit non-zero **or produce no output** cause the status line to go blank; output must go to stdout. `git` outside a repo prints `fatal: not a git repository` to stderr; `jq` on malformed input prints parse errors; under `set -e` any failing probe (like `git rev-parse` outside a repo) kills the whole script mid-render. In `claude --debug` the stderr is logged, but in normal use the user just sees nothing.

**Why it happens:**
Probes (git checks, optional lookups) are *expected* to fail sometimes, but their failure semantics (exit code, stderr) leak into the script's own contract with Claude Code.

**How to avoid:**
- `2>/dev/null` on every external command whose failure is an expected state.
- Do **not** use `set -e`; handle failures explicitly. End the script with an unconditional successful print path and `exit 0`.
- Guarantee at least line 1 (model · dir) always prints even if every optional segment fails.

**Warning signs:**
Blank status line only in certain directories; `claude --debug` shows non-zero exit code from statusline command.

**Phase to address:**
Foundation phase (error-handling contract); verify in the git-segment phase (the main stderr producer).

---

### Pitfall 7: Git edge states — outside repo, detached HEAD, no upstream, empty repo

**What goes wrong:**
- Outside a repo: every git call fails (see Pitfall 6) — the `⎇` segment must vanish entirely.
- Detached HEAD (checked-out tag/SHA, rebase in progress): `git branch --show-current` prints **empty string** — a naive script renders `⎇ ` with nothing after it; `git rev-parse --abbrev-ref HEAD` prints the literal `HEAD`.
- No upstream (new local branch): `git rev-list --count @{u}..HEAD` errors — this is exactly the `≢` state, but only if the error is caught rather than leaked.
- Freshly-initialized repo with zero commits: `HEAD` doesn't resolve; most rev commands fail.
- The script's cwd is not guaranteed to be the workspace dir in all invocation styles — git commands should target the directory from stdin (`git -C "$CURRENT_DIR" ...`), not whatever cwd the shell happens to have.

**Why it happens:**
Each state is rare enough to never appear during development, and each one fails a *different* git command.

**How to avoid:**
`git status --porcelain=v2 --branch` handles all of these in one parse: `branch.head` is `(detached)` when detached; `branch.upstream` line absent ⇒ `≢`; `branch.ab +N -M` present only with upstream ⇒ drives `≡`/`↑`/`↓`; `branch.oid (initial)` for empty repos. Add fixtures/test repos for each state.

**Warning signs:**
`⎇ HEAD` or `⎇ ` (empty) in the line during a rebase; `fatal: no upstream configured` leaking anywhere; ahead/behind shown as `↑0 ↓0` instead of hidden.

**Phase to address:**
Git segment phase — make these five states explicit acceptance criteria.

---

### Pitfall 8: Symlink install silently breaks inside Docker Sandboxes

**What goes wrong:**
`~/.claude/statusline.sh` is a symlink to `/Users/sv/github/claude-code-status-line/statusline.sh`. Inside a Docker Sandbox, that absolute host path exists only if the repo is mounted at the **identical path**; if `~/.claude` is shared but the repo isn't (or is mounted at `/workspace/...`), the symlink dangles and the status line is simply blank in the sandbox with no error. Community reports (Docker forums) already show Docker Sandbox + Claude sessions missing parts of user-level `~/.claude` config — the "sandboxes mount/share `~/.claude`" assumption in PROJECT.md is unvalidated. Related: if the script ever resolves paths relative to itself (`$(dirname "$0")` for a config or lib file), the symlink makes that resolve into `~/.claude/`, not the repo — and `readlink -f` is only reliably available on macOS ≥ 12.3.

**Why it happens:**
Symlinks encode host-absolute paths; containers re-map paths. It works on the host, so the install "looks done."

**How to avoid:**
- Keep the script **fully self-contained**: single file, no sourcing of sibling files, no `$0`-relative paths. Then the only failure mode is the dangling link itself.
- Validate the assumption early: launch a Docker Sandbox, run `ls -L ~/.claude/statusline.sh`, confirm it resolves and executes. If it dangles, the README's install story changes (copy instead of symlink, or mount requirement documented).
- Also verify workspace-trust behavior in the sandbox — untrusted workspaces skip the statusline command entirely (`claude --debug` logs `Status line command skipped: workspace trust not accepted`).

**Warning signs:**
Works on host, blank in sandbox; `file ~/.claude/statusline.sh` inside the container reports "broken symbolic link".

**Phase to address:**
Install/README phase, with a mandatory sandbox verification step. This is the single highest-risk assumption in the project — validate before polishing segments.

---

### Pitfall 9: ANSI escapes and Unicode symbols corrupt layout or render as garbage

**What goes wrong:**
- Width math that counts raw bytes counts ANSI escape sequences (`\033[32m` = 5 chars) and multi-byte UTF-8 symbols (`⎇` = 3 bytes) as visible width — truncation/padding lands mid-escape and garbles the line. Official docs note complex escape sequences can occasionally garble output when they overlap other UI updates, and **multi-line status lines with escape codes are more prone to rendering issues**.
- `tput cols` does not work (script output is captured, not a TTY) — use the `COLUMNS` env var (set by Claude Code ≥ v2.1.153).
- `echo -e` is unreliable across shells; escape codes appear literally as `\033[32m` text. Docs recommend `printf '%b'`.
- Under a `C`/`POSIX` locale (common in minimal containers), bash `${#var}` and `cut`/`awk` operate per-byte, so any length logic on strings containing `⎇ ≡ ≢ ↓ ↑ ╭ ╰ ·` miscounts; the symbols themselves pass through to the host terminal fine as raw UTF-8 bytes, but depend on the terminal font to display.
- The right side of the status row is **shared with system notifications and the verbose token counter** — long lines get truncated on narrow terminals by Claude Code itself.

**Why it happens:**
The script's output looks like a normal terminal string but is post-processed by Claude Code's renderer, and the box-drawing design makes the line long and symbol-heavy.

**How to avoid:**
- Don't implement custom truncation/padding at all if avoidable — emit short segments and let hiding-empty-segments keep the line compact. If truncation is needed, strip ANSI before measuring and use `COLUMNS`.
- Use `printf '%b'` (or `printf` with literal `$'\033'` codes) exclusively; never `echo -e`.
- Always `\033[0m` reset at end of each line so a canceled render doesn't bleed color.
- Keep escapes simple (SGR colors only; no cursor movement, no OSC unless needed).
- Test in a narrow terminal (~80 cols) and inside the sandbox terminal.

**Warning signs:**
Garbled characters after resize; color bleeding into the input prompt; line 2 wrapping; literal `\033[` text visible.

**Phase to address:**
Rendering/colorization phase; narrow-terminal check in verification.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| One `jq` call per field | Readable code | 10-15 subprocess spawns per render; visible latency | Never — single-pass extraction from day one |
| `#!/usr/bin/env bash` + bash-5 idioms | Nicer syntax on host | Blank line wherever bash is 3.2; hidden env dependency | Never for this project (two mandated environments) |
| Skipping fixture payloads ("I'll test live") | Faster start | Absent-field states (free plan, session start, post-compact) never exercised; `null` leaks to UI | Never — fixtures are ~20 lines each |
| Inline OAuth usage-API call for `f()` | Segment works immediately | Blocks renders, breaks when undocumented endpoint changes, platform-asymmetric credentials | Never inline; only as cached TTL'd background fetch |
| Hard-coding window size display (`1M`) | Trivial | Wrong for 200k sessions; `context_window_size` already provided | Never — field is free |
| No cache for git info | Simpler script | Only hurts in very large repos | Acceptable for MVP; add session_id-keyed cache only if timing budget exceeded |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Claude Code stdin | Assuming all documented fields always present | Every field guarded with `// empty` / `// 0`; segments render conditionally |
| Claude Code stdin | Reading stdin lazily/partially | `input=$(cat)` once, first thing; parse from the variable |
| Claude Code renderer | Writing status to stderr, or exiting non-zero on partial failure | stdout only; unconditional `exit 0`; always print line 1 |
| Claude Code renderer | Assuming the script runs to completion | In-flight runs are canceled on new triggers; keep total runtime well under ~150ms |
| git | `git branch --show-current` as the only branch source | `git status --porcelain=v2 --branch` single call; handles detached/no-upstream/initial |
| git | Computing `↓` via `git fetch` | Use local tracking ref (`branch.ab`); accept that `↓` reflects last fetch |
| OAuth usage API (`api.anthropic.com/api/oauth/usage`) | Treating it as stable/documented | Undocumented, community-discovered; cache ≥300s, degrade to hiding `f()` on any failure |
| `~/.claude/.credentials.json` | Assuming it exists on macOS | May be Keychain-only on macOS (LOW confidence — verify empirically); Linux sandbox likely has the file if auth is shared |
| Model display name | Stripping only ` (1M context)` exactly | Strip any parenthesized suffix pattern; names drift across releases |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Sequential git subprocesses | Lag/blank line in big repos | 3-call maximum (`rev-parse` gate, `status --porcelain=v2 --branch`, stash count), `--no-optional-locks` | Repos with >10k files or slow disks (and any repo, mildly) |
| Per-field `jq` spawns | 50-150ms of pure fork overhead | One `jq ... @tsv` extraction | Every render, everywhere |
| Network call in render path | Multi-second freezes offline/VPN; canceled renders | No network in render path, ever; background/TTL cache only | First flaky network |
| Cache keyed by `$$` | Cache never hits; doubles work | Key by `session_id` from stdin | Immediately (documented gotcha) |
| `refreshInterval` + expensive script | Constant CPU churn even when idle | Only set `refreshInterval` if countdown must tick; keep script cheap enough that it doesn't matter | When countdown display added |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging/echoing the OAuth token while debugging the `f()` fallback | Credential leak into transcripts/scrollback | Never print token; redact in any debug output |
| World-readable usage cache in shared `/tmp` with predictable name | Other local users read usage/account data; symlink attacks on multi-user systems | Cache under `~/.claude/` (0600) or `${TMPDIR}` with `umask 077` |
| Executing content derived from stdin JSON (eval, unquoted expansion) | Malicious repo/branch names (e.g., `$(...)` in a branch name) execute in the user's shell | Quote every expansion; never `eval`; treat branch names and dir names as untrusted strings |
| Symlinked script writable from repo checkout | Anything that writes to the repo effectively edits a file executed by every Claude session | Acceptable by design here (repo is source of truth), but document it in README |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing `null`, `0%`, `↑0`, `#0` placeholders | Noise defeats glanceability | Hide-on-empty (already a project decision) — enforce per segment |
| `⎇ ` with empty branch during rebase/detached HEAD | Confusing broken-looking line | Show short SHA or `(detached)` explicitly |
| Countdown frozen between messages | `(2h:50m)` looks wrong during long idle | Accept staleness for MVP; optionally set `refreshInterval: 60` later |
| Red context color at benign low-usage moments (static thresholds) | Alarm fatigue | Thresholds tuned to action points (e.g., green <60, yellow <85, red ≥85) |
| Line exceeding narrow terminals | Claude Code truncates; right side collides with system notifications | Keep segments terse; test at 80 columns |
| `↓`/`↑` semantics inverted | Misleads push/pull decisions | Locked in Key Decisions: `↓` incoming, `↑` outgoing — encode in a fixture test |

## "Looks Done But Isn't" Checklist

- [ ] **Git segment:** Often missing detached-HEAD/no-upstream/empty-repo handling — verify against fixture repos in all five states (no repo, clean, dirty, detached, no-upstream)
- [ ] **Rate-limit segment:** Often missing the absent-field states — verify with a payload lacking `rate_limits` entirely and one lacking only `seven_day`
- [ ] **Context segment:** Often missing null/float `used_percentage` — verify with `null` and `23.5` payloads; verify `200000` vs `1000000` window renders `200k` vs `1M`
- [ ] **Countdown:** Often built with `date -d`/`date -v` — verify pure epoch arithmetic by running the same fixture on macOS and in a Linux container
- [ ] **Install:** Often only tested on host — verify the symlink resolves and the script executes **inside an actual Docker Sandbox**, including workspace trust
- [ ] **Error contract:** Often breaks in an untested directory — verify `cd /tmp && ./statusline.sh < fixture.json` prints line 1 and exits 0 with no stderr
- [ ] **Bash 3.2:** Often bash-5 idioms creep in — verify `/bin/bash -n statusline.sh` on macOS and a full run under macOS `/bin/bash`
- [ ] **Colors:** Often missing trailing reset — verify line ends with `\033[0m` and nothing bleeds into the prompt

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Blank line in one environment | LOW | `claude --debug` logs exit code + stderr of first invocation; run script manually with a captured payload |
| f() source disappears (endpoint change) | LOW | Segment auto-hides (hide-on-empty); remove fallback code at leisure |
| Schema drift in new Claude Code release | LOW-MEDIUM | Re-capture live payload (`cat > /tmp/payload.json` as statusline command), diff against fixtures, adjust jq paths |
| bash-3.2 incompatibility shipped | LOW | shellcheck + syntax check pinpoint the construct; rewrite in 3.2 subset |
| Symlink dangles in sandbox | MEDIUM | Requires install-story change (copy, or documented mount requirement) and README update — cheap in code, but invalidates the documented workflow |

## Pitfall-to-Phase Mapping

Suggested phases (roadmap not yet written — mapped to logical phase roles):

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Slow renders | Core script (foundation) | `time` under 150ms in a large repo; no network syscalls |
| 2. `f()` data source | Rate-limit segment — **needs deeper research** | Captured live payload inspected; degradation path demonstrated |
| 3. bash 3.2 subset | Foundation (style rules + shellcheck) | Runs under macOS `/bin/bash` and Linux bash |
| 4. BSD/GNU divergence | Foundation + rate-limit (countdown) | Same fixture output identical on both platforms |
| 5. Schema absence/null | Foundation (parsing + fixtures) | Fixture suite passes for all absence states |
| 6. stderr/exit contract | Foundation | Blank-line test from non-repo dir; exit 0 always |
| 7. Git edge states | Git segment | Five fixture repos, five explicit acceptance criteria |
| 8. Symlink in sandbox | Install/README — **validate assumption first** | Live Docker Sandbox check of symlink resolution + execution |
| 9. ANSI/Unicode rendering | Rendering/colorization | 80-column test; reset codes; `printf '%b'` only |

**Ordering implication:** Pitfall 8 (sandbox symlink) and Pitfall 2 (`f()` source) are the two assumptions that can invalidate design decisions — cheap to validate, expensive to discover late. Both deserve early spikes before segment polish.

## Sources

- Official statusline documentation (schema, absence semantics, cancellation, caching, `stat` ordering gotcha, COLUMNS, troubleshooting): [code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline) — cross-verified, MEDIUM per confidence seam
- Rate-limit gotchas gist ("all the gotchas": v2.1+ requirement, `resets_at` absence, date portability, pacing math): [gist.github.com/patyearone](https://gist.github.com/patyearone/7c753ef536a49839c400efaf640e17de) — MEDIUM
- OAuth usage endpoint fallback and caveats: [github.com/ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline) — LOW-MEDIUM (single community source for endpoint details)
- Docker Sandbox missing user-level `~/.claude` config (symlink-assumption risk): [Docker Community Forums](https://forums.docker.com/t/docker-sandbox-claude-missing-plugins-rules-user-level-config-such-as-claude-md/151158) — LOW (single forum report; validate empirically)
- Sandbox-mode field absent from statusline payload: [anthropics/claude-code#56843](https://github.com/anthropics/claude-code/issues/56843) — MEDIUM
- Performance/caching community practice: [claudefa.st statusline guide](https://claudefa.st/blog/tools/statusline-guide), [andrewconnell.com](https://www.andrewconnell.com/articles/claude-code-cli-statusline/) — MEDIUM
- bash 3.2 / BSD-vs-GNU divergences: long-established, corroborated by official docs' own `stat`/`printf '%b'` guidance — HIGH for the facts themselves

---
*Pitfalls research for: Claude Code custom statusline (bash, macOS + Docker Sandbox Linux)*
*Researched: 2026-08-21*
