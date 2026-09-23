# Herdr worktree Git workflow

In a Herdr-managed worktree, complete implementation, verification, commits, pushes, and pull-request creation without waiting for an extra checkpoint.

Before any merge, rebase, local or remote branch deletion, worktree removal, force-push, `git reset`, or `git clean`, stop and ask the user for explicit approval for that specific operation. Do not infer approval from a request to finish a pull request, and do not bypass this pause with an alternate command or wrapper.

Keep each task in its own branch and worktree. Never run two tasks against the same checked-out branch.
