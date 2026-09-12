# Project brief

## Status line design

I want to create a custom `statusline.sh` that I can use on my current machine (host) and inside my [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). What I want to have

```text
Row 1: model_name (effort) · current_dir_name · current_git_branch branch_status behind ahead stash

Row 2: context_usage_in_percentage/context_usage_in_tokens/window_size · 5h usage_in_percentage when_reset · Week usage_in_percentage when_reset · Fable usage_in_percentage when_reset
```

- `model_name` - displays a model name; some model names have the `(1M context)` suffix, e.g. `Opus (1M context)`. We need to cut this; I want to have only the name.
- `effort` - current effort, e.g. `(high)`
- `current_dir_name` - the directory where Claude is running, e.g. `myproject`
- `current_git_branch` - if the folder is a git repository, it should show the current branch name as its own segment after the directory, e.g. `myproject · main`
- `branch_status` - if the branch has changes or untracked files, we should add asterisks next to it. The sync state is one mutually exclusive token: green `≡` when in sync with the upstream (ahead=behind=0), red `≢` when there is no upstream, otherwise the arrow counts replace the glyph, e.g. `main* ≡` or `main* ↓2 ↑3`
- `behind` - commits on the remote not yet pulled, e.g. `↓2` — yellow when behind only, red when also ahead (diverged)
- `ahead` - local commits not yet pushed, e.g. `↑3` — blue when ahead only, red when also behind (diverged)
- `stash` - number of current stashes, e.g. `#2`, in cyan
- `context_usage_in_percentage` - how much of the context from the context window is used in %, e.g. `10%`
- `context_usage_in_tokens` - how much of the context from the context window is used in shortened numbers, e.g. `100k`
- `window_size` - context window size in shortened numbers, e.g. `1m`
- `5h usage_in_percentage when_reset` - info about the 5h limit: the label first, how much percentage of the limit is used, then the local clock time it resets at - `5h 50% 14:50`
- `Week usage_in_percentage when_reset` - the same for the 1-week limit - `Week 15% Mon 21:10`. `when_reset` is a 24-hour local `HH:MM`; the 3-letter weekday appears only when the reset falls on another day. A reset that already passed renders `now`, and a window with no known reset drops the time and keeps the percentage.
- `Fable usage_in_percentage when_reset` - the Fable 5 weekly limit, rendered in the same shape as its own last segment on row 2 (not as an `f()` inside the weekly segment) - `Fable 74% Mon 21:10`

Whole example

```text
Opus 5 (high) · myproject · main* ↓2 ↑3 #2
10%/100k/1M · 5h 50% 14:50 · Week 15% Mon 21:10 · Fable 74% Mon 21:10
```

## README.md

Briefly describes what the status line shows and the command that symlinked the `statusline.sh` to the `~/.claude` folder.
