#!/usr/bin/env bash
# Renders tmux's status-left: the session name, plus -- whenever
# voice-toggle.sh has a recording or transcription in progress -- a
# "REC" / "TRANSCRIBING..." indicator padded out to sit in the middle of
# the status bar. status-left is left-anchored, so leading padding is what
# actually moves the indicator (the same trick on status-right, which is
# right-anchored, is a no-op -- padding before right-anchored content just
# grows invisible space that gets pushed off along with it).
# $1 is the client's terminal width (tmux's #{client_width}); $2 is the
# plain session-name prefix (tmux's "[#{session_name}] ", pre-expanded by
# tmux before this script runs).
# Polled by tmux (status-interval) and force-refreshed by voice-toggle.sh
# via `tmux refresh-client -S` for instant updates.

CLIENT_WIDTH="${1:-80}"
PREFIX="${2:-}"
STATE_FILE="$HOME/.cache/claude-voice/recording"

case "$(cat "$STATE_FILE" 2>/dev/null)" in
    recording)
        TEXT='\xe2\x97\x8f REC'
        VISIBLE_LEN=5
        STYLE='fg=colour196,bold'
        ;;
    transcribing)
        TEXT='TRANSCRIBING...'
        VISIBLE_LEN=15
        STYLE='fg=colour220,bold'
        ;;
    *)
        printf '%s' "$PREFIX"
        exit 0
        ;;
esac

PAD=$(( CLIENT_WIDTH / 2 - ${#PREFIX} - VISIBLE_LEN / 2 ))
(( PAD < 1 )) && PAD=1

printf '%s' "$PREFIX"
printf '%*s' "$PAD" ''
printf "#[$STYLE]$TEXT#[default] "
