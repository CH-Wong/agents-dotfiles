#!/usr/bin/env bash
# tmux prefix+v: toggle background voice dictation for whichever pane was
# active when recording started. Runs fully detached from any pane -- the
# pane's own screen (Claude Code's TUI) is never touched. A floating popup
# (voice-popup.sh) shows recording/transcribing state and closes itself
# once state goes back to idle. On stop, the transcript is injected into
# the target pane via `tmux send-keys`, exactly as if typed there.

set -uo pipefail

WHISPER_BIN="$HOME/tools/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL="$HOME/tools/whisper.cpp/models/ggml-base.en.bin"
# VAD trims trailing/leading silence before decoding -- without it,
# base.en can hallucinate repeated tokens (e.g. "[pause] [pause] ...")
# into the gap between finishing a sentence and pressing stop.
VAD_MODEL="$HOME/tools/whisper.cpp/models/ggml-silero-v6.2.0.bin"
# Initial-prompt vocabulary hint: soft-biases decoding toward jargon that's
# rare in Whisper's training data (proper nouns, tool names, acronyms).
# Edit this file directly to add your own terms -- no code changes needed.
VOCAB_FILE="$HOME/agents-dotfiles/voice/vocabulary.txt"
# PulseAudio source name to record from, e.g. "RDPSource"; empty = default.
# List available sources with: pactl list short sources
INPUT_DEVICE="${VOICE_INPUT_DEVICE:-}"
STATE_DIR="$HOME/.cache/claude-voice"
STATE_FILE="$STATE_DIR/recording"
PANE_FILE="$STATE_DIR/target_pane"
WAV_FILE="$STATE_DIR/rec.wav"
PID_FILE="$STATE_DIR/parecord.pid"
DEBUG_LOG="$STATE_DIR/debug.log"
MIC_NAME_FILE="$STATE_DIR/mic_name"

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
    rm -f "$PANE_FILE" "$MIC_NAME_FILE"

    if [[ ! -x "$WHISPER_BIN" ]]; then
        log "ERROR whisper-cli missing at $WHISPER_BIN"
        rm -f "$STATE_FILE"
        tmux_refresh
        tmux display-message "voice: whisper-cli not found"
        exit 1
    fi

    VAD_ARGS=()
    [[ -f "$VAD_MODEL" ]] && VAD_ARGS=(--vad -vm "$VAD_MODEL")
    PROMPT_ARGS=()
    [[ -s "$VOCAB_FILE" ]] && PROMPT_ARGS=(--prompt "$(cat "$VOCAB_FILE")")
    TRANSCRIPT="$("$WHISPER_BIN" -m "$WHISPER_MODEL" -f "$WAV_FILE" -nt -np "${VAD_ARGS[@]}" "${PROMPT_ARGS[@]}" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//')"
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

    rm -f "$WAV_FILE" "$MIC_NAME_FILE"
    DEVICE_ARGS=()
    [[ -n "$INPUT_DEVICE" ]] && DEVICE_ARGS=(--device="$INPUT_DEVICE")
    setsid parecord "${DEVICE_ARGS[@]}" --channels=1 --rate=16000 --format=s16le "$WAV_FILE" < /dev/null > /dev/null 2>&1 &
    disown
    echo $! > "$PID_FILE"
    printf 'recording' > "$STATE_FILE"
    tmux_refresh

    # Query Windows' actual default recording device name in the
    # background (powershell.exe startup is slow, ~0.5-1s) so the popup
    # can show it once ready -- catches "wrong mic selected" mistakes
    # (e.g. a mic in a different room) that a bare level meter alone
    # can't name. Best-effort: if AudioDeviceCmdlets isn't installed or
    # the query fails/hangs, mic_name just never appears and the popup
    # falls back to the level meter alone.
    (
        timeout 5 powershell.exe -NoProfile -Command \
            "Import-Module AudioDeviceCmdlets -ErrorAction Stop; (Get-AudioDevice -Recording).Name" \
            2>/dev/null | tr -d '\r' | head -1 > "$MIC_NAME_FILE"
    ) &
    disown

    # Bottom-middle of the active pane. tmux clamps popups to stay fully
    # on-screen, so if the pane is too small this naturally falls back to
    # bottom-middle of the whole terminal instead.
    tmux display-popup -E -T ' Voice ' -w 46 -h 10 \
        -x '#{e|/:#{e|-:#{e|+:#{popup_pane_left},#{popup_pane_right}},#{popup_width}},2}' \
        -y '#{e|-:#{popup_pane_bottom},#{popup_height}}' \
        "~/bin/voice-popup.sh" &
    disown

    log "recording started, pane=$PANE_ID pid=$(cat "$PID_FILE")"
fi
