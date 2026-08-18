#!/usr/bin/env bash
# Content for the floating popup shown while a recording or transcription
# is in progress. voice-toggle.sh opens the popup with
# `tmux display-popup -E ... voice-popup.sh`; -E closes the popup as soon
# as this script exits, so exiting here is what dismisses it.
#
# tmux popups take over all keyboard input while shown, so prefix+v can't
# reach the normal tmux keybinding table from here -- it would just be
# typed (and echoed) into this script's stdin instead, which is the
# "typed text shows up in the popup" bug this fixes. Local echo is turned
# off, and this script itself listens for a keypress: any key while
# recording stops it, the same way pressing prefix+v a second time
# normally would from an ordinary pane.

stty -echo 2>/dev/null
trap 'stty echo 2>/dev/null' EXIT

STATE_FILE="$HOME/.cache/claude-voice/recording"

while :; do
    STATE="$(cat "$STATE_FILE" 2>/dev/null)"
    clear
    case "$STATE" in
        recording)
            printf '\n\n  \033[1;31m\xe2\x97\x8f  REC\033[0m\n\n  Recording... press any key to stop\n'
            ;;
        transcribing)
            printf '\n\n  \033[1;33mTRANSCRIBING...\033[0m\n\n  Running whisper.cpp locally\n'
            ;;
        *)
            exit 0
            ;;
    esac

    if [[ "$STATE" == recording ]] && read -t 0.3 -n 1 -s _; then
        while read -t 0.05 -n 1 -s _; do :; done   # drain trailing keys, e.g. the "v" from a prefix+v habit-press
        ~/bin/voice-toggle.sh &
        disown
    fi
done
