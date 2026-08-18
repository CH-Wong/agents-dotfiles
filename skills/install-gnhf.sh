#!/usr/bin/env bash
# One-time, idempotent install of the gnhf skill globally (all agents, not
# just Claude Code), plus the `gnhf` CLI it wraps. Not run automatically by
# bootstrap.sh -- opt in per machine, since it needs network access and
# installs a global npm package.
# Run: ~/agents-dotfiles/skills/install-gnhf.sh
#
# GNHF is an agent orchestrator that runs a coding agent unattended in a
# loop, committing each successful iteration -- see
# https://github.com/kunchenguid/gnhf. By design it launches the worker
# agent with permission checks disabled (--dangerously-skip-permissions for
# Claude, --dangerously-bypass-approvals-and-sandbox for Codex, --yolo for
# Cursor/Copilot) so it can proceed with nobody there to approve tool calls.
# That is not a bug to patch around; the skill (skills/gnhf/SKILL.md) is
# required to disclose it and get the user's go-ahead before the first
# launch in a conversation.
#
# Installs from CH-Wong/gnhf, a fork of kunchenguid/gnhf, whose only change
# is that disclosure requirement -- see AGENTS.md there for the upstream
# sync procedure. The `gnhf` CLI itself is pinned to a version already
# checked with `npm audit` (0 vulnerabilities) rather than tracking
# whatever npm resolves as latest.
#
# gnhf sends anonymous, non-identifying usage telemetry (agent name + run
# mode only, never cwd/branch/prompt) unless GNHF_TELEMETRY=0 is set in
# your environment -- add that yourself if you want it off.

set -euo pipefail

GNHF_VERSION="0.1.44"

npm install -g "gnhf@$GNHF_VERSION"
npx -y skills add CH-Wong/gnhf --skill gnhf --global -y

echo "Installed. ~/.claude/skills/gnhf should now symlink to ~/.agents/skills/gnhf."
echo "gnhf CLI pinned at $GNHF_VERSION -- bump GNHF_VERSION in this script to upgrade deliberately."
