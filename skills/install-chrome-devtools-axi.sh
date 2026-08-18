#!/usr/bin/env bash
# One-time, idempotent install of the chrome-devtools-axi skill globally
# (all agents, not just Claude Code). Not run automatically by
# bootstrap.sh -- opt in per machine, since it downloads Google Chrome
# (~140MB) via Google's official apt repo and runs a package via npx.
# Run: ~/agents-dotfiles/skills/install-chrome-devtools-axi.sh
#
# Wraps chrome-devtools-mcp with token-efficient TOON output, combined
# operations, and contextual suggestions -- see https://axi.md and
# https://github.com/kunchenguid/chrome-devtools-axi.
#
# Needs a real Linux Chrome to launch. On WSL there is normally only a
# Windows-side Chrome under /mnt/c, which Puppeteer cannot launch directly,
# so this installs google-chrome-stable on the Linux side too.

set -euo pipefail

if ! command -v google-chrome-stable >/dev/null; then
  echo "Installing Google Chrome..."
  TMP_DEB="$(mktemp --suffix=.deb)"
  curl -fsSL -o "$TMP_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -y "$TMP_DEB"
  rm -f "$TMP_DEB"
fi

npx -y skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi --global -y

echo "Installed. ~/.claude/skills/chrome-devtools-axi should now symlink to ~/.agents/skills/chrome-devtools-axi."
