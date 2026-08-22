# API Coverage — Anthropic OAuth usage endpoint (`GET https://api.anthropic.com/api/oauth/usage`) + Claude Code statusline stdin `rate_limits`

> Full coverage by default. Opt-outs are explicit, reasoned decisions.
> Surface enumerated from the live response captured 2026-08-22 (04-CONTEXT.md `<specifics>`, 04-RESEARCH.md §Verified Facts 2) and the installed Claude Code 2.1.240 binary (04-RESEARCH.md §Verified Facts 1). Phase 4 scope = the Fable weekly bucket only (D-47, D-49, Deferred Ideas).

| capability | decision | reason |
|---|---|---|
| `limits[]` entry `kind: "weekly_scoped"` with `scope.model.display_name` starting with `fable` (case-insensitive, first hit) → `percent` (0–100 int) | INTEGRATE | the phase's datum (D-47, D-50) — rendered as `Fable pct/1w` |
| same entry → `resets_at` (ISO-8601 string) | INTEGRATE | the segment's own countdown (D-54) via `iso_to_epoch` |
| stdin `rate_limits.model_scoped[] {display_name, utilization, resets_at}` (forward-compat projection in the binary; not on the statusline stdin in 2.1.240) | INTEGRATE | D-48 stdin-first probe folded into the single jq pass; empty today, exercised by `tests/fixtures/fable-stdin.json` |
| `limits[]` `weekly_scoped` entries for other models (Opus, Sonnet, …) | OPT-OUT | not needed yet — Deferred Idea in 04-CONTEXT.md ("other model-scoped weekly buckets"); the prefix-match adapter leaves room for it |
| `limits[]` `kind: "session"` (`percent`, `resets_at`) | OPT-OUT | not needed — the 5-hour window already arrives on stdin as `rate_limits.five_hour` (LIM-01, Phase 1) |
| `limits[]` `kind: "weekly_all"` (`percent`, `resets_at`) | OPT-OUT | not needed — the all-models weekly window already arrives on stdin as `rate_limits.seven_day` (LIM-02, Phase 1) |
| `limits[].severity` (`normal`/`warning`/…) | OPT-OUT | not needed yet — the script applies its own D-03/D-04/D-05 thresholds on the number (D-53); Fable-aware tuning is deferred to PRES-05 |
| `limits[].is_active`, `limits[].group`, `limits[].scope.model.id`, `limits[].scope.surface` | OPT-OUT | not needed — selection uses `kind` + `scope.model.display_name` only (D-50); `id` is null on the account today |
| `five_hour {utilization, resets_at, limit_dollars, used_dollars, remaining_dollars}` | OPT-OUT | not needed — stdin `rate_limits.five_hour` is the source for the 5h segment; dollar fields are null on subscriptions |
| `seven_day {utilization, resets_at, …}` | OPT-OUT | not needed — stdin `rate_limits.seven_day` is the source for the 1w segment |
| `seven_day_opus`, `seven_day_sonnet` | OPT-OUT | deprecated/null on the account (State of the Art row); the per-model data moved into `limits[]` — never read (D-47) |
| `seven_day_oauth_apps`, `seven_day_cowork`, `seven_day_omelette` | OPT-OUT | not needed yet — unrelated per-surface windows; no requirement |
| `extra_usage {is_enabled, monthly_limit, used_credits, utilization, currency}` | OPT-OUT | not needed yet — D-49 forbids using usage credits as a proxy for the Fable bucket; usage-credits display is excluded from the phase boundary |
| `spend {percent, severity, enabled}` | OPT-OUT | not needed yet — spend display excluded by the phase boundary (D-49) |
| misc flag keys (`amber_ladder`, `cinder_cove`, `iguana_necktie`, `member_dashboard_available`, `nimbus_quill`, `omelette_promotional`, `tangelo`) | OPT-OUT | not needed — server feature flags irrelevant to the status line |
| Authentication: `Authorization: Bearer <token>` + `anthropic-beta: oauth-2025-04-20` + `Content-Type: application/json` | INTEGRATE | the live-verified request headers (D-62); fed through `curl -K -` so the token never enters argv |
| OAuth token refresh (`refreshToken`, `/oauth/token`) | OPT-OUT | forbidden — Claude Code owns refresh; the script is read-only and hides on 401 (D-62, CLAUDE.md "never refresh the OAuth token yourself") |
| HTTP status semantics (401 bad token, 429 no auth, 5xx) | OPT-OUT (collapsed) | `curl -f` turns every non-2xx into "hidden"; the script never needs the reason (RESEARCH §Don't Hand-Roll) |
