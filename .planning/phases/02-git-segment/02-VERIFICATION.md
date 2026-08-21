---
phase: 02-git-segment
verified: 2026-08-21T00:00:00Z
status: gaps_found
score: 5/5 git-segment success criteria verified (goal achieved); blocked by a confirmed render-path RCE
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The render path must not execute attacker-controlled payload values (the plan's own trust boundary: 'stdin JSON fields are untrusted'). A confirmed command-injection (RCE) fires via rate_limits.*.resets_at on the primary target interpreter."
    status: failed
    reason: "CR-01 reproduced live on the host /bin/bash 3.2.57 (arm64-apple-darwin25): a hostile resets_at value of the form 'x[$(cmd)]' flows unvalidated from jq @sh/eval into the $(( P5_RST - NOW )) / $(( P7_RST - NOW )) arithmetic sinks in seg_5h/seg_1w and the embedded command substitution executes. Confirmed 3/3 trials for five_hour and both windows by observing the injected file appear in a sandbox-writable dir. The harness reports 82/82 green because its injection probe (section 7) only covers current_dir, so the vector passes CI silently (WR-01). This phase modified statusline.sh and exercises this exact ingestion path at its seam; no later roadmap phase addresses input validation, so it is not deferrable."
    artifacts:
      - path: "statusline.sh"
        issue: "Lines 147 and 157: `$(fmt_duration $(( P5_RST - NOW )))` / `$(( P7_RST - NOW ))` feed untrusted resets_at (sourced lines 176,178) into a bash arithmetic context that command-substitutes an array subscript on bash 3.2.57."
      - path: "tests/run.sh"
        issue: "Section 7 injection probe covers only .workspace.current_dir; resets_at (and other numeric arithmetic-reachable fields) are untested, masking the RCE (WR-01)."
    missing:
      - "Enforce numeric type at the jq boundary so non-numbers become empty: `... // \"\" | numbers // \"\"` on every numeric field (CTX_PCT, CTX_TOK, CTX_WIN, P5_PCT, P5_RST, P7_PCT, P7_RST). The existing `[ -n \"$P5_RST\" ]` guards then skip the emptied field."
      - "Extend the harness injection probe to .rate_limits.five_hour.resets_at and .seven_day.resets_at (assert no touched file), run under /bin/bash to catch the version-specific 3.2 behavior."
      - "Optional (WR-02): a fixture with a non-numeric numeric field asserting zero stderr bytes — the same jq guard closes the `integer expression expected` stderr noise."
human_verification:
  - test: "Render the full-form git segment in a live terminal on both a light and a dark theme and read line 1 at a glance."
    expected: "Every marker is legible and distinguishable: magenta branch, yellow dirty *, green ≡ / red ≢, yellow ↓N, green ↑N, dim #N — no marker washes out against either background."
    why_human: "Color legibility and glanceability in a real terminal is a visual judgment no string/byte assertion can prove (plan 01 D5, human_judgment: true; mirrors Phase 1's dim-readability UAT)."
---

# Phase 2: Git Segment Verification Report

**Phase Goal:** Line 1 shows the full git situation at a glance in any repo state, without slowing the render
**Verified:** 2026-08-21
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

The git-segment goal is functionally achieved: all five ROADMAP success criteria are verified against real temp repos, and the full harness runs 82 checks with 0 failures on the host bash 3.2.57. However, adversarial verification of the shared render path confirmed the code-review BLOCKER **CR-01**: an arbitrary-command-execution vulnerability that fires on every render given a hostile `resets_at` payload value. Because this phase modified `statusline.sh` and drives this exact ingestion path — and the confirmed RCE is not covered by any later phase — the phase is `gaps_found` despite the git segment itself being correct.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Full dirty+upstream+behind/ahead+stash repo → line 1 ends `⎇ main* ≡ ↓2 ↑3 #2` (SC1) | ✓ VERIFIED | Harness "git full form: line 1" exact-equality PASS; exit 0, 0 stderr bytes |
| 2 | Outside a repo the whole git segment and its joiner space are absent (SC2) | ✓ VERIFIED | "git not-a-repo: line 1" = `Opus 5 (high) · plaindir`, no trailing space; seg_git returns 0 on non-zero git exit (statusline.sh:92) |
| 3 | Clean / detached / no-upstream / unborn render correctly; zero-value counters never appear (SC3) | ✓ VERIFIED | Harness checks: clean in-sync `⎇ main ≡`, detached `⎇ <sha>` (no sync glyph), no-upstream `⎇ feature/x-1 ≢`, unborn `⎇ main* ≢`; boundary-ones proves `↓1 ↑1 #1` while clean proves 0-counters hidden |
| 4 | Render well under ~300ms, single jq pass + one primary git status call (SC4, PORT-02) | ✓ VERIFIED | 10 uncached renders in 0s (budget 2s); grep gates: 1 `porcelain=v2`, 1 `jq -r`, all `git -C` carry `GIT_OPTIONAL_LOCKS=0` |
| 5 | Frame prefixes `╭─`/`╰─` removed; both lines flush-left; always exactly two lines (SC5) | ✓ VERIFIED | `grep -c '╭─\|╰─' statusline.sh` = 0; fixture line-1/line-2 checks + "empty: exactly 2 output lines" PASS |
| 6 | Worst-case (empty/malformed stdin): line 1 bare blue dir basename, line 2 blank, exit 0 | ✓ VERIFIED | empty/malformed fixtures → line1 `$HERE`, line2 ``, exit 0, 0 stderr |
| 7 | Every git invocation carries `GIT_OPTIONAL_LOCKS=0` (no repo mutation) | ✓ VERIFIED | grep: 0 `git -C` lines missing the guard; all commands read-only (status/rev-parse/rev-list) |
| 8 | No network operation in the render path (prohibition) | ✓ VERIFIED | `grep -cE 'git .*fetch|curl' statusline.sh` = 0; seg_git only issues local status/rev-parse/rev-list |
| 9 | Ahead/behind pass through as verbatim base-10 integers at any magnitude (backstop) | ✓ VERIFIED (direct code observation) | statusline.sh:124-125 print `${behind}`/`${ahead}` verbatim; no `shorten_num` anywhere in seg_git (lines 118-127) |
| 10 | Stash count passes through verbatim at any magnitude (backstop) | ✓ VERIFIED (direct code observation) | statusline.sh:126 prints `${stash}` verbatim; only arithmetic is the `-gt 0` gate |

**Score:** 5/5 ROADMAP success criteria verified; 10/10 git-segment truths verified. Goal achieved for the git segment — but see the blocking gap below.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `statusline.sh` | seg_git renderer, MAGENTA constant, frameless two-line assembly | ✓ VERIFIED | seg_git() ×1, MAGENTA= ×1, frame chars ×0, single porcelain call, seam join at main():191 |
| `tests/run.sh` | Frame-free expectations, 35m whitelist, temp-repo matrix, latency budget | ✓ VERIFIED (see WR-01 coverage gap) | 82 checks, mk_repo/tgit/git_render/git_line1 present, TESTTMP on EXIT trap, latency PASS |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| main() | seg_git() | `git_seg` captured once, appended to dir_seg with a plain space | ✓ WIRED | statusline.sh:188,191 `dir_seg="$dir_seg${git_seg:+ $git_seg}"` |
| seg_git() | git porcelain v2 | single `GIT_OPTIONAL_LOCKS=0 git -C` status call, bash-3.2 read loop | ✓ WIRED | statusline.sh:92 + here-string `while IFS= read -r` loop (:95-107) |
| tests/run.sh | statusline.sh | `jq --arg d ... workspace.current_dir` mutation piped in | ✓ WIRED | git_render() (:182-186) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| seg_git | branch/dirty/ahead/behind/stash | live `git status --porcelain=v2 --branch` + `rev-list refs/stash` on `$DIR` | ✓ real git state, not hardcoded | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full harness green on host bash 3.2.57 | `/bin/bash tests/run.sh` | 82 checks, 0 failures, exit 0 | ✓ PASS |
| CR-01 RCE via resets_at (five_hour) | full-script render w/ `resets_at:"x[$(touch F)]"` → sandbox-writable F | file created 3/3 trials | ✗ FAIL (security blocker) |
| CR-01 RCE via resets_at (seven_day) | same, seven_day window | file created | ✗ FAIL (security blocker) |
| Direct-inline arith injection (control) | `$(( a[$(touch F)] ))` on host bash | fires | ℹ confirms bash-3.2 subscript cmdsub mechanism |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| GIT-01 | 02-01 | Branch prefixed `⎇`; hidden outside a repo | ✓ SATISFIED | full-form + not-a-repo harness checks |
| GIT-02 | 02-01 | `*` suffix on dirty/untracked tree | ✓ SATISFIED | full-form (`main*`), unborn-with-file (`main*`), verbatim branch name |
| GIT-03 | 02-01 | `≡` with upstream, `≢` without | ✓ SATISFIED | clean in-sync `≡`; no-upstream `≢` (red glyph byte-asserted) |
| GIT-04 | 02-01 | `↓N`/`↑N`, hidden at zero | ✓ SATISFIED | boundary-ones (`↓1 ↑1`), full-form (`↓2 ↑3`), clean (none) |
| GIT-05 | 02-01 | `#N` stash, hidden at zero | ✓ SATISFIED | boundary-ones (`#1`), full-form (`#2`), clean (none) |
| GIT-06 | 02-01, 02-02 | Edge states render/degrade correctly | ✓ SATISFIED | 7-state matrix: not-a-repo, clean, ones, full, no-upstream, detached, unborn |
| PORT-02 | 02-01, 02-02 | Fast render, single jq pass + one git status call | ✓ SATISFIED | latency 10 renders/0s; grep gates 1 porcelain + 1 jq -r |

All 7 declared requirement IDs are present in both PLAN frontmatter and REQUIREMENTS.md (mapped to Phase 2). No orphaned requirements. Note: the CR-01 RCE is a security-posture defect orthogonal to these functional requirements — none of them assert input-validation of arithmetic-reachable fields, which is why all 7 read SATISFIED while the phase is still blocked.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| statusline.sh | 147, 157 (sinks); 176, 178 (source) | Untrusted `resets_at` → `$(( ))` arithmetic → command substitution on bash 3.2.57 | 🛑 BLOCKER (CR-01, reproduced live) | Arbitrary local command execution on every render given a server-/MITM-controlled payload value |
| tests/run.sh | 147-156 | Injection probe covers only `current_dir` | ⚠️ WARNING (WR-01) | Masks CR-01 — suite is 82/82 green while the RCE is live |
| statusline.sh | 22-23, 132-138 | Non-numeric numeric fields leak `integer expression expected` to stderr | ⚠️ WARNING (WR-02) | Robustness/noise defect; not injecting (only `$(( ))` does). Closed by the same jq `numbers` guard |
| statusline.sh | 182, 193, 197, 199 | `NOW`/`LINE1`/`LINE2` not declared `local` in main() | ℹ INFO (IN-01) | Harmless in a run-once-then-exit script; scoping inconsistency |

No unresolved TBD/FIXME/XXX debt markers found in the modified files.

### Human Verification Required

**1. Live-terminal color legibility (plan 01 D5)**

**Test:** Render the full-form git segment in a real terminal on both a light and a dark theme; read line 1 at a glance.
**Expected:** magenta branch, yellow `*`, green `≡` / red `≢`, yellow `↓N`, green `↑N`, dim `#N` are each legible and distinguishable against both backgrounds.
**Why human:** Color legibility/glanceability is a visual judgment no assertion can prove (deferred to UAT; mirrors Phase 1's dim-readability check).

### Gaps Summary

The git segment meets its goal on every functional axis: all five ROADMAP success criteria and all seven requirements are verified against real temp repos, the single-call/latency budget holds, and the read-only/no-network/no-mutation prohibitions are satisfied by inspection. The blocking gap is **not** in `seg_git` — it is the confirmed command-injection (CR-01) in the shared ingestion path this phase modified and exercises. I reproduced the RCE live on the project's primary interpreter (`/bin/bash` 3.2.57), reliably, for both rate-limit windows; the passing 82-check suite hides it because the injection probe only covers `current_dir` (WR-01). A one-line jq guard (`| numbers // ""` on every numeric field) closes both CR-01 and the WR-02 stderr-noise warning; the harness must then grow a `resets_at` injection probe run under `/bin/bash`. No later roadmap phase covers input validation, so this is a real, actionable gap for Phase 2, not a deferral.

---

_Verified: 2026-08-21_
_Verifier: Claude (gsd-verifier)_
