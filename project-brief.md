# Project brief

## Status line design

I want to create a custom `statusline.sh` that I can use on my current machine (host) and inside my [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). What I want to have

```text
Row 1: model_name (effort) · current_dir_name · current_git_branch branch_status ahead behind stash

Row 2: context_usage_in_percentage/context_usage_in_tokens/window_size · usage_in_percentage/5h (when_reset) · usage_in_percentage/1w f(usage_in_percentage) (when_reset)
```

- `model_name` - displays a model name; some model names have the `(1M context)` suffix, e.g. `Opus (1M context)`. We need to cut this; I want to have only the name.
- `effort` - current effort, e.g. `(high)`
- `current_dir_name` - the directory where Claude is running, e.g. `myproject`
- `current_git_branch` - if the folder is a git repository, it should show the current branch name as its own segment after the directory, e.g. `myproject · main`
- `branch_status` - if the branch has changes or untracked files, we should add asterisks next to it. If the branch is pushed to remote, then `≡`; if not, `≢`, e.g. `main* ≡`
- `ahead` - how many commits are ahead in remote, e.g. `↓2`
- `behind` - how many commits are not pushed to remote, e.g. `↑3`
- `stash` - number of current stashes, e.g. `#2`
- `context_usage_in_percentage` - how much of the context from the context window is used in %, e.g. `10%`
- `context_usage_in_tokens` - how much of the context from the context window is used in shortened numbers, e.g. `100k`
- `window_size` - context window size in shortened numbers, e.g. `1m`
- `usage_in_percentage/5h (when_reset)` - info about the 5h limit, how much percentage of the limit is used and when it resets - `50%/1w (2h:50m)`
- `usage_in_percentage/1w f(usage_in_percentage) (when_reset)` - info about the 1-week limit, how much percentage of the limit is used and when it resets. The `f()` is the Fable 5 limit. Example: `15%/1w f(60%) (3d:5h:57m)`

Whole example

```text
Opus 5 (high) · myproject · main* ≡ ↓2 ↑3 #2
10%/100k/1M · 50%/1w (2h:50m) · 15%/1w f(60%) (3d:5h:57m)
```

## README.md

Briefly describes what the status line shows and the command that symlinked the `statusline.sh` to the `~/.claude` folder.
