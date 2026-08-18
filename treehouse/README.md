# treehouse

Manages a pool of reusable, isolated git worktrees so each agent session gets its own environment instantly, with dependencies and build cache intact, instead of a fresh clone every time.
Upstream: <https://github.com/kunchenguid/treehouse>

## Setup on a new machine

1. Run `treehouse/install.sh` once to download the `treehouse` binary into `~/.local/bin`.
   This is a separate opt-in step, not run automatically by `bootstrap.sh`, since it pulls a binary release over the network.
2. Restart your shell (or `source ~/.profile`) so `~/.local/bin` lands on `PATH`.

## Usage

- `treehouse` (or `treehouse get`) inside a repo -- claim a worktree from the pool and drop into a subshell there.
  `exit` the subshell to return it to the pool.
- Optional per-repo config: `treehouse.toml` at the repo root (e.g. `max_trees`).
- Optional per-user config: `~/.config/treehouse/config.toml` -- same settings plus `post_create` / `pre_destroy` shell hooks, and `root` to relocate the pool (defaults to `~/.treehouse`).

See the upstream README for the full command reference and config options.
