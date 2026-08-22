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

# Same idea as link_dir but for a single file, refusing to clobber a real
# (non-symlink) file that might contain unrelated local content.
link_file() {
  local target="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    echo "Warning: $dest already exists and is not a symlink - leaving it alone." >&2
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

mkdir -p ~/bin
for f in "$REPO_DIR"/bin/*.sh; do
  link_file "$f" ~/bin/"$(basename "$f")"
done

# Source every tmux/*.conf module idempotently, without clobbering any
# other machine-specific ~/.tmux.conf content the user may have added
# locally. New modules just need to be dropped in tmux/ - no bootstrap
# changes required.
touch ~/.tmux.conf
for f in "$REPO_DIR"/tmux/*.conf; do
  CONF_LINE="source-file $f"
  if ! grep -qF "$CONF_LINE" ~/.tmux.conf; then
    echo "$CONF_LINE" >> ~/.tmux.conf
  fi
done

echo "Symlinks wired up:"
ls -la ~/.claude/AGENTS.md ~/.claude/CLAUDE.md ~/.claude/skills ~/bin
