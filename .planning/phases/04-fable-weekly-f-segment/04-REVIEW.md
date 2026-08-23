---
phase: 04-fable-weekly-f-segment
reviewed: 2026-08-23T00:08:18Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - README.md
  - kit/files/home/.claude/statusline.sh
  - kit/spec.yaml
  - tests/fixtures/fable-stdin.json
  - tests/fixtures/usage/fable.json
  - tests/fixtures/usage/no-bucket.json
  - tests/render-fixtures.sh
  - tests/run.sh
  - tests/sandbox.sh
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-23T00:08:18Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Fable weekly adapter in `kit/files/home/.claude/statusline.sh` (token lookup, TTL/grace cache, bounded curl, guarded jq parsers, `iso_to_epoch`, `seg_fable`), the harness additions in `tests/run.sh` §11 and `tests/sandbox.sh` §5.13, the two usage fixtures, the stdin fixture, `tests/render-fixtures.sh`, `kit/spec.yaml` and the README. Every claim below was exercised against the real script under `/bin/bash` 3.2.57 (probes run from a scratch directory with synthetic credentials, a `file://` endpoint and a scratch cache); the harness itself passes 220/220 on the host and, per `tests/out/sandbox/EVIDENCE.txt`, 220/220 in the sandbox.

What holds up well: bash 3.2 syntax throughout (no `declare -A`, no `${var,,}`, no `date -d/-r`, `printf` only); every value that reaches `eval` or `$(( ))` passes through a jq type/range guard (`uint`, `strings`, `arrays[]?/objects`) and the 12-field array/subscript probes confirm one quoted word per assignment; the token never enters argv (builtin `printf` into `curl -K -`), never hits stdout/stderr, and the cache holds numbers only; the cache write is `mktemp` (0600 on BSD and GNU) + `mv -f` so symlinks are replaced, never followed; `iso_to_epoch` is pure arithmetic and matches the 17-row table.

What does not hold up: (1) the failure path has no backoff, so offline / firewalled / revoked-token users pay a full `--max-time` curl plus a credentials/Keychain read on every render, contradicting the README's "at most one request every 5 minutes"; (2) `curl` is invoked without `-q`, so a user's `~/.curlrc` (`--trace*`, `-v`, `-o`, `-L`, proxies) silently changes the request and can dump the bearer token to a trace file; (3) the token is spliced into the curl config text unsanitized, so a newline/quote in the credential file injects curl directives (verified: `output = ...` wrote an arbitrary file) - low-trust-boundary but inconsistent with the hardening applied to every other input; (4) the sandbox Fable probe asserts "renders" whenever a credentials file exists, which fails on accounts/credentials without a Fable bucket even though a hidden segment is the documented correct outcome. Plus six INFO items (future `fetched_at` served forever, non-usage-shaped 2xx JSON negative-cached, relative cache path, numeric `model_scoped.resets_at` dropped, harness claims vs. the 192.0.2.1 probe, unquoted `$PWD` in a remote `-c` string).

## Warnings

### WR-01: No failure backoff - every render on a failed fetch re-reads credentials and blocks for the full curl timeout

**File:** `kit/files/home/.claude/statusline.sh:344-351` (also `:290-296`, `:308-316`; README.md:79)
**Issue:** `write_cache` is only called when `fetch_usage` succeeds. On any failure (curl timeout, DNS failure, firewall drop, 401/403 after token revocation, non-JSON body) the cache's `fetched_at` is never bumped, so the next render - which fires on every assistant message and every `refreshInterval` tick (60 s) - repeats `read_cache` + `get_token` (jq on the credentials file and, on macOS, the `security` Keychain call) + a curl that waits up to `FAB_MAXTIME`. Verified: with a stale cache and an unroutable URL, three consecutive renders each took 2 s and `fetched_at` stayed at its pre-failure value. This continues for the whole grace hour and forever after it (the segment is hidden but the probe keeps running). Consequences: an offline laptop renders the status line 2 s late on every update; a user who has not clicked "Always Allow" gets the Keychain dialog on every render rather than once; the README's "at most one request every 5 minutes" (README.md:79) is false on exactly the paths where it matters. CLAUDE.md's constraint is that data lookups "must be fast and never block the prompt".
**Fix:** Record failures in the cache and gate the fetch on them, keeping the last good values for the grace window:
```bash
# write_cache PCT RST [FAILED_AT] -> {"fetched_at","pct","resets_at","failed_at"}
write_cache() {
  local tmp
  mkdir -p "${FAB_CACHE%/*}" 2>/dev/null
  tmp=$(mktemp "${FAB_CACHE%/*}/.usage.XXXXXX" 2>/dev/null) || return 1
  printf '{"fetched_at":%s,"pct":%s,"resets_at":%s,"failed_at":%s}\n' \
    "${4:-$NOW}" "${1:-null}" "${2:-null}" "${3:-null}" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$FAB_CACHE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}
# read_cache: add C_FAIL=\(.failed_at // "" | uint) to the @sh string.
# get_fable_weekly, after the fresh-hit check:
  if [ -n "$C_FAIL" ] && [ $(( NOW - C_FAIL )) -ge 0 ] && [ $(( NOW - C_FAIL )) -lt "$FAB_RETRY" ]; then
    :                                          # recent failure: no token read, no curl
  elif fetch_usage; then
    FAB_PCT=$F_PCT; FAB_RST=$(iso_to_epoch "$F_RST_ISO")
    write_cache "$FAB_PCT" "$FAB_RST"; return 0
  else                                         # keep old values, remember the failure
    write_cache "$C_PCT" "$C_RST" "$NOW" "${C_AT:-$NOW}"
  fi
  # grace check unchanged (uses C_AT)
```
with `FAB_RETRY=60` (one retry per minute, well under the TTL). Update README.md:79 to describe the retry interval, and add a harness probe asserting that a second render after a failed fetch within `FAB_RETRY` does not invoke curl (e.g. measure wall time with `STATUSLINE_CURL_MAX_TIME=1` against `http://192.0.2.1/`: first render <=2 s, second render <1 s).

### WR-02: `curl` runs without `-q` - the user's `~/.curlrc` is honored and can leak the bearer token or alter the request

**File:** `kit/files/home/.claude/statusline.sh:314-315`
**Issue:** curl reads `$CURL_HOME/.curlrc` / `$HOME/.curlrc` by default; `-K -` adds to it, it does not replace it. A `.curlrc` containing `--trace`, `--trace-ascii`, `--dump-header` or `-v` writes the outgoing `Authorization: Bearer <token>` header to a file / stderr (the script's `2>/dev/null` hides stderr, but a trace *file* persists on disk in plaintext); `-o`, `-w`, `-L`, `--proxy`, `--insecure`, `--resolve` etc. silently change where the request goes, what the body looks like, or whether TLS is verified. The script header explicitly promises "TLS verification and the proxy environment are left untouched" and "never printed, never stored" - both depend on the user's rc file today. This is an automated, credentialed request every few minutes that the user did not type, so it deserves the hardening an interactive `curl` does not.
**Fix:** Disable rc-file processing; `-q` must be the first argument:
```bash
| curl -q -s -f --max-time "$FAB_MAXTIME" -K - "$FAB_URL" 2>/dev/null) || return 1
```
(`-q` only disables the default config file; the explicit `-K -` still applies, and `HTTPS_PROXY`/`CURL_CA_BUNDLE` environment handling is unchanged.) Optionally add a harness probe that points `CURL_HOME` at a directory whose `.curlrc` contains `-w '\n'` or `--fail-early` and asserts the render is unchanged.

### WR-03: Token spliced into the curl config text unsanitized - a newline or quote in the credential injects curl directives

**File:** `kit/files/home/.claude/statusline.sh:253-256`, `:314`
**Issue:** `get_token` accepts "any non-empty string" and `fetch_usage` interpolates it with `printf 'header = "Authorization: Bearer %s"\n...'` into the `-K -` config stream. curl's config grammar is line-oriented with `\"`-escaped quoted values, so a token value containing `"` + newline terminates the header line and starts new directives. Verified with a synthetic credentials file: `"accessToken":"abc\"\noutput = \"<path>\"\nurl = \"file://...\""` made curl write the response body to `<path>` (file created, 1167 bytes) - i.e. arbitrary file write and request redirection driven by the credentials JSON. The source is the user's own credential store / `STATUSLINE_CREDENTIALS_FILE`, so the trust boundary is low (whoever can edit that file already has the token), which is why this is a WARNING and not a BLOCKER - but every other input in this phase (stdin, cache, endpoint body) received a strict shape guard, and this one did not, even though it is the only input that feeds a second interpreter (curl's config parser).
**Fix:** Constrain the token shape in the jq guard (OAuth access tokens are URL-safe base64/`sk-ant-oat01-...`):
```jq
| (.accessToken? // "" | strings // "") as $t
| select($t != "" and ($t | test("^[A-Za-z0-9._~+/=-]+$")) and ($e / 1000) > $now) | $t
```
and, belt and braces, refuse tokens containing a quote or control character in bash before building the config: `case "$tok" in *[![:alnum:]._~+/=-]*) return 1 ;; esac`. Add a harness probe with a newline/quote-bearing synthetic token asserting the segment hides and no file is written.

### WR-04: Sandbox Fable probe asserts "renders" whenever a credentials file exists - fails on valid hidden outcomes; unquoted `$PWD` in the remote command

**File:** `tests/sandbox.sh:278-292`
**Issue:** §5.13 decides the expected outcome purely from `test -f /home/agent/.claude/.credentials.json`. With the file present it requires `· Fable NN%/1w` on line 2. But the script's own contract makes a *hidden* segment the correct result in several present-file cases: the account/plan has no `weekly_scoped` Fable bucket (D-49 negative result), the token is expired (`expiresAt` guard, D-62), the credentials JSON is not an OAuth blob (API-key sandboxes), or the sandbox egress proxy rejects `/api/oauth/usage`. Any of these turns a correct render into a counted FAIL that also flips the script's exit status, so the summary line certifying PORT-01/PORT-04/D-32 becomes account-dependent. The evidence run happened to pass (90 %) but the check is not stable across accounts or weeks. Secondary: line 281 interpolates `$PWD` into a `bash -c` *string* (`< $PWD/tests/fixtures/full.json`), so a repo path containing a space or glob character breaks the redirection - elsewhere the script passes `"$PWD/..."` as a proper argv word (lines 185, 193, 202).
**Fix:** Decide from the outcome the script itself recorded, and pass the fixture path as an argument:
```bash
FAB_RAW=$(sx "$NAME" /bin/bash -c 'unset STATUSLINE_NO_FABLE; /bin/bash "$1" < "$2"' _ "$SBX_SL" "$PWD/tests/fixtures/full.json" 2>/dev/null)
...
if [ "$CREDS" = present ]; then
  CACHE_PCT=$(sx "$NAME" jq -r '.pct // "null"' /home/agent/.claude/statusline-usage-cache.json 2>/dev/null)
  case "$FAB_L2" in
    *"· Fable "*"%/1w"*) check_ok "Fable segment renders in sandbox (FAB-02, D-63)" 0 ;;
    *) if [ "$CACHE_PCT" = null ]; then
         emit "INFO credentials present but endpoint reported no Fable bucket / token unusable - hidden is correct (D-49/D-62)"
       else
         check_ok "Fable segment renders in sandbox (FAB-02, D-63)" 1
       fi ;;
  esac
fi
```
(keep the existing absent-file branch). Still assert unconditionally that the render exited 0 and that line 1 matches the host render, so the probe certifies the script never blanks the line.

## Info

### IN-01: A cache with `fetched_at` in the future is served as fresh forever

**File:** `kit/files/home/.claude/statusline.sh:341`, `:348`
**Issue:** The freshness test is `NOW - C_AT < FAB_TTL` with no lower bound; a `fetched_at` ahead of the clock (clock step backwards, NTP correction, a cache copied from another machine, or a hand-edited file) yields a negative age, which is `-lt 300` indefinitely, so the script never refetches and the (possibly hostile) `pct` is shown until the clock catches up. Verified: `{"fetched_at":99999999999999,"pct":5,...}` renders `Fable 5%/1w` with a valid fixture endpoint available. The `uint` guard bounds the value below 1e15 but not relative to `NOW`.
**Fix:** Treat negative ages as stale (and therefore ineligible for grace too):
```bash
age=$(( NOW - C_AT ))
if [ -n "$C_AT" ] && [ "$age" -ge 0 ] && [ "$age" -lt "$FAB_TTL" ]; then ...
```

### IN-02: Any 2xx JSON body - including `{}`, `null`, `"string"` - counts as "answered, no bucket" and is negative-cached for 5 minutes

**File:** `kit/files/home/.claude/statusline.sh:317-326`
**Issue:** `fetch_usage` returns 0 whenever jq produces output, and the guarded program produces `F_PCT='' F_RST_ISO=''` for every JSON value that is not an object with a `limits` array (verified with `{}` and `"just a string"`: cache written with `pct:null`). A proxy/CDN error page that is JSON with a 200, a maintenance stub, or a future schema change therefore *hides* the segment for the TTL instead of keeping the last good value under the grace rule, which is what a malformed answer should do. The distinction matters once WR-01 adds failure backoff, since "no bucket" (cache hidden for TTL) and "unusable answer" (serve stale) diverge.
**Fix:** Make the body shape part of the success condition so the wrong shape yields no jq output (-> `return 1` -> grace):
```jq
select(type == "object" and (.limits | type) == "array")
| ( [ .limits[] | objects | select(...) ] | first // {} ) as $b
| @sh "..."
```

### IN-03: A relative / slash-less `STATUSLINE_USAGE_CACHE` silently creates a directory of that name and never writes a cache

**File:** `kit/files/home/.claude/statusline.sh:240`, `:292-295`
**Issue:** `${FAB_CACHE%/*}` on a value without `/` returns the whole value, so `mkdir -p relcache` creates a *directory* named after the intended file, `mktemp relcache/.usage.XXXXXX` succeeds, and `mv -f tmp relcache` moves the temp file *into* the directory under its random name; `read_cache` then sees a directory (`-r` true, jq fails, all empties), so every render fetches again. Verified. The header comment calls the value an "absolute path (D-57, D-65)" but nothing enforces it. Test-only knob today; still a silent misconfiguration mode.
**Fix:** Validate once at the top:
```bash
case "$FAB_CACHE" in /*) ;; *) FAB_CACHE=$HOME/.claude/statusline-usage-cache.json ;; esac
```

### IN-04: Stdin probe accepts only an ISO-string `model_scoped[].resets_at`; a numeric epoch (the shape of its `five_hour`/`seven_day` siblings) is dropped

**File:** `kit/files/home/.claude/statusline.sh:397-398`, `:337-339`
**Issue:** `FAB_SI_RST=\($ms.resets_at // "" | strings // "")` empties any non-string, and `get_fable_weekly` feeds it only through `iso_to_epoch`. The rest of the stdin `rate_limits` contract uses epoch *seconds* as numbers (`five_hour.resets_at`, `seven_day.resets_at`), and `model_scoped` is acknowledged in the code as "absent today", i.e. its shape is a guess. If Claude Code ships it with a numeric `resets_at`, the percent renders but the countdown silently disappears (verified with `resets_at: 0` -> `Fable 33%/1w`, no parens). Low cost to accept both now rather than debug a missing countdown later.
**Fix:** Emit the field as a number when numeric, a string otherwise, and branch in `get_fable_weekly`:
```jq
FAB_SI_RST=\($ms.resets_at // "" | (numbers | floor | select(. >= 0 and . < 1e15)) // (strings // ""))
```
```bash
case "$FAB_SI_RST" in ''|*[!0-9]*) FAB_RST=$(iso_to_epoch "$FAB_SI_RST") ;; *) FAB_RST=$FAB_SI_RST ;; esac
```

### IN-05: Harness header says "no network", but §11.10 sends traffic to 192.0.2.1; empty-assignment prefix style is brittle

**File:** `tests/run.sh:10-11`, `:613-627`, `:486`, `:618`
**Issue:** The top comment promises "hermetic - no Keychain, no network"; §11.10 deliberately opens a TCP connection to TEST-NET-1 (and, on a host with `http_proxy` set, to the proxy). Harmless, but the header is wrong and the probe's wall-time bound depends on the network stack (a proxy that *accepts* and stalls would fail the 3 s bound only because of `--max-time`). Separately, `STATUSLINE_NO_FABLE= STATUSLINE_USAGE_CACHE=...` (shellcheck SC1007) relies on the reader knowing that `VAR= cmd` assigns an empty string; `STATUSLINE_NO_FABLE=''` says so explicitly.
**Fix:** Amend the header ("no Keychain, no network except one connection attempt to the unroutable TEST-NET-1 address in §11.10") and use `STATUSLINE_NO_FABLE=''` in `fable_render` and §11.10.

### IN-06: `ls -l ... | cut -c1-10` mode check depends on `ls` column layout

**File:** `tests/run.sh:508`; `tests/sandbox.sh:294`
**Issue:** The 0600 assertion takes the first ten characters of `ls -l`, which is the mode string on both BSD and GNU today (extended-attribute `@` / SELinux `.` land at column 11), so it works, but it is the only place in the suite that asserts a file mode and it does so through a presentation format rather than a fact. `stat` differs BSD/GNU, so `ls` is the pragmatic choice - document that the column-10 slice is intentional, or use the project's own dual-fallback pattern.
**Fix:** Either leave as-is with a comment, or:
```bash
mode=$(stat -c %a "$CACHE" 2>/dev/null || stat -f %Lp "$CACHE" 2>/dev/null)
check_eq "fable: cache file mode 600" "600" "$mode"
```

---

_Reviewed: 2026-08-23T00:08:18Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
