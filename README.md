# Claude Code Status Line

A two-line bash status line for Claude Code: model and effort, directory, git state, context usage and rate limits — the same script on the macOS host and inside Docker Sandboxes.

## What it shows

```text
Opus 5 (high) · myproject ⎇ main* ≡ ↓2 ↑3 #2
10%/100k/1M · 50%/5h (2h:50m) · 15%/1w (3d:5h:57m)
```

Percentages turn yellow at 70% and red at 90%; segments with no data (no git repo, no effort, no rate-limit data yet) disappear together with their separators.

## Symbol legend

| Token | Meaning |
|-------|---------|
| `Opus 5 (high)` | Model name (suffixes like `(1M context)` stripped) and reasoning effort — effort hidden when the model has none |
| `myproject` | Basename of the working directory |
| `⎇ main` | Current branch (short SHA when detached) — the whole git segment is hidden outside a repo |
| `*` | Working tree has changes or untracked files |
| `≡` / `≢` | Branch has / has no upstream |
| `↓2` | Commits behind upstream (hidden at 0; from the last fetch — the script never fetches) |
| `↑3` | Commits ahead of upstream (hidden at 0) |
| `#2` | Stash count (hidden at 0) |
| `10%/100k/1M` | Context used as percent / tokens / window size |
| `50%/5h (2h:50m)` | 5-hour rate-limit usage and time to reset |
| `15%/1w (3d:5h:57m)` | Weekly rate-limit usage and time to reset |

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
```

If the line stays blank in Claude Code, run `claude --debug` (it logs the script's exit code/stderr and workspace-trust skips) and check `chmod +x ~/.claude/statusline.sh`.

## Install in Docker Sandboxes

Docker Sandboxes do not import your host `~/.claude` and cannot follow symlinks to host paths, so the script is delivered by the sbx kit in `kit/` — it copies the script to `/home/agent/.claude/statusline.sh` and sets the same `statusLine` settings at every start.

Local directory — use the absolute path to this repo's `kit/` (other projects' sandboxes do not mount this repo):

```sh
sbx run claude --kit /absolute/path/to/claude-code-status-line/kit            # new sandbox
sbx kit add <sandbox-name> /absolute/path/to/claude-code-status-line/kit      # existing sandbox
```

Remote — straight from GitHub:

```sh
sbx run claude --kit "git+https://github.com/sergiivelykodnyi/claude-code-statusline.git#dir=kit"
```

`kit.allowedSources` may need the GitHub prefix allow-listed, e.g. `sbx settings set kit.allowedSources '["docker.io/","github.com/sergiivelykodnyi/"]'`; `#ref=<tag-or-commit>&dir=kit` pins a version.

The status line shows up after the first message in the sandbox; the same verify command works inside a sandbox shell (`sbx exec <sandbox-name> ...`).

## Requirements

- bash 3.2+ (macOS `/bin/bash` is fine), `jq`, `git`
- Claude Code ≥ 2.1.x (rate-limit fields and `refreshInterval`)
- For sandboxes: Docker Sandboxes `sbx` ≥ 0.39 (kit spec v2)
