# Quick Task 260826-wid: change the branch symbol ⎇ to the dot separator " · " to make Git a separate segment - Context

**Gathered:** 2026-08-26
**Status:** Ready for planning

<domain>
## Task Boundary

Remove the `⎇ ` glyph prefix from the git segment in `kit/files/home/.claude/statusline.sh`, and
promote git from a space-attached suffix of the directory segment into a first-class line-1
segment joined by the existing dim dot separator.

Current line 1: `Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2`
Target  line 1: `Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2`

Out of scope: line 2 (context / 5h / 1w / Fable), the separator string itself (`sep=" ${DIM}·${RESET} "`
already exists at line ~409 and is reused as-is), and all other segment renderers.

</domain>

<decisions>
## Implementation Decisions

### Branch color
- The branch label keeps **MAGENTA**. Only the `⎇ ` glyph and its trailing space are removed from
  `out="${MAGENTA}⎇ ${label}${RESET}"` → `out="${MAGENTA}${label}${RESET}"`.
- Rationale: preserves the git segment's existing visual identity and keeps it distinct from the
  blue directory segment now that they are peers.

### Git sub-part joining
- **Exactly one** dot separator is added — between the directory segment and the git segment.
- Inside the git segment, the dirty star, `≡`/`≢`, `↓N`/`↑N` and `#N` stay **space-joined** to the
  branch exactly as today: `main* ≡ ↓2 ↑3 #2`. Git remains one segment with internal structure.
- Mechanically: drop the `dir_seg="$dir_seg${git_seg:+ $git_seg}"` splice in `main()` and pass
  `"$git_seg"` as its own argument to `join_segments`. `join_segments` already skips empties
  (D-14/PRES-04), so outside a repo there is no dangling separator — the existing
  hide-over-placeholder behaviour (GIT-01) is preserved for free.

### Docs scope
- **In scope:** `README.md` (sample line + symbol table row) and `tests/run.sh` (all `⎇` assertions,
  including the raw-ANSI expectation at line 415).
- **Out of scope (user decision):** `project-brief.md`, `.planning/PROJECT.md`, and the archived
  `.planning/research/*`, `.planning/RETROSPECTIVE.md`, `.planning/milestones/v1.0-ROADMAP.md`.
  Flagged: `project-brief.md` and `.planning/PROJECT.md` still specify `⎇` as a requirement, so
  they will disagree with the shipped script until separately updated. Accepted as-is.
- `.claude/CLAUDE.md` line 109 mentions "hide the whole `⎇` segment" — a behavioural note, not a
  rendering spec; leave it.

### Claude's Discretion
- Comment updates inside `statusline.sh` (the segment header comment at line 139 describes
  `magenta "⎇ branch"`) — update to match the new rendering.
- Exact wording of the README symbol-table row for the branch.
- Whether to keep the `git_seg` local variable or inline `$(seg_git)` into the `join_segments` call.

</decisions>

<specifics>
## Specific Ideas

- The separator to reuse is the one already defined in `main()`:
  `sep=" ${DIM}·${RESET} "` (D-01) — do not introduce a second separator definition.
- Touch points identified:
  - `kit/files/home/.claude/statusline.sh:139` (comment), `:173` (the glyph), `~:411-413` (splice + join)
  - `README.md:8`, `README.md:20`
  - `tests/run.sh:353, 366, 381, 396, 405, 410, 415`

</specifics>

<canonical_refs>
## Canonical References

No external specs. Project conventions in `.claude/CLAUDE.md` apply: bash 3.2-compatible syntax,
`printf '%b'` over `echo -e`, no BSD/GNU-divergent flags, hide-over-placeholder for empty segments.

</canonical_refs>
