---
phase: 01
slug: core-status-line-from-stdin
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-21
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| stdin JSON → shell eval | Untrusted payload strings (directory names, model names are user/filesystem-controlled) interpolated into an eval'd string | Attacker-influenceable strings (paths, model names) |
| script stdout → terminal | Output bytes interpreted by the terminal emulator (SGR/escape sequences alter terminal state) | Rendered status line bytes |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Elevation of privilege | eval of jq output in main | high | mitigate | Single jq `@sh`-quoted extraction (statusline.sh:121) feeds the only `eval` (statusline.sh:133); no raw JSON concatenated. Harness check re-runs hostile-dirname injection probe with canary file (`tests/.pwned not created` — passing) | closed |
| T-01-02 | Tampering (terminal state) | printf output path | medium | mitigate | Escape bytes exist only in palette constants; all data printed via `printf '%s'` (zero `%b`/`echo -e` occurrences). Harness palette-purity check asserts only SGR codes 0m/2m/31m/32m/33m/34m/36m appear — passing | closed |
| T-01-03 | Denial of service (blanked status line) | arithmetic comparisons, jq failure modes | medium | mitigate | Truncate-then-guard (`${PCT%.*}`) before `-ge` comparisons; jq stderr suppressed; no `set -e`; unconditional `exit 0` (statusline.sh:155, PORT-03). Harness asserts exit 0 + zero stderr bytes for every fixture — passing | closed |
| T-01-SC | Tampering | package installs | low | accept | No package-manager installs in this phase — bash plus preinstalled system tools only (01-RESEARCH.md Package Legitimacy Audit: none) | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-01-01 | T-01-SC | No supply-chain surface: the phase installs no packages; runtime is bash 3.2 + preinstalled jq/git only | plan-time register (01-01-PLAN / 01-02-PLAN) | 2026-08-21 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-21 | 4 | 4 | 0 | gsd-secure-phase (L1 short-circuit: plan-time register, ASVS L1, harness 66/66 passing) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-21
