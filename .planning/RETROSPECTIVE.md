# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-08-23
**Phases:** 4 | **Plans:** 13 (29 tasks, +1 quick task) | **Commits:** 108 over 3 days (2026-08-21 → 2026-08-23)

### What Was Built
- `statusline.sh` (432 lines, bash 3.2): two-line colorized status — model/effort/dir + git (`⎇ main* ≡ ↓2 ↑3 #2`) on line 1; context · 5h · 1w · Fable weekly with countdowns on line 2 — from one jq `@sh` pass with all 10 stdin fields type-guarded
- Never-fail contract: exit 0, zero stderr, line 1 always renders; every empty segment hides with its separator
- Dual-environment install: host `ln -sf` into `~/.claude`; Docker Sandboxes via the `kit/` sbx mixin kit with an idempotent startup `statusLine` merge; renders byte-identical host vs sandbox
- Fail-silent Fable weekly segment from the OAuth usage endpoint behind a 0600 TTL cache (+grace, negative cache, kill switch), live in both environments
- `tests/run.sh` 66 → 220 hermetic checks, `tests/sandbox.sh` 12 live checks, `tests/render-fixtures.sh` byte-diff, `tests/probe-kit-add.sh`; README with install + legend

### What Worked
- **Risk-gradient phase order** (stdin-only → git → install/dual-env → external endpoint): each phase reused the prior phase's hide/never-fail structure; Plan 01-02 and Task 2 of 02-01 needed zero script changes
- **Single jq `@sh` choke point**: both eval RCEs (CR-01, CR-02) closed at one site with byte-identical renders, instead of scattered shell guards
- **"Probe must bite" convention**: every security/regression probe demonstrated to FAIL against the pre-fix or mutated script — caught the gap that string-only probes left open (CR-02)
- **Byte-for-byte evidence over eyeballing**: raw fixture renders dumped per environment + `diff -r` proved PORT-01 mechanically; live sandbox runs gated on a real Docker Desktop action, never faked
- **Exported kill switch for the harness**: `STATUSLINE_NO_FABLE` kept 220 checks hermetic (no Keychain, no network, no `~/.claude` writes) — its absence was observed to go live during one bite run, then locked in

### What Was Inefficient
- Phase 2 needed two verification rounds and two gap-closure plans (02-03, 02-04) for the eval RCEs — type-guarding should have been a Phase 1 success criterion given `eval` was in the design from day one
- `sbx kit add` was assumed to work in the Phase 3 README, then disproved live; a quick task (260822-rbm) re-probed an install-only kit variant that was also refused — an earlier five-minute probe would have saved a doc rewrite
- Host `~/.claude/statusline.sh` drifted to a stale regular-file copy (not the symlink) between phases, so the Phase 4 host UAT first had to re-run the README install line
- Phase 4 docs reconciliation (D-52) touched REQUIREMENTS/PROJECT/ROADMAP/README after the D-51 layout correction — the brief's in-segment notation should have been challenged at requirements time

### Patterns Established
- `seg_*` renderer functions + `join_segments` with hide-empty assembly; colored spans cover the whole token, `RESET` after each span
- `GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch` parsed with a bash-3.2-safe here-string `while read` loop (no subshell variable loss)
- Epoch-arithmetic countdowns only; `iso_to_epoch` table-tested; never `date -d`/`date -r`
- Canonical script lives under `kit/files/home/.claude/`; repo is the source of truth for both environments
- Test evidence under gitignored `tests/out/<env>/`; live probes emit `[probe, not counted]` verdict lines separate from the counted summary
- Every new harness probe ships with a recorded pre-fix failure set

### Key Lessons
1. When the script `eval`s tool output, make input type-guarding a success criterion of the first phase, not a gap-closure item later
2. Probe third-party tooling assumptions (sbx, endpoint shapes) live before writing the sentence in the README — five minutes of evidence beats a reconciliation plan
3. Challenge layout notation in the brief at requirements time; two layout corrections (frames, Fable segment) each cost a docs pass
4. Hermeticity must be proven, not assumed — run the harness once with the network/credentials path deliberately enabled to confirm the guard is load-bearing
5. Keep the install target honest between phases (re-run the install line before each host UAT) or the UAT tests a stale file

### Cost Observations
- Model mix: adaptive profile (not tracked per plan — STATE.md metrics table empty)
- Sessions: ~4 working sessions across 3 days (one per phase, Phase 4 split across two)
- Notable: 13 plans averaged ~2.2 tasks; security gap-closure plans were the cheapest (single-file jq edits) but required the most verification rounds

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~4 | 4 | Established "probe must bite" and byte-diff evidence conventions; security gap closure folded into phase plans instead of inserted phases |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 220 hermetic + 12 live sandbox | all 29 v1 requirements traced; 21 threats closed (0 blocking open) | 0 (jq, git, curl only — all pre-approved) |

### Top Lessons (Verified Across Milestones)

1. Type-guard at the single ingestion choke point before the first `eval` ships — (v1.0; re-verify next milestone)
2. Probe external tooling assumptions live before documenting them — (v1.0; re-verify next milestone)
