# no-mistakes

Local git proxy that gates `git push` behind an AI-driven validation pipeline (review, test, docs, lint) before forwarding to the real remote and opening a clean PR.
Upstream: <https://github.com/kunchenguid/no-mistakes>

## Setup on a new machine

1. Run `no-mistakes/install.sh` once to download the `no-mistakes` binary and start its background daemon.
   This is a separate opt-in step, not run automatically by `bootstrap.sh`, since it pulls a binary release over the network and restarts a daemon.
2. Inside any repo you want gated, run `no-mistakes init` to point a `no-mistakes` git remote at a disposable local bare repo and install the `/no-mistakes` skill for Claude Code.

## Usage

- `git push no-mistakes <branch>` -- push a committed branch through the gate instead of `origin`.
- `no-mistakes` -- opens the TUI to walk through committing and pushing through the gate, or attach to a running pipeline.
- `/no-mistakes <task>` -- Claude Code skill (installed by `no-mistakes init`) that does a task and gates it, or gates existing committed work, headlessly.

Nothing reaches the real remote until every pipeline check (review, test, docs, lint) is green.
