#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$REPO_DIR" == /mnt/c/* ]]; then
  # Running under WSL with the repo cloned onto the Windows drive.
  WIN_USER_DIR="$(dirname "$REPO_DIR")"
  WIN_AGENTS="$WIN_USER_DIR/AGENTS.md"

  ln -sf "$REPO_DIR/AGENTS.md" "$WIN_AGENTS"
  mkdir -p ~/.claude
  ln -sf "$WIN_AGENTS" ~/.claude/AGENTS.md
else
  # Plain Linux/macOS machine, no Windows drive involved.
  mkdir -p ~/.claude
  ln -sf "$REPO_DIR/AGENTS.md" ~/.claude/AGENTS.md
fi

ln -sf AGENTS.md ~/.claude/CLAUDE.md

echo "Symlinks wired up:"
ls -la ~/.claude/AGENTS.md ~/.claude/CLAUDE.md
