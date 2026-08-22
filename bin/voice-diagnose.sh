#!/usr/bin/env bash
# One-shot diagnostic: records N seconds of mic audio, reports capture
# quality (peak/clipping), then transcribes the SAME recording with a
# few different whisper configs so you can tell capture vs model apart.
#
# Usage: ~/bin/voice-diagnose.sh [seconds]
# Default 6s. Speak a test sentence as soon as it says "recording now".

set -uo pipefail

DURATION="${1:-6}"
INPUT_DEVICE="${VOICE_INPUT_DEVICE:-}"
DEVICE_ARGS=()
[[ -n "$INPUT_DEVICE" ]] && DEVICE_ARGS=(--device="$INPUT_DEVICE")

WHISPER_DIR="$HOME/tools/whisper.cpp"
WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
BASE_MODEL="$WHISPER_DIR/models/ggml-base.en.bin"
SMALL_MODEL="$WHISPER_DIR/models/ggml-small.en.bin"
VAD_MODEL="$WHISPER_DIR/models/ggml-silero-v6.2.0.bin"

OUT_DIR="$HOME/.cache/claude-voice"
mkdir -p "$OUT_DIR"
WAV="$OUT_DIR/diagnose_$(date +%s).wav"

echo "=== recording now for ${DURATION}s -- speak a test sentence ==="
parecord "${DEVICE_ARGS[@]}" --channels=1 --rate=16000 --format=s16le --file-format=wav "$WAV" &
REC_PID=$!
sleep "$DURATION"
kill "$REC_PID" 2>/dev/null
sleep 0.3
echo "=== recording saved to $WAV ==="
echo

echo "--- capture stats (peak amplitude, 0-32767; clipping if hitting ~32767) ---"
python3 - "$WAV" <<'PYEOF'
import sys, wave, struct
with wave.open(sys.argv[1], 'rb') as w:
    n = w.getnframes()
    data = w.readframes(n)
    samples = struct.unpack("<%dh" % (len(data)//2), data)
    peak = max(abs(s) for s in samples)
    rms = (sum(s*s for s in samples) / len(samples)) ** 0.5
    clipped = sum(1 for s in samples if abs(s) >= 32760)
    dur = n / w.getframerate()
    print(f"duration={dur:.2f}s peak={peak} rms={rms:.0f} clipped_samples={clipped}")
    if peak < 3000:
        print("-> looks QUIET. Input gain may be too low.")
    elif clipped > 50:
        print("-> looks CLIPPED. Input gain may be too high / distorting.")
    else:
        print("-> levels look healthy.")
PYEOF
echo

echo "--- transcript: base.en, no VAD (current production config) ---"
"$WHISPER_BIN" -m "$BASE_MODEL" -f "$WAV" -nt -np 2>/dev/null
echo

if [[ -f "$VAD_MODEL" ]]; then
    echo "--- transcript: base.en + VAD ---"
    "$WHISPER_BIN" -m "$BASE_MODEL" -f "$WAV" -nt -np --vad -vm "$VAD_MODEL" 2>/dev/null
    echo
fi

if [[ -f "$SMALL_MODEL" ]]; then
    echo "--- transcript: small.en + VAD ---"
    "$WHISPER_BIN" -m "$SMALL_MODEL" -f "$WAV" -nt -np --vad -vm "$VAD_MODEL" 2>/dev/null
    echo
fi

echo "=== done. wav kept at $WAV for further inspection ==="
