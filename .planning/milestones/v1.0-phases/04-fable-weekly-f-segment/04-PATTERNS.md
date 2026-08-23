# Phase 04: Fable Weekly f() Segment - Pattern Map

**Mapped:** 2026-08-22
**Files analyzed:** 12 (1 script modified, 3 harness scripts modified, 3 fixtures added, 1 kit spec optional, 4 docs modified)
**Analogs found:** 11 / 12 (the only no-analog item is the network/cache collector; RESEARCH.md Patterns 4–6 supply a bash-3.2-verified prototype for it)

All analogs live in this repo. The codebase is a single bash script plus a bash harness, so "role" below is expressed in the project's own vocabulary (helper, segment renderer, ingestion, collector, probe block, fixture, evidence probe, doc).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `kit/files/home/.claude/statusline.sh` — `iso_to_epoch` (new helper) | pure helper | transform (string → int) | `fmt_duration` lines 36–46, `shorten_num` lines 19–34 (same file) | role-match (pure arithmetic helper, `local` vars, `printf '%s'`, no subprocess); verified body in RESEARCH Pattern 3 |
| `statusline.sh` — stdin `model_scoped` probe (2 new jq assignments) | ingestion | transform (JSON → eval words) | the single jq pass lines 181–195 | exact (same program, same `uint`/`strings` guards) |
| `statusline.sh` — `get_token` / `read_cache` / `write_cache` / `fetch_usage` / `get_fable_weekly` (new collector block) | collector / adapter | file-I/O + request-response (cached) | `seg_git` lines 89–128 (external-process call, `2>/dev/null`, `|| return 0`, guard-empties-before-arithmetic) + jq pass lines 181–195 (guarded second jq + `eval`) + `kit/spec.yaml` lines 42–45 (mktemp + mv atomic write) | partial — no existing network/cache code; RESEARCH Patterns 4–6 are the prototype |
| `statusline.sh` — `seg_fable` (new segment renderer) | segment renderer | transform (vars → ANSI string) | `seg_1w` lines 151–159 + dim-label idiom in `seg_model_effort` line 73 | exact |
| `statusline.sh` — line-2 join in `main` (modified) | composition | — | line 210 `join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)"` | exact (append 4th arg) |
| `statusline.sh` — header comment (env var docs) | doc-in-code | — | lines 1–5 header; `tests/render-fixtures.sh` lines 15–19 "Env inputs:" block | exact |
| `tests/run.sh` — `export STATUSLINE_NO_FABLE=1` + new §11 Fable block | test probe block | batch (render → assert) | §2 helper tables lines 66–79 (iso_to_epoch table), §3 `run_fixture` 95–105, §5 threshold bytes 133–140, §6 palette purity 144–152, §7.2/7.4 injection probes 170–225, §7.3 stderr-bytes 188–195, §9 wall-clock budget 403–412 | exact |
| `tests/fixtures/fable-stdin.json` (new stdin fixture) | fixture | — | `tests/fixtures/full.json` (`resets_at: 0` determinism) | exact |
| `tests/fixtures/usage/fable.json`, `tests/fixtures/usage/no-bucket.json` (new endpoint fixtures) | fixture | — | CONTEXT `<specifics>` JSON (sanitized live shape); sub-directory so `render-fixtures.sh` line 49 glob skips them | no codebase analog (new data shape) — shape given in CONTEXT/RESEARCH |
| `tests/render-fixtures.sh` — `export STATUSLINE_NO_FABLE=1` | harness | batch | its own header "Determinism" lines 24–28 + `INSTALLED=${INSTALLED:-…}` env idiom line 33 | exact |
| `tests/sandbox.sh` — §5.x credentials-presence + live Fable render probe | evidence probe | request-response (sbx exec) | §5.4 `sx "$NAME" test -x …` lines 171–173, §5.6 INFO line 180–182, §5.8 `sx -e VAR=… "$NAME" …` lines 191–195, §5.7 `case … in *pattern*) r=0` 185–189 | exact |
| `kit/spec.yaml` — optional curl guard | config | — | `setup.install` line 21 (D-33 guard) | exact |
| `README.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `project-brief.md` (D-52/D-66) | docs | — | README "What it shows" lines 7–12, legend table 16–28, install notes 59–70; grep hits listed below | exact |

## Pattern Assignments

### `statusline.sh` — `iso_to_epoch` (pure helper, transform)

**Analog:** `kit/files/home/.claude/statusline.sh` lines 36–46 (`fmt_duration`) — place the new helper directly after it (RESEARCH: "next to fmt_duration").

**Helper shape to copy** (lines 36–46):
```bash
# fmt_duration DELTA_SECONDS -> countdown text (D-09/D-10: only leading zero
# units drop, past resets print "now" — caller adds the parens).
fmt_duration() {
  local delta=$1 d h m
  if [ "$delta" -le 0 ]; then printf 'now'; return; fi      # D-10
  if [ "$delta" -lt 60 ]; then printf '<1m'; return; fi
  d=$(( delta / 86400 )); h=$(( delta % 86400 / 3600 )); m=$(( delta % 3600 / 60 ))
  ...
}
```
Conventions to keep: comment header `# name ARGS -> result (D-xx refs)`, one `local` line declaring every variable, `printf '%s'` output (never `echo`), `return 0` with **no output** as the "unparseable → hidden" contract (same as `seg_*` returning empty). The verified body is RESEARCH.md Pattern 3 (lines 297–332 of 04-RESEARCH.md); copy it verbatim — it is bash-3.2-tested (17/17 vs Python). Two traps already noted there: `case` bracket patterns must not contain a space (`[Tt]` not `[Tt ]`), and every two-digit field needs `10#` before `$(( ))`.

**Unit-table test pattern** (tests/run.sh lines 74–79) to reuse for the 17-row ISO table:
```bash
for pair in -5:now 0:now '30:<1m' '59:<1m' 60:1m 3000:50m 10200:2h:50m \
            273420:3d:3h:57m 262800:3d:1h:0m 90061:1d:1h:1m; do
  n=${pair%%:*}; want=${pair#*:}
  check_eq "fmt_duration $n -> $want" "$want" "$(fmt_duration "$n")"
done
```
Note: ISO strings contain `:`; use a different delimiter (`|`, as in §7.5 lines 236–243 `label=${spec%%|*}; rest=${spec#*|}`) for the iso_to_epoch table.

---

### `statusline.sh` — stdin `model_scoped` probe (ingestion)

**Analog:** `kit/files/home/.claude/statusline.sh` lines 181–195 (the single jq pass).

**Core pattern** (lines 181–195):
```bash
  vars=$(printf '%s' "$input" | jq -r '
    def uint: (numbers | floor | select(. >= 0 and . < 1e15)) // "";
    @sh "
    MODEL=\(.model.display_name // "" | strings // "")
    ...
    P7_PCT=\(.rate_limits.seven_day.used_percentage // "" | uint)
    P7_RST=\(.rate_limits.seven_day.resets_at // "" | uint)
  " ' 2>/dev/null)
  eval "$vars"
```
Add the `as $ms` binding **between** `def uint` and `@sh` (RESEARCH Pattern 1), then two more assignment lines `FAB_SI_PCT=\($ms.utilization // "" | uint)` and `FAB_SI_RST=\($ms.resets_at // "" | strings // "")`. Keep the big comment block at lines 164–178 accurate: it says "7 numeric fields" / "3 string fields" / "10 @sh-ingested fields" — update the counts (8 numeric, 4 string, 12 fields) and extend §7.4 of run.sh (which says "Every one of the 10 @sh-ingested fields is probed") with the two new paths.

---

### `statusline.sh` — collector block (`get_token`, `read_cache`, `write_cache`, `fetch_usage`, `get_fable_weekly`)

**Analog (partial):** `seg_git` lines 89–128 for the external-process discipline; jq pass lines 181–195 for the guarded second jq + eval; `kit/spec.yaml` lines 42–45 for atomic tmp+mv. Function bodies: RESEARCH.md Patterns 4, 5, 6 (bash-3.2 prototyped — copy them).

**External-call discipline** (seg_git lines 90–92, 108–117):
```bash
  [ -n "$DIR" ] || return 0                   # stdin workspace dir only, never $PWD
  local status line label upstream=0 detached=0 dirty=0 ahead=0 behind=0 ab stash sha out
  status=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch 2>/dev/null) || return 0
  ...
  [ -z "$ahead" ]  && ahead=0                 # guard empties before arithmetic
  [ -z "$behind" ] && behind=0
  ...
  stash=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" rev-list --walk-reflogs --count refs/stash 2>/dev/null)
  [ -z "$stash" ] && stash=0                  # no stash ref -> 0
```
Apply the same to `curl`, `security`, `jq`, `mktemp`, `mv`, `rm`: every call `2>/dev/null`, failure → fall through to hidden, empties guarded before any `$(( NOW - C_AT ))`.

**Guarded second jq + eval** (copy the idiom of lines 182–195 into `read_cache` / `fetch_usage`): re-declare `def uint: …` inside each separate jq program (jq defs are per-program), `@sh` every assignment, `eval "$v"` — empty output on non-JSON leaves the variables at their pre-set `""`. Variable pre-clearing (`C_AT=""; C_PCT=""; C_RST=""`) mirrors `seg_git`'s `upstream=0 detached=0 …` initialisation.

**Atomic write** (kit/spec.yaml lines 42–45, POSIX-sh flavour — port to bash with the same shape):
```sh
          tmp=$(mktemp "$H/.claude/.settings.XXXXXX")
          jq -n '…' "$S" > "$tmp"
          mv "$tmp" "$S"
```
For the cache use `mktemp "${FAB_CACHE%/*}/.usage.XXXXXX"` (template in the same dir → `mv` is a rename, 0600 by default on BSD and GNU), `printf '{"fetched_at":%s,"pct":%s,"resets_at":%s}\n'` then `mv -f`, `rm -f "$tmp"` on failure (RESEARCH Pattern 5).

**Placement / scoping rule:** `NOW` is declared `local` in `main` (line 179) and set at line 197; `seg_*` see it by dynamic scope. `get_fable_weekly` must be **called directly in `main`** (not inside `$(…)`) after line 197 and before the line-2 join, so `FAB_PCT`/`FAB_RST` are set in main's shell. Declare `FAB_PCT FAB_RST` (and the `C_*`/`F_*` temporaries if you want them scoped) in main's `local` line 179 or leave them as plain globals like `MODEL`/`DIR` (which `eval` creates as globals).

**Token hygiene:** `-K -` with a builtin `printf` pipe (RESEARCH Pattern 4) — never `-H "Authorization: …"` in argv; never print the token or the body anywhere (stderr must stay at 0 bytes — run.sh §3/§7.3 assert this for every fixture).

---

### `statusline.sh` — `seg_fable` (segment renderer)

**Analog:** `kit/files/home/.claude/statusline.sh` lines 151–159 (`seg_1w`) — place `seg_fable` directly after it.

**Core pattern** (lines 151–159):
```bash
# Weekly rate-limit segment pct/1w (countdown) (LIM-02, D-05, D-07, D-09/D-10).
seg_1w() {
  [ -n "$P7_PCT" ] || return 0
  local pct=${P7_PCT%.*} out
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
  out="$(pct_color "$pct")${pct}%${RESET}/1w"
  [ -n "$P7_RST" ] && out="${out} ($(fmt_duration $(( P7_RST - NOW ))))"
  printf '%s' "$out"
}
```
**Dim literal-label idiom** (seg_model_effort line 73):
```bash
  [ -n "$EFFORT" ] && out="${out} ${DIM}(${EFFORT})${RESET}"
```
`seg_fable` = the `seg_1w` body with `P7_*` → `FAB_*` and `out="${DIM}Fable${RESET} $(pct_color "$pct")${pct}%${RESET}/1w"` (D-53: colour on the number only; `/1w` and countdown plain). Comment header cites FAB-01, D-51/D-53/D-54/D-55.

---

### `statusline.sh` — line-2 join (composition)

**Analog:** line 210:
```bash
  body=$(join_segments "$sep" "$(seg_context)" "$(seg_5h)" "$(seg_1w)")
```
Append `"$(seg_fable)"` as the last argument; `join_segments` (lines 58–64) already drops empty parts and their separators (D-55 / PRES-04). Nothing else in `main` changes except the collector call above.

---

### `statusline.sh` — header comment (env var documentation)

**Analog:** `tests/render-fixtures.sh` lines 15–19:
```bash
# Env inputs:
#   INSTALLED         path of the installed script
#                     (default: $HOME/.claude/statusline.sh)
#   REQUIRE_INSTALLED non-empty -> a missing / non-executable INSTALLED is a
#                     FAIL (exit 1) instead of an INFO skip (sandbox strictness)
```
Add an equivalent block to the statusline.sh header (lines 1–5) listing `STATUSLINE_NO_FABLE`, `STATUSLINE_USAGE_URL`, `STATUSLINE_CREDENTIALS_FILE`, `STATUSLINE_USAGE_CACHE`, `STATUSLINE_CURL_MAX_TIME` with defaults (D-65: "documented only in the script header/tests"). Defaulting idiom: `FAB_CACHE=${STATUSLINE_USAGE_CACHE:-$HOME/.claude/statusline-usage-cache.json}` (same as render-fixtures.sh line 33 `INSTALLED=${INSTALLED:-$HOME/.claude/statusline.sh}`).

---

### `tests/run.sh` — kill-switch export + new §11 "Fable weekly" block

**Analog:** `tests/run.sh` itself; every assertion style needed already exists.

**Global export placement:** after `SL=kit/files/home/.claude/statusline.sh` (line 13) add `export STATUSLINE_NO_FABLE=1` with a comment (Pitfall 1: otherwise §3–§9 would read the Keychain / hit the network). Inside §11 each command gets `STATUSLINE_NO_FABLE= STATUSLINE_USAGE_URL=… STATUSLINE_CREDENTIALS_FILE=… STATUSLINE_USAGE_CACHE="$TESTTMP/usage.json" /bin/bash "$SL"` as per-command prefixes.

**Temp dir + cleanup** (lines 44–46) — reuse `$TESTTMP`, already trapped:
```bash
ERRTMP=$(mktemp "${TMPDIR:-/tmp}/statusline-test.XXXXXX") || exit 1
TESTTMP=$(mktemp -d "${TMPDIR:-/tmp}/statusline-git.XXXXXX") || exit 1
trap 'rm -f "$ERRTMP"; rm -rf "$TESTTMP"' EXIT
```

**Render + exit + stderr-bytes + stripped line 2** (run_fixture lines 95–105) — the capture discipline for every Fable render:
```bash
  out=$(/bin/bash "$SL" < "tests/fixtures/$f.json" 2>"$ERRTMP"); rc=$?
  errbytes=$(wc -c < "$ERRTMP" | tr -d '[:space:]')
  check_eq "$f: exit code" "0" "$rc"
  check_eq "$f: stderr bytes" "0" "$errbytes"
  l1=$(printf '%s\n' "$out" | strip_ansi | sed -n 1p)
  l2=$(printf '%s\n' "$out" | strip_ansi | sed -n 2p)
```
Expected line 2 for the cold `file://` render with `full.json` stdin: `10%/100k/1w …` — precisely `10%/100k/1M · 50%/5h (now) · 15%/1w (now) · Fable 74%/1w (now)` (fixture `resets_at` set to `1970-01-01T00:00:00Z`); with `no-rate-limits.json` stdin: `10%/100k/1M · Fable 74%/1w (now)` (D-55 peer rule).

**Fixture mutation via jq** (lines 125–127, 135–136, 244–245) — for threshold variants and cache ageing:
```bash
  raw=$(jq --argjson p "$p" '.rate_limits.five_hour.used_percentage = $p' \
        tests/fixtures/full.json | /bin/bash "$SL")
```
For the endpoint fixture write a mutated copy into `$TESTTMP` and point `STATUSLINE_USAGE_URL=file://$TESTTMP/x.json` at it; for cache ageing `jq '.fetched_at -= 400' "$CACHE" > "$CACHE.new" && mv "$CACHE.new" "$CACHE"`.

**Colour-byte assertion** (lines 137–139) — Fable variant `want="${ESC}[2mFable${ESC}[0m ${ESC}[33m74%${ESC}[0m/1w"`:
```bash
  want="${ESC}[${code}m${num}%${ESC}[0m/5h"
  case "$raw" in *"$want"*) r=0;; *) r=1;; esac
  check_ok "threshold bytes: pct $p -> SGR ${code}m before ${num}%, reset before /5h" $r
```

**Palette purity** (lines 144–152) — rerun verbatim on a Fable render (`0m 2m 31m…36m` set unchanged).

**Injection / array probes** (lines 170–183, 206–224) — add `.rate_limits.model_scoped[0].utilization` / `.resets_at` / `display_name` paths and `.rate_limits.model_scoped = "x"` / `= ["",  "touch", "tests/.pwned"]` forms; the hostile-cache probe writes `"x[$(touch tests/.pwned)]"` JSON / `garbage` into `$TESTTMP/usage.json` and asserts `[ ! -e tests/.pwned ]` + 0 stderr. All under `/bin/bash` (§7.2 comment, lines 166–169, explains why).

**Wall-clock bound** (lines 405–412) for the timeout probe (`STATUSLINE_USAGE_URL=http://192.0.2.1/ STATUSLINE_CURL_MAX_TIME=1`): `t0=$(date +%s) … t1=$(date +%s); [ $(( t1 - t0 )) -le 3 ]` — assert the upper bound only (RESEARCH Pitfall 6: sandbox proxy fails in 0 s).

**File-mode check (portable):** `ls -l "$CACHE" | cut -c1-10` → `-rw-------` (RESEARCH testability table; avoids `stat`).

**Prove-it-bites convention** (02-04-PLAN.md lines 265–278): each new probe must be shown to FAIL against a deliberately broken variant (e.g. kill switch ignored, negative cache not written) and PASS against the real script, with `git status --short` clean afterwards.

---

### `tests/fixtures/fable-stdin.json`, `tests/fixtures/usage/fable.json`, `tests/fixtures/usage/no-bucket.json`

**Analog:** `tests/fixtures/full.json`:
```json
{"session_id":"fix-full","model":{"display_name":"Opus 5 (1M context)"},"effort":{"level":"high"},"workspace":{"current_dir":"/tmp/myproject"},"context_window":{"used_percentage":10.4,"total_input_tokens":100000,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":50.9,"resets_at":0},"seven_day":{"used_percentage":15.2,"resets_at":0}}}
```
- `fable-stdin.json` = `full.json` + `"model_scoped":[{"display_name":"Fable","utilization":33,"resets_at":"1970-01-01T00:00:00Z"}]` inside `rate_limits` (epoch-0 ISO → `(now)`, deterministic like `resets_at: 0`). It may live in `tests/fixtures/` because the exported kill switch keeps `render-fixtures.sh` dumps deterministic; `render-fixtures.sh` line 24 comment ("all 7 fixtures") must become 8.
- `usage/fable.json` = the CONTEXT `<specifics>` response with the Fable bucket's `resets_at` changed to `1970-01-01T00:00:00Z`; `usage/no-bucket.json` = same minus the `weekly_scoped` entry. Sub-directory on purpose: `render-fixtures.sh` line 49 `for f in tests/fixtures/*.json` is non-recursive. No IDs/tokens in either file.

---

### `tests/render-fixtures.sh` — determinism export

**Analog:** its own header lines 24–28 and env idiom line 33. Add `export STATUSLINE_NO_FABLE=1` right after `SL=…` (line 31) and extend the "Determinism:" paragraph with one sentence (Fable path disabled so dumps never depend on network/credentials — D-64).

---

### `tests/sandbox.sh` — §5.x credentials presence + live Fable render

**Analog:** `tests/sandbox.sh` lines 171–173 (`test -x` probe), 180–182 (INFO line), 185–189 (case-match on output), 191–195 (`sx -e VAR=…`).

**Presence probe (never cats the file)** (lines 171–173):
```bash
sx "$NAME" test -x "$SBX_SL"
check_ok "kit script present and executable: $SBX_SL" $?
```
→ `if sx "$NAME" test -f /home/agent/.claude/.credentials.json; then CREDS=present; else CREDS=absent; fi; emit "INFO credentials file: $CREDS"`.

**Env into the sandbox** (lines 193–194):
```bash
sx -e INSTALLED=/home/agent/.claude/statusline.sh -e REQUIRE_INSTALLED=1 "$NAME" \
  /bin/bash "$PWD/tests/render-fixtures.sh" "$OUT_SBX" > "$OUT_SBX/render.log" 2>&1
```
→ `sx -e STATUSLINE_NO_FABLE= "$NAME" /bin/bash -c "/bin/bash $PWD/kit/files/home/.claude/statusline.sh < $PWD/tests/fixtures/full.json"` piped through a local `strip_ansi` (copy `ESC`/`strip_ansi` from run.sh lines 17–20 — sandbox.sh has no strip helper today).

**Conditional pass/INFO** (lines 185–189 `case "$last" in *"checks, 0 failures") r=0 ;; *) r=1 ;; esac`): when `CREDS=present` → `check_ok "Fable segment renders in sandbox (FAB-02, D-63)"` on `case "$l2" in *"Fable "*)`; when absent → `emit "INFO credentials absent — Fable hidden is the correct outcome (D-63)"` and assert the line does **not** contain `Fable`. Record elapsed seconds with `date +%s` before/after as an INFO line (style of line 146 `INFO sandbox.sh start: …`).

---

### `kit/spec.yaml` — optional curl guard (config)

**Analog:** line 21:
```yaml
    - command: command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends jq git)
      description: Guard the script's dependencies (jq, git) — no-op on the claude-code base image (D-33)
```
If touched: add `&& command -v curl >/dev/null 2>&1` and `curl` to the apt list + description; re-run `sbx kit validate kit` (sandbox.sh §5.1). Note `tests/sandbox.sh` §5.5 compares the script only, not spec.yaml, so no byte-diff breaks.

---

### Docs (`README.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `project-brief.md`)

**Analog:** README structure; exact grep-located lines:
- `README.md` lines 7–10 example block → append ` · Fable 74%/1w (2d:4h:30m)` to line 9; line 12 sentence mentions what hides; legend table lines 16–28 → new row after line 28 (`| \`Fable 74%/1w (2d:4h:30m)\` | Fable weekly usage and time to reset — needs the Claude Code OAuth login; hidden otherwise |`); one note near lines 59–70 (token from `~/.claude/.credentials.json` or macOS Keychain item "Claude Code-credentials"; `STATUSLINE_NO_FABLE=1` kill switch; possible one-time Keychain "Always Allow"; sandboxes: renders when `/home/agent/.claude/.credentials.json` exists — sbx `anthropic` secret or `/login`). Verify-command line 64/67 may stay (kill switch not needed there: stdin has no Fable, and the live path is the point) — or document that a hidden Fable is expected without credentials.
- `.planning/REQUIREMENTS.md` line 39 (FAB-01 wording), line 42 (FAB-04 "`f()` segment" → "Fable segment").
- `.planning/PROJECT.md` lines 15, 22, 39, 48, 59, 89.
- `project-brief.md` lines 10, 25, 31 — optional one-line "layout correction (Phase 4)" note (discretion, D-52).
Docs-only commits follow the Phase 2/3 convention (`gsd_run query commit`).

## Shared Patterns

### Never-fail / hide-on-failure contract
**Source:** `statusline.sh` lines 1–5 header, line 92 (`… 2>/dev/null) || return 0`), line 219 (`exit 0  # unconditional`)
**Apply to:** every new function in the collector and `seg_fable`
Every external command is `2>/dev/null`; every failure path ends in empty `FAB_PCT` → segment hidden; no `set -e/-u`; stderr stays at 0 bytes (asserted by run.sh §3 for every fixture).

### Guard empties before arithmetic / `[ -ge ]`
**Source:** `statusline.sh` lines 109–110, 117, 135–136, 145, 155
```bash
  [ -z "$pct" ] && pct=0                      # guard before arithmetic
```
**Apply to:** `C_AT`, `FAB_RST`, `F_PCT` before `$(( NOW - … ))`, and any `[ "$x" -lt "$FAB_TTL" ]`.

### jq type-guard + `@sh` + `eval` (the injection boundary)
**Source:** `statusline.sh` lines 164–195 (comment + program)
**Apply to:** the extended stdin program, `read_cache`, `fetch_usage`, `get_token` (`jq -r '.claudeAiOauth.accessToken // empty | strings'`). Re-declare `def uint` in each separate program. Harness §7.2/§7.4 probes (run.sh 170–225) must be extended to the new fields and the cache file.

### Segment renderer shape
**Source:** `seg_1w` lines 151–159; dim label line 73
**Apply to:** `seg_fable` — `[ -n "$X" ] || return 0`, `local pct=${X%.*} out`, colour only the number, optional ` ($(fmt_duration …))`, `printf '%s' "$out"`.

### Per-command env overrides with production defaults
**Source:** `tests/render-fixtures.sh` line 33 `INSTALLED=${INSTALLED:-$HOME/.claude/statusline.sh}`; `tests/sandbox.sh` line 193 `sx -e VAR=…`
**Apply to:** the five `STATUSLINE_*` knobs; `export STATUSLINE_NO_FABLE=1` at the top of run.sh and render-fixtures.sh; per-command `STATUSLINE_NO_FABLE= …` inside the Fable probe block.

### Harness assertion vocabulary
**Source:** `tests/run.sh` lines 22–42 (`check_eq`/`check_ok`), 17–20 (`ESC`/`strip_ansi`), 95–105 (`run_fixture`), 137–139 (raw byte `case`), 405–412 (`date +%s` wall-clock bound); `tests/sandbox.sh` 76–103 (`emit`-routed twins)
**Apply to:** every new §11 probe and the sandbox §5.x probe; one PASS/FAIL line per check; probes shown to bite (02-04-PLAN.md lines 265–278 style).

### Atomic tmp + mv, 0600
**Source:** `kit/spec.yaml` lines 42–45; `tests/sandbox.sh` line 217 (`mktemp … && jq … > "$t" && mv "$t" "$S"`)
**Apply to:** `write_cache` (template in the cache's own directory; `mv -f`; `rm -f` on failure).

## No Analog Found

| File / unit | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `statusline.sh` collector (`get_token`, `fetch_usage`, cache TTL/grace flow) | collector | request-response + file-I/O | No existing network call or cache file in the codebase; use RESEARCH.md Patterns 4–6 (prototyped under `/bin/bash` 3.2.57) and the shared external-call/guard idioms above |
| `tests/fixtures/usage/*.json` | fixture | — | New data shape (OAuth usage response); take the sanitized JSON from CONTEXT `<specifics>` |

## Metadata

**Analog search scope:** `kit/files/home/.claude/statusline.sh`, `tests/run.sh`, `tests/render-fixtures.sh`, `tests/sandbox.sh`, `tests/probe-kit-add.sh` (header only), `tests/fixtures/*.json`, `kit/spec.yaml`, `README.md`, grep of `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `project-brief.md`, `.planning/phases/02-git-segment/02-04-PLAN.md` (bite convention)
**Files scanned:** 14
**Pattern extraction date:** 2026-08-22
