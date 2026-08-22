# Voice dictation

Fully local, offline push-to-talk voice dictation for Claude Code prompts, using whisper.cpp.
The recording/transcribe pipeline itself is pure WSL2/Linux via a tmux keybinding and popup -- no Windows-side component required for that part.
Two optional conveniences do reach across into Windows (both WSL-only, both best-effort/no-op elsewhere): the popup's mic-name display (PowerShell `AudioDeviceCmdlets`) and `tmux/clipboard.conf`'s copy-to-Windows-clipboard binding (`clip.exe`).

## Setup on a new machine

1. Run `bootstrap.sh` (from the repo root) to symlink the scripts into `~/bin` and source every `tmux/*.conf` module into `~/.tmux.conf`.
2. Run `voice/setup-whisper.sh` once to install dependencies, build whisper.cpp, and download the `base.en` transcription model and the `silero` VAD model.
   This is a separate opt-in step, not run automatically by `bootstrap.sh`, since it pulls a compiler toolchain and ~150MB of model files.
   On WSL with `powershell.exe` reachable, it also installs the `AudioDeviceCmdlets` PowerShell module (best-effort -- a failure here doesn't stop the script, the popup just won't show a mic name).

## Usage

- `prefix + v` in tmux starts recording. A floating popup appears at the bottom middle of the active pane (or the bottom middle of the whole terminal if the pane is too small to fit it), showing:
  - the actual Windows default recording device name (WSL only, needs `AudioDeviceCmdlets` -- see Setup), so a wrong/distant mic is visible immediately instead of discovered after a bad transcript
  - a live input-level bar, updated ~10x/second, reading directly off the growing wav file
  - a "very quiet -- check input device" warning if the level stays low for over a second
- Press any key while the popup is showing to stop recording (not `prefix + v` again -- tmux popups take over all keyboard input while displayed, so the normal keybinding can't reach it; see Design notes).
  The popup switches to "TRANSCRIBING..." while whisper.cpp runs locally (VAD-trimmed, to avoid silence-hallucination artifacts), then closes itself once the result is typed into whatever pane was active when you started -- exactly as if you'd typed it.
- `voice-level.sh` shows a live mic input level meter standalone (outside a recording), useful for a quick mic check.
- `voice-diagnose.sh [seconds]` records a one-off sample, reports capture stats (peak/clipping), and transcribes it with a few model/VAD combinations side by side -- the tool to reach for when dictation quality seems off, to tell a capture problem from a model problem.
- `VOICE_INPUT_DEVICE` env var selects a specific PulseAudio source (see `pactl list short sources`); empty uses the default.

## Design notes

Recording is triggered by a tmux keybinding, not a Claude Code keybinding or `$EDITOR`/Ctrl+G.
Claude Code tears down its own screen before handing off to `$EDITOR` (like `git commit` opening vim), so anything routed through that path causes a visible blank flash with no way around it.
Triggering from tmux directly and injecting the transcript with `tmux send-keys` avoids that entirely -- Claude Code's screen is never suspended or touched.

tmux popups own all keyboard input while displayed -- there is no click-through/non-focus-stealing popup mode, so `prefix + v` cannot reach tmux's normal keybinding table once the popup is up.
`voice-popup.sh` therefore turns off local echo (`stty -echo`) and reads its own keypress to trigger the stop, rather than waiting on the tmux binding.
It also drains any input left buffered right after that keypress, so a habit-press of the full `prefix + v` sequence does not leak the trailing `v` into whatever pane regains focus once the popup closes.

The popup redraws in place rather than calling `clear` every tick -- a full-screen clear before each redraw blanks the terminal for a frame, which reads as blinking at a 10x/second refresh rate.
Instead it clears the real screen once up front, then each redraw only moves the cursor home (`\033[H`) and clears trailing garbage per-line (`\033[K`) and below the frame (`\033[J`).

`tmux/clipboard.conf` pipes copy-mode's copy action through `clip.exe` instead of relying on tmux's OSC 52 `set-clipboard external` escape-code round trip.
OSC 52 support is terminal-emulator-dependent and was observed landing copies only in tmux's own paste buffer, not the real Windows clipboard; piping through `clip.exe` (native WSL interop) sidesteps that entirely.
