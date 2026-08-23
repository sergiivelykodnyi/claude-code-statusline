---
phase: 01-core-status-line-from-stdin
verified: 2026-08-21T18:52:49Z
status: passed
score: 18/18 must-haves verified
behavior_unverified: 0
overrides_applied: 0
prohibitions:

  - statement: "MUST NOT write files, create caches, log, or transmit stdin payload contents anywhere (read-only, network-free)"
    tier: test
    status: verified
    enforcement_evidence: "Wired: tests/run.sh injection probe asserts tests/.pwned never created (run.sh:140-149). Verifier probe: script run from clean cwd with clean TMPDIR created 0 files in either; source scan shows no curl/wget/tee/mktemp/file-redirection in statusline.sh; only subprocesses are cat, jq, date"

  - statement: "MUST NOT render placeholder or filler text for absent data (hide-over-placeholder; sole exception D-12 context zero-state)"
    tier: test
    status: verified
    enforcement_evidence: "Wired: tests/run.sh fixture loop asserts byte-exact ANSI-stripped lines for all 7 fixtures (no-effort/no-rate-limits/only-five-hour/empty/malformed all show segments fully absent with separators); the word 'null' and any N/A/dash scaffold appear in no fixture output"

  - statement: "MUST NOT reduce or restyle the locked layout: no directory truncation, no width logic, no 256-color/truecolor SGR (D-02, D-15, D-16)"
    tier: judgment
    status: unverified-prohibition
    flagged: true
    llm_judge_verdict: "NON-AUTHORITATIVE PASS — grep finds no COLUMNS/tput/truncation logic in statusline.sh; no 38;2/38;5 SGR codes in code lines; harness palette-purity check passes (only 0m/2m/31m/32m/33m/34m/36m in output); directory rendered full-length. Human review recommended (judgment-tier cannot be closed autonomously)"
coincidental_reliance_items:

  - truth: "Zero-byte and non-JSON stdin render line 1 as top frame + basename of PWD (D-13 fallback keyed off empty MODEL/DIR after eval)"
    reason: undeclared-precondition
    harden: "The eval'd variables (MODEL, EFFORT, DIR, CTX_*, P5_*, P7_*) are never initialized before `eval \"$vars\"` (statusline.sh:133). When jq emits nothing, the names inherit exported environment values — reproduced: `MODEL='LEAKED-MODEL' DIR=/evil/leaked-dir ./statusline.sh < malformed.json` renders '╭─ LEAKED-MODEL · leaked-dir'. Fix: initialize all ten vars to empty immediately before the eval (review WR-01)."
human_verification:

  - test: "Render `./statusline.sh < tests/fixtures/full.json` in both a light-themed and a dark-themed terminal"
    expected: "Dim (SGR 2 faint) frame glyphs and '·' separators are visible-but-receded; cyan model, blue directory, and green/yellow/red percentages are readable on both themes. If SGR 2 is invisible/ugly, the documented fallback is a one-constant swap to bright-black"
    why_human: "Visual readability of SGR 2 faint across terminal themes cannot be asserted by byte checks (harvested from 01-02-PLAN <human-check>; carried in SUMMARY coverage D3/D5, research assumption A1, D-02)"

  - test: "Confirm the rendered layout matches your locked decisions: full-length directory name, no segment dropping at narrow widths, named-16 colors only"
    expected: "Layout matches D-01/D-02/D-15/D-16 exactly as you specified — nothing shortened, dropped, or restyled"
    why_human: "Judgment-tier prohibition (01-01-PLAN must_haves.prohibitions #3) — autonomous verification recorded a NON-AUTHORITATIVE pass; per policy this requires explicit human resolution and is flagged 'unverified-prohibition — human review recommended'"
---

# Phase 1: Core Status Line from Stdin — Verification Report

**Phase Goal:** One glance shows which model at which effort, where Claude is running, and how much context and rate limit remain — rendered entirely from the stdin JSON payload
**Verified:** 2026-08-21T18:52:49Z
**Status:** human_needed (all automated checks pass; 2 items need a human glance)
**Re-verification:** No — initial verification

## Goal Achievement

All evidence below was gathered by executing the actual script and harness — SUMMARY claims were re-derived empirically, not trusted.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC1: Full payload prints colorized two-line frame: `╭─ Opus 5 (high) · myproject` / `╰─ 10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)` | ✓ VERIFIED | Ran `./statusline.sh < tests/fixtures/full.json`: exit 0, 0 stderr bytes, exactly 2 lines matching (with `(now)` for past resets_at); dynamic payload with resets_at now+10230/now+280620 rendered `(2h:50m)` and `(3d:5h:57m)` exactly |
| 2 | SC2: Context and rate-limit percentages shift color across warning/critical thresholds | ✓ VERIFIED | Context site: 69.9→`[32m69%`, 70→`[33m70%`, 89.9→`[33m89%`, 90→`[31m90%` (byte-verified); 5h site: harness threshold quartet passes; 1w site: 69.9→`[32m69%…/1w`, 90→`[31m90%…/1w` (byte-verified) |
| 3 | SC3: Absent/null fields hide segments and separators entirely — no placeholders, no errors | ✓ VERIFIED | no-effort→`╭─ Opus 5 · myproject`; no-rate-limits→`╰─ 10%/100k/1M`; only-five-hour→`╰─ 10%/100k/1M · 50%/5h (now)`; null-context→`╰─ 0%/0/200k`; all exit 0, 0 stderr, no dangling separators |
| 4 | SC4: Always exits 0, silent stderr, line 1 renders in every case | ✓ VERIFIED | Empty stdin (`printf ''`), zero-byte fixture, `not json`, and 64 bytes of /dev/urandom all: exit 0, 0 stderr bytes, line 1 = `╭─ <PWD basename>`, line 2 = bare `╰─` |
| 5 | Absent/null model → line 1 is `╭─ myproject` alone, no dangling separator | ✓ VERIFIED | `jq 'del(.model)'` and `.model.display_name = null` both render `╭─ myproject` |
| 6 | Multi-byte model name passes byte-identically; suffix strip cuts at first ` (` | ✓ VERIFIED | `Ōpus 5 (1M context)` renders `Ōpus 5` |
| 7 | Boundary cutoffs 69/70/89/90 identical on all three percentage sites | ✓ VERIFIED | Byte-verified on context and 1w sites (this run) and 5h site (harness quartet); `pct_color` unit table 69→GREEN/70→YELLOW/89→YELLOW/90→RED passes |
| 8 | Float percentages truncate before display and comparison (89.9 → `89%` yellow, never red) | ✓ VERIFIED | Harness: `[33m89%[0m/5h` byte-span assertion passes for 89.9 |
| 9 | Countdowns from pure epoch arithmetic, single `date +%s`: 10230s→`2h:50m`, 273450s→`3d:3h:57m`, 262800s→`3d:1h:0m`, past→`(now)` | ✓ VERIFIED | `fmt_duration` unit table (10 cases incl. inner-zero `3d:1h:0m`) passes; non-comment `date +%s` count in statusline.sh = 1; live-countdown e2e check passes |
| 10 | Only percentage numbers carry threshold color; labels/countdowns plain; model cyan, dir blue, effort dim, frame/separators dim | ✓ VERIFIED | Raw byte dump: `[36mOpus 5[0m`, `[2m(high)[0m`, `[34mmyproject[0m`, `[2m╭─[0m`, `[2m·[0m`, `[32m10%[0m/100k/1M` — reset lands before every label |
| 11 | Output carries 3-byte UTF-8 `╭─`/`╰─` regardless of locale; every SGR from the named-16 palette | ✓ VERIFIED | Byte dump shows `\342\225\255\342\224\200` / `\342\225\260\342\224\200`; `LC_ALL=C` run renders identically; palette-purity check (only 0m/2m/31m/32m/33m/34m/36m) passes |
| 12 | Every fixture (all 7) → exit 0 and zero stderr bytes under /bin/bash | ✓ VERIFIED | Harness fixture loop (28 checks) + independent re-runs, all exit 0 / 0 stderr bytes |
| 13 | Rate-limit windows hide independently; order always context → 5h → 1w | ✓ VERIFIED | only-five-hour keeps 5h and drops 1w; no-rate-limits drops both; separators travel with segments |
| 14 | null-context renders `0%/0/200k` with green zero — segment never hides while window size known | ✓ VERIFIED | Stripped line 2 = `╰─ 0%/0/200k`; raw output contains `[32m0%` (green byte confirmed) |
| 15 | Empty/malformed stdin → frame + PWD basename, bare bottom frame; fallback keyed off empty MODEL/DIR after eval, never jq's exit code | ✓ VERIFIED (coincidental-reliance) | Behaviorally verified (truth 4); source has no branch on jq exit status. Advisory: holds only under the undeclared precondition that MODEL/DIR/etc. are not exported in the invoking environment — see coincidental_reliance_items (review WR-01) |
| 16 | Empty percentages guard to 0 before arithmetic; past resets_at renders `(now)`; no integer-expression errors reach stderr | ✓ VERIFIED | All contract-shaped inputs (empty/null pct, float pct, resets_at 0) produce 0 stderr bytes. Known out-of-contract advisory: a float `resets_at` (not in the verified stdin contract) emits 103 stderr bytes — review WR-02, plan's Flagged Assumption 2 explicitly scoped this residual |
| 17 | Renders are side-effect-free (no files, no locks) and both lines end with SGR reset (backstop truth) | ✓ VERIFIED | Directly observed behavior: run from clean cwd with clean TMPDIR created 0 files in either; raw byte dump shows both lines terminate with `\033[0m`; only subprocesses are cat/jq/date (none lock-taking) |
| 18 | `/bin/bash tests/run.sh` exits 0 covering helper tables, boundaries, all 7 fixtures, palette purity, injection probe | ✓ VERIFIED | Executed: 66 checks, 0 failures, exit 0; `tests/.pwned` absent after run |

**Score:** 18/18 truths verified (0 present-but-behavior-unverified — every truth was exercised by an actual test run)

### Prohibitions (must-NOT checks)

| # | Statement | Tier | Status | Evidence |
| --- | --------- | ---- | ------ | -------- |
| P1 | No file writes, caches, logs, or transmission of payload | test | ✓ VERIFIED | Wired injection-canary test (run.sh:140-149) + verifier clean-dir probe: 0 files created; no network/write constructs in source |
| P2 | No placeholder/filler text for absent data | test | ✓ VERIFIED | Wired harness fixture loop asserts byte-exact hidden-segment outputs |
| P3 | No layout reduction/restyle (truncation, width logic, 256-color) | judgment | ⚠ UNVERIFIED — flagged | NON-AUTHORITATIVE LLM-judge PASS (no COLUMNS/tput/truncation/38;2/38;5 in code; palette purity passes). Human review recommended — routed to human_verification |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `statusline.sh` | Executable script, `#!/bin/bash`, min 90 lines, palette + helpers + jq @sh ingestion + 5 renderers + assembler + source guard | ✓ VERIFIED | 162 lines, executable, `bash -n` passes; all named functions present (shorten_num, fmt_duration, pct_color, join_segments, seg_model_effort, seg_dir, seg_context, seg_5h, seg_1w, main); BASH_SOURCE guard at line 160 |
| `tests/fixtures/full.json` | Happy-path payload: suffix model, float pcts, 1M window, past resets_at | ✓ VERIFIED | Renders the exact expected happy-path lines |
| `tests/run.sh` | Harness, contains BASH_SOURCE, min 60 lines | ✓ VERIFIED | 163 lines, executable, `bash -n` passes, sources statusline.sh, contains BASH_SOURCE; 66 checks pass |
| `tests/fixtures/{no-effort,no-rate-limits,only-five-hour,null-context,empty,malformed}.json` | Fixture Matrix contents; empty = 0 bytes; malformed = `not json` | ✓ VERIFIED | All 6 exist; empty.json is 0 bytes; malformed.json is `not json`; each renders its exact matrix lines |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| stdin JSON payload | scalar vars (MODEL, EFFORT, DIR, CTX_*, P5_*, P7_*) | single `jq -r '@sh …'` pass, `// ""` on every field, eval'd | ✓ WIRED | statusline.sh:121-133; all 10 fields present with `// ""`; jq stderr suppressed; injection probe proves @sh quoting holds |
| segment renderers | framed output lines | `join_segments` skip-empty joiner | ✓ WIRED | statusline.sh:143,146; no dangling/doubled separators in any fixture combination |
| tests/run.sh | statusline.sh pure helpers | sourcing under BASH_SOURCE guard, stdin from /dev/null | ✓ WIRED | run.sh:55; 29 helper-table unit checks execute against the sourced functions |
| tests/run.sh | statusline.sh end-to-end contract | piping each fixture, asserting exit/stderr/exact stripped lines | ✓ WIRED | run.sh:86-106 run_fixture loop, 28 checks |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| statusline.sh line 1 | MODEL/EFFORT/DIR | stdin JSON via jq @sh eval | Yes — fixture values flow to rendered output (mutating the fixture changes the render) | ✓ FLOWING |
| statusline.sh line 2 | CTX_*/P5_*/P7_* + NOW | stdin JSON + `date +%s` | Yes — dynamic resets_at payloads produce live countdowns; pct mutations shift colors | ✓ FLOWING |

No static returns, hardcoded values, or mocks on the render path.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Full contract regression | `/bin/bash tests/run.sh` | 66 checks, 0 failures, exit 0 | ✓ PASS |
| Never-fail on garbage | `head -c 64 /dev/urandom \| ./statusline.sh` | exit 0, 0 stderr, 2 lines, line 1 renders | ✓ PASS |
| Countdown exactness | resets_at now+10230/now+280620 | `(2h:50m)` and `(3d:5h:57m)` | ✓ PASS |
| No-write contract | run from clean cwd + clean TMPDIR | 0 files created | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes declared or present; `tests/run.sh` is the phase's declared harness and was executed by the verifier (see above).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| SESH-01 | 01-01 | Model name with suffix stripped | ✓ SATISFIED | `Opus 5 (1M context)` → `Opus 5`; multi-byte `Ōpus 5` preserved |
| SESH-02 | 01-01, 01-02 | Effort in parens, hidden when absent | ✓ SATISFIED | `(high)` dim; no-effort fixture → no parens, no trailing space |
| SESH-03 | 01-01 | Directory basename | ✓ SATISFIED | `myproject` blue, full length; PWD fallback |
| CTX-01 | 01-01, 01-02 | Context as `pct/used/window` | ✓ SATISFIED | `10%/100k/1M`; D-12 zero-state `0%/0/200k` never hides while window known |
| CTX-02 | 01-01 | k/M shortening | ✓ SATISFIED | shorten_num D-08 table, 13 cases pass (truncation, one decimal below 10 units) |
| LIM-01 | 01-01 | 5h segment with countdown | ✓ SATISFIED | `50%/5h (2h:50m)` |
| LIM-02 | 01-01 | Weekly segment with countdown | ✓ SATISFIED | `15%/1w (3d:5h:57m)` |
| LIM-03 | 01-01 | Pure epoch arithmetic, d:h:m format | ✓ SATISFIED | Single `date +%s`; no `date -d`/`date -r` anywhere; fmt_duration table passes |
| LIM-04 | 01-02 | Segments hidden when fields absent | ✓ SATISFIED | Independent per-window hides verified on 3 fixtures |
| PRES-01 | 01-01 | Two-line `╭─`/`╰─` frame | ✓ SATISFIED | UTF-8 byte sequences confirmed, both lines, every input class |
| PRES-02 | 01-01 | ANSI colorized | ✓ SATISFIED | Named-16 SGR throughout; palette purity check |
| PRES-03 | 01-01, 01-02 | Threshold color shifts | ✓ SATISFIED | 69/70/89/90 quartet on all three sites |
| PRES-04 | 01-02 | Hidden segments take separators, no placeholders | ✓ SATISFIED | All hide fixtures byte-exact; join_segments unit checks |
| PORT-03 | 01-02 | Never stderr/non-zero exit; degrade to hidden | ✓ SATISFIED | Exit 0 + 0 stderr on all 7 fixtures, empty stdin, binary garbage |

Orphan check: REQUIREMENTS.md maps exactly these 14 IDs to Phase 1; the union of both plans' `requirements` fields covers all 14. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No TBD/FIXME/XXX/TODO/HACK/placeholder markers in statusline.sh or tests/run.sh | — | (`XXXXXX` grep hit is the mktemp template in the test harness, not a debt marker) |

Known advisories from 01-REVIEW.md (reproduced by the verifier, neither breaks a must-have):

- ⚠ **WR-01** — eval'd variables uninitialized: exported `MODEL`/`DIR` env values leak into the render when jq fails (reproduced: `╭─ LEAKED-MODEL · leaked-dir`). Tracked as the coincidental-reliance advisory on truth 15; recommended hardening: initialize all ten vars before `eval "$vars"` (statusline.sh:133).
- ⚠ **WR-02** — out-of-contract float `resets_at` reaches `$(( ))` and emits 103 stderr bytes plus a malformed `()` segment (exit stays 0, line still renders). Within the verified stdin contract (epoch-second integers) the zero-stderr contract holds; plan 01-02 Flagged Assumption 2 explicitly scoped this residual. Recommended for Phase 2 hardening: an `int_or_empty` sanitizer per the review.

### Human Verification Required

#### 1. Dim styling readability (light + dark themes)

**Test:** Render `./statusline.sh < tests/fixtures/full.json` in both a light-themed and a dark-themed terminal.
**Expected:** Dim frame/separators visible-but-receded; cyan model, blue directory, green/yellow/red percentages readable on both themes.
**Why human:** SGR 2 faint readability across themes cannot be asserted by byte checks (planner-deferred `<human-check>` from 01-02-PLAN; SUMMARY coverage D3/D5).

#### 2. Layout-lock prohibition sign-off (judgment tier)

**Test:** Confirm the rendered layout matches the locked decisions — full-length directory, no width-based dropping, named-16 colors only.
**Expected:** Nothing shortened, dropped, or restyled versus D-01/D-02/D-15/D-16.
**Why human:** Judgment-tier prohibition; the autonomous LLM-judge verdict (PASS) is non-authoritative by policy — flagged `unverified-prohibition — human review recommended`.

### Gaps Summary

No gaps. Every roadmap success criterion and every plan must-have truth was verified by executing the actual script against real and adversarial inputs; all four claimed commits (64b9cbe, 4c6630c, c713240, 638bb49) exist in git history. The phase completes with 2 flagged human items (dim-styling visual check, judgment-tier layout prohibition) and 1 coincidental-reliance advisory (WR-01 env-leak precondition) plus 1 out-of-contract robustness advisory (WR-02) recommended for Phase 2 hardening.

---

_Verified: 2026-08-21T18:52:49Z_
_Verifier: Claude (gsd-verifier)_
