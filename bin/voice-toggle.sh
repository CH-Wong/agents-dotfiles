#!/usr/bin/env bash
# tmux prefix+v: toggle background voice dictation for whichever pane was
# active when recording started. Runs fully detached from any pane -- the
# pane's own screen (Claude Code's TUI) is never touched. Only the tmux
# status bar (tmux-voice-status.sh) shows recording state. On stop, the
# transcript is injected into the target pane via `tmux send-keys`, exactly
# as if typed there.

set -uo pipefail

WHISPER_BIN="$HOME/tools/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL="$HOME/tools/whisper.cpp/models/ggml-base.en.bin"
# PulseAudio source name to record from, e.g. "RDPSource"; empty = default.
# List available sources with: pactl list short sources
INPUT_DEVICE="${VOICE_INPUT_DEVICE:-}"
STATE_DIR="$HOME/.cache/claude-voice"
STATE_FILE="$STATE_DIR/recording"
PANE_FILE="$STATE_DIR/target_pane"
WAV_FILE="$STATE_DIR/rec.wav"
PID_FILE="$STATE_DIR/parecord.pid"
DEBUG_LOG="$STATE_DIR/debug.log"

mkdir -p "$STATE_DIR"
log() { printf '[%s] :: %s\n' "$(date +%T.%3N)" "$1" >> "$DEBUG_LOG"; }
tmux_refresh() { tmux refresh-client -S 2>/dev/null; }

if [[ -f "$STATE_FILE" ]]; then
    # --- stop recording, then transcribe ---
    log "stop requested"
    PARECORD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
    [[ -n "$PARECORD_PID" ]] && kill "$PARECORD_PID" 2>/dev/null
    sleep 0.3   # let parecord flush the wav header/data before we read it
    rm -f "$PID_FILE"
    printf 'transcribing' > "$STATE_FILE"
    tmux_refresh

    TARGET_PANE="$(cat "$PANE_FILE" 2>/dev/null || true)"
    rm -f "$PANE_FILE"

    if [[ ! -x "$WHISPER_BIN" ]]; then
        log "ERROR whisper-cli missing at $WHISPER_BIN"
        rm -f "$STATE_FILE"
        tmux_refresh
        tmux display-message "voice: whisper-cli not found"
        exit 1
    fi

    TRANSCRIPT="$("$WHISPER_BIN" -m "$WHISPER_MODEL" -f "$WAV_FILE" -nt -np 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//')"
    log "transcript='$TRANSCRIPT'"
    rm -f "$WAV_FILE" "$STATE_FILE"
    tmux_refresh

    if [[ -z "$TRANSCRIPT" ]]; then
        tmux display-message "voice: no speech detected"
        exit 0
    fi

    if [[ -n "$TARGET_PANE" ]]; then
        tmux send-keys -t "$TARGET_PANE" -l -- "$TRANSCRIPT"
        log "sent to pane $TARGET_PANE"
    else
        log "ERROR no target pane recorded"
    fi
else
    # --- start ---
    log "start requested"
    PANE_ID="$(tmux display-message -p '#{pane_id}')"
    printf '%s' "$PANE_ID" > "$PANE_FILE"

    rm -f "$WAV_FILE"
    DEVICE_ARGS=()
    [[ -n "$INPUT_DEVICE" ]] && DEVICE_ARGS=(--device="$INPUT_DEVICE")
    setsid parecord "${DEVICE_ARGS[@]}" --channels=1 --rate=16000 --format=s16le "$WAV_FILE" < /dev/null > /dev/null 2>&1 &
    disown
    echo $! > "$PID_FILE"
    printf 'recording' > "$STATE_FILE"
    tmux_refresh
    log "recording started, pane=$PANE_ID pid=$(cat "$PID_FILE")"
fi
