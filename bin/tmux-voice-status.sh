#!/usr/bin/env bash
# Renders the recording indicator segment for tmux's status-right.
# Polled by tmux (status-interval) and force-refreshed by voice-toggle.sh
# via `tmux refresh-client -S` for instant, glow-pulsing updates.

STATE_FILE="$HOME/.cache/claude-voice/recording"

[[ -f "$STATE_FILE" ]] || exit 0

case "$(cat "$STATE_FILE" 2>/dev/null)" in
    2) printf '#[fg=colour160,bold]\xe2\x97\x8f REC#[default] ' ;;
    *) printf '#[fg=colour196,bold]\xe2\x97\x8f REC#[default] ' ;;
esac
