#!/usr/bin/env bash
# Live mic level meter -- talk and watch the bar. Ctrl+C to stop.
# Reads raw 16-bit mono PCM from the same source voice-toggle.sh uses.

set -uo pipefail

INPUT_DEVICE="${VOICE_INPUT_DEVICE:-}"
DEVICE_ARGS=()
[[ -n "$INPUT_DEVICE" ]] && DEVICE_ARGS=(--device="$INPUT_DEVICE")

parec "${DEVICE_ARGS[@]}" --channels=1 --rate=16000 --format=s16le 2>/dev/null | python3 -c '
import sys, struct

CHUNK = 3200  # 0.1s of audio at 16kHz/16-bit/mono
while True:
    data = sys.stdin.buffer.read(CHUNK)
    if not data:
        break
    n = len(data) // 2
    if n == 0:
        continue
    samples = struct.unpack("<%dh" % n, data[: n * 2])
    peak = max(abs(s) for s in samples)
    bars = int(peak / 1000)
    print("\r[%-32s] %5d" % ("#" * min(bars, 32), peak), end="", flush=True)
'
