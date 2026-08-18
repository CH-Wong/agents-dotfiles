# Voice dictation

Fully local, offline push-to-talk voice dictation for Claude Code prompts, using whisper.cpp.
Works entirely inside WSL2/Linux via a tmux keybinding and popup; no Windows-side component needed.

## Setup on a new machine

1. Run `bootstrap.sh` (from the repo root) to symlink the scripts into `~/bin` and wire `~/.tmux.conf`.
2. Run `voice/setup-whisper.sh` once to install dependencies, build whisper.cpp, and download the model.
   This is a separate opt-in step, not run automatically by `bootstrap.sh`, since it pulls a compiler toolchain and a ~140MB model file.

## Usage

- `prefix + v` in tmux starts recording. A floating "REC" popup appears at the bottom middle of the active pane (or the bottom middle of the whole terminal if the pane is too small to fit it).
- `prefix + v` again stops recording. The popup switches to "TRANSCRIBING..." while whisper.cpp runs locally, then closes itself once the result is typed into whatever pane was active when you started -- exactly as if you'd typed it.
- `voice-level.sh` shows a live mic input level meter, useful for checking the mic is actually being picked up.
- `VOICE_INPUT_DEVICE` env var selects a specific PulseAudio source (see `pactl list short sources`); empty uses the default.

## Design notes

Recording is triggered by a tmux keybinding, not a Claude Code keybinding or `$EDITOR`/Ctrl+G.
Claude Code tears down its own screen before handing off to `$EDITOR` (like `git commit` opening vim), so anything routed through that path causes a visible blank flash with no way around it.
Triggering from tmux directly and injecting the transcript with `tmux send-keys` avoids that entirely -- Claude Code's screen is never suspended or touched.
