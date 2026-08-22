# Phase 4: Fable Weekly f() Segment - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 adds the Fable-specific weekly usage to line 2 as a **separate, last segment** — `Fable 74%/1w (2d:4h:30m)` — sourced from the Claude Code OAuth usage data (stdin field if the installed Claude Code emits one, otherwise `GET https://api.anthropic.com/api/oauth/usage` with the Claude Code OAuth token discovered from `~/.claude/.credentials.json` or the macOS Keychain), cached in a per-user file with a TTL, fetched with a short curl timeout, and hidden on any failure so the rest of the line never changes or slows. It updates the README (example, legend, one note) and extends the harness + sandbox probe. Requirements: FAB-01, FAB-02, FAB-03, FAB-04 (FAB-01's "inside the weekly segment" wording is superseded by D-51 below — see reconciliation D-52). Excludes: any other model-scoped bucket (Opus/Sonnet), usage-credits/spend display, background daemons, token refresh.

</domain>

<decisions>
## Implementation Decisions

### Which number the segment shows
- **D-47:** The segment always shows the **Fable** weekly bucket, regardless of the model in use. Verified live on 2026-08-22 against the user's account: the bucket lives **only** in the endpoint's `limits[]` array as `{kind: "weekly_scoped", group: "weekly", percent: 74, severity, resets_at: "2026-08-24T18:00:00.097816+00:00", scope: {model: {id: null, display_name: "Fable"}, surface: null}, is_active: true}`; the legacy keys `seven_day_opus` / `seven_day_sonnet` were **null**. `percent` is already an integer 0–100 (top-level `seven_day.utilization` is also 0–100, e.g. `39.0`) — the 0–1 vs 0–100 question is settled: **no scaling**.
- **D-48:** Data-source priority: **stdin first, endpoint fallback**, behind the adapter seam so `seg_*` rendering never knows the source. The installed Claude Code 2.1.240 binary contains a `rate_limits.model_scoped[] = [{display_name, utilization, resets_at (ISO string)}]` projection ("Per-model weekly windows from the server limits[] array … present only when the server emits them"); the researcher must verify whether that reaches the **statusline stdin** (2.1.238 projected only `five_hour`+`seven_day`). If present → use it (no network, no credentials); if absent → OAuth endpoint.
- **D-49:** Endpoint answers but no Fable bucket (plan without Fable, bucket moved to usage credits, schema reshuffle) → **segment hidden**. No proxy via `extra_usage`/`spend`.
- **D-50:** Bucket matching: `scope.model.display_name` (endpoint) / `display_name` (stdin) **case-insensitively starts with `fable`**, **first hit in server order** — survives renames like "Fable 5" without code changes. No exact-name knob.

### Layout & rendering (supersedes the brief's `f()` placement)
- **D-51:** The Fable datum is a **full peer segment on line 2, rendered last**, joined with the standard dim ` · ` like every other segment: `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)`. User's words: *"let's make f() as a separate segment with its own countdown similar to 1w: 'Fable 30%/1w (2d:4h:30m)' and let's put it last, after 1w limit."* This **supersedes** `project-brief.md` / PROJECT.md's `15%/1w f(60%) (…)` in-segment form. — **Reversibility:** reversible — one segment function and one join call; but README/PROJECT/REQUIREMENTS text must move with it.
- **D-52:** Reconcile the planning docs with D-51 in this phase: REQUIREMENTS.md FAB-01 wording (`f(pct)` inside the weekly segment → separate `Fable pct/1w (countdown)` segment last on line 2), PROJECT.md "Target Layout" + segment definitions, README example/legend. `project-brief.md` stays as the historical brief (add a one-line "layout correction" note like the Phase 2 frame note, or leave untouched — Claude's discretion).
- **D-53:** Styling: label is the **literal word `Fable`, rendered dim** (SGR 2, like the effort label); the percentage number gets `pct_color` thresholds **on the number only** (D-03/D-04/D-05, integer-truncated per D-07); `/1w` and the countdown plain. ANSI-16 only (D-02).
- **D-54:** The segment carries **its own countdown** from the Fable bucket's `resets_at` via `fmt_duration` (same `now`/`<1m`/`d:h:m` rules, D-09/D-10). When `resets_at` is missing or unparseable → render `Fable 74%/1w` with no parens. Note: the endpoint (and the binary's `model_scoped` projection) deliver `resets_at` as an **ISO-8601 string** (`2026-08-24T18:00:00.097816+00:00`), not epoch — the script needs a **pure-bash, bash-3.2, BSD/GNU-neutral ISO→epoch conversion** (no `date -d`, no `date -j`); technique is Claude's discretion. Live on 2026-08-22 the Fable and all-models weekly resets coincided to the second, but they are independent fields and may drift — always use the Fable bucket's own value.
- **D-55:** Hidden entirely (with its separator) whenever there is no Fable value; it renders **even if the stdin 1w segment is absent** (it is a peer, not a sub-segment). Hidden = kill switch set, no credentials, fetch failure past the grace window, no bucket, parse failure.

### Cache & freshness (FAB-03)
- **D-56:** Cache TTL **300 s** — weekly usage moves slowly; one call per 5 min per machine is gentle on an undocumented endpoint; up to 5 min lag is invisible at weekly scale.
- **D-57:** **One shared per-user cache file** (usage is account-level; N sessions → 1 fetch per TTL), e.g. `~/.claude/statusline-usage-cache.json` (name/location at discretion; **not** a predictable world-readable `/tmp` path), created **0600**, written **atomically (tmp + mv)** so concurrent renders never read a torn file. Never keyed by `$$`.
- **D-58:** **Stale-while-error, bounded:** if the cache is past TTL and the refresh fails (offline, timeout, 401/403, schema change), keep serving the last-good value up to a grace window (~1 h since it was fetched; exact value discretion), then hide. Retry on every render after TTL while failing, each bounded by the curl timeout — no backoff state required.
- **D-59:** **Cold start waits, bounded:** with no cache, the render performs one synchronous `curl --max-time ~2` (exact value discretion, must stay well under what a user perceives as a stall) so the segment appears on the first online render; no background processes, no detached fetches (REQUIREMENTS out-of-scope).

### Credentials (FAB-02)
- **D-60:** Token lookup order, one ordered list for both environments (no `uname` branch): (1) `~/.claude/.credentials.json` → `.claudeAiOauth.accessToken`; (2) if absent/unreadable and `command -v security` succeeds: `security find-generic-password -s "Claude Code-credentials" -w` → `.claudeAiOauth.accessToken`; (3) else no token → hidden. Read the token only when a fetch is actually needed (cache stale) — cheap renders touch neither store.
- **D-61:** macOS Keychain access dialog: **accept a one-time prompt**. Claude Code writes the item through the same `security` CLI, so none is expected; if one appears the user clicks "Always Allow" once and the README says so. No extra machinery.
- **D-62:** Expired/rejected token → hidden; the script **never refreshes the token** and **never prints it** (carried from STACK.md / PITFALLS.md). Live-verified request headers that worked 2026-08-22: `Authorization: Bearer <token>`, `anthropic-beta: oauth-2025-04-20`, `Content-Type: application/json`.
- **D-63:** Sandbox: `tests/sandbox.sh` gains a probe — does `/home/agent/.claude/.credentials.json` exist, and does the Fable segment render in the kit-created sandbox? If the file is absent, a hidden segment **is the correct outcome**; the kit **never copies or forwards** the host token; the README states where the token must live. Success criterion 2 is satisfied by "renders when the file exists, hides cleanly when not".
- **D-64:** **Kill switch:** one env var (name at discretion, e.g. `STATUSLINE_NO_FABLE=1`, settable in the shell or via `settings.json` `env`) disables the Fable path entirely — no credential read, no network, segment hidden. Also the deterministic "off" switch for `tests/render-fixtures.sh` byte-diffs.

### Testability & docs
- **D-65:** **Env overrides** for the endpoint URL, the credentials-file path, and the cache-file path (all defaulting to production values; names at discretion, documented only in the script header/tests). `tests/run.sh` uses them to point at a local fixture/fake (e.g. a sanitized copy of the live response shape in `tests/fixtures/`, served via `file://` or a tiny local server — discretion) and asserts: render shape/colors, cache hit (no fetch within TTL), stale-grace serve/hide, timeout → no blocking/no stderr, ISO→epoch parse, kill switch, missing-bucket hide. Phase 2 convention applies: **every new probe must be shown to bite**. No real token or account data in the repo.
- **D-66:** README: update the "What it shows" example with `· Fable 74%/1w (2d:4h:30m)`, add a legend row (Fable weekly usage and its reset; needs the Claude Code OAuth login, hidden otherwise), plus **one short note** covering where the token is read from (credentials file / Keychain), the kill-switch env var, and the possible one-time Keychain prompt on macOS.

### Claude's Discretion
- Env var names (kill switch, endpoint/credentials/cache overrides); cache file name, location (under `~/.claude/` preferred) and format (raw response vs extracted fields); exact `--max-time`; exact stale-grace window; whether the cache records fetch time via mtime (`stat -c %Y || stat -f %m`, Linux form first) or an embedded field.
- ISO-8601 → epoch technique (pure bash arithmetic: parse `YYYY-MM-DDTHH:MM:SS`, honour `Z`/`±HH:MM` offsets, ignore fractional seconds) and where it lives (helper next to `fmt_duration`).
- Name and position of the adapter (`get_fable_weekly` / `seg_fable`), whether the cached JSON is parsed with a second jq call (acceptable — it's off the stdin choke point) and how the stdin `model_scoped` probe is folded into the existing single-pass jq program if the field exists.
- How the harness fakes the endpoint; sanitized fixture content; how `tests/sandbox.sh` detects credentials without printing them.
- Whether `project-brief.md` gets a "layout correction" note or stays untouched (D-52).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Layout & requirements
- `.planning/ROADMAP.md` §Phase 4 — goal, research flag, four success criteria (criterion 1's `15%/1w f(60%) (…)` form is superseded by D-51; treat as "weekly segment followed by the Fable segment")
- `.planning/REQUIREMENTS.md` — FAB-01..FAB-04 (FAB-01 wording to reconcile per D-52)
- `.planning/PROJECT.md` — Target Layout + Key Decisions (f() isolated behind an adapter seam, cached, fail-silent); layout to reconcile per D-52
- `project-brief.md` — original brief (historical; `f()` placement superseded)

### Verified technical facts (research + live evidence)
- `.planning/research/STACK.md` §"Rate-limit data sources" — endpoint, headers, token locations (Keychain item `"Claude Code-credentials"` verified present; `~/.claude/.credentials.json` absent on host), prescription (curl `--max-time`, TTL cache, hide on failure, never refresh token), bash 3.2 / BSD-GNU rules (`stat` dual fallback Linux-first, no `date -d`/`-r`)
- `.planning/research/PITFALLS.md` — Pitfall 2 (f() not on stdin), "never block" rules, security rows (never log the token; no world-readable predictable `/tmp` cache — use `~/.claude/` 0600 or `umask 077`), `$$`-keyed cache anti-pattern
- `.planning/research/ARCHITECTURE.md` — f() adapter seam (`get_model_weekly_pct` → `""` on failure), Pattern 4 mtime-TTL cache and `file_mtime` shim, "Any external/API data: never in the hot path, separate cache file, long TTL, always-hide on failure"
- `.planning/research/FEATURES.md` — why `f()` matters (Fable cap depletes independently), community precedents (ohugonnot 300 s cache with locking; jtbr gist 180 s)
- **Live endpoint evidence (2026-08-22, this discussion)** — recorded in `<specifics>` below: `limits[]` `weekly_scoped` bucket with `scope.model.display_name: "Fable"`, `percent` 0–100, ISO `resets_at`; `seven_day_opus`/`seven_day_sonnet` null; other top-level keys present (`extra_usage`, `spend`, `seven_day_oauth_apps`, …)
- Installed Claude Code binary `/Users/sv/.local/share/claude/versions/2.1.240` — `fetchUtilization: GET /api/oauth/usage`; usage-payload schema with `model_scoped[] {display_name, utilization, resets_at}` ("present only when the server emits them"); researcher must check whether the **statusline** payload constructor now projects it
- https://code.claude.com/docs/en/statusline — stdin schema, caching guidance (`session_id` key; not needed here since the cache is per-user), never-block guidance
- https://github.com/ohugonnot/claude-code-statusline and https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b — community OAuth-usage implementations (endpoint pattern, token discovery, TTL caching) — MEDIUM confidence, corroborating only

### Existing code (modification targets)
- `kit/files/home/.claude/statusline.sh` — the script (226 lines): `seg_1w`, `join_segments`, `fmt_duration`, `pct_color`, `shorten_num`, single-pass jq ingestion with `uint`/`strings` guards, `NOW`, line-2 join `join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)"` (append the Fable segment here)
- `tests/run.sh` (433 lines, 125+ checks: syntax, helper tables, fixture loop, thresholds, palette purity, injection/non-numeric probes, git matrix, latency budget) — extend with the Fable probes (D-65)
- `tests/fixtures/*.json` — stdin fixtures; add Fable stdin/endpoint fixtures
- `tests/render-fixtures.sh` — byte-for-byte host/sandbox render dump (must stay deterministic → kill switch or override during dumps)
- `tests/sandbox.sh` (269 lines) — live sandbox evidence; add the credentials/segment probe (D-63)
- `README.md` — example, legend, install notes (D-66)
- `kit/spec.yaml` — unchanged unless a sandbox dependency (curl) must be guarded in `setup.install` like jq/git (D-33 pattern)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fmt_duration`, `pct_color`, `DIM`, `RESET`, `join_segments` — the Fable segment composes entirely from these once it has `pct` and an epoch `resets_at`.
- `seg_1w` is the template: `pct_color` on the number, `/1w`, optional ` (countdown)` — `seg_fable` is the same shape with a dim `Fable ` prefix and its own reset epoch.
- `NOW=$(date +%s)` single date call — reuse for the Fable countdown and for cache-age math.
- Harness helpers `check_eq`/`check_ok`, ANSI-strip, fixture loop, and the "probe must bite" convention.

### Established Patterns
- bash 3.2 subset, `#!/bin/bash`, no `set -e/-u`, unconditional `exit 0`, nothing on stderr — every new call (`curl`, `security`, `jq`, `stat`, `mktemp`, `mv`) must be `2>/dev/null`-guarded and fall through to "hidden".
- One jq pass over stdin is the security choke point (Phase 2): new stdin fields (`model_scoped`) go **into that program** with the same `strings`/`uint` guards; the cached endpoint JSON may be parsed by a separate guarded jq call (it is local, 0600, written by us — but still type-guard numbers before `$(( ))`).
- Segment renderers echo their segment or `""`; hide-over-placeholder; PRES-04 separator rule is already handled by `join_segments`.
- Colors: ANSI named-16 only; dim = SGR 2.
- Docs-only commits via `gsd_run query commit`; cross-environment proof = `tests/render-fixtures.sh` + `diff -r`; live sandbox = `tests/sandbox.sh`.

### Integration Points
- Line 2 assembly in `main()`: add `"$(seg_fable)"` as the fourth (last) argument of the line-2 `join_segments` call.
- Adapter: a collector that (a) checks the kill switch, (b) checks stdin `model_scoped` vars from the jq pass, (c) else reads the cache (fresh → use; stale → fetch with token → write cache atomically → use; fetch failed → last-good if within grace, else hide), and exports `FAB_PCT` / `FAB_RST` (epoch) for `seg_fable`.
- Token: `~/.claude/.credentials.json` then `security` (host has only the Keychain item today; the sandbox status is unverified — D-63).
- README sections "What it shows", "Symbol legend", and the install notes; `tests/sandbox.sh` probe list; `tests/render-fixtures.sh` determinism.
- Sandboxed agents: this repo's sandbox blocks network to `api.anthropic.com` and commit signing — live endpoint checks and commits need `dangerouslyDisableSandbox` (see memory notes); Docker Desktop/sandboxd must be running for the sandbox probe.

</code_context>

<specifics>
## Specific Ideas

- Target line 2 (user's example, adapted): `10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 30%/1w (2d:4h:30m)` — Fable segment **last**, own countdown, `Fable` dim, percent threshold-colored.
- Live response shape captured 2026-08-22 (sanitized; values are the user's real numbers at that moment, safe to reuse as fixture data):
  ```json
  {
    "five_hour": {"utilization": 2.0, "resets_at": "2026-08-22T22:00:00.044006+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
    "seven_day": {"utilization": 39.0, "resets_at": "2026-08-24T18:00:00.044031+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
    "seven_day_opus": null, "seven_day_sonnet": null, "seven_day_oauth_apps": null,
    "limits": [
      {"kind": "session",       "group": "session", "percent": 2,  "severity": "normal", "resets_at": "2026-08-22T22:00:00.097604+00:00", "scope": null, "is_active": false},
      {"kind": "weekly_all",    "group": "weekly",  "percent": 39, "severity": "normal", "resets_at": "2026-08-24T18:00:00.097627+00:00", "scope": null, "is_active": false},
      {"kind": "weekly_scoped", "group": "weekly",  "percent": 74, "severity": "normal", "resets_at": "2026-08-24T18:00:00.097816+00:00", "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}, "is_active": true}
    ],
    "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null, "currency": null},
    "spend": {"percent": 0, "severity": "normal", "enabled": false}
  }
  ```
  (Other top-level keys present and irrelevant: `amber_ladder`, `cinder_cove`, `iguana_necktie`, `member_dashboard_available`, `nimbus_quill`, `omelette_promotional`, `seven_day_cowork`, `seven_day_omelette`, `tangelo`.)
- Selection rule in jq terms (reference, not prescriptive): `.limits[]? | select(.kind=="weekly_scoped" and ((.scope.model.display_name // "") | ascii_downcase | startswith("fable"))) | [.percent, .resets_at]` — first result.
- Working request: `curl -s --max-time N -H "Authorization: Bearer $TOK" -H "anthropic-beta: oauth-2025-04-20" -H "Content-Type: application/json" https://api.anthropic.com/api/oauth/usage`.
- The user was explicit that the new layout "is a bit different from what project-brief.md describes, but it should be easier to handle" — do not revert to the in-segment `f()` form.

</specifics>

<deferred>
## Deferred Ideas

- Showing other model-scoped weekly buckets (Opus/Sonnet/…) or `extra_usage`/`spend` (usage credits) — new capability, not this phase; the adapter's prefix-match rule leaves room for it later.
- Fable-aware color tuning (e.g. different thresholds for the Fable cap) — belongs with PRES-05 (v2 threshold tuning).

</deferred>

---

*Phase: 4-Fable Weekly f() Segment*
*Context gathered: 2026-08-22*
