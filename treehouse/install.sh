#!/usr/bin/env bash
# One-time, idempotent install of the treehouse CLI.
# Not run automatically by bootstrap.sh -- opt in per machine, since it
# downloads a binary release over the network.
# Run: ~/agents-dotfiles/treehouse/install.sh
#
# Manages a pool of reusable, isolated git worktrees so each agent session
# gets its own environment instantly instead of a fresh clone -- see
# https://github.com/kunchenguid/treehouse.
#
# Upstream's installer only avoids sudo if ~/.local/bin is already on PATH,
# else it falls back to /usr/local/bin (sudo). On a fresh machine
# ~/.local/bin usually doesn't exist yet, so ~/.profile hasn't put it on
# PATH. Create the dir and export it for this invocation so the upstream
# script picks the sudo-free path; ~/.profile then keeps it on PATH for
# every future shell once the directory exists.

set -euo pipefail

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh

echo "Installed. Restart your shell (or 'source ~/.profile') to pick up ~/.local/bin on PATH."
echo "Run 'treehouse' inside any git repo to get a pooled, reusable worktree."
