# Phase 3: Install & Dual-Environment Validation - Research

**Researched:** 2026-08-22
**Domain:** Install story for a bash status line — macOS host symlink + Docker Sandboxes (`sbx` v0.39.0) mixin kit + README
**Confidence:** MEDIUM-HIGH (CLI behaviour verified locally against `sbx` v0.39.0; kit semantics cross-checked between official docs and Docker's own contrib kits; one load-bearing behaviour — the sandbox engine rewriting `~/.claude/settings.json` — is evidenced only by community/contrib sources and must be confirmed in the live-sandbox UAT)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Sandbox install via mixin kit (replaces the shared-`~/.claude` assumption)
- **D-30:** Docker Sandboxes are served by a **`kind: mixin` sbx kit** committed in this repo. Static `files/home/.claude/statusline.sh` in the kit lands at `/home/agent/.claude/statusline.sh` at sandbox creation (kits copy `files/home/…` into `/home/agent/…`, preserving exec bits). Rationale: the Docker Sandboxes FAQ states user-level `~/.claude` is not imported and "Don't use symlinks to host paths because a sandboxed agent can't follow them." — **Reversibility:** costly — the README install story, repo layout, and sandbox UAT all build on the kit; reverting means re-documenting and re-verifying both environments.
- **D-31:** The **canonical `statusline.sh` moves into the kit directory** (e.g. `<kit-dir>/files/home/.claude/statusline.sh`); the repo root no longer holds the script (no shim). The host symlink and the kit both consume this single file — zero duplication. `tests/run.sh` must follow the script to its new path. — **Reversibility:** costly — every documented command and the harness path reference change if the file moves again.
- **D-32:** The `statusLine` setting reaches the sandbox via the kit's **`setup.startup` idempotent `jq` merge** that sets only the `statusLine` key in `/home/agent/.claude/settings.json` (create the file if absent, preserve all other keys, safe to re-run every start). The docs list that path as sandbox-managed/reserved, so the merge must be minimal and non-destructive, and the phase must verify the sandbox tooling does not clobber it (if it does, fall back to documenting project-scope `.claude/settings.json` — see Claude's Discretion).
- **D-33:** The kit's `setup.install` **guards the script's dependencies**: `command -v jq >/dev/null || apt-get install -y jq` (same for `git`), run once at creation — cheap insurance against base-image changes.
- **D-34:** Merged sandbox settings are byte-for-byte the documented host snippet: `{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}` — host and sandbox render identically by construction.

#### Host install command
- **D-35:** README host install one-liner is run from the repo root with an absolute target and forced replace: `ln -sf "$PWD/<kit-dir>/files/home/.claude/statusline.sh" ~/.claude/statusline.sh`. `-f` is required because the user's existing host link points at the old root path and must be re-pointed.
- **D-36:** README also offers an **optional copy variant** (`cp` into `~/.claude/statusline.sh`) for people who don't want a live symlink; it **overwrites** any existing `~/.claude/statusline.sh` and the README carries an explicit **warning note** saying so.
- **D-37:** README documents **both** ways to apply the kit, reader's choice: (a) local — `sbx run claude --kit /abs/path/to/<kit-dir>` for new sandboxes and `sbx kit add <sandbox> /abs/path/to/<kit-dir>` for existing ones (absolute path: other projects' sandboxes don't mount this repo); (b) remote — `sbx run claude --kit "git+https://github.com/<owner>/claude-code-status-line.git#dir=<kit-dir>"` (note `kit.allowedSources` may need the GitHub prefix allow-listed).
- **D-38:** README includes **one mock-input verify command** — pipe a sample JSON payload into `~/.claude/statusline.sh` and expect the two colored lines — usable on the host and inside a sandbox shell; optionally mention `claude --debug` for the blank-line case.

#### Validation evidence (PORT-01 / PORT-04)
- **D-39:** "Identical in a live Docker Sandbox" = **harness-in-sandbox + live check**: run `tests/run.sh` inside a sandbox created with the kit (e.g. `sbx run shell --kit <kit-dir>` with this repo as the workspace — it is mounted at the same absolute path) and diff fixture renders **byte-for-byte** against the host run; plus one `sbx run claude --kit <kit-dir>` session where the user eyeballs the live status line. Both are required; the harness part should be re-runnable.

#### README shape
- **D-40:** Lean, ~60–80 lines, five sections: **What it shows** (fenced two-line text example, no screenshot), **Symbol legend** (one compact table: `⎇ * ≡ ≢ ↓N ↑N #N`, context segment, 5h/1w segments), **Install on host** (symlink one-liner, optional cp variant + warning, settings snippet as paste-this-JSON, verify command), **Install in Docker Sandboxes** (kit: local `--kit`/`sbx kit add` and `git+https` reference), **Requirements** (bash 3.2+, jq, git, Claude Code ≥ 2.1.x). No Development section.
- **D-41:** README describes **current output only** — no `f()` in the example or legend; Phase 4 updates the README when the Fable segment lands.
- **D-42:** Two one-line explanatory notes: (a) why sandboxes need a kit (host `~/.claude` isn't imported; symlinks can't cross into the sandbox); (b) with the symlink install, editing/pulling the repo changes the live status line immediately (the cp variant is the alternative).

#### Settings snippet
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

### Deferred Ideas (OUT OF SCOPE)
- `.sbxenv.yaml` per-project kit wiring and a host-side `jq` merge one-liner were considered and intentionally not documented (README stays lean); revisit only if users ask.
- Project-scope `.claude/settings.json` as the sandbox settings route — fallback only if D-32's merge proves unreliable.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PORT-01 | The script produces identical output on macOS host (bash 3.2, BSD userland) and inside Docker Sandboxes (Linux, GNU userland) | §Byte-diff mechanism (render dump + `diff -r`/`cmp`, deterministic fixtures), §Sandbox environment facts (Ubuntu base, `agent`/uid 1000, jq+git present), harness-in-sandbox via `sbx exec` |
| PORT-04 | The script works when invoked via a symlink from `~/.claude/statusline.sh`, verified in both environments | §Host symlink facts (`ln -sf` over the existing *regular file*, `$0`/`BASH_SOURCE` unaffected, self-contained script), §Kit static-file exec bit + `chmod 0755` insurance, render-through-installed-path dump |
| DOCS-01 | README briefly describes what the status line shows (with the example layout) and the `ln -s` command that symlinks `statusline.sh` into `~/.claude` | §README facts (install one-liner, cp-variant pitfalls, verify payload), §Code Examples |
| DOCS-02 | README includes the `settings.json` `statusLine` snippet (with `refreshInterval` so countdowns tick while idle) | §Claude Code statusLine settings (fields verified from official docs: `type`, `command`, `padding`, `refreshInterval` min 1, tilde expansion, reload semantics) |
</phase_requirements>

## Summary

Phase 3 has no new rendering logic; it is a **relocation + packaging + documentation + dual-environment proof** phase. The three load-bearing technical facts the planner needs are: (1) the **exact `spec.yaml` grammar the installed `sbx` v0.39.0 accepts** — verified locally with `sbx kit validate` / `sbx kit inspect --json` against a draft kit: `schemaVersion: "2"` is mandatory for a `setup:` block, `setup.install[].command` must be a **string** (multi-line `|` blocks fine), `setup.startup[].command` must be a **string array** (`["sh","-c","…"]`), `user: "0"`, `description`, `background`, `requires.agent`, `setup.files[].mode/onlyIfMissing` all validate; (2) **the sandbox engine rewrites `/home/agent/.claude/settings.json`** — Docker's own contrib `claude-mem` kit comments "at create time the engine seeds this file late in the sequence and overwrites whatever exists; merging before that loses our key", and community kits/posts (sbx 0.38) report a fresh `settings.json` on every `sbx run` — which means D-32's **startup-time idempotent merge is the right design**, and it must **wait for the platform seed** (poll for the `themeId` key, ≤60 s, then merge anyway) exactly as Docker's contrib kit does; (3) on the host, **`~/.claude/statusline.sh` is today a regular-file copy, not a symlink** (verified: `file` + `cmp` identical to the repo script, mtime 13:53 today) — `ln -sf` replaces it fine (tested), but the README's cp variant must not be written as `cp src ~/.claude/statusline.sh` when a symlink may exist, because BSD `cp` **follows the symlink and writes through into the repo** (tested; also re-creates the old root-path file if the link dangles).

Two documented-vs-CLI conflicts need an explicit plan decision: the docs say `sbx kit add` "supports mixin kits limited to `environment.variables`, `setup.install`, and `permissions.network.allow`" (i.e. **no `files/`, no `setup.startup`**), while the v0.39.0 `sbx kit add --help` says the container is **recreated with the new kit appended to its original kit list** — whether static files land on `kit add` must be checked in the sandbox UAT before D-37(a)'s `sbx kit add` sentence is published as-is. And `sbx kit inspect --json` reports `mode: 420` (0644) for **every** static file regardless of its on-disk mode (tested with 0600/0755/0777) even though the zip produced by `sbx kit pack` preserves modes and Docker's contrib statusline kit README states "The engine preserves the file's executable bit" — treat exec-bit preservation as MEDIUM and add a one-line `chmod 0755` to the startup reconcile as insurance.

**Primary recommendation:** Create `kit/` at the repo root (`kit/spec.yaml` + `kit/files/home/.claude/statusline.sh` via `git mv`, mode 100755 preserved), model `spec.yaml` on Docker's contrib `claude-sbx-statusline` + `claude-mem` kits (schemaVersion "2", `requires.agent: claude`, install-time `jq`/`git` guard, a root `setup.startup` `["sh","-c",…]` that waits for the platform seed then `jq`-merges only `.statusLine`, `chmod 0755`s the script and `chown`s `~/.claude`), re-point `tests/run.sh` to `SL=kit/files/home/.claude/statusline.sh`, add a small render-dump script so host and sandbox fixture renders can be `diff -r`'d, and drive the sandbox half of D-39 with `sbx create claude . --kit ./kit` + `sbx exec` (not `sbx run shell`, because the kit should declare `requires.agent: claude`).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical script location | Repo (`kit/files/home/.claude/statusline.sh`) | — | Single source consumed by host symlink and kit (D-31) |
| Host install | User's shell (README one-liner: `ln -sf` / `cp`) | macOS FS semantics | Agents never touch `~/.claude` (D-46); README must be correct for BSD `ln`/`cp` |
| Host settings | User pastes JSON into `~/.claude/settings.json` | Claude Code settings loader | Official-docs style; reload is automatic on next interaction |
| Sandbox file delivery | sbx kit engine (`files/home` → `/home/agent`) at creation | `setup.startup` `chmod` insurance | Docs: static files copied at creation; exec bit preservation MEDIUM |
| Sandbox settings | Kit `setup.startup` (root) jq merge, every start | `setup.install` (optional duplicate) | Platform seeds/overwrites `settings.json` late at create (contrib evidence) → startup reconcile wins |
| Dependency guard | Kit `setup.install` (root, once) | Base image (already has jq+git) | D-33; apt needs root + network at creation |
| Dual-env proof | `tests/run.sh` + render-dump script run on host and via `sbx exec` | Human live check (`sbx run claude --kit`) | D-39; both halves required |
| Documentation | `README.md` (repo root) | `.planning/research/ARCHITECTURE.md` layout note | DOCS-01/02, D-40..D-45 |

## Project Constraints (from CLAUDE.md)

Directives extracted from `./.claude/CLAUDE.md` that bind this phase:

- **Dependencies assumed:** `jq`, `git`, standard Unix tools in both environments (the kit's D-33 guard is insurance, not a requirement).
- **Portability:** identical behaviour on macOS (BSD userland, bash 3.2.57) and Docker Sandbox Linux (GNU) — avoid flags that differ (`date -d`/`-r`, `stat -c`/`-f` alone, `sed -i` quirks, `readlink -f`, `echo -e`). The **kit's `setup.*` commands run on Linux only** (root shell in the sandbox) so GNU-isms like `mktemp -p` are acceptable *there*; anything that runs on the host (`tests/*.sh`, README one-liners) must stay BSD/GNU-neutral and bash-3.2-safe.
- **Performance:** status line must stay fast; Phase 3 must not add render-path work (it doesn't — install/packaging only).
- **Config shape is prescribed:** `{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 60}}` in `~/.claude/settings.json`; `refreshInterval` recommended 30–60 (D-43 = 60); `padding` optional int (D-44 = 0); script must be `chmod +x`; non-zero exit or empty output blanks the line; workspace trust must be accepted.
- **Testing pattern:** mock-input via `echo '{…}' | ./statusline.sh`; `claude --debug` for a blank line; shellcheck optional advisory.
- **Never:** `git fetch` in the script, blocking curl, token refresh, node-based statusline deps — unchanged by this phase.
- **GSD workflow enforcement:** file edits happen through GSD commands; atomic docs commits via `gsd_run query commit`.

## Standard Stack

No new runtime dependencies. This phase uses tools already present; versions verified on the host 2026-08-22.

### Core
| Tool | Version (host) | Purpose | Why Standard |
|------|----------------|---------|--------------|
| `sbx` (Docker Sandboxes CLI) | v0.39.0 (`def8cb05…`), `/opt/homebrew/bin/sbx` [VERIFIED: `sbx version`] | Validate/inspect the kit locally; create sandbox with `--kit`; `sbx exec` to run the harness inside | Only supported way to get files into `/home/agent` (FAQ: host `~/.claude` not imported) |
| `jq` | 1.7.1 host; present in `docker/sandbox-templates:claude-code` [CITED: github.com/docker/sbx-kits-contrib claude-sbx-statusline README — "jq … git, awk, hostname … All are present on the claude-code base image"] | Kit startup merge of `.statusLine`; script ingestion | Already a project dependency |
| `git` | 2.50.1 host; in base image [CITED: same] | Preserves the script's 100755 mode across the move (`git ls-files -s` → `100755` today) [VERIFIED: `git ls-files -s statusline.sh`] | — |
| `/bin/bash` | 3.2.57 host; bash 5 in Ubuntu image [ASSUMED: Ubuntu base per docs; exact version unverified] | Harness + script | — |
| `diff`/`cmp`/`cksum` | POSIX; present on host (`/usr/bin/diff` Apple/FreeBSD, `/usr/bin/cmp`) [VERIFIED] | Host-vs-sandbox byte comparison | Identical semantics BSD/GNU |
| `claude` | 2.1.239 host [VERIFIED: `claude --version`] | Host UAT; `claude --debug` for blank line | `refreshInterval`/`padding` supported |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `/sbin/sha256sum` (macOS, GNU-format output) and `shasum -a 256` (perl) both exist on this host [VERIFIED]; Linux has coreutils `sha256sum` | Optional checksum manifest | Only if a one-line manifest is preferred over `diff -r`; `cksum` (POSIX) is the most portable single command |
| `shellcheck` 0.11.0 (`/opt/homebrew/bin`) [VERIFIED] | Advisory lint of `tests/*.sh` and the kit's inline sh | Keep as non-failing advisory (existing harness convention) |
| Docker Desktop / `sandboxd` | Required to create sandboxes; **currently `Status: stopped`** [VERIFIED: `sbx daemon status`] | Sandbox UAT only; `sbx kit validate/inspect/pack` work with the daemon stopped [VERIFIED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mixin kit (D-30) | Custom template image (`sbx template`/Dockerfile), `.sbxenv.yaml`, `sbx skills import` | Templates bake the script into an image (rebuild on every script change, and the agent config is still recreated at create); `.sbxenv.yaml` deferred by CONTEXT; skills import is for skills only |
| `setup.startup` merge (D-32) | `setup.install`-only merge (Docker contrib `claude-sbx-statusline` does this) | Contrib `claude-mem` kit documents that the engine seeds `settings.json` *after* install at create time and overwrites → install-only can lose the key; startup + wait is robust; doing both is harmless |
| `diff -r` of dumped renders | `sha256sum` manifest | Checksums hide *what* differs; `diff`/`cmp` show the byte; both portable |
| `sbx exec` into a `claude` sandbox for the harness | `sbx run shell --kit kit` (CONTEXT example) | With `requires.agent: claude` the kit is inert on the `shell` agent; `sbx exec` on the kit-created `claude` sandbox exercises the real install path and "If the sandbox is stopped, it is started first" [VERIFIED: `sbx exec --help`] |

**Installation:** nothing to install. (No packages → Package Legitimacy Audit not applicable: no external packages are added by this phase.)

## Package Legitimacy Audit

Not applicable — this phase installs no npm/PyPI/crates packages. The only "install" is `apt-get install -y jq git` **inside the sandbox at creation, guarded by `command -v`**, against Ubuntu's official repos (already present in the base image, so the guard is expected to be a no-op).

## Architecture Patterns

### System Architecture Diagram

```
 repo (host path == sandbox path, bidirectional bind mount)
 ┌──────────────────────────────────────────────────────────────────────┐
 │ kit/spec.yaml                                                        │
 │ kit/files/home/.claude/statusline.sh   ◄── canonical script (100755)│
 │ tests/run.sh  tests/fixtures/*.json  tests/render-fixtures.sh (new) │
 │ README.md                                                            │
 └───────┬───────────────────────────────────────┬──────────────────────┘
         │ host: user runs README one-liner      │ sandbox: sbx create/run claude . --kit ./kit
         ▼                                       ▼
 ~/.claude/statusline.sh ──symlink──► repo   sbx engine: files/home/.claude/statusline.sh
 ~/.claude/settings.json (user pastes           → /home/agent/.claude/statusline.sh (at creation)
   statusLine snippet, refreshInterval 60)      setup.install (root, once): jq/git guard
         │                                      setup.startup (root, every start):
         │                                        wait platform seed → jq merge .statusLine
         │                                        → chmod 0755 script → chown agent ~/.claude
         ▼                                       ▼
  Claude Code (host) ── stdin JSON ──►  same script  ◄── stdin JSON ── Claude Code (sandbox)
         │                                       │
         └──────── tests/render-fixtures.sh  ────┘
                   dumps raw renders → tests/out/{host,sandbox}/ → diff -r (byte-identical = PORT-01)
                   also renders via ~/.claude/statusline.sh vs repo path → cmp (PORT-04 both envs)
```

### Recommended Project Structure

```
claude-code-status-line/
├── README.md                          # NEW (DOCS-01/02, D-40..D-45)
├── kit/                               # NEW — the sbx mixin kit (D-30)
│   ├── spec.yaml                      # schemaVersion "2", kind mixin
│   └── files/home/.claude/statusline.sh   # MOVED here via git mv (D-31), mode 100755
├── tests/
│   ├── run.sh                         # SL= re-pointed; optional -x check; INFO on installed path
│   ├── render-fixtures.sh             # NEW — dumps raw fixture renders to a dir for diff (D-39)
│   ├── sandbox.sh                     # OPTIONAL — wraps sbx create/exec/diff for D-39
│   └── fixtures/*.json                # unchanged
├── .gitignore                         # add tests/out/
└── .planning/research/ARCHITECTURE.md # layout note updated (kit dir)
```

### Pattern 1: Mixin kit modelled on Docker's contrib kits (spec grammar verified on v0.39.0)

**What:** `schemaVersion: "2"`, `kind: mixin`, `requires.agent: claude`, install = string commands, startup = array command as root with wait + merge.
**When to use:** Always (locked D-30..D-34).
**Grammar facts verified locally with `sbx kit validate` / `inspect --json` (v0.39.0, daemon stopped):** [VERIFIED: local CLI probe 2026-08-22]
- `schemaVersion: "2"` required — with `"1"` or absent: `field setup not found in type spec.SpecFile`.
- `setup.install[].command` **must be a string** (single line or `|` block); an array fails `cannot unmarshal !!seq into string`.
- `setup.startup[].command` **must be a string array**; a string fails `cannot unmarshal !!str … into []string`.
- Accepted fields: `name`, `version` (optional), `displayName`, `description`, `requires: {agent: claude|shell}`, per-command `user: "0"`, `description`, `background: true`; `setup.files[] {path, content, mode: "0755", onlyIfMissing: true}`.
- Unknown top-level keys are rejected (`field bogusKey not found`).
- Validation does **not** reject static files or `setup.files` targeting the reserved `~/.claude/settings.json` — the reserved-path rule is a documented convention, not enforced.
- `sbx kit inspect --json` lists `files[]` with `relativePath`, `target: "home"`, `mode: 420` (0644) for **every** file regardless of on-disk mode; `sbx kit pack` zips preserve real modes (`-rwxr-xr-x` for the script). Treat "engine preserves exec bit" as [CITED: sbx-kits-contrib claude-sbx-statusline README — "The engine preserves the file's executable bit, so Claude Code can invoke it directly."] MEDIUM and add `chmod 0755` insurance.

**Example (recommended `kit/spec.yaml`):**
```yaml
# Source: grammar verified with `sbx kit validate` v0.39.0; shape follows
# github.com/docker/sbx-kits-contrib (claude-sbx-statusline + claude-mem)
schemaVersion: "2"
kind: mixin
name: claude-code-status-line
version: "1.0.0"
displayName: Claude Code Status Line
description: Ships ~/.claude/statusline.sh and sets the statusLine key in ~/.claude/settings.json (jq merge; all other keys preserved).
requires:
  agent: claude            # settings.json is only read by Claude Code; inert elsewhere
setup:
  install:
    - command: command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends jq git)
      description: Guard the script's dependencies (both already ship in the claude-code base image)
  startup:
    - command:
        - sh
        - -c
        - |
          set -e
          H=/home/agent; S=$H/.claude/settings.json
          mkdir -p "$H/.claude"
          # Wait for the platform's own settings seed (it lands late at create
          # time and overwrites the file); merge after it, every start.
          i=0; while [ $i -lt 60 ] && ! grep -q themeId "$S" 2>/dev/null; do sleep 1; i=$((i+1)); done
          tmp=$(mktemp -p "$H/.claude")
          jq -n 'try (input) catch {} | (if type=="object" then . else {} end)
                 | .statusLine = {type:"command",command:"~/.claude/statusline.sh",padding:0,refreshInterval:60}' \
             "$S" > "$tmp" 2>/dev/null || printf '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":60}}\n' > "$tmp"
          mv "$tmp" "$S"
          chmod 0755 "$H/.claude/statusline.sh" 2>/dev/null || true
          chown -R agent:agent "$H/.claude"
      user: "0"
      description: Idempotent statusLine merge after the platform seed; exec-bit + ownership insurance
```
Notes: `jq -n 'try (input) catch {}'` was tested on the host against a missing-arg/empty/invalid/array file — empty and invalid content yield `{}`; a **nonexistent path makes jq exit 2** (hence the `|| printf` fallback, or `[ -f "$S" ] || echo '{}' > "$S"` first, as the contrib kit does) [VERIFIED: local jq 1.7.1 probe]. The `set -e` + `|| true` on `chmod` keeps the reconcile from aborting before `chown` if the file is absent.

### Pattern 2: Host install one-liners that survive today's real host state

**What:** `ln -sf` over the **existing regular file** (today's state), safe cp variant.
**Facts (tested on macOS 26.6.2, BSD `ln`/`cp`/`install`):** [VERIFIED: scratch probe 2026-08-22]
- `~/.claude/statusline.sh` is currently a **regular file** (9800 bytes, identical to repo `statusline.sh`, mtime Aug 22 13:53) — **not** the symlink CONTEXT.md assumes. `ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh` replaces a regular file *and* re-points an existing symlink (both tested, rc 0).
- Pitfall: if the destination were a **directory**, `ln -sf` creates the link *inside* it (tested). Not today's state; no README action needed beyond the absolute-path form.
- `cp SRC ~/.claude/statusline.sh` when the destination is a **symlink follows it and writes through into the repo file** (tested: repo file content replaced); on a **dangling** symlink it creates the file at the old target path (tested: `repo/GONE.sh` re-created). `install -m 755 SRC DEST` does the same write-through (tested). → README cp variant must be `rm -f ~/.claude/statusline.sh && cp kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh` (cp preserves the exec bit to a fresh destination — tested `-rwxr-xr-x`).
- Running via the symlink: `$0` and `BASH_SOURCE[0]` are the *link path* (`~/.claude/statusline.sh`), not the target (tested) — irrelevant because the script is fully self-contained (no `$0`-relative paths; source guard compares `BASH_SOURCE[0]` to `$0`, both the link path, so `main` still runs).
- `git mv statusline.sh kit/files/home/.claude/statusline.sh` keeps mode 100755 (index shows `100755` today) [VERIFIED: `git ls-files -s`].

### Pattern 3: Deterministic render dump + POSIX diff for PORT-01/PORT-04

**What:** A small bash-3.2-safe script renders each fixture through (a) the repo script and (b) `$HOME/.claude/statusline.sh` if present, writing raw bytes to `OUTDIR/{repo,installed}/<fixture>.out`; compare with `cmp`/`diff -r`.
**Why deterministic:** all seven fixtures render time-independently (`resets_at: 0` → `(now)`; `empty`/`malformed` render the harness's `$PWD` basename, identical in both environments because the workspace is mounted at the same absolute path [CITED: docs.docker.com/ai/sandboxes/architecture — "Your workspace is mounted at the same absolute path as on your host"]). The git-state matrix in `tests/run.sh` uses temp repos with fresh commits (SHAs/timestamps differ) and is *not* byte-comparable across environments — its PASS/FAIL summary line ("125 checks, 0 failures" today [VERIFIED]) is the in-sandbox evidence for that part.
**Where to write:** `tests/out/<env>/…` inside the repo (gitignored) — the sandbox can write there because the mount is bidirectional [CITED: architecture page — "changes in either direction are instant"]; then `diff -r tests/out/host tests/out/sandbox` on the host. `$TMPDIR` is `/tmp/claude-501` on the host and unset (→ `/tmp`) in the sandbox — fine for scratch, wrong for cross-env comparison, hence the in-repo dir.
**Checksum option:** `cksum` (POSIX, byte-identical output on BSD/GNU), or `/sbin/sha256sum` (macOS, GNU-format output, verified) vs coreutils `sha256sum`; `shasum -a 256` also present on macOS. Not needed if `diff -r` is used.

### Pattern 4: Driving the sandbox half of D-39

```bash
# Source: sbx v0.39.0 --help texts (verified locally)
sbx create --name sl-test claude . --kit "$PWD/kit"     # creation is the only time --kit applies
sbx exec sl-test sh -c 'ls -l ~/.claude/statusline.sh; jq .statusLine ~/.claude/settings.json'
sbx exec sl-test /bin/bash tests/run.sh                  # repo mounted at the same absolute path
sbx exec sl-test /bin/bash tests/render-fixtures.sh tests/out/sandbox
/bin/bash tests/render-fixtures.sh tests/out/host && diff -r tests/out/host tests/out/sandbox
sbx run --name sl-test                                   # live eyeball (Claude agent read from spec)
sbx rm sl-test
```
`sbx exec` "If the sandbox is stopped, it is started first" and runs as the container's default user (`-u root` available) [VERIFIED: `sbx exec --help`]. Default sandbox name is `<agent>-<workdir>` [VERIFIED: `sbx run --help`]. `--kit` "(Experimental) Kit reference (directory, ZIP, or OCI). Can be specified multiple times" and "only takes effect when a sandbox is created" [VERIFIED CLI / CITED kits docs].

### Anti-Patterns to Avoid
- **Static file or `setup.files` targeting `~/.claude/settings.json`:** docs reserve `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/.config.json` for the claude agent — "Treat these paths as sandbox-managed … Don't target them with static files, `setup.files`, or install commands. Later setup can replace your content" [CITED: docs.docker.com/ai/sandboxes/customize/kits]. Validation won't stop you (verified) — the engine will.
- **Merging before the platform seed:** `claude-mem` comment: "at create time the engine seeds this file late in the sequence and overwrites whatever exists; merging before that loses our key" [CITED: raw.githubusercontent.com/docker/sbx-kits-contrib/main/claude-mem/spec.yaml].
- **Using `sbx kit add` as the documented path for existing sandboxes without verifying:** docs: "It supports mixin kits limited to `environment.variables`, `setup.install`, and `permissions.network.allow`" [CITED: kits docs] vs CLI: "The sandbox's container is recreated with the new kit appended to its original kit list" [VERIFIED: `sbx kit add --help`]. Verify in UAT; if files don't land, document "recreate the sandbox (`sbx rm` + `sbx run … --kit`)" instead.
- **README cp variant as bare `cp SRC ~/.claude/statusline.sh`:** writes through an existing symlink into the repo (tested).
- **`sbx run shell --kit kit` for the harness** when the kit declares `requires.agent: claude` (the kit would be inert); use the `claude` sandbox + `sbx exec`.
- **GitHub URL in README copied from CONTEXT verbatim:** the actual remote is `git@github.com:sergiivelykodnyi/claude-code-statusline.git` (repo name `claude-code-statusline`, not `claude-code-status-line`) [VERIFIED: `git remote -v`]; the `git+https://…#dir=kit` reference must use the real name (and the repo must be public for anonymous `git+https`).
- **Relying on `setup.install` alone for settings** (contrib `claude-sbx-statusline` pattern): works only if the engine seeds before install or merges; the startup reconcile covers both orders.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Getting a file into `/home/agent` | `sbx cp` scripts, bind-mount tricks, host symlinks | Kit `files/home/…` | FAQ: symlinks to host paths can't be followed; `~/.claude` not imported |
| JSON merge of one key | sed/awk on settings.json | `jq '.statusLine = {...}'` with `try (input) catch {}` guard, tmp + `mv` | Handles absent/empty/invalid/non-object files; atomic rename |
| Byte comparison | custom hex dumps | `cmp` / `diff -r` (POSIX) | Identical on BSD/GNU |
| Kit validation | hand-reading YAML | `sbx kit validate ./kit` + `sbx kit inspect --json ./kit` | Ground truth for the installed CLI; works offline, daemon stopped |
| Settings reload | restart Claude | nothing — "Settings reload automatically, but changes won't appear until your next interaction" [CITED: code.claude.com/docs/en/statusline] | — |

**Key insight:** every moving part here is a thin declarative layer over tools already verified; the risk is in *semantics* (who overwrites what, when) — verified empirically, not hand-built.

## Runtime State Inventory

Phase 3 moves `statusline.sh` (a rename/relocation) — inventory of state outside the repo that still references the old location:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the script keeps no state; no caches exist yet (Phase 4 adds one) — verified by reading `statusline.sh` | none |
| Live service config | **Host `~/.claude/statusline.sh` is a regular-file copy of the repo script** (not a symlink; identical bytes, mtime today 13:53) — stale copy after the move; **`~/.claude/settings.json` `statusLine` = `{"type":"command","command":"~/.claude/statusline.sh","padding":0}`, no `refreshInterval`** [VERIFIED: `/bin/ls -l`, `file`, `cmp`, `jq .statusLine`] | User re-points with the README `ln -sf` and pastes the snippet (D-46 — host UAT); agents do not edit |
| OS-registered state | None (no launchd/cron/pm2; Claude Code invokes the script by settings path only) | none |
| Secrets/env vars | None referenced by this phase | none |
| Build artifacts / installed packages | None; the only derived artifact would be `sbx kit pack` zips — not part of the plan. Existing sandboxes (if any) created *before* the kit do not contain the script — `sbx ls` could not be run (daemon stopped) | README: existing sandboxes need `sbx kit add` (if verified) or recreate |

## Common Pitfalls

### Pitfall 1: Kit `spec.yaml` written in the docs' loose shape fails `sbx kit validate`
**What goes wrong:** `schemaVersion` omitted or `"1"`, install command as array, startup command as string → `INVALID … unmarshal errors`.
**Why it happens:** v0.39.0 parses kit-spec v2 strictly (release notes: "sbx kit inspect now describes kits using kit-spec v2 field names") [CITED: github.com/docker/sbx-releases/releases v0.39.0].
**How to avoid:** `schemaVersion: "2"`; install `command:` string; startup `command:` `["sh","-c","…"]`; run `sbx kit validate ./kit` as a harness/plan check (works offline).
**Warning signs:** `field setup not found in type spec.SpecFile`, `cannot unmarshal !!seq into string`.

### Pitfall 2: `settings.json` merge lost to the platform seed
**What goes wrong:** statusLine key present in install output but absent when Claude starts; or present on first start and gone after `sbx run` re-attach.
**Why it happens:** the engine seeds `~/.claude/settings.json` late at creation and overwrites; community reports a fresh file on each run (sbx 0.38) [CITED: claude-mem spec comment; vrchr.fr 2026-08-06 "each sbx run restarts with a blank settings.json"; SamirSaidani/sbx-claude-kit README "~/.claude/settings.json is overwritten on every sandbox creation"].
**How to avoid:** startup reconcile as root with the `themeId` wait (≤60 s, merge regardless afterwards); keep it idempotent; optionally also merge in install.
**Warning signs:** `jq .statusLine ~/.claude/settings.json` empty after start; status line blank in the sandbox while `~/.claude/statusline.sh` renders fine when piped manually.

### Pitfall 3: Startup doesn't gate the agent → first render may lag
**What goes wrong:** Claude starts before the reconcile finishes; no status line until the next interaction.
**Why it happens:** "startup commands don't gate the agent entrypoint" [CITED: kits docs]; Claude reloads settings automatically but "changes won't appear until your next interaction" [CITED: statusline docs].
**How to avoid:** Accept (document in the plan's UAT expectation: type one message / press Enter). Don't `sleep` longer than needed — poll.

### Pitfall 4: Exec bit not where you expect it
**What goes wrong:** `~/.claude/statusline.sh` not executable → "Permission denied" → blank line.
**Why it happens:** `inspect --json` reports 0644 for everything (engine behaviour unknowable offline); a `cp` to a fresh dest keeps the bit, but a checkout with `core.fileMode=false` wouldn't.
**How to avoid:** `chmod 0755` in startup reconcile; add `[ -x "$SL" ]` check to `tests/run.sh`; README verify command surfaces it immediately. Claude docs: "Verify your script is executable: `chmod +x ~/.claude/statusline.sh`" [CITED].

### Pitfall 5: `cp` variant writes through a symlink
**What goes wrong:** User with a symlink runs the cp variant; repo file gets overwritten (or a file reappears at the old root path if the link dangles).
**Why it happens:** BSD/GNU `cp` follow destination symlinks (tested on macOS).
**How to avoid:** README: `rm -f ~/.claude/statusline.sh && cp …`, plus the D-36 warning.

### Pitfall 6: `git+https` kit reference blocked by default
**What goes wrong:** `sbx run claude --kit "git+https://github.com/…"` refused.
**Why it happens:** "By default, only kits hosted on Docker Hub (`docker.io/`) are allowed"; `kit.allowedSources` "Entries match as prefixes on a path-segment boundary"; local dirs governed by `kit.allowLocalKits` (default `true`) [CITED: kits docs].
**How to avoid:** README note: `sbx settings set kit.allowedSources '["docker.io/","github.com/sergiivelykodnyi/"]'` (daemon must be running for `sbx settings`). Also the real repo name is `claude-code-statusline`.

### Pitfall 7: Workspace trust / sandboxd not running
**What goes wrong:** Status line silently blank in a new sandbox; `sbx create` fails.
**Why it happens:** Trust dialog not accepted ("Status line command skipped: workspace trust not accepted") [CITED: statusline docs]; `sandboxd` is currently stopped on the host [VERIFIED].
**How to avoid:** Plan's UAT step starts Docker Desktop/`sbx daemon start` first; sandbox claude runs `--dangerously-skip-permissions` by default [CITED: docs agents/claude-code] — trust is typically pre-accepted in the sandbox but verify with `claude --debug` if blank.

### Pitfall 8: `sbx kit add` may not deliver `files/`
See Anti-Patterns; verify before publishing D-37(a)'s sentence.

## Code Examples

### README host install (verified semantics)
```bash
# Source: tested on macOS 26.6.2 /bin/ln, /bin/cp (BSD)
# symlink (live; editing/pulling the repo updates the status line immediately)
ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh
# OR copy (static; overwrites any existing ~/.claude/statusline.sh)
rm -f ~/.claude/statusline.sh && cp kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh
```

### README settings snippet (fields verified against official docs)
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 60
  }
}
```
Docs: "The optional `padding` field adds extra horizontal spacing … Defaults to `0`"; "The optional `refreshInterval` field re-runs your command every N seconds in addition to the event-driven updates. The minimum is `1`. Set this when your status line shows time-based data"; "The `command` field runs in a shell" (so `~` expands) [CITED: code.claude.com/docs/en/statusline].

### README verify command (deterministic, exercises both lines; host and sandbox)
```bash
# Source: tests/fixtures/full.json shape; resets_at 0 renders "(now)" forever
echo '{"model":{"display_name":"Opus 5 (1M context)"},"effort":{"level":"high"},"workspace":{"current_dir":"/tmp/myproject"},"context_window":{"used_percentage":10.4,"total_input_tokens":100000,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":50.9,"resets_at":0},"seven_day":{"used_percentage":15.2,"resets_at":0}}}' | ~/.claude/statusline.sh
# expect (colored):
# Opus 5 (high) · myproject
# 10%/100k/1M · 50%/5h (now) · 15%/1w (now)
```

### `tests/render-fixtures.sh` sketch (bash 3.2-safe, BSD/GNU-neutral)
```bash
#!/bin/bash
# Usage: /bin/bash tests/render-fixtures.sh OUTDIR  — raw renders for byte diff (D-39)
cd "$(dirname "$0")/.." || exit 1
SL=kit/files/home/.claude/statusline.sh
OUT=${1:?outdir}; mkdir -p "$OUT/repo" "$OUT/installed"
for f in tests/fixtures/*.json; do
  n=${f##*/}; n=${n%.json}
  /bin/bash "$SL" < "$f" > "$OUT/repo/$n.out" 2>/dev/null
  [ -x "$HOME/.claude/statusline.sh" ] && "$HOME/.claude/statusline.sh" < "$f" > "$OUT/installed/$n.out" 2>/dev/null
done
# PORT-04 within one environment: installed path == repo path
[ -d "$OUT/installed" ] && diff -r "$OUT/repo" "$OUT/installed"
```
Then on the host: `diff -r tests/out/host/repo tests/out/sandbox/repo` (PORT-01).

### Harness relocation
```bash
# tests/run.sh
SL=kit/files/home/.claude/statusline.sh          # was: statusline.sh
[ -x "$SL" ]; check_ok "exec bit: $SL is executable" $?   # new, cheap, bites on mode loss
# optional advisory only (keeps the harness hermetic in the sandbox):
[ -e "$HOME/.claude/statusline.sh" ] && printf 'INFO installed: %s\n' "$(ls -l "$HOME/.claude/statusline.sh")"
```
`. "./$SL"` and `/bin/bash -n "$SL"` work unchanged with the nested path.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PROJECT.md assumption "sandboxes share `~/.claude`" / symlink install in sandbox | Mixin kit delivering `files/home/.claude/statusline.sh` | Docs FAQ (host `~/.claude` not imported) — confirmed this research | Kit is the sandbox install (D-30) |
| Kit spec v1 (`schemaVersion: "1"`, some kits use `commands.*`) | Kit spec v2 (`schemaVersion: "2"`, `setup.install/startup/files`) | sbx v0.39.0 (2026-08-19) describes kits with v2 field names; v1 `setup:` rejected by local validator | Write v2 |
| Install-time `settings.json` merge (contrib statusline kit) | Startup reconcile after platform seed (contrib claude-mem; community kits) | 2026 (claude-mem/vrchr/sbx-claude-kit reports) | D-32 startup merge + wait |
| `sbx kit add` limited to env/install/network (docs) | CLI v0.39.0: container recreated with kit appended | v0.39.0 help text | Verify in UAT |

**Deprecated/outdated:**
- CONTEXT.md "Host: `~/.claude/statusline.sh` currently → repo `statusline.sh`" — it is a regular-file copy today; `ln -sf` still correct.
- CONTEXT.md D-37 repo URL `claude-code-status-line.git` — actual GitHub repo is `claude-code-statusline`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Sandbox base image bash is ≥4 and `/bin/bash` exists (Ubuntu) | Standard Stack | `tests/run.sh` uses `/bin/bash` — if absent the harness can't run in-sandbox (Ubuntu always ships it; LOW risk) |
| A2 | Docker Desktop (or the sbx runtime) must be running for `sbx create/run`; `sbx daemon start` suffices | Pitfall 7 | UAT blocked until started |
| A3 | The platform seed key `themeId` is present in the engine-written `settings.json` (claude-mem relies on it) | Pattern 1 | Wait loop times out at 60 s then merges anyway — only a delay |
| A4 | `sbx exec` default user is `agent` (docker-exec semantics; `-u root` offered) | Pattern 4 | Harness would run as root; temp repos still work; `tests/out` files root-owned on the mount — use `-u 1000` if so |
| A5 | Engine copies `files/home` at creation only and preserves the exec bit | Pattern 1 | Covered by `chmod 0755` in startup reconcile |
| A6 | The GitHub repo `sergiivelykodnyi/claude-code-statusline` is public (needed for anonymous `git+https` kit refs) | Pitfall 6 | README documents a reference readers can't use; local `--kit` path still works |

## Open Questions (RESOLVED)

All four are closed by the Phase 3 plans: each has a concrete probe or evidence step whose outcome settles it at execution time and is recorded in `tests/out/sandbox/EVIDENCE.txt` and the 03-03 SUMMARY; the README follows the observed result (03-03 Task 3).

1. **Does `sbx kit add` deliver `files/` and `setup.startup` on v0.39.0?** — RESOLVED → 03-03-PLAN Task 1 step 12 (kit-add probe: create `<NAME>-add` without a kit, `sbx kit add`, then `wait_statusline` + `test -x`; check name `sbx kit add delivers ...`); 03-03 Task 3 keeps or replaces the README `sbx kit add` sentence per the PASS/FAIL line.
   - What we know: docs say only env vars / install / network-allow; CLI says container recreated with kit appended.
   - What's unclear: which is current.
   - Recommendation: plan a UAT step — `sbx create claude .` (no kit) → `sbx kit add NAME "$PWD/kit"` → check `~/.claude/statusline.sh` + `statusLine`. Word the README sentence accordingly; if unsupported, document recreate.
2. **Does the engine rewrite `settings.json` on every start (not only at create)?** — RESOLVED → 03-03-PLAN Task 1 step 11 (stop/start probe with an in-sandbox canary key; check name `statusLine survives stop/start (D-32)`); on FAIL, 03-03 Task 3 applies the CONTEXT fallback (document project-scope `.claude/settings.json`) and records it.
   - What we know: create-time late overwrite (contrib comment); "each `sbx run` … blank settings.json" (community, sbx 0.38).
   - What's unclear: v0.39.0 restart behaviour.
   - Recommendation: startup reconcile covers both; UAT: `sbx stop` + `sbx run --name` and re-check `.statusLine`. If the reconcile itself is reverted *after* running (engine writes after the 60 s window), fall back to the deferred project-scope `.claude/settings.json` route (precedence: project settings override user settings [CITED: code.claude.com/docs/en/settings — "a key at a higher level overrides the same key anywhere below it"; shared project sits above user]).
3. **Is the sandbox's `$HOME/.claude/statusline.sh` rendered via the kit identical to the repo copy byte-for-byte?** — RESOLVED → the PORT-04 render diff: `tests/render-fixtures.sh` (03-01-PLAN Task 2) run inside the sandbox with `INSTALLED=/home/agent/.claude/statusline.sh REQUIRE_INSTALLED=1` (03-03 Task 1 steps 8 and 10; check names `render dump in sandbox: installed == repo (PORT-04 sandbox half)` and `PORT-04: host vs sandbox installed-path renders byte-identical`). Expected yes (same file).
4. **`sbx run shell` image contents (jq/git)?** — RESOLVED: not needed — the harness runs via `sbx exec` in the `claude` sandbox (03-03 Task 1 step 7); `sbx run shell` is not used anywhere in Phase 3.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `sbx` CLI | kit validate/inspect, sandbox UAT | ✓ | v0.39.0 | — |
| `sandboxd` / Docker Desktop | sandbox UAT | ✗ (stopped) | — | Start before UAT (`sbx daemon start`); validate/inspect work offline |
| `docker` client | — (not directly used) | ✓ | 29.6.2 | — |
| `/bin/bash` | harness, script | ✓ | 3.2.57 | — |
| `jq` | script, merge tests | ✓ | 1.7.1 | — |
| `git` | harness, mode preservation | ✓ | 2.50.1 | — |
| `claude` | host UAT | ✓ | 2.1.239 | — |
| `diff`, `cmp`, `cksum`, `/sbin/sha256sum`, `shasum` | byte diff | ✓ | Apple diff; shasum 6.02 | — |
| `shellcheck` | advisory | ✓ | 0.11.0 | skip advisory |
| `unzip`, `python3` | optional kit-zip inspection | ✓ | — | — |

**Missing dependencies with no fallback:** none (sandboxd must simply be started for the UAT).
**Missing dependencies with fallback:** sandboxd stopped → start it; everything else present.

## Validation Architecture

Skipped — `.planning/config.json` sets `workflow.nyquist_validation: false`. (For the planner: the existing `tests/run.sh` — 125 checks, 0 failures on the host today — plus the new exec-bit check and `tests/render-fixtures.sh` are the phase's automated evidence; run with `/bin/bash tests/run.sh`.)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no credentials touched; Phase 4 owns the OAuth token) |
| V3 Session Management | no | — |
| V4 Access Control | yes (sandbox) | Kit startup runs as root only for the merge, then `chown -R agent:agent ~/.claude`; no world-writable files; script 0755 |
| V5 Input Validation | yes | `jq` merge treats `settings.json` as untrusted data (`try … catch {}`, object check); README one-liners quote `$PWD`; the statusline script's Phase 2 stdin guards are unchanged |
| V6 Cryptography | no | — (optional: `sbx kit sign/verify` exists in v0.39.0 but out of scope) |
| V14 Configuration / supply chain | yes | Local `--kit` path is the primary route; `git+https` pinned with `#ref=` when documented; `kit.allowedSources` default denies non-docker.io sources; `apt-get` guard uses Ubuntu official repos only |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Kit supply chain: remote `git+https` kit swapped | Tampering | Pin `#ref=<tag-or-sha>` in the README remote example; prefer local `--kit`; `kit.allowedSources` allow-list is prefix-matched |
| Root startup command clobbers agent config | Tampering / DoS | Merge only `.statusLine`; atomic tmp+`mv`; `chown` back; never `rm`/replace the whole file; verify in UAT |
| `cp` write-through into the repo via symlink | Tampering (self-inflicted) | `rm -f` before `cp` in README; warning note (D-36) |
| Untrusted/garbage `settings.json` breaks the merge | DoS | `try (input) catch {}` + object check → merge still produces valid JSON |
| Blank status line hides failure (silent) | Repudiation-ish | README verify command + `claude --debug`; harness exec-bit check |
| Status line command path expansion (`~`) in settings | Elevation? | Documented shell expansion; fixed literal path `~/.claude/statusline.sh` (D-34); no user input in the command string |

## Sources

### Primary (HIGH confidence)
- Local `sbx` v0.39.0 CLI: `sbx version`, `sbx --help`, `sbx kit --help`, `sbx kit validate/add/inspect/pack --help`, `sbx run --help`, `sbx create --help`, `sbx exec --help`, `sbx settings --help`, `sbx daemon status`; `sbx kit validate` / `inspect --json` / `pack` against a draft kit (schema grammar, file modes) — 2026-08-22
- Local host probes: `ln -sf`/`cp`/`install` semantics on macOS 26.6.2; `jq 1.7.1` merge behaviour on absent/empty/invalid/array files; `/bin/ls -l`, `file`, `cmp` on `~/.claude/statusline.sh`; `jq .statusLine ~/.claude/settings.json`; `git ls-files -s`; `git remote -v`; tool versions; `tests/run.sh` baseline (125/0)
- Repo files read: `statusline.sh`, `tests/run.sh`, `tests/fixtures/*.json`, `project-brief.md`, `.planning/research/{PITFALLS,STACK,ARCHITECTURE}.md`, `.planning/{PROJECT,ROADMAP,REQUIREMENTS,STATE}.md`, `.planning/config.json`, `.gitignore`

### Secondary (MEDIUM confidence — official docs fetched via WebFetch)
- https://docs.docker.com/ai/sandboxes/customize/kits/ — kit kinds, `files/home`, install/startup/files semantics, reserved paths, `--kit` creation-only, `sbx kit add` limitation sentence, sources, `kit.allowedSources` / `kit.allowLocalKits`
- https://docs.docker.com/ai/sandboxes/faq/ — `~/.claude` not imported; symlink warning; `sbx skills import`
- https://docs.docker.com/ai/sandboxes/architecture/ — same absolute path, bidirectional, persistence
- https://docs.docker.com/ai/sandboxes/agents/claude-code/ — host user-level config not picked up; default `--dangerously-skip-permissions`; base image `docker/sandbox-templates:claude-code`
- https://docs.docker.com/ai/sandboxes/customize/templates/ — Ubuntu base, non-root `agent` with sudo, "Most variants include Git, Docker CLI, and common development tools"
- https://code.claude.com/docs/en/statusline — settings fields, `refreshInterval` min 1, `padding` default 0, command runs in a shell, troubleshooting, trust, reload semantics, mock-input tip
- https://code.claude.com/docs/en/settings — scopes/precedence (project above user)
- https://github.com/docker/sbx-kits-contrib — `claude-sbx-statusline/spec.yaml` + README (install-time jq merge, exec bit preserved, jq/git in base image, git+https `#dir=` refs), `claude-mem/spec.yaml` (startup wait-for-`themeId` + reconcile as root; engine overwrite comment), `code-server/spec.yaml` (startup array form, `user: "1000"`, `setup.files mode`), repo README (`#ref=&dir=` syntax)
- https://github.com/docker/sbx-releases/releases — v0.39.0 notes (kit-spec v2 field names)

### Tertiary (LOW–MEDIUM confidence — community; corroborating only)
- https://www.vrchr.fr/posts/2026/08/06/sbx-kit-project-host/ — sbx 0.38.0: "each `sbx run` … blank `settings.json`"; startup jq merge
- https://github.com/SamirSaidani/sbx-claude-kit — "`~/.claude/settings.json` is overwritten on every sandbox creation"; startup init script
- https://github.com/nicmeriano/claude-sandbox-template — engine replaces `settings.json` at container init (template context)
- https://andrewlock.net/running-ai-agents-with-customized-templates-in-docker-sandbox/ (2026-04-14), dev.to/ajeetraina — base image tool list incl. jq, git; `agent` user
- https://github.com/docker/sbx-releases/issues/113 — "agent configuration files are always recreated when a sandbox is created"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools present and versions verified locally; no new packages
- Kit schema/grammar: HIGH — verified with the installed `sbx kit validate`/`inspect`
- Sandbox engine behaviour (settings overwrite timing, exec-bit copy, `sbx kit add` scope): MEDIUM — docs + Docker contrib kits + community, not reproducible offline (daemon stopped); UAT must confirm
- Host install semantics: HIGH — tested on the actual macOS host
- Pitfalls: MEDIUM-HIGH

**Research date:** 2026-08-22
**Valid until:** ~2026-09-21 for host/CLI facts; sbx is experimental and ships often (v0.39.0 on 2026-08-19) — re-run `sbx kit validate` and re-check `sbx kit add --help` if the CLI is upgraded before execution.
