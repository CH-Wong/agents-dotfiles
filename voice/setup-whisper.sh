#!/usr/bin/env bash
# One-time, idempotent setup for the local voice dictation pipeline.
# Not run automatically by bootstrap.sh -- opt in per machine, since it
# pulls a compiler toolchain, builds a native binary, and downloads a
# ~140MB model. Run: ~/agents-dotfiles/voice/setup-whisper.sh
#
# After this, wire up tmux/voice.conf (bootstrap.sh does that part) and
# use prefix+v to toggle recording.

set -euo pipefail

WHISPER_DIR="$HOME/tools/whisper.cpp"
MODEL="base.en"

if ! command -v cmake >/dev/null || ! command -v pacat >/dev/null || ! command -v ffmpeg >/dev/null; then
  echo "Installing system dependencies (requires sudo)..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq pulseaudio-utils ffmpeg build-essential cmake git
fi

if [[ ! -x "$WHISPER_DIR/build/bin/whisper-cli" ]]; then
  if [[ ! -d "$WHISPER_DIR" ]]; then
    echo "Cloning whisper.cpp..."
    mkdir -p "$(dirname "$WHISPER_DIR")"
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
  fi
  echo "Building whisper.cpp..."
  cmake -B "$WHISPER_DIR/build" -S "$WHISPER_DIR" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$WHISPER_DIR/build" --config Release -j"$(nproc)"
fi

if [[ ! -f "$WHISPER_DIR/models/ggml-$MODEL.bin" ]]; then
  echo "Downloading $MODEL model..."
  bash "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL"
fi

echo "Done. whisper-cli: $WHISPER_DIR/build/bin/whisper-cli"
echo "Model: $WHISPER_DIR/models/ggml-$MODEL.bin"
echo "Make sure bootstrap.sh has been run so ~/bin and ~/.tmux.conf are wired up, then use prefix+v in tmux."
