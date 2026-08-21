# Phase 2: Git Segment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-21
**Phase:** 2-Git Segment
**Areas discussed:** Git segment colors, Frame removal fallout, Edge-state display, Latency verification

---

## Git segment colors

| Option | Description | Selected |
|--------|-------------|----------|
| Semantic per-marker | Each marker colored by what it signals — most glanceable | ✓ |
| Uniform segment color | Whole git segment in one color — calmer, less informative | |
| Branch colored, rest dim | Only branch gets color; markers recede | |

**User's choice:** Semantic per-marker

| Option | Description | Selected |
|--------|-------------|----------|
| Magenta | Only unclaimed strong ANSI-16 color; no collision with threshold colors | ✓ |
| Green when clean / yellow when dirty | Branch name as state indicator (p10k-style); overloads threshold colors | |
| Default foreground | Branch uncolored | |

**User's choice:** Magenta for branch name + `⎇` glyph

| Option | Description | Selected |
|--------|-------------|----------|
| *=yellow, ≡ dim, ≢ yellow | Attention states yellow; red reserved for critical usage | |
| *=red, ≡=green, ≢=red | Traffic-light semantics, louder line | |
| All markers dim | Markers present but quiet | |

**User's choice:** Free-text hybrid — `*`=yellow, `≡`=green, `≢`=red
**Notes:** User rejected both presets and specified their own mix: dirty stays a yellow warning, but the sync pair gets full traffic-light treatment (green upstream-present, red no-upstream). Red intentionally carries a second meaning beyond critical thresholds.

| Option | Description | Selected |
|--------|-------------|----------|
| ↓=yellow, ↑=green, #=dim | Behind=attention, ahead=positive, stash=background | ✓ |
| ↓=red, ↑=green, #=yellow | Behind shouts red; stashes visibly reminded | |
| All counts default | Symbols alone carry meaning | |

**User's choice:** ↓=yellow, ↑=green, #=dim

---

## Frame removal fallout

| Option | Description | Selected |
|--------|-------------|----------|
| Empty line | Blank second line — status stays two rows tall, layout never jumps | ✓ |
| Omit line 2 entirely | More compact but status area shrinks/grows between renders | |

**User's choice:** Empty line when line 2 has zero segments

| Option | Description | Selected |
|--------|-------------|----------|
| Bare dirname | Blue directory basename from $PWD, same fallback minus the frame | ✓ |
| Dirname + placeholder marker | Adds a dim hint that data is missing | |

**User's choice:** Bare dirname as worst-case line-1 fallback

---

## Edge-state display

| Option | Description | Selected |
|--------|-------------|----------|
| Short SHA | 7-char commit SHA via rev-parse — tells you where you are during rebase/bisect | ✓ |
| Literal (detached) | Zero extra git calls, but no commit info | |

**User's choice:** Short SHA in the branch position when detached

| Option | Description | Selected |
|--------|-------------|----------|
| Branch name as usual | Unborn branch renders `⎇ main ≢` (+ `*` if files present) — no special case | ✓ |
| Hide sync symbol in empty repos | Avoids red ≢ noise in every fresh repo | |

**User's choice:** Branch name as usual for unborn/empty repos

| Option | Description | Selected |
|--------|-------------|----------|
| Hide sync symbol | Upstream concept doesn't apply to a detached commit; red would be false alarm | ✓ |
| Show ≢ anyway | Uniform rule: no upstream → ≢ always | |

**User's choice:** Hide `≡`/`≢` entirely when detached

---

## Latency verification

| Option | Description | Selected |
|--------|-------------|----------|
| Timed test in run.sh | Permanent timed assertion against a real-repo fixture — regression-proof | ✓ |
| One-off measurement | Measure at UAT, record, no permanent test | |
| Trust the baseline | ~12ms baseline is orders of magnitude under budget | |

**User's choice:** Timed test in tests/run.sh

| Option | Description | Selected |
|--------|-------------|----------|
| No cache | Two fast git calls per render; cache stays a documented future lever | ✓ |
| Add TTL cache now | Session-keyed /tmp cache with ~5s TTL — future-proofs monorepos | |

**User's choice:** No cache

---

## Claude's Discretion

- Color span granularity (symbol+number together vs separately)
- Exact latency threshold value and portable timing mechanism (BSD + GNU)
- porcelain v2 parsing structure within the prescriptive stack constraints
- Git segment attachment at the marked seam in `statusline.sh`

## Deferred Ideas

None — discussion stayed within phase scope.
