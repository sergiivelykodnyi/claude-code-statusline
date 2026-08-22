# Phase 3: Install & Dual-Environment Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-22
**Phase:** 3-Install & Dual-Environment Validation
**Areas discussed:** Sandbox validation method, Symlink resilience & install command, README shape & depth, Settings snippet details

---

## Sandbox validation method

### Q1 — How do your Docker Sandboxes see Claude Code config today?

| Option | Description | Selected |
|--------|-------------|----------|
| Not sure — verify empirically first | Launch a sandbox and inspect before planning around it | |
| Host ~/.claude is mounted/shared | Sandbox sees real ~/.claude at some home path | |
| Sandbox has its own ~/.claude | Independent config per sandbox | |

**User's choice:** Free text — "Not sure, it looks like we need to create an sbx kit to put statusline.sh inside the Docker sandbox. You can investigate docs https://docs.docker.com/ai/sandboxes/ … kits docs …/customize/kits/".
**Notes:** Docs read during the session established: `~/.claude` is not imported into sandboxes; symlinks to host paths can't be followed; sandbox user `agent`, home `/home/agent`; workspace mounted at the same absolute path; mixin kits copy `files/home/…` to `/home/agent/…`; `~/.claude/settings.json` is a reserved sandbox-managed path.

### Q2 — Where should the canonical statusline.sh live?

| Option | Description | Selected |
|--------|-------------|----------|
| Move script into the kit dir (Recommended) | One file; host symlink points into the kit; kit copies it | ✓ |
| Keep root statusline.sh, kit holds a copy | Two files kept byte-identical by the harness | |
| Kit fetches the script at creation | curl from GitHub raw in setup.install | |

**User's choice:** Move script into the kit dir.

### Q3 — How does the statusLine setting reach the sandbox?

| Option | Description | Selected |
|--------|-------------|----------|
| Kit startup jq-merge (Recommended) | Idempotent minimal merge of the statusLine key into /home/agent/.claude/settings.json | ✓ |
| Project .claude/settings.json | Per-repo shared-project scope | |
| Both: kit merge + README shows project snippet | | |

**User's choice:** Kit startup jq-merge.

### Q4 — What evidence counts as "renders identically in a live sandbox"?

| Option | Description | Selected |
|--------|-------------|----------|
| Harness-in-sandbox + live check (Recommended) | tests/run.sh inside a kit-created sandbox, byte-diff vs host, plus a live `sbx run claude --kit` eyeball | ✓ |
| Live eyeball only | | |
| Harness-in-sandbox only | | |

**User's choice:** Harness-in-sandbox + live check.

---

## Symlink resilience & install command

### Q1 — Exact form of the host install one-liner

| Option | Description | Selected |
|--------|-------------|----------|
| ln -sf "$PWD/<kit path>" from repo root (Recommended) | Absolute target, -f replaces the stale link | ✓ |
| Placeholder absolute path, no -f | Reader edits the path | |
| Keep a thin root statusline.sh shim too | exec wrapper at repo root | |

**User's choice:** `ln -sf "$PWD/<kit path>"` from repo root.

### Q2 — How should the README tell you to apply the kit?

| Option | Description | Selected |
|--------|-------------|----------|
| --kit flag + sbx kit add (Recommended) | Local dir for new/existing sandboxes | ✓ |
| Git-URL kit reference | `git+https://…#dir=<kit-dir>` | ✓ |
| .sbxenv.yaml per project | Declarative per-project opt-in | |

**User's choice:** Free text — "Could you add both … Users should make a choice that is better for them."

### Q3 — Should the kit guarantee jq/git inside the sandbox?

| Option | Description | Selected |
|--------|-------------|----------|
| Guarded install in kit (Recommended) | `command -v jq || apt-get install -y jq` once at creation | ✓ |
| Assume present, verify in phase | | |

**User's choice:** Guarded install in kit.

### Q4 — Include a verify-the-install step?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, one mock-input command (Recommended) | Pipe sample JSON into ~/.claude/statusline.sh | ✓ |
| Yes, just `ls -L ~/.claude/statusline.sh` | | |
| No verify step | | |

**User's choice:** One mock-input command.

---

## README shape & depth

### Q1 — Structure and length

| Option | Description | Selected |
|--------|-------------|----------|
| Lean: 5 sections (Recommended) | What it shows, legend, host install, sandbox install, requirements (~60–80 lines) | ✓ |
| Minimal: no legend | ~40 lines | |
| Fuller: + development section | ~100+ lines | |

**User's choice:** Free text — Lean 5 sections, plus an optional `cp` install variant that overwrites the existing file, with a warning note in the README about that behavior.

### Q2 — Example output format

| Option | Description | Selected |
|--------|-------------|----------|
| Text block only (Recommended) | Fenced two-line example | ✓ |
| Text block + screenshot | PNG under docs/ | |
| Screenshot only | | |

**User's choice:** Text block only.

### Q3 — Treatment of the Phase-4 f() segment

| Option | Description | Selected |
|--------|-------------|----------|
| Describe current output only (Recommended) | Phase 4 updates README | ✓ |
| Show target layout, mark f() as planned | | |

**User's choice:** Describe current output only.

### Q4 — Explanatory notes

| Option | Description | Selected |
|--------|-------------|----------|
| Both notes, one line each (Recommended) | Why a kit; live-symlink behavior | ✓ |
| Only the sandbox note | | |
| Neither | | |

**User's choice:** Both notes.

---

## Settings snippet details

### Q1 — refreshInterval

| Option | Description | Selected |
|--------|-------------|----------|
| 60 seconds (Recommended) | Minute-granular countdowns | ✓ |
| 30 seconds | | |
| 10 seconds | | |

**User's choice:** 60 seconds.

### Q2 — padding

| Option | Description | Selected |
|--------|-------------|----------|
| Include padding: 0 (Recommended) | Matches current host settings and frameless layout | ✓ |
| Omit padding | | |

**User's choice:** Include padding: 0.

### Q3 — How to apply the snippet

| Option | Description | Selected |
|--------|-------------|----------|
| Show JSON to paste (Recommended) | Official-docs style | ✓ |
| jq merge one-liner | | |
| Both | | |

**User's choice:** Show JSON to paste.

### Q4 — Who applies it on the host

| Option | Description | Selected |
|--------|-------------|----------|
| You apply it following the README (Recommended) | README-following is the UAT; agents don't touch ~/.claude/settings.json | ✓ |
| Executor edits host settings.json | | |

**User's choice:** User applies it following the README.

---

## Claude's Discretion

- Kit directory name/location (suggested `kit/`), kit name/version fields, spec.yaml layout
- Exact idempotent jq-merge command and setup.startup form
- tests/run.sh path relocation, host-vs-sandbox byte-diff mechanism, optional `tests/sandbox.sh` helper
- Mock-input payload for the README verify command
- Fallback if sandbox tooling overwrites the merged statusLine key

## Deferred Ideas

- `.sbxenv.yaml` per-project kit wiring; host-side jq merge one-liner (not documented — README stays lean)
- Project-scope `.claude/settings.json` as the sandbox settings route (fallback only)
