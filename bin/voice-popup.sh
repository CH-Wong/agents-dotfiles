#!/usr/bin/env bash
# Content for the floating popup shown while a recording or transcription
# is in progress. voice-toggle.sh opens the popup with
# `tmux display-popup -E ... voice-popup.sh`; -E closes the popup as soon
# as this script exits, so exiting here is what dismisses it. Polls the
# state file and repaints every 0.3s to pick up the recording ->
# transcribing -> idle transition.

STATE_FILE="$HOME/.cache/claude-voice/recording"

while :; do
    STATE="$(cat "$STATE_FILE" 2>/dev/null)"
    clear
    case "$STATE" in
        recording)
            printf '\n\n  \033[1;31m\xe2\x97\x8f  REC\033[0m\n\n  Recording... prefix+v to stop\n'
            ;;
        transcribing)
            printf '\n\n  \033[1;33mTRANSCRIBING...\033[0m\n\n  Running whisper.cpp locally\n'
            ;;
        *)
            exit 0
            ;;
    esac
    sleep 0.3
done
