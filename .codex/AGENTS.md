# Herdr worktree Git workflow

In a Herdr-managed worktree, complete implementation, verification, commits, pushes, and pull-request creation without waiting for an extra checkpoint.

Before any merge, rebase, local or remote branch deletion, worktree removal, force-push, `git reset`, or `git clean`, stop and ask the user for explicit approval for that specific operation. Detect destructive intent regardless of option order or syntax, including `git push --force` / `-f`, remote deletion with `--delete` / `-d`, and deletion refspecs such as `:branch`. Do not infer approval from a request to finish a pull request, and do not bypass this pause with an alternate command or wrapper.

After explicit approval, use canonical leading-option forms such as `git push --force-with-lease origin <branch>` or `git push --delete origin <branch>` so the command approval rules also match. Ordinary non-destructive pushes remain autonomous.

Herdr's configured worktree root is `~/.herdr/worktrees` by default, as set in `.config/herdr/config.toml`. It may be overridden; inspect the active Herdr config and `git worktree list` before locating a checkout. Use Herdr or Git worktree commands to remove managed checkouts only after the user's explicit approval; do not delete directories manually.

Keep each task in its own branch and worktree. Never run two tasks against the same checked-out branch.
