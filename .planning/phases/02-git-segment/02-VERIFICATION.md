---
phase: 02-git-segment
verified: 2026-08-22T07:46:33Z
status: gaps_found
score: 13/14 must-haves verified (all 5 ROADMAP success criteria + all 02-03 gap-closure truths verified; blocked by a NEW confirmed render-path RCE, CR-02)
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "5/5 success criteria verified; blocked by CR-01 RCE"
  gaps_closed:
    - "CR-01: hostile rate_limits.*.resets_at of the form x[$(cmd)] no longer reaches the $(( )) arithmetic sinks — jq `numbers // \"\"` guard on all 7 numeric fields; re-probed live on /bin/bash 3.2.57, both windows, no marker, rc 0, 0 stderr"
    - "WR-01: harness section 7.2 probes resets_at (both windows) + 3 context_window fields under /bin/bash; 7.3 probes a non-numeric numeric field for zero stderr (82 -> 95 checks, 0 failures)"
    - "WR-02: non-numeric total_input_tokens renders 10%/0/1M with 0 stderr bytes (harness 7.3 PASS, re-run)"
  gaps_remaining: []
  regressions: []
  new_gaps:
    - "CR-02: array-valued JSON in any of the 3 unguarded string fields (model.display_name, effort.level, workspace.current_dir) makes jq @sh emit multiple quoted words which eval executes as a command — reproduced live on /bin/bash 3.2.57 for all three fields (marker created, rc 0, 0 stderr). Pre-existing since Phase 1, surfaced by the post-gap-closure review; not a regression of 02-03 but the same defect class the previous verification treated as blocking."
gaps:
  - truth: "The render path must not execute attacker-controlled payload values (plan 02-03's own trust boundary: stdin JSON fields are untrusted; the jq @sh/eval seam is the single place an untrusted value can reach a code-execution context). A confirmed command-injection (RCE) fires via an array-valued string field on the primary target interpreter."
    status: failed
    reason: "CR-02 reproduced live on host /bin/bash 3.2.57 + jq 1.7.1: `{\"model\":{\"display_name\":[\"\",\"touch\",\"$M\"]}}` (and the same array in .effort.level and .workspace.current_dir) piped into statusline.sh created the marker file $M in a sandbox-writable dir, exit 0, zero stderr. Mechanism: jq @sh quotes each ARRAY ELEMENT as its own word — `jq -r '@sh \"MODEL=\\(.model.display_name // \"\")\"'` emits `MODEL='' 'touch' '/x/y'` (observed) — and `eval \"$vars\"` (statusline.sh:184) parses that as an assignment prefix followed by the command `touch /x/y`. The 02-03 guard (`| numbers // \"\"`) closed this vector for the 7 numeric fields (array in resets_at -> no marker, verified) but the plan explicitly left MODEL/EFFORT/DIR with bare `// \"\"`, and its threat register T-02-04 ('current_dir already mitigated by @sh quoting') is falsified by the array form. workspace.current_dir is the git segment's own input (seg_git: git -C \"$DIR\"), so this sits squarely on the path this phase owns. The 95/95 harness cannot see it: every injection probe (7.1/7.2/7.3) injects a STRING payload, none an ARRAY (WR-04). No later roadmap phase (3 = install/README, 4 = f() segment) addresses stdin type validation, so it is not deferrable."
    artifacts:
      - path: "statusline.sh"
        issue: "Lines 173-175: `MODEL=\\(.model.display_name // \"\")`, `EFFORT=\\(.effort.level // \"\")`, `DIR=\\(.workspace.current_dir // \"\")` carry no string-type guard; a JSON array/object there is not collapsed to one token before `eval \"$vars\"` at line 184."
      - path: "tests/run.sh"
        issue: "Sections 7.1-7.3 inject only string payloads; there is no array-payload probe for any @sh-ingested field (WR-04) — the regression net has a hole shaped exactly like CR-02, the same false-confidence failure mode WR-01 had for CR-01."
    missing:
      - "Enforce string type at the jq boundary on the 3 string fields, mirroring the numeric guard: `MODEL=\\(.model.display_name // \"\" | strings // \"\")`, `EFFORT=\\(.effort.level // \"\" | strings // \"\")`, `DIR=\\(.workspace.current_dir // \"\" | strings // \"\")` — verified on host: array display_name -> `MODEL=''`; a normal string passes unchanged. Keep it inside the single jq program (PORT-02 one-jq-pass budget). All 10 fields are then uniformly type-guarded before eval."
      - "Add an array-payload injection probe per @sh-ingested field (at minimum .model.display_name, .effort.level, .workspace.current_dir; ideally all 10) run under /bin/bash: `jq \"$path = [\\\"\\\",\\\"touch\\\",\\\"tests/.pwned\\\"]\" tests/fixtures/full.json | /bin/bash \"$SL\"`, asserting exit 0 and `[ ! -e tests/.pwned ]`, with fixed check names. Confirm the probe FAILS against the pre-fix script (as 02-03 did for resets_at) so it provably bites."
      - "Optional (WR-03, robustness/noise, not RCE): well-typed non-integer numbers still leak arithmetic/`[` errors to stderr — verified on host: resets_at=1755800000.5 -> 103 stderr bytes (`syntax error: invalid arithmetic operator`), resets_at=1e100 -> 76 bytes (`value too great for base`), used_percentage=1e2 / total_input_tokens=100000.7 -> `integer expression expected`. A jq canonicalizer such as `(numbers | floor | select(. >= 0 and . < 1e15)) // \"\"` on CTX_TOK/CTX_WIN/P5_RST/P7_RST (and `floor` on the PCT fields) closes it; add a zero-stderr probe for a float resets_at. Contract-shaped integer payloads are unaffected, which is why this is a warning, consistent with the Phase 1 verification's 'out-of-contract advisory' treatment of the same residual."
human_verification:
  - test: "Render the full-form git segment in a live terminal on both a light and a dark theme and read line 1 at a glance."
    expected: "Every marker is legible and distinguishable: magenta branch, yellow dirty *, green ≡ / red ≢, yellow ↓N, green ↑N, dim #N — no marker washes out against either background."
    why_human: "Color legibility and glanceability in a real terminal is a visual judgment no string/byte assertion can prove (plan 01 D5, human_judgment: true; mirrors Phase 1's dim-readability UAT). Carried forward unchanged from the previous verification; unaffected by 02-03."
---

# Phase 2: Git Segment Verification Report (re-verification after gap-closure plan 02-03)

**Phase Goal:** Line 1 shows the full git situation at a glance in any repo state, without slowing the render
**Verified:** 2026-08-22T07:46:33Z
**Status:** gaps_found
**Re-verification:** Yes — after gap-closure plan 02-03 (commits `ac5c87a` fix, `4775cf2` test, `3d7a8f2` docs; all present in `git log`)

## Goal Achievement

The git segment still meets its goal on every functional axis: all five ROADMAP success criteria re-verified against the current code (harness re-run: 95 checks, 0 failures, exit 0 under `/bin/bash` 3.2.57), no regressions. The previous blocking gap **CR-01** (resets_at arithmetic RCE) and its supporting warnings **WR-01 / WR-02** are confirmed closed by live re-probe — not by trusting the SUMMARY. However, the fresh code review's **CR-02** was independently reproduced here: an array-valued JSON string field (`model.display_name`, `effort.level`, or `workspace.current_dir`) escapes jq `@sh` per-element quoting into multiple `eval` words and executes an arbitrary command, silently (rc 0, 0 stderr), on the primary target interpreter. This is the same defect class — a confirmed RCE reachable from the stdin payload through the shared ingestion seam this phase modified and consumes — that the previous verification correctly treated as blocking, and no later phase covers input validation. The phase therefore remains `gaps_found`, with a narrow, one-line-per-field remediation.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Full dirty+upstream+behind/ahead+stash repo → line 1 ends `⎇ main* ≡ ↓2 ↑3 #2` (SC1) | ✓ VERIFIED | Harness re-run: `git full form: line 1` PASS (exact equality), exit 0, 0 stderr |
| 2 | Outside a repo the whole git segment and its joiner space are absent (SC2) | ✓ VERIFIED | `git not-a-repo: line 1` = `Opus 5 (high) · plaindir` PASS; seg_git returns 0 on git failure (statusline.sh:92); seam `${git_seg:+ $git_seg}` (:195) |
| 3 | Clean / detached / no-upstream / unborn render correctly; zero-value counters never appear (SC3) | ✓ VERIFIED | Harness: clean in-sync `⎇ main ≡`, detached `⎇ <sha>`, no-upstream `⎇ feature/x-1 ≢`, unborn `⎇ main* ≢`, boundary-ones `↓1 ↑1 #1` all PASS; `-gt 0` gates at :124-126 |
| 4 | Render well under ~300ms, single jq pass + one primary git status call (SC4, PORT-02) | ✓ VERIFIED | `latency: 10 full renders in 0s (budget 2s)` PASS; grep gates: `jq -r` ×1, `porcelain=v2` ×1, `git -C` lines missing `GIT_OPTIONAL_LOCKS=0` = 0; numeric guard added INSIDE the one jq program (count 7 in the jq block) |
| 5 | Frame prefixes removed; both lines flush-left; always exactly two lines (SC5) | ✓ VERIFIED | `grep -c '╭─\|╰─' statusline.sh` = 0; fixture line checks + `empty: exactly 2 output lines (D-22)` PASS |
| 6 | Worst-case (empty/malformed stdin): line 1 bare blue dir basename, line 2 blank, exit 0 | ✓ VERIFIED | `empty`/`malformed` fixtures: line1 `$HERE`, line2 ``, exit 0, 0 stderr — PASS |
| 7 | Every git invocation carries `GIT_OPTIONAL_LOCKS=0`; read-only (status/rev-parse/rev-list) | ✓ VERIFIED | grep: 0 unguarded `git -C`; only status/rev-parse/rev-list at :92,113,116 |
| 8 | Ahead/behind pass through verbatim at any magnitude (backstop) | ✓ VERIFIED (direct code observation) | :101-102 strip sign only; :124-125 print `${behind}`/`${ahead}` verbatim; no shorten_num in seg_git |
| 9 | Stash count passes through verbatim at any magnitude (backstop) | ✓ VERIFIED (direct code observation) | :116-117, :126 print `${stash}` verbatim; only arithmetic is the `-gt 0` gate |
| 10 | 02-03: hostile `x[$(cmd)]` in `five_hour.resets_at` OR `seven_day.resets_at` executes nothing on /bin/bash 3.2.57 (CR-01 closed) | ✓ VERIFIED | Live re-probe this run: both windows, marker files absent, rc 0, 0 stderr; harness 7.2 `five_hour resets_at` / `seven_day resets_at` ... `not created` PASS |
| 11 | 02-03: all 7 numeric fields type-enforced at the single jq @sh boundary | ✓ VERIFIED | `sed -n '/jq -r/,/2>\/dev\/null)/p' statusline.sh \| grep -c 'numbers // ""'` = 7 (:176-182); `jq -r` count = 1; array in resets_at → no marker (guard also neutralizes arrays) |
| 12 | 02-03: non-numeric numeric field → zero stderr bytes (WR-02 closed) | ✓ VERIFIED | Harness 7.3 `non-numeric probe: total_input_tokens stderr bytes` PASS, line 2 `10%/0/1M · 50%/5h (now) · 15%/1w (now)` PASS |
| 13 | 02-03: full harness green on /bin/bash 3.2.57 with original 82 + new probes (WR-01 closed) | ✓ VERIFIED | Ran once: `95 checks, 0 failures`, rc 0; all 13 new named PASS lines present |
| 14 | The render path must not execute attacker-controlled payload values (trust boundary of 02-03 / carried from previous gap) | ✗ FAILED | **CR-02 reproduced live**: array `["","touch","$M"]` in `.model.display_name`, `.effort.level`, and `.workspace.current_dir` each created the marker, rc 0, 0 stderr, under `/bin/bash` 3.2.57. jq emits `MODEL='' 'touch' '/x/y'`; `eval "$vars"` (:184) runs it |

**Score:** 13/14 truths verified (0 present, behavior-unverified). All 5 ROADMAP success criteria verified; all 4 02-03 gap-closure truths verified; one security truth FAILED (new vector, same class as CR-01).

### Prohibitions (must-NOT checks)

| # | Statement | Status | Evidence |
| --- | --- | --- | --- |
| P1 | No network operation in the render path (no `git fetch`, no `curl`) | ✓ VERIFIED | `grep -cE 'git .*fetch\|curl' statusline.sh` = 0 |
| P2 | No repository mutation during render (read-only, `GIT_OPTIONAL_LOCKS=0`) | ✓ VERIFIED | All three git calls read-only and guarded (:92,113,116) |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `statusline.sh` | seg_git renderer, MAGENTA constant, frameless two-line assembly, numbers-guard on 7 numeric fields, `local ... NOW LINE1 LINE2` | ✓ VERIFIED (functionally) / ✗ security gap | seg_git ×1, MAGENTA ×1, frame chars ×0, 7 `numbers // ""` in jq block, `local` line :170 includes NOW LINE1 LINE2 (IN-01 closed). **String fields :173-175 unguarded (CR-02).** Working tree clean vs commit `ac5c87a` |
| `tests/run.sh` | Frame-free expectations, 35m whitelist, temp-repo matrix, latency budget, section 7.2 resets_at/context_window probes under /bin/bash, 7.3 non-numeric probe | ✓ VERIFIED (coverage gap WR-04) | 95 checks; 7.2 loop over 5 label:path pairs, all `/bin/bash "$SL"`, `[ ! -e tests/.pwned ]`; 7.3 via `$ERRTMP`. **No array-payload probe** (`grep -c '\[\\"\\",' tests/run.sh` = 0) |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| main() | seg_git() | `git_seg` captured once, appended to dir_seg with a plain space | ✓ WIRED | :192, :195 `dir_seg="$dir_seg${git_seg:+ $git_seg}"` |
| seg_git() | git porcelain v2 | single `GIT_OPTIONAL_LOCKS=0 git -C` status, bash-3.2 here-string read loop | ✓ WIRED | :92 + :95-107 |
| jq @sh boundary → eval → `$(( P5_RST - NOW ))` / `$(( P7_RST - NOW ))` | 02-03 key link: numeric guard is the single choke point | ✓ WIRED | :176-182 guard; :147/:157 sinks only reachable through `[ -n "$P5_RST" ]` after the guard empties non-numbers; live probe confirms |
| jq @sh boundary → eval (string fields) | MODEL/EFFORT/DIR | `// ""` only | ✗ BROKEN (security) | Array value yields multiple words → command execution at :184 (CR-02) |
| tests/run.sh | statusline.sh | `jq --arg d ... workspace.current_dir` mutation piped in | ✓ WIRED | git_render() |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| seg_git | branch/dirty/ahead/behind/stash | live `git status --porcelain=v2 --branch` + `rev-list refs/stash` on `$DIR` | ✓ real git state from temp repos | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Full harness green on host bash 3.2.57 | `/bin/bash tests/run.sh` (run once) | `95 checks, 0 failures`, rc 0 | ✓ PASS |
| CR-01 closed (five_hour + seven_day `resets_at` = `x[$(touch M)]`) | full-script render under /bin/bash | no marker, rc 0, 0 stderr | ✓ PASS |
| Array in numeric field (`resets_at` = `["","touch",M]`) | full-script render | no marker (numbers guard) | ✓ PASS |
| **CR-02: array in `.model.display_name`** | `jq '.model.display_name = ["","touch","M"]' \| /bin/bash statusline.sh` | **MARKER CREATED**, rc 0, 0 stderr | ✗ FAIL (security blocker) |
| **CR-02: array in `.effort.level`** | same | **MARKER CREATED**, rc 0, 0 stderr | ✗ FAIL (security blocker) |
| **CR-02: array in `.workspace.current_dir`** | same | **MARKER CREATED**, rc 0, 0 stderr | ✗ FAIL (security blocker) |
| Object in `.workspace.current_dir` | `{"workspace":{"current_dir":{"a":"b"}}}` | rc 0, 0 stderr, no execution (object quotes as one token) | ℹ not exploitable via object, only array |
| jq @sh mechanism | `jq -r '@sh "MODEL=\(.model.display_name // "")"'` on array input | `MODEL='' 'touch' '/x/y'` | ℹ confirms per-element quoting |
| WR-03: `resets_at` float / exponent | `1755800000.5` / `1e100` | 103 / 76 stderr bytes (`invalid arithmetic operator`, `value too great for base`), rc 0 | ⚠ WARNING (fail-silent contract breached for out-of-contract numbers) |
| WR-03: `used_percentage=1e2`, `total_input_tokens=100000.7` | full-script render | 244 / 130 stderr bytes (`integer expression expected`) | ⚠ WARNING |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist; the project's runnable check is `tests/run.sh`, executed above (rc 0, 95/0).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| GIT-01 | 02-01 | Branch prefixed `⎇`; hidden outside a repo | ✓ SATISFIED | full-form + not-a-repo harness checks |
| GIT-02 | 02-01 | `*` suffix on dirty/untracked tree | ✓ SATISFIED | full-form (`main*`), unborn (`main*`), verbatim slashed branch |
| GIT-03 | 02-01 | `≡` with upstream, `≢` without | ✓ SATISFIED | clean in-sync `≡`; no-upstream red `≢` byte-asserted |
| GIT-04 | 02-01 | `↓N`/`↑N`, hidden at zero | ✓ SATISFIED | boundary-ones, full-form, clean |
| GIT-05 | 02-01 | `#N` stash, hidden at zero | ✓ SATISFIED | boundary-ones, full-form, clean |
| GIT-06 | 02-01, 02-02, 02-03 | Edge states render/degrade correctly | ✓ SATISFIED | 7-state matrix + malformed-input degradation (7.3) |
| PORT-02 | 02-01, 02-02, 02-03 | Fast render, single jq pass + one git status call | ✓ SATISFIED | latency PASS; grep gates hold after the guard was added inside the one jq program |

All 7 declared requirement IDs appear in PLAN frontmatter (02-01: all 7; 02-02: GIT-06, PORT-02; 02-03: PORT-02, GIT-06) and in REQUIREMENTS.md mapped to Phase 2. No orphaned requirements. As before, CR-02 is a security-posture defect orthogonal to these functional requirements (none asserts input-type validation), which is why all 7 read SATISFIED while the phase is still blocked. Note for the Phase 1 contract PORT-03 ("never emits stderr noise"): CR-02 preserves rc 0 / 0 stderr (the RCE is silent); WR-03 breaches the stderr clause only for out-of-contract non-integer numbers.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| statusline.sh | 173-175 (source), 184 (sink) | Array-valued string field → `@sh` multi-word → `eval` executes it | 🛑 BLOCKER (CR-02, reproduced live ×3 fields) | Silent arbitrary local command execution on every render given a hostile payload value |
| tests/run.sh | 147-188 | Injection probes inject only string payloads; no array vector | ⚠ WARNING (WR-04) | Suite is 95/95 green while the RCE is live — same false-confidence mode as WR-01 |
| statusline.sh | 147, 157, 23-24, 51-52 | Well-typed float/exponent numbers pass the `numbers` guard and leak arithmetic/`[` errors to stderr | ⚠ WARNING (WR-03) | Fail-silent breach for out-of-contract numeric values; not injecting |
| statusline.sh | 111 | Branch literally named `(detached)` misdetected as detached HEAD | ℹ INFO (IN-02) | Cosmetic, near-impossible branch name |
| 02-03-PLAN.md threat model | T-02-04 | Disposition "accept — current_dir already mitigated by @sh quoting" | ℹ INFO | Falsified by CR-02; should become "mitigate" with the strings guard + array probe |

No TBD/FIXME/XXX debt markers in the modified files (the two `XXX` grep hits are `mktemp` templates in tests/run.sh:43-44, not markers).

### Human Verification Required

**1. Live-terminal color legibility (plan 01 D5)** — carried forward unchanged.

**Test:** Render the full-form git segment in a real terminal on both a light and a dark theme; read line 1 at a glance.
**Expected:** magenta branch, yellow `*`, green `≡` / red `≢`, yellow `↓N`, green `↑N`, dim `#N` are each legible and distinguishable against both backgrounds.
**Why human:** Color legibility/glanceability is a visual judgment no assertion can prove.

### Gaps Summary

Gap-closure plan 02-03 did exactly what it promised and it is confirmed by live re-probe, not by its SUMMARY: the `numbers` guard on all 7 numeric fields severs the CR-01 `resets_at` → `$(( ))` path on `/bin/bash` 3.2.57, the harness now probes every arithmetic-reachable field under `/bin/bash` (95/95), and the WR-02 stderr leak for non-number types is gone. Nothing regressed — all five ROADMAP success criteria, both prohibitions, and all seven requirements re-verify.

The phase still cannot pass because the same defect class re-appears through a vector 02-03 deliberately left open. The plan instructed "Do NOT touch the string fields MODEL, EFFORT, DIR" and its threat register accepted `current_dir` as already safe via `@sh` quoting. That assumption holds only for scalar strings: jq `@sh` quotes each element of an **array** as a separate word, so `{"model":{"display_name":["","touch","/path"]}}` becomes `MODEL='' 'touch' '/path'` and `eval "$vars"` executes `touch /path`. I reproduced this for all three string fields on the host interpreter (marker created, exit 0, zero stderr). `workspace.current_dir` is the very field the git segment consumes, the previous verification's standard was that a confirmed stdin-reachable RCE in the shared ingestion seam blocks the phase, and no later phase covers input validation — so this is an actionable Phase 2 gap, not a deferral. The fix is symmetric to 02-03: `| strings // ""` on the three string fields inside the same jq program (verified to collapse arrays to `''` while passing normal strings), plus an array-payload probe per field run under `/bin/bash` so the harness can finally see this vector (WR-04). WR-03 (float/exponent stderr noise) is an optional robustness follow-on, consistent with Phase 1's out-of-contract advisory.

---

_Verified: 2026-08-22T07:46:33Z_
_Verifier: Claude (gsd-verifier)_
