# Phase 3: Install & Dual-Environment Validation - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 makes the status line installable and proven on both target environments, and documents it. On the **macOS host** the install is a symlink from `~/.claude/statusline.sh` into this repo (plus an optional copy variant). Inside **Docker Sandboxes** (`sbx` v0.39.0, Linux, user `agent`, home `/home/agent`) the install is a **mixin kit** shipped in this repo — discussion established from the official docs that sandboxes do *not* import host `~/.claude` and cannot follow symlinks to host paths, so the PROJECT.md assumption "sandboxes share `~/.claude`" is false and the kit replaces it. The phase proves identical rendering on host and in a live kit-created sandbox (PORT-01, PORT-04) and writes the README with what the line shows, the host install + `settings.json` snippet (with `refreshInterval`), the sandbox kit install, and a verify step (DOCS-01, DOCS-02). Requirements: PORT-01, PORT-04, DOCS-01, DOCS-02. Excludes: Fable `f()` segment and any README mention of it (Phase 4); new segments; install script (out of scope per PROJECT.md).

</domain>

<decisions>
## Implementation Decisions

### Sandbox install via mixin kit (replaces the shared-`~/.claude` assumption)
- **D-30:** Docker Sandboxes are served by a **`kind: mixin` sbx kit** committed in this repo. Static `files/home/.claude/statusline.sh` in the kit lands at `/home/agent/.claude/statusline.sh` at sandbox creation (kits copy `files/home/…` into `/home/agent/…`, preserving exec bits). Rationale: the Docker Sandboxes FAQ states user-level `~/.claude` is not imported and "Don't use symlinks to host paths because a sandboxed agent can't follow them." — **Reversibility:** costly — the README install story, repo layout, and sandbox UAT all build on the kit; reverting means re-documenting and re-verifying both environments.
- **D-31:** The **canonical `statusline.sh` moves into the kit directory** (e.g. `<kit-dir>/files/home/.claude/statusline.sh`); the repo root no longer holds the script (no shim). The host symlink and the kit both consume this single file — zero duplication. `tests/run.sh` must follow the script to its new path. — **Reversibility:** costly — every documented command and the harness path reference change if the file moves again.
- **D-32:** The `statusLine` setting reaches the sandbox via the kit's **`setup.startup` idempotent `jq` merge** that sets only the `statusLine` key in `/home/agent/.claude/settings.json` (create the file if absent, preserve all other keys, safe to re-run every start). The docs list that path as sandbox-managed/reserved, so the merge must be minimal and non-destructive, and the phase must verify the sandbox tooling does not clobber it (if it does, fall back to documenting project-scope `.claude/settings.json` — see Claude's Discretion).
- **D-33:** The kit's `setup.install` **guards the script's dependencies**: `command -v jq >/dev/null || apt-get install -y jq` (same for `git`), run once at creation — cheap insurance against base-image changes.
- **D-34:** Merged sandbox settings are byte-for-byte the documented host snippet: `{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}` — host and sandbox render identically by construction.

### Host install command
- **D-35:** README host install one-liner is run from the repo root with an absolute target and forced replace: `ln -sf "$PWD/<kit-dir>/files/home/.claude/statusline.sh" ~/.claude/statusline.sh`. `-f` is required because the user's existing host link points at the old root path and must be re-pointed.
- **D-36:** README also offers an **optional copy variant** (`cp` into `~/.claude/statusline.sh`) for people who don't want a live symlink; it **overwrites** any existing `~/.claude/statusline.sh` and the README carries an explicit **warning note** saying so.
- **D-37:** README documents **both** ways to apply the kit, reader's choice: (a) local — `sbx run claude --kit /abs/path/to/<kit-dir>` for new sandboxes and `sbx kit add <sandbox> /abs/path/to/<kit-dir>` for existing ones (absolute path: other projects' sandboxes don't mount this repo); (b) remote — `sbx run claude --kit "git+https://github.com/<owner>/claude-code-status-line.git#dir=<kit-dir>"` (note `kit.allowedSources` may need the GitHub prefix allow-listed).
- **D-38:** README includes **one mock-input verify command** — pipe a sample JSON payload into `~/.claude/statusline.sh` and expect the two colored lines — usable on the host and inside a sandbox shell; optionally mention `claude --debug` for the blank-line case.

### Validation evidence (PORT-01 / PORT-04)
- **D-39:** "Identical in a live Docker Sandbox" = **harness-in-sandbox + live check**: run `tests/run.sh` inside a sandbox created with the kit (e.g. `sbx run shell --kit <kit-dir>` with this repo as the workspace — it is mounted at the same absolute path) and diff fixture renders **byte-for-byte** against the host run; plus one `sbx run claude --kit <kit-dir>` session where the user eyeballs the live status line. Both are required; the harness part should be re-runnable.

### README shape
- **D-40:** Lean, ~60–80 lines, five sections: **What it shows** (fenced two-line text example, no screenshot), **Symbol legend** (one compact table: `⎇ * ≡ ≢ ↓N ↑N #N`, context segment, 5h/1w segments), **Install on host** (symlink one-liner, optional cp variant + warning, settings snippet as paste-this-JSON, verify command), **Install in Docker Sandboxes** (kit: local `--kit`/`sbx kit add` and `git+https` reference), **Requirements** (bash 3.2+, jq, git, Claude Code ≥ 2.1.x). No Development section.
- **D-41:** README describes **current output only** — no `f()` in the example or legend; Phase 4 updates the README when the Fable segment lands.
- **D-42:** Two one-line explanatory notes: (a) why sandboxes need a kit (host `~/.claude` isn't imported; symlinks can't cross into the sandbox); (b) with the symlink install, editing/pulling the repo changes the live status line immediately (the cp variant is the alternative).

### Settings snippet
- **D-43:** `refreshInterval` = **60** seconds (countdowns are minute-granular; lowest idle overhead; accepted up-to-a-minute lag on `<1m`/`now`).
- **D-44:** Snippet includes **`"padding": 0`** (matches the user's current host settings and the frameless D-21 layout).
- **D-45:** README presents the snippet as a JSON block to paste into `~/.claude/settings.json` (official-docs style); no jq one-liner for the host.
- **D-46:** **The user applies the snippet and re-points the symlink on the host by following the README — that is the host UAT.** Agents never edit `~/.claude/settings.json` or other files outside the repo.

### Claude's Discretion
- Kit directory name and location in the repo (suggested: `kit/` at repo root; keep the README path short), kit `name`/`version` fields, and the `spec.yaml` layout within the documented mixin schema.
- Exact idempotent jq-merge command, the `setup.startup` form (`command:` string vs array), and whether the merge also runs under `setup.install`.
- How `tests/run.sh` relocates its `SL=` path and whether it gains a check that the host symlink target exists; the portable byte-diff mechanism for host-vs-sandbox fixture renders; any helper script (e.g. `tests/sandbox.sh`) that automates D-39.
- Exact mock-input payload used in the README verify command (should exercise line 1 + line 2, e.g. the `tests/fixtures/full.json` shape).
- If the sandbox tooling is found to overwrite the merged `statusLine` key on start/re-attach, choose the fallback (document project-scope `.claude/settings.json`, or re-merge via `setup.startup`) and record it in the plan.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Docker Sandboxes (user-referenced during discussion — the install story depends on these)
- https://docs.docker.com/ai/sandboxes/ — product overview; `sbx run claude`; index of subpages
- https://docs.docker.com/ai/sandboxes/customize/kits/ — **kit spec** (`kind: mixin`/`sandbox`, `files/home/…` → `/home/agent/…`, `setup.install` once at creation, `setup.startup` every start & idempotent, `setup.files` with `onlyIfMissing`, reserved claude paths `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/.config.json`; `--kit` only at creation; `sbx kit add`; kit sources local/ZIP/git+https/OCI; `kit.allowedSources`)
- https://docs.docker.com/ai/sandboxes/faq — **"Sandboxes don't import your complete user-level agent configuration … files under `~/.claude` remain on the host"**; "Don't use symlinks to host paths"; `sbx skills import`
- https://docs.docker.com/ai/sandboxes/architecture/ — VM-based; workspace mounted at the **same absolute path** as on the host, bidirectional; persistence across stop/start, deleted on `sbx rm`
- https://docs.docker.com/ai/sandboxes/usage/ — extra workspaces `sbx run claude . /path:ro`; `sbx run` flags; persistence
- https://docs.docker.com/ai/sandboxes/configuration/environment-files/ — `.sbxenv.yaml` (`kits:` list, `sbx env run`) — considered and not chosen as the documented route; useful background only
- Local CLI: `sbx` v0.39.0 at `/opt/homebrew/bin/sbx` — `sbx run --help` (agents: claude, shell, …; `--kit strings` experimental; extra PATH args with `:ro`), `sbx kit --help` (add/inspect/pack/validate/…), `sbx create --help`

### Claude Code docs
- https://code.claude.com/docs/en/statusline — stdin schema, `statusLine` settings shape (`type`, `command`, `padding`, `refreshInterval`), `claude --debug`, workspace-trust requirement
- https://code.claude.com/docs/en/settings — settings scopes/precedence (user `~/.claude/settings.json`, shared project `.claude/settings.json`, local, managed)

### Layout & requirements
- `project-brief.md` — target layout, example output, and the one-sentence README brief ("what it shows + the symlink command")
- `.planning/REQUIREMENTS.md` — PORT-01, PORT-04, DOCS-01, DOCS-02 (the 4 requirements this phase covers)
- `.planning/ROADMAP.md` §Phase 3 — goal and the four success criteria

### Verified technical facts (research)
- `.planning/research/PITFALLS.md` §Pitfall 8 — "Symlink install silently breaks inside Docker Sandboxes" (now confirmed by the FAQ; the kit is the mitigation), workspace-trust note, symlink-writable-from-repo note to document
- `.planning/research/STACK.md` — settings config shape with `refreshInterval`, `claude --debug`, mock-input testing pattern, bash 3.2/BSD-GNU portability rules
- `.planning/research/ARCHITECTURE.md` — repo layout expectations (README, single script) — to be updated for the kit dir; "portability pass" step

### Existing code (modification targets)
- `statusline.sh` — the script to relocate into the kit dir unchanged (226 lines, bash 3.2, never-fail contract)
- `tests/run.sh` + `tests/fixtures/*.json` — 125-check harness; `SL=statusline.sh` path must follow the move; reused inside the sandbox for D-39

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `statusline.sh`: complete, verified (Phases 1–2) — Phase 3 moves it, does not change its rendering. Source guard at the bottom lets the harness source helpers.
- `tests/run.sh`: `cd "$(dirname "$0")/.."`, `SL=statusline.sh`, `check_eq`, ANSI-strip helper, fixture loop — the same run inside the sandbox gives the byte-identical evidence for D-39; fixture renders can be dumped to files and diffed host vs sandbox.
- `tests/fixtures/full.json`: natural payload for the README verify command (D-38).

### Established Patterns
- bash 3.2 subset, `#!/bin/bash`, no `set -e/-u`, exit 0 always, nothing on stderr — the kit's startup/install commands run on Linux bash but the script itself stays 3.2-safe.
- Harness convention (Phase 2): every new check must be shown to bite (fail before / pass after).
- Atomic docs-only commits via `gsd_run query commit`.

### Integration Points
- Host: `~/.claude/statusline.sh` currently → `/Users/sv/github/claude-code-status-line/statusline.sh` (stale after D-31; user re-points via README, D-46). `~/.claude/settings.json` has `statusLine` with `padding: 0` and **no `refreshInterval`** today.
- Sandbox: `/home/agent/.claude/statusline.sh` (kit file) + `/home/agent/.claude/settings.json` (`statusLine` key merged at startup, D-32). Workspace = this repo at its host absolute path when running the harness inside the sandbox.
- Docker daemon/sandboxd was not running during discussion — the sandbox UAT needs Docker Desktop/sandboxd up.

</code_context>

<specifics>
## Specific Ideas

- The user's own framing: "it looks like we need to create an sbx kit to put statusline.sh inside the Docker sandbox" — the kit *is* the sandbox install, not a workaround.
- The user wants the README to offer choices rather than one path: both local-dir and git+https kit references; symlink *and* cp on the host.
- Settings snippet to document verbatim: `{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 0, "refreshInterval": 60}}`.

</specifics>

<deferred>
## Deferred Ideas

- `.sbxenv.yaml` per-project kit wiring and a host-side `jq` merge one-liner were considered and intentionally not documented (README stays lean); revisit only if users ask.
- Project-scope `.claude/settings.json` as the sandbox settings route — fallback only if D-32's merge proves unreliable.

</deferred>

---

*Phase: 3-Install & Dual-Environment Validation*
*Context gathered: 2026-08-22*
