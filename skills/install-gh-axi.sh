#!/usr/bin/env bash
# One-time, idempotent install of the gh-axi skill globally (all agents,
# not just Claude Code). Not run automatically by bootstrap.sh -- opt in
# per machine, since it installs the `gh` CLI via apt and runs a package
# via npx.
# Run: ~/agents-dotfiles/skills/install-gh-axi.sh
#
# Wraps the official `gh` CLI with token-efficient TOON output, contextual
# suggestions, and structured errors -- see https://axi.md and
# https://github.com/kunchenguid/gh-axi.
#
# After this, authenticate `gh` yourself (interactive, not scripted):
#   gh auth login

set -euo pipefail

if ! command -v gh >/dev/null; then
  echo "Installing gh CLI..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi

npx -y skills add kunchenguid/gh-axi --skill gh-axi --global -y

echo "Installed. ~/.claude/skills/gh-axi should now symlink to ~/.agents/skills/gh-axi."
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated yet -- run 'gh auth login' (interactive, cannot be scripted)."
fi
