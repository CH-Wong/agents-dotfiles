# Global skills

Personal Claude Code skills, reusable across every project.
Each skill lives in its own subfolder with a `SKILL.md`.
This directory is symlinked to `~/.claude/skills` by `bootstrap.sh`.
Project-specific skills stay in that project's own `.claude/skills` folder and are not affected by this repo.

## Remotely-installed skills

Some skills are not authored in this repo but installed globally from a git source via the `skills` CLI (`npx skills add ... --global`), which manages its own `~/.agents/skills/<name>` directory and symlinks it into `~/.claude/skills` (and other agents' skill directories).
These get their own opt-in install script here, same convention as `voice/setup-whisper.sh`: not run automatically by `bootstrap.sh`, since they need network access.

- `install-lavish.sh` installs the `lavish` skill from a hardened fork, `CH-Wong/lavish-axi`.
