# Phase 4: Fable Weekly f() Segment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-22
**Phase:** 4-Fable Weekly f() Segment
**Areas discussed:** Which number f() shows, Cache & freshness policy, Credentials & Keychain, Rendering & testability

---

## Which number f() shows

| Option | Description | Selected |
|--------|-------------|----------|
| Always Fable | Match the bucket whose display_name starts with 'Fable' regardless of model in use | ✓ |
| Current model's bucket | Show the bucket matching the stdin model display_name | |
| Fable, else fall back | Prefer Fable; otherwise another model-scoped bucket under a different letter | |

**User's choice:** Always Fable

| Option | Description | Selected |
|--------|-------------|----------|
| Stdin first, endpoint fallback | Use a stdin model-scoped field when present; OAuth endpoint otherwise | ✓ |
| Endpoint only | One code path regardless of Claude Code version | |
| Stdin only if verified, else endpoint | Ship exactly one source for this Claude Code version | |

**User's choice:** Stdin first, endpoint fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Hide f() | No Fable bucket → hidden (hide-over-placeholder) | ✓ |
| Show usage-credits instead | Render `extra_usage` utilization as a proxy | |

**User's choice:** Hide f()

| Option | Description | Selected |
|--------|-------------|----------|
| Prefix match, first hit | display_name case-insensitively starts with 'fable'; first in server order | ✓ |
| Exact name, configurable | Exact 'Fable' by default, env-overridable | |
| Prefix match, highest utilization | Prefix rule; most-depleted bucket wins | |

**User's choice:** Prefix match, first hit
**Notes:** Scout of the installed Claude Code 2.1.240 binary showed no `seven_day_fable` key; per-model buckets are an array with a server-supplied display_name. A later live endpoint check confirmed the Fable bucket appears only in `limits[]` (`kind: weekly_scoped`), with `seven_day_opus`/`seven_day_sonnet` null.

---

## Cache & freshness policy

| Option | Description | Selected |
|--------|-------------|----------|
| 300 s | One call per 5 min per machine; community norm; invisible lag at weekly scale | ✓ |
| 60 s | Matches refreshInterval; ~5× more calls | |
| 180 s | jtbr gist middle ground | |

**User's choice:** 300 s

| Option | Description | Selected |
|--------|-------------|----------|
| One per user | Shared per-user cache file (0600, atomic tmp+mv); N sessions → 1 fetch per TTL | ✓ |
| One per session_id | Official statusline caching guidance; independent fetches; orphan files | |

**User's choice:** One per user

| Option | Description | Selected |
|--------|-------------|----------|
| Serve last-good, bounded | Keep last value up to a grace window (~1 h), then hide; retry each render after TTL | ✓ |
| Hide immediately | Any failure = hidden, even with a 6-minute-old value | |
| Serve last-good forever | Never hide while any cache exists | |

**User's choice:** Serve last-good, bounded

| Option | Description | Selected |
|--------|-------------|----------|
| Wait, bounded by timeout | One synchronous curl with short --max-time on cold start; no background processes | ✓ |
| Never wait | Skip on first render; fetch only on later renders | |

**User's choice:** Wait, bounded by timeout

---

## Credentials & Keychain

| Option | Description | Selected |
|--------|-------------|----------|
| File first, then Keychain | `~/.claude/.credentials.json` then `security find-generic-password -s "Claude Code-credentials" -w`; no OS branch | ✓ |
| Keychain first on macOS, file otherwise | Branch on uname/`command -v security` | |
| Env var override first, then file, then Keychain | Honour a token env var first | |

**User's choice:** File first, then Keychain

| Option | Description | Selected |
|--------|-------------|----------|
| Accept a one-time prompt | README says "Always Allow"; no extra machinery | ✓ |
| Never risk a prompt | Read Keychain only when stale and no kill switch; still cannot suppress macOS | |
| Skip Keychain entirely | Host users must supply the token themselves | |

**User's choice:** Accept a one-time prompt

| Option | Description | Selected |
|--------|-------------|----------|
| Verify live; hidden is acceptable | tests/sandbox.sh probes `.credentials.json` presence and the segment; hidden OK if absent; kit never copies tokens | ✓ |
| Document a sandbox login step | README tells users to log in inside the sandbox | |
| Kit ships/forwards the host token | Copy/mount host credentials into the sandbox | |

**User's choice:** Verify live; hidden is acceptable

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, one env var | Kill switch disables the Fable path entirely (no credential read, no network) | ✓ |
| No knob | Keep the script knob-free | |

**User's choice:** Yes, one env var

---

## Rendering & testability

| Option | Description | Selected |
|--------|-------------|----------|
| Same thresholds, number only | pct_color on the number only, wrapper/label plain (D-05 pattern) | ✓ |
| Whole f(..) token colored | Color spans the entire token | |
| Dim, no thresholds | Neutral secondary info | |

**User's choice:** Same thresholds, number only

| Option | Description | Selected |
|--------|-------------|----------|
| f() only inside 1w; 1w countdown only | Sub-segment of the weekly segment; no 1w → no f(); ignore Fable's reset | |
| f() can stand alone | Own segment when 1w is absent | |
| Show Fable's own reset too | e.g. `f(60% 2d:1h)` | |

**User's choice:** Free text — first "let's separate f() from the 1w segment, put f() first: `f(3%) 15%/1w (3d:5h:57m)`", then (after asking whether the 1w and Fable `resets_at` are the same — live check: identical to the second today, but independent fields) revised to: **"let's make f() a separate segment with its own countdown similar to 1w: `Fable 30%/1w (2d:4h:30m)` and put it last, after the 1w limit."** Interim answers "plain space joiner" and "ignore Fable reset" were superseded by this revision.

| Option | Description | Selected |
|--------|-------------|----------|
| Literal `Fable`, dim label | Hard-coded dim `Fable`; number threshold-colored; rest plain | ✓ |
| Server display_name, dim | Render whatever the server's display_name says | |
| Literal `Fable`, plain (not dim) | Label at equal weight to the numbers | |

**User's choice:** Literal `Fable`, dim label

| Option | Description | Selected |
|--------|-------------|----------|
| Env overrides | Env vars for endpoint URL, credentials path, cache path (production defaults); harness uses local fixture | ✓ |
| PATH shim for curl/security | Fake executables on PATH | |
| Cache-file injection only | Pre-write cache; fetch path covered only by live UAT | |

**User's choice:** Env overrides

| Option | Description | Selected |
|--------|-------------|----------|
| Example + legend + one note | Updated example, legend row, one note (token location, kill switch, Keychain prompt) | ✓ |
| Example + legend only | Minimal | |
| Dedicated 'Fable weekly' section | Longer section with endpoint/caching/troubleshooting | |

**User's choice:** Example + legend + one note

---

## Claude's Discretion

- Env var names (kill switch, endpoint/credentials/cache overrides); cache file name/location/format; exact `--max-time`; exact stale-grace window; mtime vs embedded fetch-time.
- ISO-8601 → epoch technique and helper placement.
- Adapter/segment naming and placement; second guarded jq call over the cached JSON; folding a stdin `model_scoped` probe into the single-pass jq program if the field exists.
- How the harness fakes the endpoint; sanitized fixture content; how `tests/sandbox.sh` detects credentials without printing them.
- Whether `project-brief.md` gets a "layout correction" note (D-52).

## Deferred Ideas

- Other model-scoped weekly buckets (Opus/Sonnet/…) and usage-credits/spend display — new capability.
- Fable-specific color thresholds — PRES-05 (v2).
