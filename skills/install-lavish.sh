#!/usr/bin/env bash
# One-time, idempotent install of the lavish skill globally (all agents,
# not just Claude Code). Not run automatically by bootstrap.sh -- opt in
# per machine, since it needs network access and runs a package via npx.
# Run: ~/agents-dotfiles/skills/install-lavish.sh
#
# Installs from CH-Wong/lavish-axi, a fork of kunchenguid/lavish-axi, which
# pins the lavish-axi CLI to a fixed version instead of letting npx run
# whatever is newest on npm, and gates the `share` command (which publishes
# artifacts publicly by default) behind explicit user request.
# Upstream sync lives in ~/code/lavish-axi (origin = the fork, upstream =
# kunchenguid/lavish-axi): git fetch upstream && git merge upstream/main.

set -euo pipefail

npx -y skills add CH-Wong/lavish-axi --skill lavish --global -y

echo "Installed. ~/.claude/skills/lavish should now symlink to ~/.agents/skills/lavish."
