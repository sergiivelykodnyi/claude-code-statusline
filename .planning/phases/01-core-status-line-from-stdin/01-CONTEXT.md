# Phase 1: Core Status Line from Stdin - Context

**Gathered:** 2026-08-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers `statusline.sh` rendering everything derivable from the stdin JSON payload alone: line 1 with suffix-stripped model name, reasoning effort, and directory basename; line 2 with context usage (`pct/tokens/window`) and the 5-hour / weekly rate-limit segments with reset countdowns. Includes the two-line `╭─`/`╰─` frame, ANSI colorization with usage thresholds, hide-empty segment assembly, and the never-fail contract (always exit 0, nothing on stderr, line 1 renders in every case). Excludes: git segment (Phase 2), symlink install/README (Phase 3), Fable `f()` OAuth segment (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Colors & thresholds
- **D-01:** Dim frame, colored data — `╭─`/`╰─` frame and ` · ` separators dim/gray so chrome recedes; data segments carry the color.
- **D-02:** All colors MUST remain readable on both light and dark terminal themes — use the ANSI named 16-color palette (theme-remapped by the terminal), never hard-coded 256-color or truecolor values. This was an explicit user constraint.
- **D-03:** Usage thresholds: normal below 70%, warning at ≥70%, critical at ≥90% — same cutoffs for context and both rate-limit windows.
- **D-04:** Threshold color sequence is green → yellow → red (always colored, including healthy green).
- **D-05:** Only the percentage number changes color at thresholds; the rest of the segment (labels, countdown) keeps its normal styling.
- **D-06:** Line-1 identity colors: model name cyan, directory blue, effort dim/default.

### Number formatting
- **D-07:** Percentages truncate to integer (23.7 → `23%`) — pure-bash `${PCT%.*}`, no decimals.
- **D-08:** Shortened token numbers: one decimal when the scaled value is below 10 units (`1.5M`), integer otherwise (`147k`, `200k`); drop a trailing `.0` (`1M`, not `1.0M`).
- **D-09:** Countdowns drop leading zero units: `3d:5h:57m`, `2h:50m`, `50m`, and `<1m` under one minute.
- **D-10:** A reset time already in the past renders as `(now)` — signals the window rolled over and the next render will refresh.

### Empty-state rendering
- **D-11:** Line 2 always prints, even with zero segments — a bare `╰─` keeps the box shape stable across renders.
- **D-12:** Context segment shows `0%/0/200k` (zero usage + known window size) when `used_percentage` is null/0 early in a session — it never pops in later. This is a deliberate exception to hide-over-placeholder, scoped to the context segment only.
- **D-13:** Worst-case line 1 (malformed/empty stdin, jq failure): render `╭─` plus the directory basename from `$PWD` as fallback; line 2 is a bare `╰─`; exit 0 regardless.
- **D-14:** Line 2 joins only the segments that are present with ` · `, never emitting dangling separators; order is always context → 5h → 1w.

### Width & truncation
- **D-15:** No width logic at all — the line wraps naturally in narrow terminals. No `$COLUMNS` measurement, no truncation, no segment dropping.
- **D-16:** Directory basename renders in full, never shortened.

### Claude's Discretion
- Exact ANSI escape sequences and the code structure for color helpers (within the ANSI-16 + bash 3.2 constraints).
- Exact dim styling implementation (SGR 2 vs bright-black) — pick whatever stays visible on light themes, per D-02.
- jq extraction structure (single-pass `@sh` eval per the project's prescriptive patterns).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Layout & requirements
- `project-brief.md` — the authoritative target layout, segment definitions, and whole-line examples the output must match
- `.planning/REQUIREMENTS.md` — SESH-01..03, CTX-01..02, LIM-01..04, PRES-01..04, PORT-03 (the 14 requirements this phase covers)

### Verified technical facts (research)
- `.planning/research/STACK.md` — stdin JSON contract (field-by-field, verified 2026-08-21), bash 3.2 portability rules, prescriptive jq patterns, rendering facts from official docs
- `.planning/research/PITFALLS.md` — known failure modes to design against
- `.planning/research/ARCHITECTURE.md` — intended script structure and segment assembly approach

</canonical_refs>

<code_context>
## Existing Code Insights

Greenfield — no source code exists yet (repo contains only planning docs and `project-brief.md`). `statusline.sh` will be the first code file, created at the repo root.

### Established Patterns (from project constraints, binding on this phase)
- bash 3.2-compatible syntax, `#!/bin/bash` shebang (macOS host constraint)
- Single jq pass with `@sh`-quoted eval; `// ""` for absent/null mapping; no `@tsv` + `read`
- Epoch arithmetic only for countdowns — never `date -d` / `date -r`
- `printf '%b'` or `$'\033[...]'` literals — never `echo -e`

### Integration Points
- Consumes: Claude Code stdin JSON payload (schema in `.planning/research/STACK.md`)
- Phase 2 will insert the git segment into line 1 after the directory — keep line-1 assembly extensible

</code_context>

<specifics>
## Specific Ideas

- Output must match the brief's example shape exactly: `╭─ Opus 5 (high) · myproject` / `╰─ 10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)` (git and `f()` parts arrive in later phases).
- Light/dark theme portability of colors was raised unprompted by the user — treat it as a hard requirement, not a preference.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Core Status Line from Stdin*
*Context gathered: 2026-08-21*
