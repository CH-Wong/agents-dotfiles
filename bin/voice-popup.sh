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

STATE_DIR="$HOME/.cache/claude-voice"
STATE_FILE="$STATE_DIR/recording"
WAV_FILE="$STATE_DIR/rec.wav"
MIC_NAME_FILE="$STATE_DIR/mic_name"

# Live capture-level meter, read from the wav file parecord is writing
# to as it grows -- lets you SEE a dead/wrong mic (flat bar) while
# recording instead of finding out after a garbled transcript comes
# back. QUIET_THOLD matches the "looks QUIET" threshold voice-diagnose.sh
# uses; WARN_AFTER_ITERS gives a moment for you to start talking before
# flagging silence as a problem. POLL_INTERVAL is how often the meter
# redraws -- one poll (dd + python3 unpack) measured ~13ms, so 0.1s
# leaves plenty of headroom while looking real-time.
WAV_HEADER_BYTES=44
BAR_WIDTH=20
FULL_SCALE=32767
QUIET_THOLD=3000
POLL_INTERVAL=0.1
WARN_AFTER_ITERS=12
OFFSET=$WAV_HEADER_BYTES
MAXPEAK=0
ITER=0

level_bar() {
    local peak=$1 filled bar=""
    filled=$(( peak * BAR_WIDTH / FULL_SCALE ))
    (( filled > BAR_WIDTH )) && filled=BAR_WIDTH
    (( filled < 0 )) && filled=0
    for ((i=0;i<filled;i++)); do bar+="#"; done
    for ((i=filled;i<BAR_WIDTH;i++)); do bar+="-"; done
    printf '[%s]' "$bar"
}

# A real full-screen clear happens once, up front. Every redraw after
# that only moves the cursor home (\033[H) and clears trailing garbage
# per-line (\033[K) / below the frame (\033[J) -- clearing the whole
# screen on every 0.3s tick (the old `clear` call) blanks the terminal
# for a frame before redrawing, which reads as blinking.
clear

while :; do
    STATE="$(cat "$STATE_FILE" 2>/dev/null)"
    FRAME=""
    line() { FRAME+="$1"$'\033[K\n'; }
    case "$STATE" in
        recording)
            ((ITER++))
            SIZE="$(stat -c%s "$WAV_FILE" 2>/dev/null || echo 0)"
            PEAK=0
            if (( SIZE > OFFSET )); then
                PEAK="$(dd if="$WAV_FILE" bs=1M skip="$OFFSET" count="$((SIZE-OFFSET))" \
                    iflag=skip_bytes,count_bytes 2>/dev/null | python3 -c '
import sys, struct
data = sys.stdin.buffer.read()
n = len(data) // 2
print(max(abs(s) for s in struct.unpack("<%dh" % n, data[:n*2])) if n else 0)
')"
                OFFSET=$SIZE
                (( PEAK > MAXPEAK )) && MAXPEAK=$PEAK
            fi

            MIC_NAME="$(cat "$MIC_NAME_FILE" 2>/dev/null)"
            [[ -z "$MIC_NAME" ]] && MIC_NAME="(detecting...)"
            (( ${#MIC_NAME} > 34 )) && MIC_NAME="${MIC_NAME:0:33}\xe2\x80\xa6"

            line ""
            line "  $(printf '\033[1;31m\xe2\x97\x8f  REC\033[0m')"
            line "  Mic: $(printf '%b' "$MIC_NAME")"
            line "  $(level_bar "$PEAK")"
            if (( ITER >= WARN_AFTER_ITERS && MAXPEAK < QUIET_THOLD )); then
                line "  $(printf '\033[1;33m\xe2\x9a\xa0 very quiet -- check input device\033[0m')"
            else
                line ""
            fi
            line ""
            line "  Recording... press any key to stop"
            ;;
        transcribing)
            line ""
            line ""
            line "  $(printf '\033[1;33mTRANSCRIBING...\033[0m')"
            line ""
            line "  Running whisper.cpp locally"
            ;;
        *)
            exit 0
            ;;
    esac

    printf '\033[H%s\033[J' "$FRAME"

    if [[ "$STATE" == recording ]]; then
        if read -t "$POLL_INTERVAL" -n 1 -s _; then
            while read -t 0.05 -n 1 -s _; do :; done   # drain trailing keys, e.g. the "v" from a prefix+v habit-press
            ~/bin/voice-toggle.sh &
            disown
        fi
    else
        sleep 0.1
    fi
done
