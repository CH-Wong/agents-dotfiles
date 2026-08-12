#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Links a directory in place of ~/.claude/<name>, refusing to clobber a real
# (non-symlink) directory that might contain unrelated local content.
link_dir() {
  local target="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -d "$dest" ]]; then
    echo "Warning: $dest is a real directory, not a symlink - leaving it alone. Merge its contents into $target manually if needed." >&2
    return
  fi
  ln -s "$target" "$dest"
}

mkdir -p ~/.claude

if [[ "$REPO_DIR" == /mnt/c/* ]]; then
  # Running under WSL with the repo cloned onto the Windows drive.
  WIN_USER_DIR="$(dirname "$REPO_DIR")"
  WIN_AGENTS="$WIN_USER_DIR/AGENTS.md"

  ln -sf "$REPO_DIR/AGENTS.md" "$WIN_AGENTS"
  ln -sf "$WIN_AGENTS" ~/.claude/AGENTS.md
else
  # Plain Linux/macOS machine, no Windows drive involved.
  ln -sf "$REPO_DIR/AGENTS.md" ~/.claude/AGENTS.md
fi

ln -sf AGENTS.md ~/.claude/CLAUDE.md
link_dir "$REPO_DIR/skills" ~/.claude/skills

echo "Symlinks wired up:"
ls -la ~/.claude/AGENTS.md ~/.claude/CLAUDE.md ~/.claude/skills
