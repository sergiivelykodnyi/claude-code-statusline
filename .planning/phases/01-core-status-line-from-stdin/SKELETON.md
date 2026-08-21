# Walking Skeleton — Claude Code Status Line

**Phase:** 1
**Generated:** 2026-08-21

## Capability Proven End-to-End

Piping a Claude Code stdin JSON payload into `./statusline.sh` prints the framed, colorized two-line status — model + effort + directory on line 1, context and rate-limit segments on line 2 — with exit 0 and nothing on stderr.

This project has no DB, routing, or deployment tier. The "full stack" here is: stdin JSON → single-pass jq `@sh` eval → pure-bash formatters → segment renderers → hide-empty assembler → ANSI stdout. The Phase-1 tracer wires one payload through every one of those layers. "Dev deployment" (the `~/.claude/statusline.sh` symlink + `settings.json` wiring) is deliberately Phase 3.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Runtime | bash 3.2-compatible syntax, `#!/bin/bash`, no `set -e`/`set -u` | macOS `/bin/bash` 3.2.57 is the binding constraint; a bash-4 idiom parse-fails and blanks the line. Explicit error handling + unconditional `exit 0` (PORT-03) |
| Ingestion | ONE `jq -r '@sh "..."'` pass → `eval` into scalar vars; every field carries `// ""`; jq stderr suppressed | Locked by CONTEXT; injection-probed safe in 01-RESEARCH.md. Fallback trigger is empty `MODEL`+`DIR` after eval, never jq's exit code (empty stdin exits 0 with no output) |
| Rendering | ANSI named-16 palette stored as `$'\033[...]'` byte literals; data printed with `printf '%s'` (never `%b`, never `echo -e`); dim = SGR 2 faint | D-02 theme portability; `%s` keeps hostile data inert; SGR 2 dims whatever the theme's foreground is |
| Layout (internal layers) | palette constants → pure helpers (`shorten_num`, `fmt_duration`, `pct_color`, `join_segments`) → ingestion → segment renderers (`seg_model_effort`, `seg_dir`, `seg_context`, `seg_5h`, `seg_1w`) → assembler, all execution inside `main` | Each layer only calls layers above it (01-RESEARCH.md architecture); renderers emit `""` when data is absent so the assembler's skip-empty join implements hide-over-placeholder (PRES-04) |
| Testability | `main` invoked only when `[ "${BASH_SOURCE[0]}" = "$0" ]`; `tests/fixtures/*.json` mock payloads + `tests/run.sh` harness | Sourcing the script exposes the pure helpers for table-driven unit checks without triggering `cat`/`exit`; fixtures follow the official mock-input pattern |
| Countdowns | Pure epoch arithmetic on `resets_at - $(date +%s)` (one `date` call, reused) | `date -d` is GNU-only, `date -r` is BSD-only; arithmetic is 100% portable |
| Deployment target | Phase 3: `ln -s` into `~/.claude` + `settings.json` `statusLine` snippet with `refreshInterval` | Documented local full-stack run for Phase 1 is `./statusline.sh < tests/fixtures/full.json` |

## Stack Touched in Phase 1

- [ ] Script scaffold (`statusline.sh` at repo root, `chmod +x`, syntax-gated by `/bin/bash -n`)
- [ ] Ingestion — one real jq `@sh` eval over a real payload shape
- [ ] Formatting — real `shorten_num` / `fmt_duration` / `pct_color` helpers (verified implementations from 01-RESEARCH.md)
- [ ] Rendering — framed two-line ANSI output assembled via skip-empty joining
- [ ] Test harness — fixtures + `tests/run.sh` exercising the full pipe end-to-end (the documented local full-stack run command)

## Out of Scope (Deferred to Later Slices)

- Git segment on line 1 (Phase 2) — line-1 assembly keeps `seg_dir` as its own variable so the git segment appends after it with a space, without touching the joiner
- Symlink install, dual-environment validation, README (Phase 3)
- Fable weekly `f()` OAuth segment, credentials, curl, caching (Phase 4)
- Any width/truncation logic (D-15 — permanently out, not deferred)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: git segment (`⎇ branch* ≡ ↓N ↑N #N`) via one `git status --porcelain=v2 --branch` call
- Phase 3: symlink install verified on macOS host + Docker Sandbox, README
- Phase 4: `f(pct)` Fable weekly inside the 1w segment — cached, fail-silent, behind an adapter seam
