# Claude Code Status Line

A two-line bash status line for Claude Code: model and effort, directory, git state, context usage and rate limits — the same script on the macOS host and inside Docker Sandboxes.

## What it shows

```text
Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2
10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m) · Fable 74%/1w (2d:4h:30m)
```

Percentages turn yellow at 70% and red at 90%; segments with no data (no git repo, no effort, no rate-limit data yet, no Fable usage data (no OAuth login)) disappear together with their separators.

## Symbol legend

| Token | Meaning |
|-------|---------|
| `Opus 5 (high)` | Model name (suffixes like `(1M context)` stripped) and reasoning effort — effort hidden when the model has none |
| `myproject` | Basename of the working directory |
| `main` | Current branch (short SHA when detached) — the whole git segment is hidden outside a repo |
| `*` | Working tree has changes or untracked files |
| `≡` / `≢` | Branch has / has no upstream |
| `↓2` | Commits behind upstream (hidden at 0; from the last fetch — the script never fetches) |
| `↑3` | Commits ahead of upstream (hidden at 0) |
| `#2` | Stash count (hidden at 0) |
| `10%/100k/1M` | Context used as percent / tokens / window size |
| `50%/5h (2h:50m)` | 5-hour rate-limit usage and time to reset |
| `15%/1w (3d:5h:57m)` | Weekly rate-limit usage and time to reset |
| `Fable 74%/1w (2d:4h:30m)` | Fable-specific weekly usage and time to reset, read from the Claude Code OAuth usage data; needs the Claude Code OAuth login (Max/Pro), hidden otherwise |

## Install on the host

Symlink (recommended) — run from the repo root:

```sh
ln -sf "$PWD/kit/files/home/.claude/statusline.sh" ~/.claude/statusline.sh
```

With the symlink, editing or pulling this repo changes the live status line immediately; use the copy variant if you want a static copy:

```sh
rm -f ~/.claude/statusline.sh && cp kit/files/home/.claude/statusline.sh ~/.claude/statusline.sh
```

**Warning:** the copy variant overwrites any existing `~/.claude/statusline.sh`.

Add this to `~/.claude/settings.json` (merge into the existing object, keep your other keys):

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

`refreshInterval` re-runs the script every 60 s so the reset countdowns keep ticking while the session is idle; the status line appears after your next interaction.

Verify without a live session:

```sh
echo '{"model":{"display_name":"Opus 5 (1M context)"},"effort":{"level":"high"},"workspace":{"current_dir":"/tmp/myproject"},"context_window":{"used_percentage":10.4,"total_input_tokens":100000,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":50.9,"resets_at":0},"seven_day":{"used_percentage":15.2,"resets_at":0}}}' | ~/.claude/statusline.sh
# expect (colored):
# Opus 5 (high) · myproject
# 10%/100k/1M · 50%/5h (now) · 15%/1w (now)
# plus "· Fable NN%/1w (…)" at the end of line 2 when your OAuth credentials are available
```

If the line stays blank in Claude Code, run `claude --debug` (it logs the script's exit code/stderr and workspace-trust skips) and check `chmod +x ~/.claude/statusline.sh`.

## Fable weekly segment

The last segment on line 2 — `· Fable 74%/1w (2d:4h:30m)` in the example above — shows the Fable-specific weekly limit. It comes from the same Claude Code OAuth login the rest of Claude Code uses — no extra setup, nothing to configure — and it behaves like every other segment: present when the data is there, gone (with its separator) when it is not.

- **Token source:** the script reads the Claude Code OAuth token from `~/.claude/.credentials.json` first, then from the macOS Keychain item `Claude Code-credentials` (via the `security` CLI). The token is read-only: never refreshed, never printed, never stored anywhere else.
- **Fetch and cache:** at most one request every 5 minutes to `https://api.anthropic.com/api/oauth/usage`, with a 2-second timeout; the answer is cached with mode 0600 in `~/.claude/statusline-usage-cache.json`. If a refresh fails (offline, timeout, rejected token), the last value is kept for up to an hour, then the segment hides.
- **Kill switch:** set `STATUSLINE_NO_FABLE=1` — in your shell or under the `"env"` key of `~/.claude/settings.json` — to disable the segment entirely (no credential read, no network).
- **macOS Keychain prompt:** the first read may show one Keychain dialog for the `Claude Code-credentials` item — click "Always Allow" once and it will not ask again.
- **Docker Sandboxes:** the segment renders when `/home/agent/.claude/.credentials.json` exists inside the sandbox (created by the sbx `anthropic` secret or by `/login` inside the sandbox) and is hidden otherwise; the kit never copies or forwards the host token.

## Install in Docker Sandboxes

Docker Sandboxes do not import your host `~/.claude` and cannot follow symlinks to host paths, so the script is delivered by the sbx kit in `kit/` — it copies the script to `/home/agent/.claude/statusline.sh` and sets the same `statusLine` settings at every start.

Local directory — use the absolute path to this repo's `kit/` (other projects' sandboxes do not mount this repo):

```sh
sbx run claude --kit /absolute/path/to/claude-code-status-line/kit
```

Existing sandboxes cannot take the kit afterwards (`--kit` applies only at creation, and sbx 0.39 refuses to add a kit that declares `setup.startup`) — remove and recreate them: `sbx rm <sandbox-name>`, then the `sbx run` command above.

Remote — straight from GitHub:

```sh
sbx run claude --kit "git+https://github.com/sergiivelykodnyi/claude-code-statusline.git#dir=kit"
```

`kit.allowedSources` may need the GitHub prefix allow-listed, e.g. `sbx settings set kit.allowedSources '["docker.io/","github.com/sergiivelykodnyi/"]'`; `#ref=<tag-or-commit>&dir=kit` pins a version.

The status line shows up after the first message in the sandbox; the same verify command works inside a sandbox shell (`sbx exec <sandbox-name> ...`).

## Requirements

- bash 3.2+ (macOS `/bin/bash` is fine), `jq`, `git`, `curl`
- Claude Code ≥ 2.1.x (rate-limit fields and `refreshInterval`)
- For sandboxes: Docker Sandboxes `sbx` ≥ 0.39 (kit spec v2)
