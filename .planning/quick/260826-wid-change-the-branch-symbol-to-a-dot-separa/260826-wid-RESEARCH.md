# Quick Task 260826-wid: branch glyph ⎇ → dot separator — Research

**Researched:** 2026-08-26
**Domain:** single-file bash 3.2 rendering change + regression-test expectations
**Confidence:** HIGH (every finding read from the repo files this session; the change was prototyped and rendered)

## Summary

This is a two-line code change in `kit/files/home/.claude/statusline.sh` plus six expected-string
updates and one raw-ANSI expectation in `tests/run.sh`, and two lines in `README.md`. There is
exactly one copy of the script in the repo (`find . -name statusline.sh` → one hit), so there is no
second file to keep in sync.

I prototyped the exact edit into a scratch copy and rendered it. Results: line 1 becomes
`Opus 5 (high) · claude-code-statusline · main* ≡`, and **all 8 fixture renders are byte-identical
to the current script** (fixtures point at `/tmp/myproject`, which is not a repo, so the git segment
is empty in every fixture). That means `tests/render-fixtures.sh` and the sandbox PORT-01/PORT-04
byte diffs are untouched by this change — only the real-temp-repo assertions in section 8 of
`tests/run.sh` move.

Baseline before the change: `220 checks, 0 failures`.

**Primary recommendation:** edit `statusline.sh:173` (drop the glyph), delete the splice at
`statusline.sh:412` and add `"$git_seg"` as a fourth argument at `:413`, refresh the two comments at
`:139` and `:410-411`, update the seven `⎇` sites in `tests/run.sh`, and update `README.md:8` and
`:20`. Then re-copy the script to `~/.claude/statusline.sh` (the installed file is a **copy**, not a
symlink).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Branch color**
- The branch label keeps **MAGENTA**. Only the `⎇ ` glyph and its trailing space are removed from
  `out="${MAGENTA}⎇ ${label}${RESET}"` → `out="${MAGENTA}${label}${RESET}"`.
- Rationale: preserves the git segment's existing visual identity and keeps it distinct from the
  blue directory segment now that they are peers.

**Git sub-part joining**
- **Exactly one** dot separator is added — between the directory segment and the git segment.
- Inside the git segment, the dirty star, `≡`/`≢`, `↓N`/`↑N` and `#N` stay **space-joined** to the
  branch exactly as today: `main* ≡ ↓2 ↑3 #2`. Git remains one segment with internal structure.
- Mechanically: drop the `dir_seg="$dir_seg${git_seg:+ $git_seg}"` splice in `main()` and pass
  `"$git_seg"` as its own argument to `join_segments`. `join_segments` already skips empties
  (D-14/PRES-04), so outside a repo there is no dangling separator — the existing
  hide-over-placeholder behaviour (GIT-01) is preserved for free.

**Docs scope**
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

### Deferred Ideas (OUT OF SCOPE)
Line 2 (context / 5h / 1w / Fable), the separator string itself (`sep=" ${DIM}·${RESET} "` is reused
as-is), all other segment renderers, and the out-of-scope docs listed above.
</user_constraints>

## Project Constraints (from CLAUDE.md)

| Directive | Relevance here |
|-----------|----------------|
| bash **3.2-compatible syntax** only (macOS `/bin/bash` 3.2.57) | The replacement uses only positional function args — 3.2-safe. Nothing new introduced. |
| `printf '%b'` / `$'\033[…]'` over `echo -e` | Unchanged — palette already uses `$'\033[…]'` literals at `statusline.sh:26-33`. |
| No BSD/GNU-divergent flags | Unchanged — no `date`/`stat`/`sed -i` involved in the edit itself. |
| Hide-over-placeholder for empty segments | Preserved by `join_segments`' empty-skip — verified below. |
| GSD workflow enforcement (no direct edits outside a GSD command) | Planner/executor runs under `/gsd-quick`. |

## 1. Exact edit points — `kit/files/home/.claude/statusline.sh`

There are **three** required edits and **one** optional comment refresh.

### Edit 1 — `statusline.sh:173` (the glyph)  — REQUIRED

Current [VERIFIED: kit/files/home/.claude/statusline.sh:173, read this session]:
```bash
  out="${MAGENTA}⎇ ${label}${RESET}"
```
Replacement (verbatim from CONTEXT.md):
```bash
  out="${MAGENTA}${label}${RESET}"
```

### Edit 2 — `statusline.sh:410-412` (delete the splice) — REQUIRED

Current [VERIFIED: kit/files/home/.claude/statusline.sh:405-414, read this session]:
```bash
  sep=" ${DIM}·${RESET} "                     # dim separator (D-01)

  model_seg=$(seg_model_effort)
  dir_seg=$(seg_dir)
  git_seg=$(seg_git)
  # Phase 2: the git segment is attached to the directory with a plain
  # space; empty outside a repo, so no trailing space leaks (GIT-01).
  dir_seg="$dir_seg${git_seg:+ $git_seg}"
  body=$(join_segments "$sep" "$model_seg" "$dir_seg")
  LINE1="${body}${RESET}"
```
Replacement (lines 410-411 comment + line 412 splice deleted, line 413 gains the 4th arg):
```bash
  sep=" ${DIM}·${RESET} "                     # dim separator (D-01)

  model_seg=$(seg_model_effort)
  dir_seg=$(seg_dir)
  git_seg=$(seg_git)
  # Git is a first-class line-1 segment joined by the dim dot; join_segments
  # skips it when empty, so outside a repo no separator leaks (GIT-01/D-14).
  body=$(join_segments "$sep" "$model_seg" "$dir_seg" "$git_seg")
  LINE1="${body}${RESET}"
```

Keep `git_seg` in the `local` declaration at `statusline.sh:379`:
```bash
  local input vars sep model_seg dir_seg git_seg body NOW LINE1 LINE2 FAB_PCT FAB_RST
```
[VERIFIED: kit/files/home/.claude/statusline.sh:379]. **If** the executor takes the discretionary
option of inlining `$(seg_git)` into the `join_segments` call, `git_seg` must be removed from that
`local` list too, or shellcheck's advisory pass (`tests/run.sh` section 10) will flag an unused
assignment. Recommendation: **keep the variable** — it costs nothing, matches the `model_seg`/
`dir_seg` style, and keeps the diff to the three lines above.

### Edit 3 — `statusline.sh:139` (segment header comment) — REQUIRED by discretion note

Current [VERIFIED: kit/files/home/.claude/statusline.sh:139-143]:
```bash
# Git segment: magenta "⎇ branch", yellow dirty star, green/red sync symbol,
# yellow behind / green ahead counts, dim stash count — hidden entirely
# outside a repo (GIT-01..05, D-17..D-20, D-24..D-27). One primary status
# call parsed below, plus one stash count; all read-only and lock-free via
# GIT_OPTIONAL_LOCKS=0, uncached per D-29 (PORT-02).
```
Replace only the first line:
```bash
# Git segment: magenta branch label, yellow dirty star, green/red sync symbol,
```

### Nothing else in the script changes

- `grep -n 'COLUMNS\|wc -c\|${#' statusline.sh` → **no matches**. There is no width math anywhere,
  so removing a 3-byte glyph cannot shift any truncation/padding logic. [VERIFIED: grep, this session]
- The script header comment (`statusline.sh:1-23`) describes behaviour, not the glyph — no change.
- `seg_dir()` (`:134-138`) is untouched.

## 2. Behavioural-equivalence check

`join_segments` [VERIFIED: kit/files/home/.claude/statusline.sh:111-119, read this session]:
```bash
# join_segments SEP PARTS... -> parts joined by SEP, empties skipped
# (D-14/PRES-04: never a dangling separator).
join_segments() {
  local sep="$1" out="" part; shift
  for part in "$@"; do
    [ -n "$part" ] && out="${out:+$out$sep}$part"
  done
  printf '%s' "$out"
}
```
The `[ -n "$part" ]` guard plus `${out:+$out$sep}` means a separator is emitted **only between two
non-empty parts** — never leading, never trailing. Passing an empty `$git_seg` is therefore exactly
equivalent to the old `${git_seg:+ …}` splice producing nothing.

### State-by-state comparison (prototyped and rendered this session)

| State | Old line 1 (stripped) | New line 1 (stripped) | Delta |
|-------|----------------------|----------------------|-------|
| not a repo | `Opus 5 (high) · plaindir` | `Opus 5 (high) · plaindir` | **none** (verified byte-identical) |
| clean, in sync | `… · w ⎇ main ≡` | `… · w · main ≡` | glyph→dot separator |
| dirty, ahead/behind/stash | `… · w ⎇ main* ≡ ↓2 ↑3 #2` | `… · w · main* ≡ ↓2 ↑3 #2` | glyph→dot separator |
| detached HEAD | `… · det ⎇ <sha>` | `… · det · <sha>` | glyph→dot separator |
| unborn branch | `… · unborn ⎇ main* ≢` | `… · unborn · main* ≢` | glyph→dot separator |
| no upstream | `… · noup ⎇ feature/x-1 ≢` | `… · noup · feature/x-1 ≢` | glyph→dot separator |
| `DIR` empty (empty/malformed fixtures) | `… · claude-code-statusline` | same | **none** — `seg_git` returns at `:145` on empty `DIR` |

**The only observable difference is the dir↔git joiner**: the raw bytes go from a single
`0x20` space to `" \033[2m·\033[0m "`. Everything else is bit-stable:

- `LINE1="${body}${RESET}"` is unchanged, so the trailing double-`RESET` (`\e[0m\e[0m`) that the
  current script emits is still emitted, in the same place. [VERIFIED: statusline.sh:414]
- ANSI ordering inside the git segment is unchanged; only the 3 bytes of `⎇` plus one space are
  removed from inside the magenta span, so the span becomes `\e[35mmain\e[0m`.
- `dir_seg` is **always** non-empty (`seg_dir` always prints at least `${BLUE}${RESET}`), so the
  `model · dir` join behaves identically whether or not git renders. [VERIFIED: statusline.sh:134-138]
- Exit code stays `0` unconditionally (`statusline.sh` `exit 0`, PORT-03) — untouched.

**Byte-level regression proof run this session:** all 8 files in `tests/fixtures/` rendered through
the current script and through the prototype produce **byte-identical output** (`cat -v` compared).
Consequence: `tests/render-fixtures.sh` (repo↔installed) and `tests/sandbox.sh` (host↔sandbox)
byte diffs — PORT-01 / PORT-04 — need **no** baseline regeneration.

Prototype raw line 1 rendered against this repo directory (`cat -v`):
```
^[[36mOpus 5^[[0m ^[[2m(high)^[[0m ^[[2m·^[[0m ^[[34mclaude-code-statusline^[[0m ^[[2m·^[[0m ^[[35mmain^[[0m^[[33m*^[[0m ^[[32m≡^[[0m^[[0m
```
Prototype raw line 1 for a non-repo directory — note no trailing separator:
```
^[[36mOpus 5^[[0m ^[[2m(high)^[[0m ^[[2m·^[[0m ^[[34mmyproject^[[0m^[[0m
```

## 3. Test surface — `tests/run.sh`

Seven `⎇` sites, all in section 8. Old values quoted verbatim from the file
[VERIFIED: tests/run.sh:353,366,381,395-396,405,410,415, read this session].

| Line | Old expected | New expected |
|------|--------------|--------------|
| 353 | `"Opus 5 (high) · w ⎇ main ≡"` | `"Opus 5 (high) · w · main ≡"` |
| 366 | `"Opus 5 (high) · w ⎇ main ≡ ↓1 ↑1 #1"` | `"Opus 5 (high) · w · main ≡ ↓1 ↑1 #1"` |
| 381 | `"Opus 5 (high) · w ⎇ main* ≡ ↓2 ↑3 #2"` | `"Opus 5 (high) · w · main* ≡ ↓2 ↑3 #2"` |
| 396 | `"Opus 5 (high) · noup ⎇ feature/x-1 ≢"` | `"Opus 5 (high) · noup · feature/x-1 ≢"` |
| 405 | `"Opus 5 (high) · det ⎇ $DSHA"` | `"Opus 5 (high) · det · $DSHA"` |
| 410 | `"Opus 5 (high) · unborn ⎇ main* ≢"` | `"Opus 5 (high) · unborn · main* ≢"` |
| 415 | raw-ANSI `want=…` — see below | see below |

### Line 415 — the raw-ANSI expectation

Current [VERIFIED: tests/run.sh:415]:
```bash
want="${ESC}[35m⎇ main${ESC}[0m${ESC}[33m*${ESC}[0m ${ESC}[32m≡${ESC}[0m ${ESC}[33m↓2${ESC}[0m ${ESC}[32m↑3${ESC}[0m ${ESC}[2m#2${ESC}[0m"
```
Minimal correct replacement (glyph removed from the magenta span):
```bash
want="${ESC}[35mmain${ESC}[0m${ESC}[33m*${ESC}[0m ${ESC}[32m≡${ESC}[0m ${ESC}[33m↓2${ESC}[0m ${ESC}[32m↑3${ESC}[0m ${ESC}[2m#2${ESC}[0m"
```
**Recommended replacement** — extend the substring leftward through the new joiner so the raw-byte
check also proves the dot join, not just the glyph removal:
```bash
want="${ESC}[34mw${ESC}[0m ${ESC}[2m·${ESC}[0m ${ESC}[35mmain${ESC}[0m${ESC}[33m*${ESC}[0m ${ESC}[32m≡${ESC}[0m ${ESC}[33m↓2${ESC}[0m ${ESC}[32m↑3${ESC}[0m ${ESC}[2m#2${ESC}[0m"
```
(`${ESC}[34mw${ESC}[0m` is `seg_dir`'s output for the `w` repo; `sep` expands to
`" ${ESC}[2m·${ESC}[0m "` — space, SGR-2, `·`, SGR-0, space.) This matches the rendered prototype
bytes exactly.

If the extended form is used, also widen the check label on line 416 (currently
`"git color bytes: magenta branch, yellow *, green ≡, yellow ↓2, green ↑3, dim #2"`) to mention the
dim dot joiner.

### Would any test silently pass?

- **Yes, one:** line 415/417 is a `case "$FULL_RAW" in *"$want"*)` **substring** match scoped to the
  git segment interior. In its minimal form it proves the glyph is gone but says nothing about the
  dir↔git joiner — it would pass even if Edit 2 were forgotten. This is why the extended `want` is
  recommended. [VERIFIED: tests/run.sh:415-418]
- **No other test is at risk.** All six stripped-line-1 checks use `check_eq` against a whole-line
  literal (`check_eq NAME EXPECTED ACTUAL`, exact `[ "$2" = "$3" ]` — tests/run.sh:30-38), so they
  fail loudly if either half of the change is missing. The only interpolation anywhere in them is
  `$DSHA` at line 405, which carries the SHA only; the separator is literal text.
- Line 337 (`check_eq "git not-a-repo: line 1" "Opus 5 (high) · plaindir" "$l1"`) is the
  no-dangling-separator guard and **must not change** — it is the regression test that Edit 2 did
  not break GIT-01.

### Comment refreshes in `tests/run.sh` (cosmetic, recommended)

| Line | Current text | Suggested |
|------|--------------|-----------|
| 333 | `# 8.1 not-a-repo: segment and its joiner space entirely absent (GIT-01).` | `… segment and its dot joiner entirely absent (GIT-01).` |
| 413 | `# exactly: magenta branch span incl. glyph, yellow star, green has-upstream` | `… magenta branch span, yellow star, green has-upstream` |

### Untouched test surface

- `run_fixture` expectations (tests/run.sh:149-153) — all fixtures use `/tmp/myproject`, a non-repo,
  so line 1 has no git segment. **No change.** [VERIFIED: tests/fixtures/*.json `current_dir`]
- Section 8.7 palette-purity loop (tests/run.sh:425-434) — allows `2m` already; the new dim dot adds
  no new SGR code. **No change.**
- Section 9 latency budget, section 10 shellcheck advisory — **no change**.
- All Fable / line-2 checks — **no change**.
- `tests/render-fixtures.sh`, `tests/sandbox.sh`, `tests/probe-kit-add.sh` — **no change** (fixture
  renders proven byte-identical).

## 4. How to run the suite

```sh
/bin/bash tests/run.sh
```
Run from anywhere — the harness `cd`s to the repo root itself (tests/run.sh:16). It is hermetic:
`STATUSLINE_NO_FABLE=1` is exported at the top (D-64), so no network and no Keychain access.

**Interpreting output:** one `PASS <name>` or `FAIL <name>` line per check (a FAIL prints
`expected:` / `actual:`), then a final summary line and a matching exit code:
```
220 checks, 0 failures
```
Exit `0` iff `FAILS -eq 0` (tests/run.sh last line). `INFO` lines (shellcheck advisory, installed
path) never affect the result.

**Baseline measured this session (before any edit): `220 checks, 0 failures`.** The check count
should stay at 220 after the change unless a new check is added.

Quick manual eyeball of the new line 1:
```sh
jq --arg d "$PWD" '.workspace.current_dir=$d' tests/fixtures/full.json | /bin/bash kit/files/home/.claude/statusline.sh
```

Optional byte-level portability dump (only if the installed copy has been refreshed first):
```sh
/bin/bash tests/render-fixtures.sh tests/out/host
```

## 5. Pitfalls specific to this repo

1. **The installed script is a COPY, not a symlink.** `ls -l ~/.claude/statusline.sh` →
   `-rwxr-xr-x … 21023 Aug 24 17:00` (regular file), currently `diff`-identical to the repo
   [VERIFIED: `ls -l` + `diff -q`, this session]. After the edit the live status line will keep
   showing `⎇` until it is re-copied, and `tests/render-fixtures.sh`'s installed↔repo diff (PORT-04)
   will **fail**. Re-install after the change:
   ```sh
   ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh   # or re-cp
   ```
   `tests/run.sh` itself only prints an INFO line for the installed path, so it will not catch this.
2. **`${git_seg:+ $git_seg}` removal is the whole point** — do not "helpfully" keep it alongside the
   new `join_segments` argument, or the git segment renders twice (`… · w main* · main*`).
3. **Do not introduce a second separator definition.** `sep=" ${DIM}·${RESET} "` at
   `statusline.sh:405` (D-01) is the only one; reuse it.
4. **bash 3.2 only.** The replacement uses plain positional arguments — no `declare -A`, no `${v,,}`,
   no `mapfile`, no negative substring offsets. `join_segments` is already 3.2-safe. Nothing in this
   change touches `date`/`stat`/`sed -i`.
5. **UTF-8 / locale byte-length.** `.planning/research/PITFALLS.md:182,185` warns that byte-based
   width math miscounts multi-byte symbols (`⎇` = 3 bytes) and ANSI escapes, and that under a
   `C`/`POSIX` locale `${#var}` counts bytes. **Not applicable here** — `grep -n 'COLUMNS\|wc -c\|${#'`
   over `statusline.sh` returns nothing; the script does no length math at all. The symbols pass
   through as raw UTF-8 bytes. `·` (U+00B7, 2 bytes) is already in use on both lines, so this change
   removes a rarer glyph and reuses an already-proven one — a small legibility win.
6. **Editing the multi-byte lines.** Prefer the `Edit` tool over `sed`/`perl` in-place for the two
   lines containing `⎇`; BSD `sed` under a non-UTF-8 locale can mangle multi-byte input. (A `sed`
   prototype worked here, but the Edit tool is the safe default.)
7. **Never-fail contract.** `statusline.sh` must always exit 0 and write 0 bytes to stderr; the
   harness asserts both (`git not-a-repo: exit code` / `stderr bytes`, tests/run.sh:338-339). Nothing
   in this change can violate it, but do not add `set -e`/`set -u` while editing.
8. **Accepted doc/code disagreement (per CONTEXT.md).** After this change `project-brief.md:8,16,17,30`
   and `.planning/PROJECT.md:14,21` still specify `⎇` as a requirement, and `.claude/CLAUDE.md:109`
   still refers to "the `⎇` segment". These are deliberately **out of scope** — do not plan to fix
   them. [VERIFIED: repo-wide `grep -n '⎇'`, this session]

## 6. Docs surface — `README.md`

**Line 8** (inside the "What it shows" fenced block) [VERIFIED: README.md:8]:
```
Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2
```
→
```
Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2
```

**Line 20** (symbol legend table row) [VERIFIED: README.md:20]:
```
| `⎇ main` | Current branch (short SHA when detached) — the whole git segment is hidden outside a repo |
```
→ (wording is Claude's discretion; suggested)
```
| `main` | Current branch (short SHA when detached) — the whole git segment is hidden outside a repo |
```

**Nothing else in README.md changes.** Confirmed by reading:
- README.md:12 — "segments with no data … disappear together with their separators" — still accurate
  (now literally true for git as well).
- README.md ~line 71 "Verify without a live session" expected output uses `/tmp/myproject`, a
  non-repo, so its two expected lines are unchanged.
- Install / sandbox / Fable sections do not mention the glyph.

**Known accepted gap:** `project-brief.md` and `.planning/PROJECT.md` will disagree with the shipped
script (they name `⎇` as a requirement). Accepted per CONTEXT.md; not to be fixed in this task.

## Security Domain

`security_enforcement: true`, ASVS L1. This change is render-only and adds **no** new attack surface.

| ASVS Category | Applies | Note |
|---------------|---------|------|
| V5 Input Validation | yes (pre-existing) | The git branch label is attacker-influenceable (a hostile branch name). It is already emitted via `printf '%s' "$out"` with no format-string exposure and never `eval`'d; removing a literal prefix does not change that. The harness's eval-injection and hostile-body checks are unaffected. |
| V2/V3/V4/V6 | no | No auth, session, access-control, or crypto code is touched. The Fable OAuth path (`get_fable_weekly`) is not modified. |

No new threat introduced; no `checkpoint:human-verify` needed on security grounds.

## Package Legitimacy Audit

Not applicable — no external packages are installed or added by this task. Dependencies used
(`bash`, `git`, `jq`) are pre-existing, project-confirmed, and unchanged.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/bash` 3.2 | script runtime + harness discipline | ✓ | 3.2.57 (per CLAUDE.md; harness invokes `/bin/bash` explicitly) | — |
| `git` | section 8 temp-repo tests | ✓ | 2.50.1 (per CLAUDE.md) | — |
| `jq` | manual render checks | ✓ | 1.7.1 (per CLAUDE.md) | — |
| `shellcheck` | advisory pass only | ✗/optional | — | harness prints `INFO shellcheck not installed` and skips — never fails |
| `sbx` + Docker | `tests/sandbox.sh` (PORT-01) | not needed | — | fixture renders proven byte-identical, so the sandbox pass adds no signal for this change |

**Missing dependencies with no fallback:** none.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended extended `want` string at tests/run.sh:415 matches the produced bytes exactly | §3 | Test fails on first run; the actual bytes are printed by `check_ok`… (note: `check_ok` prints no diff — if it fails, re-derive by `cat -v` on the render). Mitigated: the prefix was read off an actual prototype render this session. |
| A2 | Bash/git/jq versions come from `.claude/CLAUDE.md`, not re-measured this session | §Environment | None material — the harness ran green (220/0) on this machine this session. |

## Open Questions

None. Every edit point, expected value, and behavioural consequence was confirmed against the files
and by rendering a prototype.

## Sources

### Primary (HIGH confidence — read/executed this session)
- `kit/files/home/.claude/statusline.sh` — lines 1-40, 100-200, 379, 390-440 read; `grep` for
  `COLUMNS|wc -c|${#` returned no matches
- `tests/run.sh` — lines 1-60, 320-470 read; full suite executed → `220 checks, 0 failures`
- `tests/fixtures/*.json` — `current_dir` values inspected; all 8 rendered old-vs-prototype and
  compared byte-for-byte
- `tests/render-fixtures.sh`, `tests/sandbox.sh` — headers read for invocation/scope
- `README.md` lines 1-100
- `.planning/research/PITFALLS.md:182,185` — UTF-8/locale width warnings
- `.planning/quick/260826-wid-.../260826-wid-CONTEXT.md` — locked decisions
- `.planning/config.json` — `nyquist_validation: false` (Validation Architecture section omitted),
  `security_enforcement: true`
- `ls -l ~/.claude/statusline.sh` + `diff -q` — installed path is a copy, currently identical

## Metadata

**Confidence breakdown:**
- Edit points: HIGH — quoted verbatim from files read this session, with line numbers
- Behavioural equivalence: HIGH — prototyped and rendered; all 8 fixtures byte-identical
- Test surface: HIGH — every `⎇` site located by repo-wide grep and read in context
- Pitfalls: HIGH — install type and absence of width math both measured

**Research date:** 2026-08-26
**Valid until:** indefinite for this task (no external/fast-moving dependencies); re-verify line
numbers if `statusline.sh` or `tests/run.sh` changes before execution.
