# Phase 1: Core Status Line from Stdin - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-21
**Phase:** 1-Core Status Line from Stdin
**Areas discussed:** Colors & thresholds, Number formatting details, Empty-state rendering, Width & truncation

---

## Colors & thresholds

**Q: Overall color approach for frame and identity segments?**

| Option | Description | Selected |
|--------|-------------|----------|
| Dim frame, colored data | Frame/separators dim gray; model/dir get stable accent colors | ✓ |
| Mostly monochrome | Default color everywhere except threshold-colored percentages | |
| Fully color-coded | Every segment its own hue | |

**User's choice:** Dim frame, colored data — via "Other" with the added constraint that colors must work in both light and dark terminal themes.
**Notes:** Theme portability is a hard requirement → ANSI named 16-color palette only, no hard-coded truecolor.

**Q: Threshold cutoffs?**

| Option | Description | Selected |
|--------|-------------|----------|
| 70% / 90% | Warning at 70, critical at 90 — standard convention | ✓ |
| 50% / 80% | Earlier warning | |
| Different per segment | Split cutoffs for context vs rate limits | |

**User's choice:** 70% / 90%

**Q: Color sequence across thresholds?**

| Option | Description | Selected |
|--------|-------------|----------|
| Green → yellow → red | Always colored, traffic-light semantics | ✓ |
| Default → yellow → red | Color only when notable | |
| Cyan → yellow → red | Color-vision-friendly variant | |

**User's choice:** Green → yellow → red

**Q: How much of the segment changes color?**

| Option | Description | Selected |
|--------|-------------|----------|
| Percentage only | Only the pct number colored | ✓ |
| Whole segment | Entire segment incl. countdown | |
| Pct + label | Color `92%/5h`, countdown neutral | |

**User's choice:** Percentage only

**Q: Accent colors for line-1 identity segments?**

| Option | Description | Selected |
|--------|-------------|----------|
| Cyan model, blue dir | Cool tones, theme-safe, no collision with status colors | ✓ |
| Magenta model, cyan dir | Warmer variant | |
| Bold default color | Weight instead of hue | |

**User's choice:** Cyan model, blue dir (effort dim/default)

---

## Number formatting details

**Q: Float percentages display?**

| Option | Description | Selected |
|--------|-------------|----------|
| Truncate to integer | 23.7 → `23%`, pure-bash `${PCT%.*}` | ✓ |
| Round to nearest | 23.7 → `24%` via printf | |
| One decimal place | 23.7 → `23.7%` | |

**User's choice:** Truncate to integer

**Q: Shortened token number precision?**

| Option | Description | Selected |
|--------|-------------|----------|
| Whole units | 147k / 200k / 1M, no decimals ever | |
| One decimal under 10 units | 1.5M when scaled value < 10, integer otherwise | ✓ |
| Always one decimal | 147.8k / 1.0M | |

**User's choice:** One decimal under 10 units (drop trailing `.0`)

**Q: Countdown edge formatting?**

| Option | Description | Selected |
|--------|-------------|----------|
| Drop leading zero units | 3d:5h:57m / 2h:50m / 50m / <1m | ✓ |
| Always show h:m | Minimum shape `0h:50m` | |
| Fully padded | Constant-width `0d:02h:50m` | |

**User's choice:** Drop leading zero units

**Q: Countdown when reset time already passed?**

| Option | Description | Selected |
|--------|-------------|----------|
| Show 'now' | Negative remaining renders `(now)` | ✓ |
| Clamp to <1m | Treat as almost-zero | |
| Hide the countdown | Drop the `(…)` part | |

**User's choice:** Show `(now)`

---

## Empty-state rendering

**Q: Line 2 with nothing to show?**

| Option | Description | Selected |
|--------|-------------|----------|
| Bare `╰─` frame | Frame always prints, box shape stable | ✓ |
| Skip line 2 entirely | One-line status until data arrives | |

**User's choice:** Bare `╰─` frame

**Q: Context segment before real usage data (null used_percentage)?**

| Option | Description | Selected |
|--------|-------------|----------|
| Show 0%/0/200k | Treat null/0 as zero usage, window size visible from start | ✓ |
| Hide until non-null | Strict hide-over-placeholder | |

**User's choice:** Show `0%/0/200k` (deliberate scoped exception to hide-over-placeholder)

**Q: Worst-case line 1 on malformed/empty stdin?**

| Option | Description | Selected |
|--------|-------------|----------|
| Frame + dir fallback | `╭─` + basename of `$PWD`; line 2 bare `╰─` | ✓ |
| Bare frames only | `╭─` / `╰─` with no content | |
| Static 'Claude' label | Placeholder model name | |

**User's choice:** Frame + dir fallback

**Q: Joining line-2 segments when some absent?**

| Option | Description | Selected |
|--------|-------------|----------|
| Join present with · | Only present segments, ` · `-separated, no dangling separators | ✓ |
| Keep positional order strict | Same + explicit ordering rule | |

**User's choice:** Join present with · (order context → 5h → 1w noted anyway)

---

## Width & truncation

**Q: Line wider than terminal?**

| Option | Description | Selected |
|--------|-------------|----------|
| Let it wrap | No width logic at all | ✓ |
| Truncate to $COLUMNS | Visible-length measurement + ellipsis | |
| Drop segments when narrow | Priority-based segment dropping | |

**User's choice:** Let it wrap

**Q: Long directory names?**

| Option | Description | Selected |
|--------|-------------|----------|
| Full basename always | Never shortened | ✓ |
| Cap with ellipsis | Truncate beyond N chars | |

**User's choice:** Full basename always (remaining width questions became moot; user confirmed done)

---

## Claude's Discretion

- Exact ANSI escape sequences and color-helper code structure (within ANSI-16 + bash 3.2 constraints)
- Dim styling implementation (SGR 2 vs bright-black) — whichever stays visible on light themes
- jq extraction structure (single-pass `@sh` eval per project patterns)

## Deferred Ideas

None — discussion stayed within phase scope.
