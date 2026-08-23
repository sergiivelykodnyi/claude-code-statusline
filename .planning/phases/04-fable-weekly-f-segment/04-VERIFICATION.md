---
phase: 04-fable-weekly-f-segment
verified: 2026-08-23T00:10:00Z
status: human_needed
score: 29/32 must-haves verified
behavior_unverified: 0
overrides_applied: 0
mvp_mode_discrepancy: "ROADMAP Phase 4 carries '**Mode:** mvp' but its goal is not in User-Story form (user-story.validate -> valid:false). Verified goal-backward against the explicit phase goal + 5 roadmap success criteria; the User Flow Coverage section below uses the user story written in 04-01-PLAN.md <objective>. Run /gsd-mvp-phase 04 only if a formal User-Story goal is wanted on the roadmap — no code gap."
unverified_prohibitions: 16  # all judgment-tier; LLM-judge verdict recorded per item below (non-authoritative) — human review recommended
human_verification:
  - test: "Host live check (roadmap SC1). Prerequisite: ~/.claude/statusline.sh is currently a content-identical REGULAR-FILE COPY of kit/files/home/.claude/statusline.sh (mtime Aug 23 02:59 +0300, not a symlink). Re-run the README install line (ln -sf <repo>/kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh) so future repo changes propagate, then start `claude` in this repo, send one short message and look at line 2."
    expected: "Line 2 ends with `· Fable NN%/1w (Nd:Nh:Nm)` — dim `Fable`, number green/yellow/red by threshold, `/1w` and countdown plain — and keeps rendering instantly on later messages (one fetch per 5 minutes, cached 0600 at ~/.claude/statusline-usage-cache.json). ~/.claude/settings.json statusLine stays {\"type\":\"command\",\"command\":\"~/.claude/statusline.sh\",\"padding\":0,\"refreshInterval\":60}. Also confirm YOU made the 02:59 copy of statusline.sh (if not, an agent breached D-46 — report it)."
    why_human: "Live Keychain token + production endpoint + TUI rendering cannot be exercised from the verifier (network to api.anthropic.com blocked in the agent sandbox; the verifier must never read the Keychain). Automated evidence already in hand: file:// renders, harness 220/0, host cache present -rw------- 58 bytes with pct and resets_at non-null (a successful live fetch happened on this host)."
  - test: "Sandbox live check (roadmap SC2). With Docker Desktop running: `sbx run --name statusline-kit-test` (left running by tests/sandbox.sh; recreate with `sbx run claude . --kit \"$PWD/kit\"` if gone), accept any trust prompt, send one short message."
    expected: "Same two-line status line with `· Fable NN%/1w (…)` last on line 2 (the sandbox has its own /home/agent/.claude/.credentials.json — observed present by tests/sandbox.sh §5.13, which rendered `· Fable 90%/1w (1d:18h:32m)` in 1 s); if the sandbox has no credentials, line 2 renders normally without the segment."
    why_human: "Visual confirmation inside a live Claude Code TUI in a Docker Sandbox; the verifier was instructed not to start/stop sandboxes or re-run tests/sandbox.sh. Machine evidence already on disk: tests/out/sandbox/EVIDENCE.txt (12 checks, 0 failures; harness in sandbox 220/0; PORT-01 8/8 byte-identical)."
  - test: "Judgment-tier prohibitions (16 across plans 01-04) — review the LLM-judge table in the report (all judged HOLD with code evidence: no credential write path, no -H/--header, no background/&/sleep/retry, no proxy value, no token in fixtures/docs, docs-only commits for 04-04, sandbox probe is presence-only)."
    expected: "Human agrees each prohibition holds; otherwise flag the item for a follow-up."
    why_human: "verification: judgment items cannot be closed by a test; the verifier records a non-authoritative verdict and hands the decision to the human (ADR-550 D4)."
---

# Phase 4: Fable Weekly f() Segment — Verification Report

**Phase Goal:** Line 2 ends with a separate Fable weekly segment `Fable pct/1w (countdown)`, fetched from the OAuth usage data and cached without ever risking or delaying the rest of the line
**Verified:** 2026-08-23T00:10:00Z
**Status:** human_needed
**Re-verification:** No — initial verification
**Mode note:** ROADMAP marks Phase 4 `**Mode:** mvp`, but the goal is not a User Story (`user-story.validate` → invalid). Verified goal-backward against the explicit goal and the five roadmap success criteria (the contract handed to the verifier); the MVP "User Flow Coverage" table below uses the user story from 04-01-PLAN.md's objective. This is a roadmap-metadata discrepancy, not a code gap (WARNING).

## User Flow Coverage (MVP framing)

User story (04-01-PLAN.md objective): «As a Claude Code Max subscriber working on the macOS host and inside Docker Sandboxes, I want to see my Fable-specific weekly usage and its reset countdown as the last segment of line 2, so that one glance tells me how much of the Fable cap is left — and never at the price of a slower or blank status line.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Start `claude` on the host (Keychain login) | line 2 ends with `· Fable NN%/1w (Nd:Nh:Nm)` | `get_token` lines 251-267 (file → Keychain, read-only); `seg_fable` 220-227; join with Fable last 416; host cache `-rw-------` 58 B with pct/resets_at non-null (live fetch occurred on this host); TUI look = human item 1 | ? human (TUI) |
| Start `claude` in the kit sandbox | same segment, token from `/home/agent/.claude/.credentials.json` | tests/sandbox.sh §5.13 lines 268-294; EVIDENCE.txt `INFO credentials file: present`, `PASS Fable segment renders in sandbox`, line 2 `… · Fable 90%/1w (1d:18h:32m)` in 1 s | ✓ (machine) / TUI = human item 2 |
| Keep chatting | later renders are instant, no blank line | 300 s TTL cache hit proven (URL switched → still 74%); blackhole endpoint hidden in 1 s wall; exit 0 always | ✓ |
| Lose credentials / go offline / endpoint changes | segment disappears, everything else unchanged | harness `fable: no credentials hidden`, `past-grace hide`, `timeout hidden`, `no bucket hidden`, hostile cache/body probes; spot checks (c)(d)(e)(g) | ✓ |

## Goal Achievement

### Observable Truths

Roadmap success criteria (contract) first, then plan-level must_haves.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | Host (Keychain): line 2 ends `15%/1w (…) · Fable 60%/1w (…)` — separate last peer with its own countdown | ? UNCERTAIN → human | Code: Keychain branch `security find-generic-password -s "Claude Code-credentials" -w` line 262 piped to guarded jq; seg_fable last (416). Shape proven via file:// fixture: `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 74%/1w (now)` (spot a). Live Keychain render not reproducible here (network blocked, Keychain must not be read); 04-01 SUMMARY records `Fable 85%/1w (1d:20h:25m)`; host cache file present 0600 58 B, pct+resets_at non-null. → human item 1 |
| SC2 | Sandbox: token from `~/.claude/.credentials.json`, segment renders the same way | ✓ VERIFIED | `get_token` reads `$HOME/.claude/.credentials.json` first (line 260); harness proves the credentials-file branch with synthetic creds; tests/out/sandbox/EVIDENCE.txt (real tests/sandbox.sh run 2026-08-22T23:27Z): `INFO credentials file: present`, `PASS Fable segment renders in sandbox (FAB-02, D-63)`, line 2 `… · Fable 90%/1w (1d:18h:32m)`, cache `-rw------- 1 agent agent 58`, `12 checks, 0 failures` |
| SC3 | Any failure → Fable silently disappears, other segments normal | ✓ VERIFIED | Spot checks: kill switch, no credentials (no cache written), blackhole timeout, garbage cache → exact base line 2, exit 0, 0 stderr bytes. Harness: `no credentials hidden`, `expired token hidden`, `past-grace hide`, `no bucket hidden`, `timeout hidden`, 45 security-probe checks, all PASS (220/0) |
| SC4 | Renders within TTL make no network call; cold fetch bounded by curl timeout | ✓ VERIFIED | Cache hit proven by switching URL to no-bucket fixture → still `Fable 74%` (spot b; harness `cache hit (no fetch)`); my scratch mutant with `FAB_TTL=0` flips it (hidden) → the probe bites. Blackhole `http://192.0.2.1/` with max-time 1 → hidden, exit 0, wall 1 s (spot e; harness `timeout wall <= 3s`). `curl -s -f --max-time "$FAB_MAXTIME"` line 315; no `&`, `sleep`, `--retry` in script |
| SC5 | Layout correction D-51 reconciled in REQUIREMENTS/PROJECT/README | ✓ VERIFIED | REQUIREMENTS.md:39 FAB-01 "separate `Fable pct/1w (countdown)` segment rendered last"; PROJECT.md:15,22,27,42; README.md:9,29,74-82; `grep -c 'f(' README/PROJECT/REQUIREMENTS` = 0; ROADMAP SC5 present |
| P1-1 | Cold file:// render → exact line 2, Fable last, dim label, threshold colour on number, exit 0, 0 stderr | ✓ VERIFIED | Spot (a): rc=0, stderr 0, line 2 exact, bytes `ESC[2mFable`; harness `cold render line 2`, `label+threshold bytes pct 74`, threshold quartet 69/70/89/90 |
| P1-2 | Cold render writes cache 0600 via mktemp+mv, `{fetched_at,pct:74,resets_at:0}`; warm render within TTL with different URL still 74 | ✓ VERIFIED | Spot (a): `-rw-------`, `[true,74,0]`; spot (b) 74 with no-bucket URL; code 290-296 |
| P1-3 | Kill switch / no creds / past grace / no bucket / garbage cache → hidden, others unchanged | ✓ VERIFIED | Spot (c)(d)(g) + harness (`kill switch hidden`, `past-grace hide`, `negative cache hit`, `hostile cache garbage hidden`) |
| P1-4 | One ordered token list: explicit file only → `~/.claude/.credentials.json` → Keychain; read only when fetch needed; `-K -` on stdin; never printed/refreshed | ✓ VERIFIED | `get_token` 251-267 (explicit-file branch has no Keychain fallback); `fetch_usage` 311-315 — headers via builtin printf into `curl -K -`; no `-H/--header/--insecure/-k/--noproxy` on code lines; no `security add-`; token read only inside `fetch_usage`, which runs only after the cache check |
| P1-5 | stdin `rate_limits.model_scoped[]` Fable entry renders with no cache read/write, no network | ✓ VERIFIED | Spot (f): `Fable 33%/1w (now)` with no creds, nonexistent URL, no cache file; jq binding lines 383-385, 397-398; `get_fable_weekly` 337-339 |
| P1-6 | tests/run.sh and tests/render-fixtures.sh export STATUSLINE_NO_FABLE=1; ≥126 checks, 0 failures | ✓ VERIFIED | run.sh:20, render-fixtures.sh:36; `/bin/bash tests/run.sh` → `220 checks, 0 failures` in 6 s |
| P1-7 | One live host render with Keychain + production endpoint recorded in SUMMARY | ? UNCERTAIN → human | Same as SC1 (SUMMARY records it; not reproducible by the verifier) |
| P1-8 | FAB-02 concurrency: no write path to either credential store | ✓ VERIFIED | grep: no `security add-`, no redirect into `.credentials.json`; token only in a local variable |
| P1-9 | FAB-03 concurrency: fetch-then-write, mktemp in cache dir + mv -f | ✓ VERIFIED | `fetch_usage` fills `body` first (314-315); `write_cache` 290-296 mktemp `"${FAB_CACHE%/*}/.usage.XXXXXX"` + `mv -f`, `rm -f` on failure; no `.usage.*` leftovers under ~/.claude |
| P1-10 | FAB-04 concurrency: garbage/hostile cache → empty values, hidden, exit 0, 0 stderr | ✓ VERIFIED | `read_cache` guarded `uint` jq (277-280); spot (g); harness `hostile cache injection …` PASS |
| P2-1 | Harness exits 0, >126 checks, 0 failures, hermetic | ✓ VERIFIED | 220/0; `fable_render` sets cache/URL/creds overrides (485-490); host `~/.claude/statusline-usage-cache.json` mtime unchanged by the run |
| P2-2 | Functional probes present and passing (cold/bytes/threshold/cache/grace/negative/creds/kill/stdin/alone/no-parens/timeout) | ✓ VERIFIED | 76 `PASS fable:` lines incl. every named probe; run.sh 499-625 read |
| P2-3 | Security probes under /bin/bash: exit 0, no tests/.pwned, 0 stderr, hidden | ✓ VERIFIED | `PASS fable: stdin injection …`, `stdin array …`, `hostile cache …`, `hostile body …`; `tests/.pwned` absent after run |
| P2-4 | iso_to_epoch 17-row table passes | ✓ VERIFIED | 18 `PASS iso_to_epoch` lines (17 rows + injected-string guard) |
| P2-5 | Every probe family shown to bite; script restored | ✓ VERIFIED (1/8 reproduced) | SUMMARY M1-M8 table; independently reproduced M5 on a scratch copy (`FAB_TTL=0` → warm render hidden instead of 74); `git diff --quiet` on the tracked script succeeds |
| P2-6 | FAB-04 concurrency hostile-cache probes | ✓ VERIFIED | as P1-10 |
| P3-1 | tests/sandbox.sh §5.13 presence-only probe + live in-sandbox render, fixed check names, INFO lines | ✓ VERIFIED | sandbox.sh 268-294: `test -f /home/agent/.claude/.credentials.json`, `unset STATUSLINE_NO_FABLE`, both check names, `INFO sandbox cache:`; `grep -c 'cat [^|]*credentials'` = 0 |
| P3-2 | Live run EVIDENCE.txt: `N checks, 0 failures`, harness >126/0, PORT-01 8 fixtures, §5.13 PASS | ✓ VERIFIED | tests/out/sandbox/EVIDENCE.txt read directly: `12 checks, 0 failures`, `PASS harness in sandbox: 220 checks, 0 failures`, `PASS PORT-01 … (8 fixtures)`, `PASS Fable segment renders in sandbox (FAB-02, D-63)` (not re-run per orchestrator instruction) |
| P3-3 | kit/spec.yaml guard checks curl; kit validates; `--help` exits 0 | ✓ VERIFIED | spec.yaml:21 `command -v curl`; EVIDENCE `PASS kit validate`; `/bin/bash tests/sandbox.sh --help` rc=0 |
| P3-4 | End-of-phase live check in both environments | ? UNCERTAIN → human | Human items 1 and 2 |
| P3-5 | Plan halts for the human (blocking gate, precondition) | ✓ VERIFIED | 04-03-PLAN.md:134 `checkpoint:human-action gate="blocking-human"`; EVIDENCE produced by a real run 23:27Z |
| P3-6 | Nothing under host ~/.claude created/modified/re-pointed by the sandbox run | ✓ VERIFIED (with note) | SUMMARY before/after identical (`9800 Aug 22 18:58`, settings unchanged). NOTE: host `~/.claude/statusline.sh` is NOW a 21023-byte regular file (content == kit script, mtime Aug 23 02:59 +0300, ~30 min after the run, coinciding with the orchestrator's 02:58 commits) — origin unknown; surfaced in human item 1 |
| P4-1 | README example/legend/Fable note/curl | ✓ VERIFIED | README.md:9,12,29,69,74-82,108; `STATUSLINE_NO_FABLE`, `Claude Code-credentials`, no `sk-ant`/paste-token text |
| P4-2 | REQUIREMENTS/PROJECT/ROADMAP reconciled with D-51; no in-segment notation | ✓ VERIFIED | see SC5 |
| P4-3 | Scoped edits only | ✓ VERIFIED | d5cd6c9 touches README.md only; 81c3890 touches PROJECT/REQUIREMENTS/ROADMAP only |
| P4-4 | ROADMAP no lost update | ✓ VERIFIED | ROADMAP Phase 4 block shows reworded goal, SC1-5 and all four plans ticked |
| P4-5 | Nothing under host ~/.claude by docs work | ✓ VERIFIED | docs-only commits |

**Score:** 29/32 truths verified (0 present-behavior-unverified; 3 UNCERTAIN → human: SC1, P1-7, P3-4 — all the same two-environment live TUI check)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kit/files/home/.claude/statusline.sh` | iso_to_epoch, adapter (get_token/read_cache/write_cache/fetch_usage/get_fable_weekly), seg_fable, stdin probe, Fable-last join, env header; ≥330 lines | ✓ VERIFIED | 432 lines; all symbols present and wired; shellcheck `--shell=bash -S warning` clean; executable |
| `tests/fixtures/usage/fable.json` | weekly_scoped Fable bucket 74 | ✓ VERIFIED | contains `weekly_scoped`; renders 74 |
| `tests/fixtures/fable-stdin.json` | model_scoped Fable 33 | ✓ VERIFIED | renders `Fable 33%/1w (now)` |
| `tests/fixtures/usage/no-bucket.json` | valid answer, no weekly_scoped | ✓ VERIFIED | `weekly_all` present, `weekly_scoped` absent |
| `tests/run.sh` | kill-switch export, iso table, fable_render, §11 | ✓ VERIFIED | line 20 export; §11 at 473-720; 220 checks |
| `tests/render-fixtures.sh` | kill-switch export + note | ✓ VERIFIED | line 36 |
| `tests/sandbox.sh` | §5.13 probe | ✓ VERIFIED | lines 268-294 |
| `kit/spec.yaml` | curl in D-33 guard | ✓ VERIFIED | line 21 |
| `README.md` | example, legend, Fable note, curl | ✓ VERIFIED | lines 9, 29, 74-82, 108 |
| `.planning/REQUIREMENTS.md` / `PROJECT.md` / `ROADMAP.md` | D-51 wording | ✓ VERIFIED | greps above |
| `tests/out/sandbox/EVIDENCE.txt` (gitignored) | real sandbox run evidence | ✓ PRESENT | 12 checks, 0 failures |

No fixture contains `accessToken` (grep -rc = 0 for every file).

### Key Link Verification

(`gsd-tools verify.key-links` reports "Source file not found" because the plans' `from:` fields are symbol names, not paths — verified manually by pattern.)

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| main() | get_fable_weekly | direct call in main's shell after NOW | ✓ WIRED | line 403 `^  get_fable_weekly` |
| main() line-2 join | seg_fable | 4th/last join_segments arg | ✓ WIRED | line 416 |
| fetch_usage | OAuth usage endpoint | `curl -s -f --max-time … -K -` | ✓ WIRED | line 315 |
| write_cache | $STATUSLINE_USAGE_CACHE | mktemp in cache dir + mv -f | ✓ WIRED | lines 293-295 |
| jq pass | get_fable_weekly stdin branch | FAB_SI_PCT / FAB_SI_RST | ✓ WIRED | lines 397-398, 337-339 |
| seg_fable | pct_color / fmt_duration / DIM | `${DIM}Fable${RESET}` … | ✓ WIRED | lines 224-225 |
| tests/run.sh §11 | statusline.sh | fable_render with overrides | ✓ WIRED | lines 485-490, 3× `STATUSLINE_USAGE_URL=` |
| tests/run.sh §11 | usage/fable.json | `file://$PWD/tests/fixtures/usage/fable.json` | ✓ WIRED | line 491 |
| tests/run.sh §2 | iso_to_epoch | sourced table | ✓ WIRED | 18 passing rows |
| tests/sandbox.sh §5.13 | kit script inside sandbox | sx … unset STATUSLINE_NO_FABLE | ✓ WIRED | line 281; EVIDENCE `INFO credentials file:` |
| tests/sandbox.sh §5.7 | tests/run.sh in sandbox | `harness in sandbox` | ✓ WIRED | line 197; EVIDENCE 220/0 |
| README Fable note | script env inputs | `Claude Code-credentials`, STATUSLINE_NO_FABLE | ✓ WIRED | README 78-81 ↔ script header 7-23 |
| REQUIREMENTS FAB-01 | ROADMAP SC1/SC5 | `Fable pct/1w (countdown)` | ✓ WIRED | REQUIREMENTS:39, ROADMAP:107,118 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| seg_fable | FAB_PCT / FAB_RST | get_fable_weekly ← stdin model_scoped / cache JSON / curl body (`limits[]` weekly_scoped Fable `percent`, `resets_at` via iso_to_epoch) | Yes — 74 from fixture, 33 from stdin, 90 live in sandbox (EVIDENCE), host cache holds non-null pct | ✓ FLOWING |
| write_cache | NOW / FAB_PCT / FAB_RST | fetched values | `[true,74,0]` written 0600 | ✓ FLOWING |

### Behavioral Spot-Checks (run in the verifier's own process; scratch dir, synthetic creds, no network)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full hermetic harness (once) | `/bin/bash tests/run.sh` | `220 checks, 0 failures`, 6 s, 0 FAIL lines, no tests/.pwned | ✓ PASS |
| Cold file:// render | overrides + full.json | line 2 `… · Fable 74%/1w (now)`, rc 0, stderr 0, cache `-rw-------` `[true,74,0]`, bytes `ESC[2mFable` | ✓ PASS |
| Warm hit, URL switched to no-bucket | same cache | still `Fable 74%` (no fetch) | ✓ PASS |
| Kill switch | STATUSLINE_NO_FABLE=1 | base line 2, no Fable | ✓ PASS |
| No credentials | missing creds file | hidden, stderr 0, no cache written | ✓ PASS |
| Blackhole endpoint, max-time 1 | `http://192.0.2.1/` | hidden, rc 0, stderr 0, wall 1 s | ✓ PASS |
| stdin-first | fable-stdin.json, no creds, bad URL | `Fable 33%/1w (now)`, no cache file | ✓ PASS |
| Garbage cache | `garbage` in cache | hidden, stderr 0 | ✓ PASS |
| Probe bites (scratch mutant FAB_TTL=0) | warm render vs no-bucket URL | mutant hides (refetch), real script keeps 74 | ✓ PASS |
| `tests/sandbox.sh --help` | before any sbx call | rc 0 | ✓ PASS |
| Host ~/.claude untouched by verification | ls -l before/after | statusline.sh + cache mtimes unchanged (02:59), no `.usage.*` temp files | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes exist or are declared; the project's probes are `tests/run.sh` (run above) and `tests/sandbox.sh` (live sbx run — not re-run per orchestrator instruction; its EVIDENCE.txt artifact was read and matches the plan's `<automated>` verify conditions).

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| FAB-01 | 01, 02, 03, 04 | Separate `Fable pct/1w (countdown)` segment last on line 2 with its own countdown (D-51 form) | ✓ SATISFIED | seg_fable + join last; exact line renders; docs reconciled |
| FAB-02 | 01, 02, 03, 04 | OAuth usage endpoint with Claude Code token — Keychain on host, credentials.json in sandboxes | ✓ SATISFIED (host Keychain TUI half → human item 1) | get_token order; sandbox EVIDENCE credentials present + render; host cache shows a successful live fetch |
| FAB-03 | 01, 02, 04 | TTL cache + short curl timeout, never blocks | ✓ SATISFIED | 300 s TTL hit proven; `--max-time 2` (knob); blackhole 1 s; 3600 s grace |
| FAB-04 | 01, 02, 03, 04 | Any failure → hidden, rest renders normally | ✓ SATISFIED | all hide paths exact-line asserted; 0 stderr; exit 0 |

Orphans: none — REQUIREMENTS.md maps exactly FAB-01..04 to Phase 4 and every one is claimed by at least one plan.

### Prohibitions (judgment-tier, non-authoritative LLM-judge verdicts — human review recommended)

| Plan | Prohibition (short) | Verdict | Evidence |
|------|---------------------|---------|----------|
| 01 | Never mutate token/credential stores; no real token committed | HOLD | no `security add-`, no redirect into credentials; fixtures/docs grep clean |
| 01 | Fable path never blocks/blanks beyond one bounded curl; no background/retry/sleep | HOLD | no `&`/`sleep`/`--retry`/`nohup`; single curl with `--max-time`; exit 0 unconditional |
| 01 | No proxy value (extra_usage/spend/seven_day_opus/all-models) | HOLD | jq selects only `weekly_scoped` + display_name startswith "fable"; no-bucket → hidden |
| 01 | Harness/dumper/verification never read Keychain, hit network, write ~/.claude | HOLD | exports at run.sh:20 / render-fixtures.sh:36; fable_render overrides; host cache mtime unchanged |
| 01 | Never ship host token into the sandbox | HOLD | kit/ has nothing credential-related; sandbox uses own file (EVIDENCE) |
| 02 | No probe reads Keychain/network/~/.claude | HOLD | as above |
| 02 | No real token/identifiers in fixtures | HOLD | `accessToken` grep 0; numbers only |
| 02 | No pre-existing check weakened/renamed | HOLD | 126 → 220, all prior names still PASS in saved output |
| 03 | Never read/print/copy credentials | HOLD | `test -f` only; `cat … credentials` grep 0 |
| 03 | No faked sandbox evidence | HOLD | EVIDENCE.txt emitted by script from real sbx results, timestamps consistent with commits |
| 03 | Never write under host ~/.claude; Docker started by user | HOLD (note) | SUMMARY before/after identical; later 02:59 change of host statusline.sh has unknown origin → human item 1 |
| 03 | No README/planning edits in plan 03 | HOLD | 99b07e5 touches tests/sandbox.sh + kit/spec.yaml only |
| 04 | Never revert to in-segment form | HOLD | `f(` count 0 in README/PROJECT/REQUIREMENTS |
| 04 | No wholesale rewrite / Plans list / checkboxes touched | HOLD | diff scope per SUMMARY; ROADMAP intact |
| 04 | No token-handling instructions beyond sources + kill switch | HOLD | README 78-82; no paste/export text |
| 04 | Docs only, nothing under ~/.claude | HOLD | d5cd6c9 / 81c3890 file lists |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER in any phase-modified file (mktemp `XXXXXX` template excluded); shellcheck clean at warning level | — | none |

### Human Verification Required

1. **Host live check (SC1)** — re-run the README `ln -sf` line first (host file is a content-identical regular-file copy dated 02:59, not a symlink), start `claude` here, send a message; line 2 must end `· Fable NN%/1w (Nd:Nh:Nm)` and keep rendering instantly; settings.json statusLine unchanged. Also confirm the 02:59 copy was your action (D-46).
2. **Sandbox live check (SC2)** — `sbx run --name statusline-kit-test`, send a message; same segment last on line 2 (or a normal line without it if the sandbox has no credentials).
3. **Prohibition review** — confirm the 16 judgment-tier prohibitions above hold.

### Gaps Summary

No code gaps. Every adapter branch (stdin-first, TTL hit, cold fetch, negative cache, stale-while-error grace, expired/absent credentials, kill switch, hostile inputs, bounded timeout) is implemented in `kit/files/home/.claude/statusline.sh`, wired into main's line-2 join as the last peer, and exercised by a 220-check hermetic harness that passed in the verifier's own process plus independent spot-check renders; sandbox evidence shows the credentials-file branch rendering live. What remains is the planned end-of-phase human live check in both environments (SC1/SC2 TUI) and two advisory notes: (a) ROADMAP marks the phase `mvp` without a User-Story goal, (b) the host `~/.claude/statusline.sh` was refreshed as a copy rather than the README symlink after plan 03's run — origin to be confirmed by the user.

---

_Verified: 2026-08-23T00:10:00Z_
_Verifier: Claude (gsd-verifier)_
