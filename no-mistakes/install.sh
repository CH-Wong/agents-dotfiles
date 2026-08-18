#!/usr/bin/env bash
# One-time, idempotent install of the no-mistakes CLI + daemon.
# Not run automatically by bootstrap.sh -- opt in per machine, since it
# downloads a binary release over the network and restarts a background
# daemon. Run: ~/agents-dotfiles/no-mistakes/install.sh
#
# After this, run `no-mistakes init` inside any repo you want gated --
# that's a per-repo decision, not something this script makes for you.
# Upstream installer: kunchenguid/no-mistakes/docs/install.sh
#
# Links the binary into ~/bin (already on PATH via bootstrap.sh) instead of
# letting the upstream installer fall back to /usr/local/bin, which would
# need sudo.

set -euo pipefail

mkdir -p "$HOME/bin"
export NO_MISTAKES_LINK_DIR="$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh

echo "Run 'no-mistakes init' inside any repo you want to gate through no-mistakes."
