---
phase: 02
slug: git-segment
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: 2026-08-22
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Register assembled from the `<threat_model>` blocks of 02-01, 02-02, 02-03 and 02-04-PLAN.md plus the `## Threat Flags` of every SUMMARY (02-03 and 02-04 flag "None — no new surface"; 02-01/02-02 carry no flags section). Plans 02-01 and 02-03 both number their threats T-02-01..T-02-04 with different meanings, so every ID below is suffixed with its originating plan.

Verification depth: ASVS L1 (grep-level) — short-circuit path (`threats_open: 0`, register authored at plan time, L1). Evidence gathered by the orchestrator against `statusline.sh` (HEAD) and a live `/bin/bash tests/run.sh` run: **125 checks, 0 failures**.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Claude Code stdin JSON → shell vars (`jq @sh` → `eval`) | Single ingestion seam. Values (model name, effort, `workspace.current_dir`, context/rate-limit numbers) can originate from server responses, transit a proxy, or be attacker-influenced (hostile directory names); jq `@sh` quotes each array *element* as its own word, so type — not only content — must be enforced before `eval` (bash 3.2.57) | untrusted strings / numbers / arrays → bash assignments, `$(( ))`, `[`, printf sinks |
| `DIR` → `git -C "$DIR"` | Attacker-influencable path crosses into git argv | untrusted path |
| repo content → rendered line | Branch names / porcelain output from potentially hostile clones cross into terminal output | untrusted text → printf args |
| shared temp root → `tests/run.sh` | Temp repos and payloads under a world-writable temp root | test fixtures |
| `tests/run.sh` → `statusline.sh` | Harness feeds constructed (incl. hostile) payloads to the script under test | regression net |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|----------|-------------|------------------------|--------|
| T-02-01 (02-01) | Tampering | `seg_git` `git -C "$DIR"` argument | high | mitigate | `DIR` ingested only via the single jq `@sh` program (`statusline.sh:186`, now also `strings`-guarded) and always double-quoted at all 3 git call sites (`:92,113,116`); no `eval` of git output (`eval` appears once, `:195`, on the jq-quoted vars only); harness section-7 `current_dir` injection probe (`tests/run.sh:150-155`) PASS, `tests/.pwned` absent | closed |
| T-02-02 (02-01) | Tampering | branch label / porcelain text in rendered output | medium | mitigate | Porcelain parsed by `while IFS= read -r` + `case` (`:95-106`), never eval'd; label is concatenated into `$out` and emitted via `printf '%s' "$out"` (`:127`) — never a format string; harness "git no-upstream verbatim branch" + "git full form" PASS | closed |
| T-02-03 (02-01) | Denial of Service | `git status` on large/slow repos blanking the line | low | accept | Accepted risk (see AR-02-01): one local porcelain call + `GIT_OPTIONAL_LOCKS=0`, zero network (`grep 'git .*fetch\|curl\|wget'` = 0 matches); latency probe "10 full renders in 0s (budget 2s)" PASS; session-keyed cache remains a documented lever (D-29) | closed (accepted) |
| T-02-04 (02-01) | Tampering | render mutating the user's repo (locks / index writes) | medium | mitigate | All 3 `git -C` lines carry `GIT_OPTIONAL_LOCKS=0` and are read-only (`status` / `rev-parse` / `rev-list`) — `statusline.sh:92,113,116`; zero write-capable git subcommands present; human sign-off in 02-UAT.md test 2 | closed |
| T-02-05 (02-02) | Tampering | temp repo root under `/tmp` | low | mitigate | `mktemp -d "${TMPDIR:-/tmp}/statusline-git.XXXXXX"` (`tests/run.sh:44`, mode-700 unpredictable dir); `trap 'rm -f "$ERRTMP"; rm -rf "$TESTTMP"' EXIT` (`:45`) | closed |
| T-02-06 (02-02) | Denial of Service | latency check flakiness blocking the harness | low | mitigate | Whole-second bound, 2 s budget for 10 renders (`tests/run.sh:386-405`), measured 0 s; no network / external services | closed |
| T-02-01 (02-03) | Tampering / Elevation | jq `@sh` boundary → `$(( P5_RST - NOW ))` / `$(( P7_RST - NOW ))` | critical | mitigate | `numbers` is the first filter of `def uint` (`statusline.sh:182`) applied to `P5_RST`/`P7_RST` (`:191,193`) so a `x[cmdsub]` string collapses to empty and the `[ -n ]` guards (`:147,157`) skip the arithmetic; `resets_at` injection probes for five_hour + seven_day run under `/bin/bash` (`tests/run.sh:163-175`) PASS, `tests/.pwned` absent | closed |
| T-02-02 (02-03) | DoS / Info disclosure | `seg_context` / `shorten_num` `[` integer tests on non-numeric fields | low | mitigate | Same `numbers`/`uint` guard maps non-numeric to empty → `[ -z ]&&=0` path; "non-numeric probe: total_input_tokens stderr bytes = 0" (`tests/run.sh:184`) PASS | closed |
| T-02-03 (02-03) | Tampering | `context_window` numeric fields → `shorten_num` / pct arithmetic | medium | mitigate | `CTX_PCT`/`CTX_TOK`/`CTX_WIN` all pass through `uint` (`statusline.sh:187-189`); array + non-integer probes cover them (`tests/run.sh:190-240`) PASS | closed |
| T-02-04 (02-03) | Spoofing / Tampering | `.workspace.current_dir` → `@sh` eval | low | accept → **CORRECTED** by 02-04 | 02-03's "accept — scalar @sh quoting suffices" was falsified live (array payload fans out into multiple eval words). Superseded by T-02-07: `current_dir` now carries the `strings` guard (`statusline.sh:186`) and an array probe (`tests/run.sh:201`). Recorded here for audit lineage only; no residual accepted risk | closed (superseded) |
| T-02-07 (02-04) | Tampering / Elevation of Privilege | jq `@sh` boundary → `eval "$vars"` → `MODEL` / `EFFORT` / `DIR` (array → multi-word escape, CR-02) | critical | mitigate | `strings // ""` guard on `.model.display_name`, `.effort.level`, `.workspace.current_dir` inside the single jq program (`statusline.sh:184-186`) — non-strings collapse to one empty `@sh` word; array-payload probes for the 3 string fields under `/bin/bash` (`tests/run.sh:190-216`) PASS; prove-it-bites: pre-fix script (`git show 5404c4e~1:statusline.sh`) → exactly those 3 probes FAIL (02-04-SUMMARY.md:74) | closed |
| T-02-08 (02-04) | Tampering | 7 numeric field extractions → same eval boundary (array payload) | low | mitigate | `uint` begins with `numbers` (`statusline.sh:182`); array probes for all 7 numeric fields (`tests/run.sh:201-216`) PASS | closed |
| T-02-09 (02-04) | Info disclosure / DoS (fail-silent breach) | `$(( RST - NOW ))`, `[ -ge ]` sinks fed float / exponent / nan numbers | low | mitigate | `def uint: (numbers \| floor \| select(. >= 0 and . < 1e15)) // ""` (`statusline.sh:182`) emits only bash-safe non-negative integers or empty; non-integer zero-stderr probes incl. the 23.5 float-percentage pin (`tests/run.sh:229-240`) PASS; prove-it-bites: pre-Task-3 script → 4 stderr-bytes probes FAIL (02-04-SUMMARY.md:85) | closed |
| T-02-10 (02-04) | Repudiation / false assurance | `tests/run.sh` section 7 probes covering string payloads only | medium | mitigate | Array-payload probes for all 10 `@sh`-ingested fields with fixed PASS-line names (`tests/run.sh:190-216`); demonstrated to bite against the pre-fix script (02-04-SUMMARY.md:32,49,74) — the net has no CR-02-shaped hole | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` (high) count toward `threats_open`*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**Counts:** 14 threats · 14 closed (12 mitigated, 1 accepted, 1 superseded-by-mitigation) · 0 open · `threats_open: 0`.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-02-01 | T-02-03 (02-01) | A pathologically large/slow repo may make `git status --porcelain=v2` exceed Claude Code's render window and blank the line. Accepted because: the call is local-only, lock-free, and uncached by design (D-29), the measured budget is 10 renders < 2 s, and a session-keyed cache (`/tmp/statusline-git-cache-$SESSION_ID`, ~5 s TTL) is a documented lever if lag ever appears. Availability-only impact, no integrity/confidentiality exposure. | Plan 02-01 author; ratified at secure-phase 2026-08-22 | 2026-08-22 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-22 | 14 | 14 | 0 | secure-phase orchestrator (ASVS L1 short-circuit; grep evidence + live `tests/run.sh` 125/0) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-22
