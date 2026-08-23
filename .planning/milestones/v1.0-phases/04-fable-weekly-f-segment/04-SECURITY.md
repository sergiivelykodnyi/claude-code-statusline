---
phase: 04
slug: fable-weekly-f-segment
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-23
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| credentials store → `get_token` | `~/.claude/.credentials.json` (sandbox/Linux) or the macOS Keychain item `Claude Code-credentials`, read-only, only when a fetch is due | OAuth bearer token (secret) |
| `fetch_usage` → `https://api.anthropic.com/api/oauth/usage` | One bounded `curl -s -f --max-time 2 -K -` per cache miss; headers on stdin, never argv; TLS verification on; HTTPS_PROXY honoured | Bearer token (out), usage JSON (in, untrusted) |
| endpoint body / cache file / stdin `model_scoped` → jq → `eval` | Every ingestion is a separate type-guarded jq program emitting `@sh` single words | Untrusted JSON → shell variables |
| script → `~/.claude/statusline-usage-cache.json` | `mktemp` in the cache dir + `mv -f`, 0600; holds only `fetched_at/pct/resets_at` | Non-secret usage numbers |
| user shell / settings.json env → script overrides | `STATUSLINE_USAGE_URL`, `STATUSLINE_USAGE_CACHE`, `STATUSLINE_CREDENTIALS_FILE`, `STATUSLINE_CURL_MAX_TIME`, `STATUSLINE_NO_FABLE` | Same trust boundary as the user's own shell |
| harness (`tests/run.sh`, `tests/render-fixtures.sh`) → host | Kill switch exported; every live-path probe redirects URL/credentials/cache into `$TESTTMP`; `file://` fixtures | No network, no Keychain, no `~/.claude` writes |
| host script (`tests/sandbox.sh`) → sandboxd → kit sandbox | Creates/stops/removes only its two named sandboxes; in-sandbox render uses the sandbox's own credentials via the proxy; credentials probed for presence only | Sandbox lifecycle; percentages and `ls -l` modes in evidence |
| README reader → host `~/.claude` | `ln -sf` install line; token sources and kill switch named, never pasted | Shell commands |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-04-01 | Information Disclosure | `fetch_usage` curl invocation | medium | mitigate | Headers reach curl as a `-K -` config on stdin (`statusline.sh:301-315`); zero `-H`/`--header` occurrences; token never in argv | closed |
| T-04-02 | Information Disclosure | token / body / account data in stdout, stderr, cache, fixtures, evidence; sandbox probe | high | mitigate | 15 × `2>/dev/null`; cache holds only `fetched_at/pct/resets_at` (`:283-294`); `grep -rc accessToken tests/fixtures/` = 0; `tests/sandbox.sh:278` probes `test -f` only (0 cat/jq/head on the file); EVIDENCE/SUMMARY carry percentages and modes only | closed |
| T-04-03 | Tampering / Elevation of Privilege | hostile endpoint body, cache, credentials JSON or stdin `model_scoped` reaching `eval` / `$(( ))` | high | mitigate | Separate guarded jq programs with `uint`/`strings` guards emitting `@sh` (`:277-278`, `:318-323`, `:357-361`); `iso_to_epoch` `case`-gated (`:70-72`); harness §11 hostile probes (220/0) with mutation bites (04-02) | closed |
| T-04-04 | Tampering | torn / partial / symlinked cache file | medium | mitigate | `mktemp "${FAB_CACHE%/*}/.usage.XXXXXX"` + `mv -f` (`:293-295`); unparseable content → hidden | closed |
| T-04-05 | Information Disclosure | world-readable usage data in a predictable /tmp path | medium | mitigate | Default `~/.claude/statusline-usage-cache.json` (`:240`), 0600 via `mktemp`; never `/tmp`, never `$$`-keyed; sandbox evidence `-rw-------` | closed |
| T-04-06 | Spoofing | `STATUSLINE_USAGE_URL=https://evil/` exfiltrating the bearer token | medium | accept | Override shares the user's own shell/settings.json trust boundary; default is the HTTPS production URL with TLS verification (`:239`); no remote/config-file source — see Accepted Risks AR-04-01 | closed |
| T-04-07 | Denial of Service (UX) | blocking network / Keychain in the render path | medium | mitigate | `--max-time ${STATUSLINE_CURL_MAX_TIME:-2}`, `FAB_TTL=300`, `FAB_GRACE=3600`, negative results cached, kill switch, `expiresAt` pre-check (`:236-255`); 04-03 live render in 1 s | closed |
| T-04-08 | Tampering | sandbox proxy bypass / TLS downgrade | medium | mitigate | 0 occurrences of `--noproxy`, `--proxy ''`, `-k`/`--insecure`; in-sandbox render used the script defaults through HTTPS_PROXY (EVIDENCE.txt) | closed |
| T-04-09 | Tampering | harness/dumper reading the host Keychain, hitting the network, or writing the real `~/.claude` cache | high | mitigate | `export STATUSLINE_NO_FABLE=1` at `tests/run.sh:20` and `tests/render-fixtures.sh:36`; live-path probes override URL/credentials/cache into `$TESTTMP`; D-46 before/after lines identical in 04-03 | closed |
| T-04-10 | Elevation of Privilege / Repudiation | script refreshing/rewriting the OAuth token; evidence claimed without a live sandbox | high | mitigate | `security add-` = 0, the only "refresh" mention is the comment "never refreshed" (`:249`); read-only `find-generic-password` (`:262`); 04-03 `autonomous: false` with `sbx ls` human-action gate + precondition; EVIDENCE.txt script-written with fixed check names | closed |
| T-04-11 | Tampering | mutated script left in the working tree after a bite run | medium | mitigate | Bite runs in 04-02 mutated scratch copies only; tracked script pristine (`git diff --quiet -- kit/files/home/.claude/statusline.sh` re-asserted as 04-03's precondition; clean tree at audit time) | closed |
| T-04-12 | Information Disclosure | synthetic credentials or real data in committed fixtures | medium | mitigate | Credentials files generated under `$TESTTMP` at run time; `grep -rc accessToken tests/fixtures/` = 0; endpoint fixtures are the sanitized CONTEXT JSON | closed |
| T-04-13 | Denial of Service | a probe that blocks the harness | low | mitigate | Timeout probe uses `STATUSLINE_CURL_MAX_TIME=1` against `192.0.2.1` (`tests/run.sh:618-619`); all other probes are `file://` or missing paths; harness 6 s wall | closed |
| T-04-14 | Tampering | sandbox lifecycle damaging other sandboxes | low | mitigate | `tests/sandbox.sh` only `sbx rm -f`/`sbx stop` its two named sandboxes (`:152,164,227`); remove-everything form never used (T-03-10 gate stands) | closed |
| T-04-15 | Information Disclosure | README instructing users to paste tokens or disable safety | low | mitigate | README: `sk-ant` = 0, "paste your token" = 0, `TOKEN=` = 0; names only the two read-only sources and the kill switch | closed |
| T-04-16 | Tampering | whole-file rewrite of REQUIREMENTS/PROJECT/ROADMAP losing other phases' content | medium | mitigate | 04-04 scoped edits; pathspec-scoped `git diff` assertions recorded in 04-04-SUMMARY (Phase 1-3 sections byte-identical) | closed |
| T-04-17 | Repudiation | docs claiming behaviour the script does not have | low | mitigate | README:79 states 5 min / 2 s / 1 h / 0600 / `~/.claude/statusline-usage-cache.json` = `FAB_TTL=300` / `FAB_MAXTIME=2` / `FAB_GRACE=3600` / mktemp 0600 / `FAB_CACHE` (`:236-240`) | closed |
| T-04-18 | Tampering | lost update on `.planning/ROADMAP.md` between 04-04 and the orchestrator's 04-03 tick | low | mitigate | 04-04 re-read before its scoped edit; 04-03's ROADMAP update landed afterwards via `roadmap.update-plan-progress` (`fc18a9f`) with the Phase 4 block intact | closed |
| T-04-SC | Tampering | package installs | low | accept | None on the host (bash/jq/curl/security/mktemp are OS-provided); kit `setup.install` `apt-get install jq git curl` is `command -v`-guarded, Ubuntu official repos, no-op on the base image — see Accepted Risks AR-04-02 | closed |
| T-04-19 | Information Disclosure | `curl` honours `~/.curlrc` (no `-q`); a user `--trace*`/`-v` directive could write the bearer token to disk | medium | mitigate | **Open — below `high` threshold (non-blocking).** Surfaced by 04-REVIEW.md WR-02; same user-owned trust boundary as T-04-06. Fix: `curl -q -s -f …` (`-q` first) | open — below high threshold (non-blocking) |
| T-04-20 | Tampering | token spliced unsanitized into the `-K -` config; a newline/quote inside the user's own credentials JSON could inject curl directives | medium | mitigate | **Open — below `high` threshold (non-blocking).** Surfaced by 04-REVIEW.md WR-03; own credential store (low trust-boundary crossing). Fix: `test("^[A-Za-z0-9._~+/=-]+$")` in the jq token guard | open — below high threshold (non-blocking) |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (`high`) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-01 | T-04-06 | `STATUSLINE_USAGE_URL` is an env override with the same trust boundary as the user's shell / settings.json; no remote or config-file source; default is the TLS-verified production URL; documented only in the script header and tests (plan 04-01 register, D-59) | plan 04-01 threat model (planner) · confirmed at audit | 2026-08-23 |
| AR-04-02 | T-04-SC | No package installs on the host; kit `setup.install` adds jq/git/curl via `command -v`-guarded apt from Ubuntu official repos only (no npm/pip/cargo anywhere in the phase) | plan 04-01/02/03/04 threat models (planner) · confirmed at audit | 2026-08-23 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-23 | 21 | 19 | 2 (both medium, below `high` — non-blocking; from 04-REVIEW.md WR-02/WR-03) | /gsd-secure-phase 04 (orchestrator, L1 grep-depth short-circuit: plan-time register, ASVS L1) |

Notes:
- Register authored at plan time (all four PLAN.md files carry `<threat_model>`); per-plan duplicates of T-04-02/03/08/09/10/SC merged into one row each with the union of their mitigations.
- T-04-19/T-04-20 are recorded from the advisory code review so they are tracked, not to re-scan for new threats; `/gsd-code-review 04 --fix` closes both.
- Independent corroboration: 04-VERIFICATION.md (29/32, 16 judgment-tier prohibitions HOLD, UAT 3/3 passed) and 04-REVIEW.md (0 critical).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed (no open threat at or above `high`)
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-23
