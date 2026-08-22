# Phase 4: Fable Weekly f() Segment - Research

**Researched:** 2026-08-22
**Domain:** bash 3.2 statusline adapter — undocumented Claude Code OAuth usage endpoint, per-platform credential discovery, TTL cache, fail-silent rendering
**Confidence:** HIGH (every load-bearing fact was verified this session against the installed binary, the live endpoint, the live Docker Sandbox, or a bash 3.2 prototype)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Which number the segment shows
- **D-47:** The segment always shows the **Fable** weekly bucket, regardless of the model in use. Verified live on 2026-08-22 against the user's account: the bucket lives **only** in the endpoint's `limits[]` array as `{kind: "weekly_scoped", group: "weekly", percent: 74, severity, resets_at: "2026-08-24T18:00:00.097816+00:00", scope: {model: {id: null, display_name: "Fable"}, surface: null}, is_active: true}`; the legacy keys `seven_day_opus` / `seven_day_sonnet` were **null**. `percent` is already an integer 0–100 (top-level `seven_day.utilization` is also 0–100, e.g. `39.0`) — the 0–1 vs 0–100 question is settled: **no scaling**.
- **D-48:** Data-source priority: **stdin first, endpoint fallback**, behind the adapter seam so `seg_*` rendering never knows the source. The installed Claude Code 2.1.240 binary contains a `rate_limits.model_scoped[] = [{display_name, utilization, resets_at (ISO string)}]` projection ("Per-model weekly windows from the server limits[] array … present only when the server emits them"); the researcher must verify whether that reaches the **statusline stdin** (2.1.238 projected only `five_hour`+`seven_day`). If present → use it (no network, no credentials); if absent → OAuth endpoint.
- **D-49:** Endpoint answers but no Fable bucket (plan without Fable, bucket moved to usage credits, schema reshuffle) → **segment hidden**. No proxy via `extra_usage`/`spend`.
- **D-50:** Bucket matching: `scope.model.display_name` (endpoint) / `display_name` (stdin) **case-insensitively starts with `fable`**, **first hit in server order** — survives renames like "Fable 5" without code changes. No exact-name knob.

#### Layout & rendering (supersedes the brief's `f()` placement)
- **D-51:** The Fable datum is a **full peer segment on line 2, rendered last**, joined with the standard dim ` · ` like every other segment: `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)`. User's words: *"let's make f() as a separate segment with its own countdown similar to 1w: 'Fable 30%/1w (2d:4h:30m)' and let's put it last, after 1w limit."* This **supersedes** `project-brief.md` / PROJECT.md's `15%/1w f(60%) (…)` in-segment form. — **Reversibility:** reversible — one segment function and one join call; but README/PROJECT/REQUIREMENTS text must move with it.
- **D-52:** Reconcile the planning docs with D-51 in this phase: REQUIREMENTS.md FAB-01 wording (`f(pct)` inside the weekly segment → separate `Fable pct/1w (countdown)` segment last on line 2), PROJECT.md "Target Layout" + segment definitions, README example/legend. `project-brief.md` stays as the historical brief (add a one-line "layout correction" note like the Phase 2 frame note, or leave untouched — Claude's discretion).
- **D-53:** Styling: label is the **literal word `Fable`, rendered dim** (SGR 2, like the effort label); the percentage number gets `pct_color` thresholds **on the number only** (D-03/D-04/D-05, integer-truncated per D-07); `/1w` and the countdown plain. ANSI-16 only (D-02).
- **D-54:** The segment carries **its own countdown** from the Fable bucket's `resets_at` via `fmt_duration` (same `now`/`<1m`/`d:h:m` rules, D-09/D-10). When `resets_at` is missing or unparseable → render `Fable 74%/1w` with no parens. Note: the endpoint (and the binary's `model_scoped` projection) deliver `resets_at` as an **ISO-8601 string** (`2026-08-24T18:00:00.097816+00:00`), not epoch — the script needs a **pure-bash, bash-3.2, BSD/GNU-neutral ISO→epoch conversion** (no `date -d`, no `date -j`); technique is Claude's discretion. Live on 2026-08-22 the Fable and all-models weekly resets coincided to the second, but they are independent fields and may drift — always use the Fable bucket's own value.
- **D-55:** Hidden entirely (with its separator) whenever there is no Fable value; it renders **even if the stdin 1w segment is absent** (it is a peer, not a sub-segment). Hidden = kill switch set, no credentials, fetch failure past the grace window, no bucket, parse failure.

#### Cache & freshness (FAB-03)
- **D-56:** Cache TTL **300 s** — weekly usage moves slowly; one call per 5 min per machine is gentle on an undocumented endpoint; up to 5 min lag is invisible at weekly scale.
- **D-57:** **One shared per-user cache file** (usage is account-level; N sessions → 1 fetch per TTL), e.g. `~/.claude/statusline-usage-cache.json` (name/location at discretion; **not** a predictable world-readable `/tmp` path), created **0600**, written **atomically (tmp + mv)** so concurrent renders never read a torn file. Never keyed by `$$`.
- **D-58:** **Stale-while-error, bounded:** if the cache is past TTL and the refresh fails (offline, timeout, 401/403, schema change), keep serving the last-good value up to a grace window (~1 h since it was fetched; exact value discretion), then hide. Retry on every render after TTL while failing, each bounded by the curl timeout — no backoff state required.
- **D-59:** **Cold start waits, bounded:** with no cache, the render performs one synchronous `curl --max-time ~2` (exact value discretion, must stay well under what a user perceives as a stall) so the segment appears on the first online render; no background processes, no detached fetches (REQUIREMENTS out-of-scope).

#### Credentials (FAB-02)
- **D-60:** Token lookup order, one ordered list for both environments (no `uname` branch): (1) `~/.claude/.credentials.json` → `.claudeAiOauth.accessToken`; (2) if absent/unreadable and `command -v security` succeeds: `security find-generic-password -s "Claude Code-credentials" -w` → `.claudeAiOauth.accessToken`; (3) else no token → hidden. Read the token only when a fetch is actually needed (cache stale) — cheap renders touch neither store.
- **D-61:** macOS Keychain access dialog: **accept a one-time prompt**. Claude Code writes the item through the same `security` CLI, so none is expected; if one appears the user clicks "Always Allow" once and the README says so. No extra machinery.
- **D-62:** Expired/rejected token → hidden; the script **never refreshes the token** and **never prints it** (carried from STACK.md / PITFALLS.md). Live-verified request headers that worked 2026-08-22: `Authorization: Bearer <token>`, `anthropic-beta: oauth-2025-04-20`, `Content-Type: application/json`.
- **D-63:** Sandbox: `tests/sandbox.sh` gains a probe — does `/home/agent/.claude/.credentials.json` exist, and does the Fable segment render in the kit-created sandbox? If the file is absent, a hidden segment **is the correct outcome**; the kit **never copies or forwards** the host token; the README states where the token must live. Success criterion 2 is satisfied by "renders when the file exists, hides cleanly when not".
- **D-64:** **Kill switch:** one env var (name at discretion, e.g. `STATUSLINE_NO_FABLE=1`, settable in the shell or via `settings.json` `env`) disables the Fable path entirely — no credential read, no network, segment hidden. Also the deterministic "off" switch for `tests/render-fixtures.sh` byte-diffs.

#### Testability & docs
- **D-65:** **Env overrides** for the endpoint URL, the credentials-file path, and the cache-file path (all defaulting to production values; names at discretion, documented only in the script header/tests). `tests/run.sh` uses them to point at a local fixture/fake (e.g. a sanitized copy of the live response shape in `tests/fixtures/`, served via `file://` or a tiny local server — discretion) and asserts: render shape/colors, cache hit (no fetch within TTL), stale-grace serve/hide, timeout → no blocking/no stderr, ISO→epoch parse, kill switch, missing-bucket hide. Phase 2 convention applies: **every new probe must be shown to bite**. No real token or account data in the repo.
- **D-66:** README: update the "What it shows" example with `· Fable 74%/1w (2d:4h:30m)`, add a legend row (Fable weekly usage and its reset; needs the Claude Code OAuth login, hidden otherwise), plus **one short note** covering where the token is read from (credentials file / Keychain), the kill-switch env var, and the possible one-time Keychain prompt on macOS.

### Claude's Discretion
- Env var names (kill switch, endpoint/credentials/cache overrides); cache file name, location (under `~/.claude/` preferred) and format (raw response vs extracted fields); exact `--max-time`; exact stale-grace window; whether the cache records fetch time via mtime (`stat -c %Y || stat -f %m`, Linux form first) or an embedded field.
- ISO-8601 → epoch technique (pure bash arithmetic: parse `YYYY-MM-DDTHH:MM:SS`, honour `Z`/`±HH:MM` offsets, ignore fractional seconds) and where it lives (helper next to `fmt_duration`).
- Name and position of the adapter (`get_fable_weekly` / `seg_fable`), whether the cached JSON is parsed with a second jq call (acceptable — it's off the stdin choke point) and how the stdin `model_scoped` probe is folded into the existing single-pass jq program if the field exists.
- How the harness fakes the endpoint; sanitized fixture content; how `tests/sandbox.sh` detects credentials without printing them.
- Whether `project-brief.md` gets a "layout correction" note or stays untouched (D-52).

### Deferred Ideas (OUT OF SCOPE)
- Showing other model-scoped weekly buckets (Opus/Sonnet/…) or `extra_usage`/`spend` (usage credits) — new capability, not this phase; the adapter's prefix-match rule leaves room for it later.
- Fable-aware color tuning (e.g. different thresholds for the Fable cap) — belongs with PRES-05 (v2 threshold tuning).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (REQUIREMENTS.md) | Research Support |
|----|-------------------------------|------------------|
| FAB-01 | Status line shows the Fable 5-specific weekly usage as `f(pct)` inside the weekly segment — **wording superseded by D-51/D-52: a separate `Fable pct/1w (countdown)` peer segment, last on line 2** | §Verified Facts 1–2 (bucket shape, `percent` 0–100, ISO `resets_at`); §Architecture Pattern 2 (`seg_fable` = `seg_1w` shape + dim label); §Pattern 3 (`iso_to_epoch`, bash-3.2-verified); §Docs Reconciliation (exact lines to change) |
| FAB-02 | Fetched from the OAuth usage endpoint with the Claude Code OAuth token, discovered from macOS Keychain on the host and `~/.claude/.credentials.json` in Docker Sandboxes | §Verified Facts 3–5 (Keychain item shape, sandbox file present + 0600 + reachable endpoint, `security` timing/exit codes); §Pattern 4 (token lookup, `-K -` to keep the token out of `ps`) |
| FAB-03 | Cached with a TTL and a short curl timeout so it never blocks rendering | §Pattern 5 (embedded-`fetched_at` JSON cache, 300 s TTL, 3600 s grace, atomic tmp+mv, 0600 via `mktemp`); §Verified Facts 6 (prototype timings: warm hit ≈ +2–5 ms, cold file:// 42 ms, live 410–440 ms, blackhole bounded by `--max-time`) |
| FAB-04 | On any failure the segment is hidden and the rest of the line renders normally | §Pattern 6 (control flow: every branch falls through to `""`), §Common Pitfalls (negative cache, harness kill switch, hostile cache file), prototype cases 4–7 and 9–10 |
</phase_requirements>

## Summary

Everything this phase depends on was verified this session, so the plan can be written with no open data-source questions. (1) The **statusline stdin in Claude Code 2.1.240 still carries only `rate_limits.five_hour` and `rate_limits.seven_day`** — the payload constructor in the installed binary literally builds `{...five_hour, ...seven_day}` and nothing else; the `model_scoped[]` projection that D-48 refers to lives in the separate *session-usage* payload (`claude usage`), not in the statusline payload. D-48's runtime order ("stdin first, endpoint fallback") therefore costs two extra guarded lines in the existing jq program and is exercised only by a fixture today; the **OAuth endpoint is the effective source**. (2) The endpoint `GET https://api.anthropic.com/api/oauth/usage` answered **HTTP 200 in ~410–440 ms** from both the macOS host (Keychain token) and the Docker Sandbox (credentials file); the Fable bucket is **only** in `limits[]` as `kind: "weekly_scoped"`, `scope.model.display_name: "Fable"`, **`percent` integer 0–100**, `resets_at` ISO-8601 string; `seven_day_opus`/`seven_day_sonnet` are `null`; a bogus token gives 401, no auth gives 429, and the `anthropic-beta` header is optional (200 without it — keep sending it anyway, it is what Claude Code and every community script send). (3) **The kit-created sandbox `statusline-kit-test` already has `/home/agent/.claude/.credentials.json`** (0600, `agent`-owned, `claudeAiOauth.{accessToken,expiresAt,…}`), seeded by the user's global sbx service secret `anthropic (oauth configured)` through sbx's credential proxy (`SBX_CRED_ANTHROPIC_MODE`, `HTTPS_PROXY` set); `curl` 8.18 honours that proxy automatically, so the Fable segment will render live inside the sandbox with zero kit changes.

The design the user locked maps onto a small, fully prototyped adapter: a kill-switch check, the stdin probe, a **JSON cache with an embedded `fetched_at`** (no `stat` shim needed), TTL 300 s / grace 3600 s, one `curl -s -f --max-time 2 -K -` (headers fed on stdin so the token never appears in `ps`), a second guarded jq call to extract `[percent, resets_at]`, an **atomic `mktemp`+`mv` write (0600 by default on both BSD and GNU `mktemp`)**, a **pure-bash days-from-civil ISO→epoch helper that matched Python on 17/17 cases under `/bin/bash` 3.2.57 (0.35 ms per call)**, and `seg_fable` which is `seg_1w` with a dim `Fable ` prefix. A throwaway prototype of the whole flow under bash 3.2 passed the cold/warm/stale-grace/past-grace/kill-switch/no-bucket/stdin-first/timeout/hostile-cache cases; the warm-hit cost is ≈ 2–5 ms on top of the current render.

Two things the planner must not miss: **(a) the harness and the render dumper must export the kill switch globally** — otherwise every `run_fixture` call on the host would read the Keychain and hit the network (2 s stalls, Keychain prompts in CI) — and un-set it only inside the Fable probe block, where the endpoint URL override points at a `file://` fixture; **(b) a successful fetch with no Fable bucket must be cached as a negative result** (pct `null`) with the same TTL, or plans without Fable would make one network call per render and violate success criterion 4.

**Primary recommendation:** Implement `get_fable_weekly` + `seg_fable` exactly as sketched in Pattern 6 (kill switch → stdin probe → cache-fresh → fetch+write → stale-grace → hidden), with env overrides `STATUSLINE_NO_FABLE`, `STATUSLINE_USAGE_URL`, `STATUSLINE_CREDENTIALS_FILE`, `STATUSLINE_USAGE_CACHE` (+ test-only `STATUSLINE_CURL_MAX_TIME`), cache at `~/.claude/statusline-usage-cache.json`, and treat an explicitly set `STATUSLINE_CREDENTIALS_FILE` as "this file only, no Keychain fallback" so the no-credentials probe is deterministic on macOS.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fable bucket value + reset (data) | External service (Anthropic OAuth usage API, HTTPS) | Claude Code stdin (forward-compat probe) | The only datum not on the statusline stdin today; the binary's `model_scoped` projection is for the usage command, not the statusline (Verified Fact 1) |
| Credential discovery | Local OS credential store (Keychain on macOS host; `~/.claude/.credentials.json` in the sandbox) | — | Read-only; Claude Code owns refresh (D-62) |
| Caching / TTL / grace | Local filesystem (`~/.claude/…`, 0600) | — | Per-user, account-level datum; atomic write; no daemon (REQUIREMENTS out-of-scope) |
| ISO→epoch, countdown, colour, join | Script (pure bash helpers) | — | Same helper layer as `fmt_duration`/`pct_color` (statusline.sh lines 38–64) |
| Rendering `Fable pct/1w (countdown)` | Script (`seg_fable`, line-2 join) | — | Peer segment appended as 4th argument of the line-2 `join_segments` call (statusline.sh line 210) |
| Sandbox egress / auth injection | Docker Sandbox platform (sbx credential proxy, `HTTPS_PROXY`) | — | Verified: the sandbox's own token + proxy reach the endpoint (200); the kit ships nothing credential-related |

## Project Constraints (from CLAUDE.md)

Directives extracted from `./.claude/CLAUDE.md` that bind this phase:

- **Dependencies:** `jq`, `git`, standard Unix tools may be assumed; `curl` is named as the supporting tool for the `f()` segment only — must be cached + fail-silent. (`curl` verified present on host 8.7.1 and sandbox 8.18.0.)
- **Portability:** identical behaviour on macOS (BSD) and Docker Sandbox Linux (GNU); **bash 3.2 syntax only**, `#!/bin/bash`; never `date -d`/`date -r`/`date -j`; `stat -c … || stat -f …` Linux-first if `stat` is ever used (this research avoids `stat` entirely); `printf '%b'`/`$'\033[…]'` not `echo -e`; no `declare -A`, `${var,,}`, `mapfile`, negative substring offsets.
- **Performance:** the script runs on every render (300 ms debounce, in-flight scripts cancelled); no blocking curl in the render path beyond a short `--max-time`; TTL cache; hide on failure.
- **Rate-limit sources:** `.rate_limits.five_hour`/`.seven_day` from stdin; `f()` via stdin `rate_limits` + optional OAuth usage endpoint; **never** scrape transcripts/`stats-cache.json`; **never** refresh the OAuth token yourself; hide `f()` if expired.
- **Credential lookup:** macOS host → `security find-generic-password -s "Claude Code-credentials" -w`; sandbox → `~/.claude/.credentials.json` (`.claudeAiOauth.accessToken`); try file first, then Keychain, else give up; no `uname` branch.
- **jq patterns:** `@sh`-quote every interpolation into `eval`; `// ""` for absent/null; truncate percentages with `${PCT%.*}`; avoid `@tsv`+`read`.
- **Testing:** mock-input testing pattern; `claude --debug` for blank lines; shellcheck `--shell=bash` advisory (installed on host, 0.11.0).
- **GSD workflow:** file changes only through GSD commands; docs commits via `gsd_run query commit`.
- **Update model:** `refreshInterval` (60 s configured on host and in the kit) re-runs the script while idle — the Fable cache will be refreshed at most every 300 s by those idle renders too.

## Standard Stack

No new packages. The phase uses tools already present in both target environments.

### Core
| Tool | Version (host / sandbox) | Purpose | Why Standard |
|------|--------------------------|---------|--------------|
| bash | 3.2.57 / 5.3.9 [VERIFIED: `/bin/bash --version` host; `sbx exec … /bin/bash --version`] | Script runtime; bash 3.2 subset | Binding constraint is macOS `/bin/bash` (CLAUDE.md) |
| jq | 1.7.1 / 1.8.1 [VERIFIED: `jq --version` both] | stdin pass (existing), endpoint-response parse, cache parse, credentials-file parse | `ascii_downcase`, `startswith`, `first`, `arrays`/`objects`/`strings`/`numbers` type filters, `@sh` all exist in jq ≥1.5 [VERIFIED: programs in Pattern 2/5 ran on jq 1.7.1] |
| curl | 8.7.1 (SecureTransport/LibreSSL) / 8.18.0 (OpenSSL) [VERIFIED: `curl --version` both] | One `GET` per TTL | `-s -f --max-time N -K -` and `file://` URLs work on both builds [VERIFIED: ran on both] |
| `security` (macOS only) | `/usr/bin/security` [VERIFIED: `command -v security`] | Keychain token read on the host | Item `"Claude Code-credentials"` present, acct `sv`, class `genp` [VERIFIED: `security find-generic-password -s "Claude Code-credentials"` metadata only]; ~21 ms per call; exit 44 when the item is missing [VERIFIED: timed 5 runs; probed a non-existent service] |
| `mktemp`, `mv`, `date +%s` | BSD / GNU [VERIFIED] | Atomic cache write, `NOW` | `mktemp "$dir/.usage.XXXXXX"` (template-path form) works on both and creates the file **0600** on both (`-rw-------` observed on host; GNU default is 0600) [VERIFIED: host `ls -l`; sandbox `mktemp` ok] — no `umask` dance needed |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `python3` (host 3.14.7, sandbox present) | **Tests only** — reference implementation for the ISO→epoch table in `tests/run.sh`? **No:** keep the harness dependency-free; the table in Pattern 3 was cross-checked against Python this session and can be hard-coded as expected epochs | Research-time verification only |
| `flock` | Present in the sandbox, **absent on macOS** [VERIFIED: `command -v flock` in sandbox only] | Do **not** use (ohugonnot uses it; not portable). Concurrent renders racing on the fetch are benign: both write valid JSON, last `mv` wins |
| shellcheck 0.11.0 (host) | Advisory in `tests/run.sh` §10 | Already wired (run.sh lines 416–421) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Embedded `fetched_at` in the cache JSON | File mtime via `stat -c %Y … \|\| stat -f %m …` | mtime needs the dual-flag shim and the Linux-first ordering gotcha; embedded field is one `printf` and zero portability risk → **use embedded** |
| `curl -K -` (config on stdin) | `curl -H "Authorization: Bearer $TOK"` | `-H` puts the token in the process argv (visible in `ps` to other local users for ~0.4 s); `-K -` with a bash-builtin `printf` keeps it out of argv at zero cost [VERIFIED: works on both builds] → **use `-K -`** |
| `file://` fixture via the endpoint URL override | PATH shim for `curl`/`security`; local HTTP server | User chose env overrides (D-65); `file://` needs no server, works in both environments and inside the agent's network-restricted dev sandbox [VERIFIED: host + Docker sandbox] |
| Second jq call on the cache (3–4 ms) | `read -r` three integers + `case` digit validation (0 subprocesses) | jq reuses the existing `uint` guard idiom and is trivially extensible; cost measured at ~3.7 ms per jq start → **use jq** (discretion; either is acceptable) |

**Installation:** none. Optional kit hardening: extend the `setup.install` guard in `kit/spec.yaml` (`command -v jq >/dev/null 2>&1 && command -v git …`) with `&& command -v curl >/dev/null 2>&1` and add `curl` to the apt fallback — a no-op on the base image (curl verified present).

## Package Legitimacy Audit

Not applicable — this phase installs no npm/PyPI/crates packages. The only tools used (`bash`, `jq`, `curl`, `security`, `mktemp`, `mv`, `date`) are OS-provided and verified present in both environments.

## Verified Facts (the research flag, closed)

### 1. The statusline stdin does NOT carry `model_scoped` in Claude Code 2.1.240 — the endpoint is the effective source [VERIFIED: binary `/Users/sv/.local/share/claude/versions/2.1.240`, byte offset ~306296605, function `$y0`]

Verbatim from the installed Mach-O (embedded JS), the statusline payload constructor:

```
DATA_q7Kp2xLm_START
A={...k.five_hour&&{five_hour:{used_percentage:k.five_hour.utilization*100,resets_at:k.five_hour.resets_at}},...k.seven_day&&{seven_day:{used_percentage:k.seven_day.utilization*100,resets_at:k.seven_day.resets_at}}};return{...v_(e,f),...C&&{session_name:C},model:{id:_,display_name:lh(_)},workspace:{current_dir:f,project_dir:e.project.originalCwd,added_dirs:s,...},version:{...VERSION:"2.1.240",...BUILD_TIME:"2026-08-22T05:07:39Z",...},...context_window:Fy0(v,T),exceeds_200k_tokens:r,fast_mode:n,...QM(_)&&{effort:{level:lW(_,m)}},thinking:{enabled:h!==!1},...(A.five_hour||A.seven_day)&&{rate_limits:A},...
DATA_q7Kp2xLm_END
```

Only `five_hour` and `seven_day` are projected; `rate_limits` is omitted entirely when both are absent. The `model_scoped` projection D-48 cites belongs to a **different** payload — the session-usage object (`rpo`, the `claude usage`/`formatRateLimits` path), verbatim:

```
DATA_c3Vn8wRt_START
rate_limits:i===null?null:a!==void 0&&a.length>0?{...i,model_scoped:a}:i,behaviors:s}}var Ufw,gQm=200,NXi=10;var npo=E(()=>{...Ufw=["five_hour","seven_day","seven_day_oauth_apps","seven_day_opus","seven_day_sonnet","cinder_cove","extra_usage","limits"]});
…schema: model_scoped:ft(ye({display_name:H().describe("Server-supplied label for the model bucket (e.g. 'Fable')."),utilization:Je().nullable(),resets_at:H().nullable()})).optional().describe("Per-model weekly windows from the server limits[] array, filtered by the overage-included-models allowlist. Additive — present only when the server emits them.")
DATA_c3Vn8wRt_END
```

The official docs agree: the stdin `rate_limits` table lists only `five_hour`/`seven_day` (`used_percentage` 0–100, `resets_at` Unix epoch seconds), "appears only for Claude.ai subscribers (Pro/Max) after the first API response … Each window … may be independently absent" [CITED: code.claude.com/docs/en/statusline, fetched 2026-08-22].

**If a future Claude Code ever projects `model_scoped` into the statusline payload, its shape and scale are known** [VERIFIED: binary, function `klr` at offset 290369496]:

```
DATA_x9Ht4bQe_START
function klr(e,t){let r=t.map((n)=>n.toLowerCase());if(r.length===0)return[];return(e??[]).filter((n)=>n.kind==="weekly_scoped"&&n.scope?.model&&r.includes(n.scope.model.display_name.toLowerCase())).map((n)=>({title:`Current week (${n.scope?.model?.display_name})`,displayName:n.scope?.model?.display_name??"",limit:{utilization:n.percent,resets_at:n.resets_at}}))}
…a=klr(i.limits,e6e()).map((l)=>({display_name:l.displayName,utilization:l.limit.utilization??null,resets_at:typeof l.limit.resets_at==="number"?new Date(l.limit.resets_at*1000).toISOString():l.limit.resets_at??null}))
DATA_x9Ht4bQe_END
```

i.e. `utilization` **is** the endpoint's `percent` (0–100 integer, no scaling), `resets_at` is an ISO string, and the list is filtered by the remote-config allowlist `tengu_usage_overage_included_models` (`e6e()`), lower-cased display-name match. The stdin probe in Pattern 2 uses exactly `{display_name, utilization (uint 0–100), resets_at (string)}`.

### 2. Live endpoint shape (re-verified 2026-08-22, host Keychain token, 436 ms) [VERIFIED: `curl -s -f --max-time 5 -w '%{http_code}' …` → 200; token never printed]

```
DATA_m2Lr7vYc_START
{"top_keys":["amber_ladder","cinder_cove","extra_usage","five_hour","iguana_necktie","limits","member_dashboard_available","nimbus_quill","omelette_promotional","seven_day","seven_day_cowork","seven_day_oauth_apps","seven_day_omelette","seven_day_opus","seven_day_sonnet","spend","tangelo"],
 "five_hour":{"utilization":4.0,"resets_at":"2026-08-22T21:59:59.939603+00:00","limit_dollars":null,"used_dollars":null,"remaining_dollars":null},
 "seven_day":{"utilization":39.0,"resets_at":"2026-08-24T17:59:59.939628+00:00",...},
 "seven_day_opus":null,"seven_day_sonnet":null,
 "limits":[{"kind":"session","group":"session","percent":4,"severity":"normal","resets_at":"2026-08-22T21:59:59.939603+00:00","scope":null,"is_active":false},
           {"kind":"weekly_all","group":"weekly","percent":39,"severity":"normal","resets_at":"2026-08-24T17:59:59.939628+00:00","scope":null,"is_active":false},
           {"kind":"weekly_scoped","group":"weekly","percent":75,"severity":"warning","resets_at":"2026-08-24T17:59:59.939927+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true}],
 "percent_types":["number","number","number"], "spend":{...,"percent":0,"severity":"normal","enabled":false,...}}
DATA_m2Lr7vYc_END
```

- `percent` is a JSON number (integer-valued) 0–100; `severity` flips `normal`→`warning` (75 % today) — the script ignores it (D-53 uses its own thresholds).
- Header matrix: with all three headers → 200; **without `anthropic-beta`** → 200; **bogus token** → **401**; **no Authorization** → **429** (not 401 — `curl -f` treats both as failure, exit 22) [VERIFIED: four live calls].
- The Fable `resets_at` and the all-models weekly `resets_at` differed by 0.3 ms today (same wall second) — independent fields (D-54).
- Claude Code itself calls this endpoint with a 5 s timeout, `Content-Type: application/json`, and its own OAuth refresh [VERIFIED: binary `t6e`: `fetchUtilization: GET /api/oauth/usage`, `_s.get("/api/oauth/usage",{timeout:5000,headers:{"Content-Type":"application/json"},refreshOAuth:!0,…})`].
- Community corroboration (MEDIUM): ohugonnot/claude-code-statusline — same URL/headers, token from `~/.claude/.credentials.json`, cache `~/.claude/usage-exact.json`, 300 s, `flock`; jtbr gist — macOS `security find-generic-password -s "Claude Code-credentials" -w`, `--max-time 3`, 180 s cache in `/tmp` [CITED: github.com/ohugonnot/claude-code-statusline; gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b].

### 3. Host credentials (macOS) [VERIFIED this session]
- `~/.claude/.credentials.json` **absent**; Keychain generic-password item `"Claude Code-credentials"` present (acct `sv`).
- Item value is JSON: top-level keys `["claudeAiOauth","mcpOAuth"]`; `.claudeAiOauth` keys `["accessToken","expiresAt","rateLimitTier","refreshToken","refreshTokenExpiresAt","scopes","subscriptionType"]`; `expiresAt` is a **13-digit number (epoch milliseconds)**; `subscriptionType` `"max"` [VERIFIED: `jq 'keys'`-only inspection, no values printed].
- `security … -w` took ~21 ms/call and produced **no Keychain prompt** when run from a sandboxed agent shell (same user) — consistent with D-61.

### 4. Sandbox credentials + egress [VERIFIED: `sbx exec statusline-kit-test …`, sbx v0.39.0, Docker Desktop 29.6.2]
- `/home/agent/.claude/.credentials.json` **present**, mode **600**, owner `agent`, keys `["claudeAiOauth"]` → `.claudeAiOauth` keys identical to the host's; `subscriptionType` `max`, `rateLimitTier` `default_claude_max_20x`; `expiresAt` ~6.7 h in the future at probe time. The access token is **26 chars** (host: 108) — it is a proxy-scoped credential: `sbx secret ls` shows a **global service secret `anthropic (oauth configured)`**, the sandbox env has `SBX_CRED_ANTHROPIC_MODE`, and `HTTP(S)_PROXY`/`NO_PROXY` are set; per `sbx secret --help`: "When a sandbox starts, the proxy uses stored secrets to authenticate API requests on behalf of the agent. The secret is never exposed directly."
- **From inside the sandbox, `curl … https://api.anthropic.com/api/oauth/usage` with that file's token → HTTP 200 in 408 ms**, Fable 75 % — the segment will render live in the kit sandbox with no kit change. `curl` honours the proxy env automatically; **never pass `--noproxy`**.
- Blackhole probe inside the sandbox (`http://192.0.2.1/`, `--max-time 1`) returned **rc 22 in 0 s** (the egress proxy answers with an HTTP error immediately) — timeouts are effectively proxy-mediated there; on the host the same probe hit `--max-time` (rc 28, 1 s).
- Tools: curl 8.18.0, bash 5.3.9, jq 1.8.1, GNU `stat`, `mktemp`, `flock`, `python3` present; **`nc` absent**; `security` absent (expected).
- Docker docs: "Sandboxes don't pick up user-level configuration from your host, such as `~/.claude`"; API key via `sbx secret set anthropic` or `/login` inside Claude Code [CITED: docs.docker.com/ai/sandboxes/agents/claude-code/]. Either route ends in the same `~/.claude/.credentials.json`, which is what the script reads — the README note should say exactly that (D-63/D-66).

### 5. What the existing code offers (read this session)
- `kit/files/home/.claude/statusline.sh` (226 lines): palette lines 8–15 (`DIM=$'\033[2m'` line 9); `fmt_duration` lines 38–46; `pct_color` lines 50–54; `join_segments` lines 58–64; `seg_1w` lines 152–159 (template for `seg_fable`); single jq pass lines 181–194 with `def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";` and `strings // ""` guards, `eval "$vars"` line 195; `NOW=$(date +%s)` line 197 (a `local` of `main`, visible to `seg_*` by dynamic scope); line-2 join `body=$(join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)")` **line 210** — append `"$(seg_fable)"`; source guard lines 224–226 (harness sources helpers without running `main`). [VERIFIED: Read]
- `tests/run.sh` (433 lines): `check_eq`/`check_ok`, `strip_ansi`, `ERRTMP` stderr-byte capture, `run_fixture` (95–105), threshold-bytes pattern (§5, 133–140), palette purity (§6), injection/array/non-integer probes (§7, all under `/bin/bash`), latency budget (§9, 10 renders ≤ 2 s, 403–412), shellcheck advisory (§10). **No env is exported today — the Fable path would be live in every render.** [VERIFIED: Read]
- `tests/render-fixtures.sh`: loops `tests/fixtures/*.json` (non-recursive, line 49) and pipes each as stdin; determinism contract in the header. [VERIFIED: Read]
- `tests/sandbox.sh` (269 lines): `sx()` = `sbx exec`; `sx -e VAR=… "$NAME"` passes env into the sandbox (line 192); §5.7 runs `tests/run.sh` in the sandbox; §5.8 runs the render dump with `INSTALLED`/`REQUIRE_INSTALLED`; probes are `check_*` lines routed through `emit` to `tests/out/sandbox/EVIDENCE.txt`. [VERIFIED: Read]
- `kit/spec.yaml`: `setup.install` guard `command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || (apt-get … jq git)` (D-33). [VERIFIED: Read]
- Fixture `tests/fixtures/full.json` uses `resets_at: 0` for deterministic `(now)` countdowns. [VERIFIED: Read]

### 6. Prototype measurements (throwaway script under `/bin/bash` 3.2.57, sourcing the real helpers) [VERIFIED: ran this session]
| Case | Result | Wall (incl. ~19 ms baseline of the probe harness) |
|------|--------|------|
| cold fetch via `file://` fixture | `Fable 74%/1w (1d:22h:20m)`, cache written `-rw-------` `{"fetched_at":…,"pct":74,"resets_at":1787594400}` | 42 ms |
| warm hit with URL pointing at a missing file | same segment (proves no fetch) | 21 ms |
| `fetched_at` −400 s + fetch failing | served from grace | 34 ms |
| `fetched_at` −4000 s + fetch failing | hidden | 38 ms |
| kill switch with fresh cache | hidden | 19 ms |
| endpoint answers without a Fable bucket | hidden, **negative cache written** (`"pct":null`) | 39 ms |
| stdin `FAB_SI_PCT=33`, `FAB_SI_RST=1970-01-01T00:00:00Z` | `Fable 33%/1w (now)`, no network | 20 ms |
| blackhole URL, `--max-time 1` | hidden, **0 stderr bytes**, wall 1 s | 1036 ms |
| hostile cache (`"x[$(touch …)]"`, arrays, `1e100`) / `garbage` | hidden, no injection, no stderr | 32–35 ms |
| live endpoint (host / sandbox) | 200 | 436 ms / 408 ms |
| `jq` process start | — | ~3.7 ms |
| `security … -w` | — | ~21 ms |
| `iso_to_epoch` | — | ~0.35 ms |

## Architecture Patterns

### System Architecture Diagram

```
Claude Code trigger (assistant msg / refreshInterval 60 s / …; 300 ms debounce, in-flight script cancelled)
        │ stdin JSON
        ▼
  [existing single jq pass]  ──▶ MODEL EFFORT DIR CTX_* P5_* P7_*  +  FAB_SI_PCT FAB_SI_RST   (stdin probe, D-48; empty today)
        │
        ▼
  get_fable_weekly  (collector; exports FAB_PCT / FAB_RST or "")
        ├─ STATUSLINE_NO_FABLE set? ───────────────────────────────▶ ""  (no file, no Keychain, no network)
        ├─ FAB_SI_PCT non-empty? ──▶ FAB_PCT=FAB_SI_PCT, FAB_RST=iso_to_epoch(FAB_SI_RST) ▶ done
        ├─ read_cache  ~/.claude/statusline-usage-cache.json  (jq, uint-guarded → C_AT C_PCT C_RST)
        │     NOW-C_AT < 300 ──────────────────────────────────────▶ C_PCT/C_RST (may be the negative "" → hidden)  [no network]
        ├─ get_token: $STATUSLINE_CREDENTIALS_FILE | ~/.claude/.credentials.json ─▶ security -s "Claude Code-credentials" -w ─▶ ""
        │     no token ────────────────────────────────────────────▶ fall to grace check
        ├─ curl -s -f --max-time 2 -K - <headers on stdin> $URL ─▶ body ─▶ jq select weekly_scoped ∧ display_name^fable (first) ─▶ [percent, resets_at ISO]
        │     200 + parseable ──▶ FAB_RST=iso_to_epoch(ISO); write_cache(pct|null, epoch|null) atomically (mktemp 0600 + mv) ▶ done
        │     any failure (rc≠0, 401/429, bad JSON) ──▶ fall through
        └─ C_AT present ∧ NOW-C_AT < 3600 ─▶ serve last-good (stale-while-error)   else ▶ ""
        │
        ▼
  seg_fable ──▶ "" | DIM"Fable"RESET + pct_color(pct)pct%RESET + "/1w" [+ " (" fmt_duration(FAB_RST-NOW) ")"]
        │
        ▼
  LINE2 = join_segments " · " seg_context seg_5h seg_1w seg_fable   (Fable last; hidden parts drop their separator)
```

### Recommended Project Structure (unchanged layout; additions marked +)
```
kit/files/home/.claude/statusline.sh   # + iso_to_epoch (next to fmt_duration), + read_cache/get_token/fetch_usage/write_cache/get_fable_weekly (collector block before main or inside main after eval), + seg_fable (after seg_1w), + 4th arg on the line-2 join, + header comment documenting the env vars
kit/spec.yaml                          # (optional) + curl in the setup.install guard
tests/run.sh                           # + `export STATUSLINE_NO_FABLE=1` near the top; + §11 "Fable weekly" block that unsets it locally and uses the overrides
tests/fixtures/fable-stdin.json        # + stdin fixture with rate_limits.model_scoped (kill switch keeps render-fixtures deterministic)
tests/fixtures/usage/fable.json        # + sanitized endpoint response (CONTEXT <specifics> JSON is safe to reuse)
tests/fixtures/usage/no-bucket.json    # + same minus the weekly_scoped entry
tests/render-fixtures.sh               # + `export STATUSLINE_NO_FABLE=1` (determinism, D-64)
tests/sandbox.sh                       # + §5.x credentials-file presence (test -f, nothing printed) + live Fable render probe (sx -e overrides unset; grep -c 'Fable' on stripped line 2)
README.md                              # + example, legend row, one note (D-66)
.planning/REQUIREMENTS.md, PROJECT.md  # D-52 wording; project-brief.md optional note
```
`tests/fixtures/usage/` is a **sub-directory on purpose**: `render-fixtures.sh` globs `tests/fixtures/*.json` non-recursively, so endpoint fixtures never get piped in as stdin payloads.

### Pattern 1: Stdin probe folded into the single jq pass (D-48, forward-compatible, zero cost) [VERIFIED: ran on jq 1.7.1 with present/absent/hostile payloads]
```jq
# add inside the existing @sh program (statusline.sh lines 181-194), after `def uint`:
( [ .rate_limits.model_scoped? // [] | arrays[]? | objects
    | select((.display_name? // "" | strings // "") | ascii_downcase | startswith("fable")) ]
  | first // {} ) as $ms
| @sh "
  ... existing 10 assignments ...
  FAB_SI_PCT=\($ms.utilization // "" | uint)
  FAB_SI_RST=\($ms.resets_at // "" | strings // "")
"
```
Behaviour verified: field absent (today's reality) → both empty; present → `74` / ISO string; `model_scoped` = string, element = string, array-valued fields, `"x[$(touch …)]"` → all empty, one quoted word each (eval-safe under bash 3.2). Note the `as $ms` binding must come **before** the `@sh` string since `@sh` is applied to the whole program output.

### Pattern 2: Endpoint parse (second jq call, off the stdin choke point) [VERIFIED: same stress set]
```jq
def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
( [ .limits? // [] | arrays[]? | objects
    | select(.kind == "weekly_scoped"
             and ((.scope.model.display_name? // "" | strings // "") | ascii_downcase | startswith("fable"))) ]
  | first // {} ) as $b
| @sh "F_PCT=\($b.percent // "" | uint) F_RST_ISO=\($b.resets_at // "" | strings // "")"
```
Real shape → `F_PCT=74 F_RST_ISO='2026-08-24T18:00:00.097816+00:00'`; no bucket → both `''`; `"FABLE 5"` renamed + an Opus bucket appended → still 74 (prefix, first hit, D-50); `percent` string/array or `limits` non-array → `''`; `percent` 74.9 → 74; non-JSON body → jq exits 5 with **no output** → treat empty `$v` as failure. Invalid `resets_at` (array) → `''` → segment without parens (D-54).

### Pattern 3: Pure-bash ISO-8601 → epoch (bash 3.2, no `date`) [VERIFIED: 17/17 agree with Python `datetime.fromisoformat` under `/bin/bash` 3.2.57; 0.35 ms/call]
```bash
# iso_to_epoch ISO -> epoch seconds, or "" when unparseable (D-54). Accepts
# YYYY-MM-DDTHH:MM:SS[.frac][Z|±HH:MM|±HHMM|<none>=UTC]; days-from-civil
# (Hinnant) in pure arithmetic: proleptic Gregorian, BSD/GNU-neutral.
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
```
Verified table (bash = Python): `2026-08-24T18:00:00.097816+00:00`→1787594400; `…17:59:59.939927+00:00`→1787594399; `2026-08-24T18:00:00Z`→1787594400; `+02:00`→1787587200; `-05:30`→1787614200; `+0200`→1787587200; `2000-02-29T00:00:00Z`→951782400; `1970-01-01T00:00:00Z`→0; `2100-03-01T12:34:56.5Z`→4107587696; `2026-02-28T23:59:59Z`→1772323199; `2028-02-29T00:00:00Z`→1835395200; `2026-12-31T23:59:59Z`→1798761599; `garbage`, `2026-13-01T00:00:00Z`, `""`, date-only `2026-08-24`, `2026-08-24T18:00:00x[$(touch …)]` → `""` (no injection). **Gotcha found while writing it:** a space inside a `case` bracket expression (`[Tt ]`) is a bash 3.2 syntax error — use `[Tt]` only. The `10#` prefix is required so `08`/`09` are not parsed as octal.

### Pattern 4: Token discovery (D-60) and the `-K -` request
```bash
# get_token -> prints the access token or nothing. Explicit STATUSLINE_CREDENTIALS_FILE
# means "this file only" (no Keychain fallback) so tests are deterministic on macOS.
get_token() {
  local f=${STATUSLINE_CREDENTIALS_FILE:-} t
  if [ -n "$f" ]; then
    jq -r '.claudeAiOauth.accessToken // empty | strings' "$f" 2>/dev/null; return 0
  fi
  t=$(jq -r '.claudeAiOauth.accessToken // empty | strings' "$HOME/.claude/.credentials.json" 2>/dev/null)
  if [ -z "$t" ] && command -v security >/dev/null 2>&1; then
    t=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty | strings' 2>/dev/null)
  fi
  printf '%s' "$t"
}
# fetch: headers via curl's config-on-stdin so the token never enters argv (ps-visible);
# printf is a bash builtin, so no process ever carries the token as an argument.
body=$(printf 'header = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\nheader = "Content-Type: application/json"\n' "$tok" \
       | curl -s -f --max-time "${STATUSLINE_CURL_MAX_TIME:-2}" -K - "${STATUSLINE_USAGE_URL:-https://api.anthropic.com/api/oauth/usage}" 2>/dev/null) || fail
```
`-f` turns 401/429/5xx into exit 22 with an empty body, so a bad token never reaches the cache. Optional cheap pre-check (discretion): if `.claudeAiOauth.expiresAt` (epoch **ms**) `/ 1000 ≤ NOW`, treat as no token and skip the network — consistent with D-62 and saves a guaranteed-401 round trip while Claude Code has not yet refreshed.

### Pattern 5: Cache file (D-56/57/58) — embedded `fetched_at`, atomic, 0600
```bash
FAB_CACHE=${STATUSLINE_USAGE_CACHE:-$HOME/.claude/statusline-usage-cache.json}
# format: {"fetched_at":<epoch>,"pct":<0-100|null>,"resets_at":<epoch|null>}  (null = negative result, D-49)
read_cache() {   # -> C_AT C_PCT C_RST ("" when unusable)
  local v; C_AT=""; C_PCT=""; C_RST=""
  [ -r "$FAB_CACHE" ] || return 0
  v=$(jq -r 'def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
             @sh "C_AT=\(.fetched_at // "" | uint) C_PCT=\(.pct // "" | uint) C_RST=\(.resets_at // "" | uint)"' "$FAB_CACHE" 2>/dev/null)
  eval "$v"                                        # empty on non-JSON -> all stay ""
}
write_cache() {  # write_cache PCT RST  (either may be empty -> null)
  local tmp; mkdir -p "${FAB_CACHE%/*}" 2>/dev/null
  tmp=$(mktemp "${FAB_CACHE%/*}/.usage.XXXXXX" 2>/dev/null) || return 1     # 0600 on BSD and GNU
  printf '{"fetched_at":%s,"pct":%s,"resets_at":%s}\n' "$NOW" "${1:-null}" "${2:-null}" > "$tmp" \
    && mv -f "$tmp" "$FAB_CACHE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}
```
Fetch into a variable **first**, then `mktemp`/`printf`/`mv` — the temp file lives for microseconds, so a render cancelled mid-curl by Claude Code leaves no orphan. `mv` over a symlink replaces the link, not its target. Constants: `FAB_TTL=300`, `FAB_GRACE=3600`.

### Pattern 6: Collector control flow (D-48/55/58/59/64) — prototyped
```bash
get_fable_weekly() {   # exports FAB_PCT / FAB_RST (epoch) or ""
  FAB_PCT=""; FAB_RST=""
  [ -n "${STATUSLINE_NO_FABLE:-}" ] && return 0                         # D-64: nothing else runs
  if [ -n "$FAB_SI_PCT" ]; then                                          # D-48: stdin first
    FAB_PCT=$FAB_SI_PCT; FAB_RST=$(iso_to_epoch "$FAB_SI_RST"); return 0
  fi
  read_cache
  if [ -n "$C_AT" ] && [ $(( NOW - C_AT )) -lt "$FAB_TTL" ]; then        # fresh (incl. negative) -> no network
    FAB_PCT=$C_PCT; FAB_RST=$C_RST; return 0
  fi
  if fetch_usage; then                                                   # sets F_PCT / F_RST_ISO; "" = no bucket
    FAB_PCT=$F_PCT; FAB_RST=$(iso_to_epoch "$F_RST_ISO")
    write_cache "$FAB_PCT" "$FAB_RST"; return 0                          # negative result cached too (D-49 + SC4)
  fi
  if [ -n "$C_AT" ] && [ $(( NOW - C_AT )) -lt "$FAB_GRACE" ]; then      # D-58 stale-while-error
    FAB_PCT=$C_PCT; FAB_RST=$C_RST
  fi
}
seg_fable() {          # D-51/53/54/55 — seg_1w shape with a dim literal label
  [ -n "$FAB_PCT" ] || return 0
  local pct=${FAB_PCT%.*} out
  out="${DIM}Fable${RESET} $(pct_color "$pct")${pct}%${RESET}/1w"
  [ -n "$FAB_RST" ] && out="${out} ($(fmt_duration $(( FAB_RST - NOW ))))"
  printf '%s' "$out"
}
# main: body=$(join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)" "$(seg_fable)")
```
`get_fable_weekly` must run **after** `eval "$vars"` and `NOW=$(date +%s)` and **before** the line-2 join; because `seg_*` run in command substitutions, the collector must set `FAB_PCT/FAB_RST` in the main shell (call it directly, not inside `$(…)`).

### Anti-Patterns to Avoid
- **Running the Fable path in tests without the kill switch** — every `run_fixture`/render-dump call would read the host Keychain and perform a real fetch (cold) → 0.4–2 s per render, prompts in CI, network in the agent sandbox. `export STATUSLINE_NO_FABLE=1` at the top of `tests/run.sh` and `tests/render-fixtures.sh`; the Fable block in run.sh runs its probes with `STATUSLINE_NO_FABLE=` (empty) **and** `STATUSLINE_USAGE_URL=file://…`, `STATUSLINE_CREDENTIALS_FILE=…`, `STATUSLINE_USAGE_CACHE=$TESTTMP/…` set per command.
- **Not caching the "no bucket" answer** — plans without Fable would fetch on every render (SC4 violation).
- **Token in argv** (`-H "Authorization: Bearer $TOK"`) — visible in `ps`; use `-K -`.
- **`flock`, `timeout`, `stat -c` alone, `date -d/-j`, `nc`** — missing or divergent on one side (`flock`/`timeout` absent on macOS; `nc` absent in the sandbox).
- **Cache in `/tmp` with a predictable name** (jtbr gist does this) — world-readable account data; use `~/.claude/`, 0600.
- **`--noproxy`/`--proxy ''`** — breaks the sandbox, whose egress and auth injection go through `HTTPS_PROXY`.
- **Branching on `uname`** — D-60 forbids; the ordered lookup covers both.
- **Letting the countdown use the all-models `seven_day.resets_at`** — D-54 requires the Fable bucket's own value.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ISO-8601 → epoch | Month-length tables + leap-year if-chains | The days-from-civil helper in Pattern 3 (already verified on leap days, century boundary, offsets) | Off-by-one on leap years / offsets is the classic bug; the verified helper is 30 lines |
| JSON field extraction / type guarding | `grep -o '"percent":[0-9]*'` / sed on the body | jq with the existing `uint`/`strings`/`arrays`/`objects` guards (Patterns 1–2) | Regex scraping breaks on key order, whitespace and nested `scope`; the guards are what keep `eval` safe |
| Atomic, private cache write | `echo > "$CACHE"` + `chmod` | `mktemp` template + `mv -f` | `mktemp` is 0600 on both platforms; `mv` is atomic within a filesystem; no torn reads |
| HTTP failure classification | Parsing status codes / bodies | `curl -f` + exit code only | 401/429/5xx/timeouts all collapse to "hidden"; the script never needs the reason |
| Token refresh | OAuth refresh flow with `refreshToken` | Nothing — read-only; hide on 401 (D-62) | Racing Claude Code's own refresh can invalidate the session (STACK.md / CLAUDE.md) |
| Cross-process locking | `flock`/lock dirs | Nothing — last writer wins, both writes are valid JSON | `flock` absent on macOS; the race costs at most one duplicate fetch per TTL |

**Key insight:** every moving part here already has a verified, portable one-liner; complexity only creeps in when someone tries to be clever about *why* a fetch failed. The contract is binary: value or hidden.

## Common Pitfalls

### Pitfall 1: Harness/dumper renders go live
**What goes wrong:** `tests/run.sh` §3–§9 and `tests/render-fixtures.sh` run the script with the host's real `$HOME` and env → Keychain read + network on cold cache (up to 2 s each, ×100+ renders), and the host `~/.claude/statusline-usage-cache.json` gets written by a test. Inside the agent's dev sandbox the network is blocked (fails fast, still wrong).
**How to avoid:** `export STATUSLINE_NO_FABLE=1` at the top of both scripts; the Fable block overrides per command; cache path override always points into `$TESTTMP`. Add a probe that proves the kill switch bites: with it set and a fresh fixture cache, line 2 must not contain `Fable`.
**Warning signs:** harness wall time jumps by seconds; a cache file appears under the real `~/.claude/` during tests.

### Pitfall 2: Negative results not cached (SC4)
**What goes wrong:** Endpoint returns 200 without a Fable bucket → nothing written → next render fetches again → one network call per render.
**How to avoid:** `write_cache "" ""` (→ `pct:null`) on any successful parse; `read_cache` then yields a fresh-but-empty hit → hidden, no network (prototype case 6).

### Pitfall 3: Render cancelled mid-fetch
**What goes wrong:** A cold/stale render takes ~0.45 s (live) — above the 300 ms debounce; if a new trigger arrives, Claude Code cancels the script, the old line stays, and the cache is not written, so the next render fetches again. During rapid message bursts this can repeat.
**How to avoid:** Accepted by D-59 (bounded); keep `--max-time 2`; fetch-then-write so no temp file orphans; the idle `refreshInterval 60` render will complete the write within a minute at the latest. Do **not** add background fetches (out of scope).
**Warning signs:** `Fable` segment appears only after the session goes idle.

### Pitfall 4: Keychain prompt / locked keychain on macOS
**What goes wrong:** If the Keychain item's ACL does not include `/usr/bin/security` (not the case for Claude Code's item — no prompt observed this session), a GUI dialog appears once per `security` call; on a headless/ssh session with a locked keychain `security` fails (non-zero) rather than hangs [ASSUMED].
**How to avoid:** D-61 — README says click "Always Allow" once; the script already hides on a non-zero `security`. No `timeout` exists on macOS, so don't plan one.

### Pitfall 5: Bash 3.2 syntax traps in the new code
**What goes wrong:** `[Tt ]` in a `case` pattern (space in brackets) is a syntax error; `${s:19}` with an empty `$s`… fine, but `$(( 08 ))` is an octal error → always `10#`; `local` inside `if` at top level is fine but `declare -g` is not. `printf '%s' "$(( … ))"` with a negative result is fine for `fmt_duration` (returns `now`).
**How to avoid:** `/bin/bash -n` gate already in run.sh §1; run all new probes under `/bin/bash` (harness discipline).

### Pitfall 6: `curl` behaviours that differ by environment
**What goes wrong:** In the sandbox a blackhole URL fails in 0 s via the proxy (rc 22); on the host it waits for `--max-time` (rc 28). A timeout probe asserting "wall ≥ 1 s" would fail in the sandbox; asserting "wall ≤ max-time + 1 and hidden and 0 stderr bytes" passes in both.
**How to avoid:** assert the upper bound only; never assert the exact curl rc.

### Pitfall 7: Fixture sanitation and file placement
**What goes wrong:** A real response pasted into `tests/fixtures/*.json` gets rendered as a stdin payload by `render-fixtures.sh` (non-recursive glob), and may carry account identifiers.
**How to avoid:** put endpoint fixtures in `tests/fixtures/usage/`; use the CONTEXT `<specifics>` JSON (numbers only, no IDs); the stdin fixture `fable-stdin.json` may live in `tests/fixtures/` because the exported kill switch makes its dump deterministic.

### Pitfall 8: Sandbox token is short/proxied — don't "validate" it
**What goes wrong:** A length or prefix check on the token (e.g. expecting `sk-ant-oat…`) would reject the sandbox's 26-char proxy credential, which works (200).
**How to avoid:** treat any non-empty string as a token; let `-f` decide.

## Testability Plan (D-65, every probe must bite)

Harness block (`tests/run.sh` new §11, all under `/bin/bash`, all with `STATUSLINE_NO_FABLE=` `STATUSLINE_USAGE_CACHE=$TESTTMP/usage.json` `STATUSLINE_CREDENTIALS_FILE=$TESTTMP/creds.json` (`{"claudeAiOauth":{"accessToken":"test-token","expiresAt":9999999999999}}`) unless stated):

| Probe | Setup | Assert | Bites because |
|-------|-------|--------|---------------|
| `iso_to_epoch` table | source helpers | the 17-row table from Pattern 3 | wrong arithmetic/offset sign |
| cold render via `file://` | URL=`file://$PWD/tests/fixtures/usage/fable.json` (resets_at in the fixture set to `1970-01-01T00:00:00Z` → `(now)`), stdin `full.json` | line 2 == `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 74%/1w (now)`; cache file exists, mode `-rw-------` (`ls -l` first 10 chars — portable) | join order / label / parens |
| colour bytes | same, pct 74 → `${ESC}[33m74%${ESC}[0m/1w`, label `${ESC}[2mFable${ESC}[0m ` | raw substring match (run.sh §5 pattern); 69/70/89/90 via fixture edits with `jq` | threshold on number only (D-53) |
| palette purity | raw render | only `0m 2m 31m…36m` (§6 pattern) | stray SGR |
| cache hit | second render with URL=`file:///nonexistent` | still `Fable 74%…` | fetch happened |
| stale-grace serve | `jq '.fetched_at -= 400'` on the cache, URL missing | still rendered | grace ignored |
| past grace hide | `.fetched_at -= 4000` | no `Fable`, 0 stderr | never hides |
| no bucket | URL=`…/usage/no-bucket.json`, empty cache | no `Fable`; cache has `"pct":null`; second render with URL missing still hidden **and** no fetch (cache untouched: compare file bytes) | negative cache missing |
| no credentials | `STATUSLINE_CREDENTIALS_FILE=$TESTTMP/none.json` (absent), URL=fixture | hidden, no cache written | Keychain fallback leaked into the override |
| kill switch | fresh cache + `STATUSLINE_NO_FABLE=1` | hidden | switch ignored |
| stdin first | `fable-stdin.json` (model_scoped Fable 33, `1970-01-01T00:00:00Z`), URL missing, no creds | `… · Fable 33%/1w (now)` | stdin probe broken |
| stdin hostile | model_scoped string / arrays / `x[$(touch tests/.pwned)]` (§7.4 discipline) | exit 0, no `.pwned`, hidden | guard regression |
| hostile cache | write `garbage` / the injected JSON from prototype case 10 | hidden, 0 stderr, no `.pwned` | cache trusted blindly |
| timeout/offline | URL=`http://192.0.2.1/`, `STATUSLINE_CURL_MAX_TIME=1`, empty cache | exit 0, hidden, 0 stderr, wall ≤ 3 s (whole-second `date +%s`) | curl blocks / errors leak |
| Fable alone on line 2 | `no-rate-limits.json` stdin + fixture URL | `10%/100k/1M · Fable 74%/1w (now)` | peer-segment rule (D-55) |
| latency (§9 unchanged) | kill switch exported | budget holds | regression elsewhere |

`tests/sandbox.sh` additions (D-63): `sx "$NAME" test -f /home/agent/.claude/.credentials.json` → `INFO credentials file: present|absent` (never cat it); then a live render `sx -e STATUSLINE_NO_FABLE= "$NAME" /bin/bash -c 'jq … full.json | /bin/bash /home/agent/.claude/statusline.sh'` piped through `strip_ansi`; `check_ok` "Fable segment renders in sandbox when credentials file present" only when present, else `INFO … hidden is the correct outcome` (as verified today: present → expect PASS). Record the elapsed ms as INFO.

## Docs Reconciliation (D-52/D-66) — exact targets [VERIFIED: grep this session]

| File | Line(s) | Current text | Change |
|------|---------|--------------|--------|
| `.planning/REQUIREMENTS.md` | 39 | `FAB-01: … as f(pct) inside the weekly segment (e.g. 15%/1w f(60%))` | `… as a separate Fable pct/1w (countdown) segment rendered last on line 2 (e.g. … · Fable 74%/1w (2d:4h:30m))` |
| `.planning/PROJECT.md` | 15, 22, 39, 48, 59, 89 | Target layout `usage_pct/1w f(usage_pct) (when_reset)`, example `15%/1w f(60%) (3d:5h:57m)`, segment definition line 39, checklist lines 48/59, decision row 89 | move `f()` out of the weekly segment into `· Fable pct/1w (reset)` last; keep the Key Decision about the adapter seam |
| `README.md` | "What it shows" block, legend table, install notes | no Fable | add `· Fable 74%/1w (2d:4h:30m)` to the example; legend row; one note (token sources, `STATUSLINE_NO_FABLE`, one-time Keychain prompt, sandbox: renders when `~/.claude/.credentials.json` exists — it does in sbx sandboxes with the anthropic secret or after `/login`) |
| `project-brief.md` | 10, 25, 31 | historical `f()` form | optional one-line "layout correction (Phase 4)" note — discretion |
| `.planning/ROADMAP.md` | Phase 4 goal + SC1 | `f(pct)` wording | not in D-52's list; CONTEXT says treat SC1 as "weekly segment followed by the Fable segment" — leave, or one-line note via the phase edit command (planner's call) |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-model weekly under `seven_day_opus`/`seven_day_sonnet` top-level keys | `limits[]` entries with `kind: "weekly_scoped"` + `scope.model.display_name`; legacy keys `null` | observed live 2026-08-22 (Claude Code 2.1.240 also reads `limits[]` via `klr`) | match by display-name prefix inside `limits[]` (D-47/D-50); never read `seven_day_opus` |
| `utilization` 0–1 internal, ×100 for stdin | endpoint top-level `utilization` **and** `limits[].percent` are already 0–100 | verified live | no scaling (D-47) |
| stdin projects only `five_hour`/`seven_day` (2.1.238) | **still only those two in 2.1.240**; `model_scoped` exists only in the usage-command payload | binary inspection 2026-08-22 | endpoint is the source; stdin probe is forward-compat |
| Token only in `~/.claude/.credentials.json` | macOS host stores it in Keychain `"Claude Code-credentials"`; sandbox still uses the file (seeded by sbx's anthropic secret / `/login`) | verified host + sandbox | ordered lookup (D-60) |
| Cache in `/tmp` (jtbr) | `~/.claude/`, 0600, atomic | project decision | no world-readable account data |

**Deprecated/outdated:** `seven_day_opus` / `seven_day_sonnet` (null on this account); STACK.md's "session-keyed temp file" prescription for this cache (superseded by D-57 per-user file).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `settings.json` `env` entries (e.g. `STATUSLINE_NO_FABLE`) are inherited by the statusline subprocess | D-64 note / README | Kill switch would have to be set in the shell profile instead — README wording only |
| A2 | On a headless/locked-keychain macOS session `security … -w` fails fast instead of hanging | Pitfall 4 | A hung render on ssh sessions; no portable `timeout` — would need a documented caveat |
| A3 | The `anthropic-beta: oauth-2025-04-20` header remains harmless/ignored (200 with and without it today) | Verified Facts 2 | None today; keep sending it (matches Claude Code + community) |
| A4 | Future stdin `model_scoped` (if ever projected into the statusline payload) keeps `{display_name, utilization 0–100, resets_at ISO}` as in `klr`/`rpo` | Pattern 1 | Stdin branch would mis-scale or miss; endpoint fallback still works because stdin values would be empty → re-verify when Claude Code changes |
| A5 | Concurrent renders racing on the fetch (N sessions, same TTL edge) are benign — last `mv` wins, at most N duplicate fetches once per TTL | Pattern 5 | Slightly more calls than "1 per TTL per machine" at the edge; no correctness issue |

## Open Questions (RESOLVED)

1. **Cache-path location when `$HOME/.claude` is missing** — `mkdir -p` it, or hide? Recommendation: `mkdir -p` (0755 default; file is 0600 anyway) — Claude Code creates the directory before any statusline runs, so this is theoretical. **RESOLVED: `mkdir -p` adopted** — `write_cache` runs `mkdir -p "${FAB_CACHE%/*}" 2>/dev/null` before the `mktemp` template (04-01-PLAN.md Task 1, step 3 `write_cache`); the file itself stays 0600 via `mktemp` + `mv -f`.
2. **Should the `expiresAt` pre-check be included?** It saves a guaranteed-401 round trip between token expiry and Claude Code's refresh (expiry observed ~6.7–7.8 h out on both hosts). Recommendation: include — 1 jq field, zero risk; hide on expiry is consistent with D-62. **RESOLVED: included** — `get_token`'s single guarded jq program prints the token only when `.claudeAiOauth.expiresAt` (if numeric, epoch ms) / 1000 is still greater than `$NOW`; a missing or non-numeric `expiresAt` never blocks (04-01-PLAN.md Task 1, step 3 `get_token`); pinned by the harness probes `fable: expired token hidden` / `fable: expired token no cache` (04-02-PLAN.md Task 1, step 4).
3. **ROADMAP SC1 wording** — D-52 lists REQUIREMENTS/PROJECT/README only; planner decides whether to touch ROADMAP. **RESOLVED: ROADMAP is reconciled too** — the Phase 4 goal and success criteria 1-3 are reworded to the D-51 separate-segment form and a criterion 5 records the layout correction, via scoped edits to the Phase 4 block only (04-04-PLAN.md Task 2, per D-52; the plan list is left to the orchestrator).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash 3.2 (host `/bin/bash`) | script + harness | ✓ | 3.2.57 | — |
| bash (sandbox) | script + harness | ✓ | 5.3.9 | — |
| jq | all parsing | ✓ / ✓ | 1.7.1 / 1.8.1 | — |
| curl | fetch | ✓ / ✓ | 8.7.1 / 8.18.0 (`file`, `https` protocols) | hide segment if absent (`command -v curl` guard) |
| `security` + Keychain item `"Claude Code-credentials"` | host token | ✓ | macOS built-in | — (sandbox has no `security`; file path used there) |
| `~/.claude/.credentials.json` | sandbox token | ✗ host / ✓ sandbox (0600, `claudeAiOauth`) | — | hidden when absent (D-63) |
| Network to `api.anthropic.com` | live fetch | ✓ host (436 ms) / ✓ sandbox via `HTTPS_PROXY` (408 ms) / **✗ inside this agent's dev sandbox** (blocked; use `dangerouslyDisableSandbox` only for explicit live checks) | — | cache/grace/hidden |
| Docker Desktop + sbx | `tests/sandbox.sh` | ✓ (sandboxd reachable; `statusline-kit-test` running) | sbx v0.39.0, Docker 29.6.2 | checkpoint:human-action if sandboxd down (Phase 3 pattern) |
| `mktemp`, `mv`, `date +%s`, `ls -l` | cache + tests | ✓ / ✓ | BSD / GNU | — |
| python3 | research verification only | ✓ host 3.14.7 / ✓ sandbox | — | not needed by tests |
| shellcheck | advisory | ✓ host | 0.11.0 | skipped in sandbox |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none blocking (hide-on-missing covers every optional piece).

## Validation Architecture

Skipped: `.planning/config.json` sets `workflow.nyquist_validation: false`. The phase's test obligations come from D-65 and the Phase 2 "probe must bite" convention — see **Testability Plan** above (the harness is `tests/run.sh`, quick run = `/bin/bash tests/run.sh`, sandbox proof = `/bin/bash tests/sandbox.sh`).

## Security Domain

`security_enforcement: true`, ASVS level 1.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (bearer token use) | Read-only token from OS store; never refreshed, never printed, never in argv (`-K -`), never cached; hide on 401/429 |
| V3 Session Management | no | — |
| V4 Access Control | yes (local file perms) | Cache 0600 via `mktemp`; `~/.claude/` not `/tmp`; read credentials file only when a fetch is needed |
| V5 Input Validation | yes | jq type guards (`uint`/`strings`/`arrays`/`objects`) on stdin `model_scoped`, endpoint body, cache file; `@sh` + `eval` single-word invariant; `iso_to_epoch` pattern-gated; every `$(( ))` sink fed only by guarded values (prototype cases 10, stdin-hostile) |
| V6 Cryptography | yes (TLS) | curl default certificate verification; never `-k`/`--insecure`; HTTPS URL default; env URL override is a developer knob (document that a malicious env could redirect the token — same trust level as the user's shell) |
| V7 Error Handling/Logging | yes | `2>/dev/null` on every new call; no token/body in any output; exit 0 always |
| V8 Data Protection | yes | Cache holds only `fetched_at/pct/resets_at`; no account IDs; fixtures sanitized |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token in process list (`ps`) during curl | Information disclosure | `curl -K -` with headers from a builtin `printf` pipe |
| Token leaked to stdout/stderr/evidence files | Information disclosure | never echo; harness/sandbox probes print presence (`test -f`) and lengths at most — prefer nothing |
| Hostile/changed endpoint body reaching `eval`/arithmetic | Tampering / Elevation | jq guards + `@sh`; non-JSON → empty `$v` → failure path |
| Torn/symlinked cache file | Tampering | `mktemp`+`mv -f` atomic; `mv` replaces a symlink rather than following it; parse guards |
| World-readable usage data | Information disclosure | `~/.claude/…` 0600 (D-57) |
| Env-override exfiltration (`STATUSLINE_USAGE_URL=https://evil/`) | Spoofing | Same trust boundary as the user's shell/settings.json; documented as a test knob only; no remote/config-file source for it |
| Blocking network in render path | Denial of service (UX) | `--max-time 2`, cache, grace, kill switch |
| Sandbox proxy bypass | Tampering | never `--noproxy`; rely on platform `HTTPS_PROXY` |

## Sources

### Primary (HIGH confidence — tool-verified this session)
- Installed Claude Code binary `/Users/sv/.local/share/claude/versions/2.1.240` (Mach-O, BUILD_TIME 2026-08-22T05:07:39Z): statusline payload constructor (`$y0`, offset ~306296605), usage payload `rpo` + `model_scoped` schema (offsets 287445515 / 300369275), `klr` (290369496), `t6e` fetchUtilization — byte-offset dumps, quoted verbatim above.
- Live `GET https://api.anthropic.com/api/oauth/usage` from host (Keychain token) and from the Docker Sandbox (credentials file) — status/timing/header matrix; structure only, tokens never printed.
- Host probes: bash 3.2.57, jq 1.7.1, curl 8.7.1 (protocols incl. `file`), `security` item metadata/keys/timing/exit 44, `mktemp` mode 0600, `~/.claude/.credentials.json` absent, settings `statusLine` with `refreshInterval 60`.
- Sandbox probes (`sbx exec statusline-kit-test`): credentials file present 0600 `agent`, token length 26, `SBX_CRED_ANTHROPIC_MODE`, proxy env, curl 8.18/bash 5.3.9/jq 1.8.1, `nc` absent, `flock`/python3 present, `sbx secret ls` → global `anthropic (oauth configured)`.
- Prototype runs under `/bin/bash` 3.2.57: `iso_to_epoch` 17-case table vs Python; jq programs (stdin probe, endpoint parse, cache parse) against real and hostile inputs; full adapter flow (10 cases) incl. timings.
- Repo files read in full: `kit/files/home/.claude/statusline.sh`, `tests/run.sh`, `tests/sandbox.sh`, `tests/render-fixtures.sh`, `tests/fixtures/full.json`, `kit/spec.yaml`, `README.md`, `04-CONTEXT.md`, `04-DISCUSSION-LOG.md`, `REQUIREMENTS.md`, `STATE.md`, `.planning/config.json`; grep-located lines in `PROJECT.md`, `project-brief.md`, `ROADMAP.md`; research docs `STACK.md`/`PITFALLS.md`/`ARCHITECTURE.md` (relevant sections), Phase 3 summaries/UAT/EVIDENCE.

### Secondary (MEDIUM confidence)
- https://code.claude.com/docs/en/statusline (fetched 2026-08-22) — stdin schema (`rate_limits` only `five_hour`/`seven_day`), caching/`stat` guidance, `refreshInterval`, never-block notes.
- https://docs.docker.com/ai/sandboxes/agents/claude-code/ — host `~/.claude` not imported; API key via `sbx secret`; `/login` inside.
- https://github.com/ohugonnot/claude-code-statusline, https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b — community endpoint/token/cache patterns (corroborating only).

### Tertiary (LOW confidence)
- None relied upon.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every tool/version measured on both targets.
- Data source / endpoint shape: HIGH — binary + two live probes today; the endpoint remains undocumented, so re-verify at execution time (cheap: one curl).
- Architecture / control flow: HIGH — prototyped end-to-end under bash 3.2 with the repo's own helpers.
- Pitfalls: HIGH for the harness kill-switch and negative-cache items (observed), MEDIUM for Keychain/headless behaviour (A2).

**Research date:** 2026-08-22
**Valid until:** ~30 days for the code patterns; the endpoint shape should be re-checked whenever Claude Code or the `/usage` UI changes (7-day horizon for that single fact).
