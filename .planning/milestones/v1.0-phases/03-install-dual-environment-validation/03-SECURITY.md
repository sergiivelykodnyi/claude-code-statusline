---
phase: 03
slug: install-dual-environment-validation
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-22
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| kit `setup.startup` (root) → `/home/agent/.claude/settings.json` | Root shell from the kit rewrites an agent-owned, platform-managed config every sandbox start | Claude Code settings JSON (non-secret) |
| platform seed → `settings.json` | The sandbox engine writes/overwrites the same file at creation | Same file |
| repo file → host `~/.claude` | User's symlink/copy points Claude Code at a repo-controlled executable | Executable bash script |
| README reader → host filesystem / remote kit source | Copy-pasted commands modify `~/.claude`; `git+https` kit ref fetches executable content into a sandbox | Shell commands, kit files |
| host script (`tests/sandbox.sh`) → sandboxd | Creates, stops, removes sandboxes by name via the local daemon | Sandbox lifecycle commands |
| sandbox → bind-mounted repo | In-sandbox harness/dumper write under `tests/out/` | Render evidence (gitignored) |
| executor → host `~/.claude` | Must remain read-only during the phase (D-46) | None (verified untouched in UAT test 3) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-01 | Tampering | `kit/spec.yaml` startup jq merge on `settings.json` | medium | mitigate | `kit/spec.yaml`: sets only `.statusLine`; `try (input) catch {}` + object check; `mktemp` + `mv`; `themeId` poll before merge; `chown agent:agent` | closed |
| T-03-02 | Denial of Service | empty/invalid/non-object `settings.json` → blank status line | low | mitigate | `kit/spec.yaml:39` `[ -f "$S" ] \|\| printf '{}\n'`; `try (input) catch {}` yields `{}` | closed |
| T-03-03 | Elevation of Privilege | root startup shell text inside `spec.yaml` | low | accept | Static repo-reviewed command text; no runtime input interpolated (AR-03-01) | closed |
| T-03-04 | Denial of Service | exec bit lost on delivered/installed script | low | mitigate | git mode `100755` on `kit/files/home/.claude/statusline.sh`; `chmod 0755` in startup; `tests/run.sh:57` exec-bit check; `tests/sandbox.sh:172` `test -x` in sandbox | closed |
| T-03-05 | Tampering | stale `*.out` evidence mixing with fresh renders | low | mitigate | `tests/render-fixtures.sh:46` clears `*.out` in both subdirs; `.gitignore:2` `tests/out/` | closed |
| T-03-SC | Tampering | `apt-get install jq git` in `setup.install` | low | accept | Guarded by `command -v`; Ubuntu official repos only; no npm/pip/cargo installs (AR-03-02) | closed |
| T-03-06 | Tampering | README copy variant vs existing symlink | low | mitigate | `README.md:41` `rm -f … && cp …`; `README.md:44` overwrite warning; no bare `cp` form | closed |
| T-03-07 | Tampering (supply chain) | README remote `git+https` kit reference | medium | mitigate | `README.md:79` local absolute `--kit` documented first; `README.md:90` `kit.allowedSources` allow-list + `#ref=` pin note; real repo name | closed |
| T-03-08 | Information Disclosure | README settings snippet / verify payload | low | accept | Fixed literal path, synthetic payload, no secrets (AR-03-03) | closed |
| T-03-09 | Elevation of Privilege | Claude Code executes the documented command path | low | accept | Literal `~/.claude/statusline.sh`; no user-controlled interpolation (AR-03-04) | closed |
| T-03-10 | Tampering | `tests/sandbox.sh` `sbx rm -f` | low | mitigate | Only the two script-owned names (`statusline-kit-test`, `-add`); remove-everything form never used (`tests/sandbox.sh:28`); `--rm` opt-in (`:14`,`:17`) | closed |
| T-03-11 | Tampering | in-sandbox writes to the bind-mounted repo | low | mitigate | Writes confined to gitignored `tests/out/` (`tests/sandbox.sh:29,61`); working tree shows no tracked-file changes after live runs (porcelain check manual, not scripted) | closed |
| T-03-12 | Repudiation | evidence claimed without a live sandbox | medium | mitigate | `tests/sandbox.sh:63` EVIDENCE.txt written from real `sbx exec` results; `:133` halts when `sbx ls` cannot reach sandboxd; SUMMARY pastes the file | closed |
| T-03-13 | Denial of Service | long image pull / VM start exceeding tool timeouts | low | accept | Re-runnable script; run with max timeout or in background (AR-03-05) | closed |
| T-03-14 | Tampering | canary write to `settings.json` inside the sandbox | low | accept | Sandbox-local throwaway sandbox, jq tmp+mv, never the host file (AR-03-06) | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**Summary threat flags:** 03-01 and 03-02 SUMMARYs report none beyond the plan register. 03-03 SUMMARY carries no `## Threat Flags` section (documentation gap only; its plan register T-03-10..14 is verified above).

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-03 | Root startup command is static, repo-reviewed text in `kit/spec.yaml`; no sandbox-runtime input is interpolated | plan 03-01 threat model | 2026-08-22 |
| AR-03-02 | T-03-SC | `apt-get` guarded by `command -v` (no-op on the claude-code base image), official Ubuntu repos only | plan 03-01 threat model | 2026-08-22 |
| AR-03-03 | T-03-08 | README snippet/payload contain a fixed literal path and synthetic data; no secrets | plan 03-02 threat model | 2026-08-22 |
| AR-03-04 | T-03-09 | Documented statusLine command is a literal path; script content is repo-reviewed | plan 03-02 threat model | 2026-08-22 |
| AR-03-05 | T-03-13 | Availability-only; `tests/sandbox.sh` is re-runnable by design | plan 03-03 threat model | 2026-08-22 |
| AR-03-06 | T-03-14 | Canary write is sandbox-local in a throwaway sandbox; host `~/.claude` never touched (UAT test 3) | plan 03-03 threat model | 2026-08-22 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-22 | 15 | 15 | 0 | /gsd-secure-phase (L1 grep-depth short-circuit; register authored at plan time) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-22
