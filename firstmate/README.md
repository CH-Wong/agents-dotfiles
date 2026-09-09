# firstmate heartbeat

`bin/fm-nudge-heartbeat.sh` is an external watchdog for the interactive Firstmate Claude Code session.

When that session hits the Claude usage limit it freezes until the limit resets, and then does not resume on its own - any in-flight worker agents just sit idle at their prompt.
This heartbeat runs from cron (outside Claude, so the limit cannot stop it), notices a frozen session that still has work in flight, and types one "drain the wake queue and continue" line into its tmux pane.
Firstmate then picks the work back up, including re-nudging the stalled workers.

It also covers other stalls - a crashed worker, a dropped connection - not just usage limits.

## What it does / does not do

It stays completely silent unless **all** of these hold:

1. Firstmate has in-flight tasks (`$FM_HOME/state/*.meta` exists).
2. Its tmux pane can be located unambiguously (a `claude` process whose working directory is exactly `$FM_HOME`).
3. That pane's visible content has not changed across the last ~3 runs (~40 minutes static = stalled, not merely parked waiting on a worker).

A healthy, actively-working session changes its pane every turn and is never nudged.
Worst-case latency to auto-resume after an overnight limit hit is roughly one hour (40 min static detection + up to 20 min to the next cron tick).

- Log: `$FM_HOME/state/.nudge-heartbeat.log`
- State: `$FM_HOME/state/.nudge-heartbeat.{hash,hash.prev,last-nudge}`
- `$FM_HOME` defaults to `~/code/firstmate`.

## Setup on a new machine

Run `firstmate/install.sh` once.
It is a separate opt-in step, not run automatically by `bootstrap.sh`, because it edits your crontab.
`bootstrap.sh` still symlinks the script itself into `~/bin/` like every other `bin/*.sh`.

```
~/agents-dotfiles/firstmate/install.sh
```

The installer is idempotent: it adds a single `*/20 * * * *` line tagged `# agents-dotfiles: firstmate heartbeat`, and does nothing if that line is already present.

## Remove it

`crontab -e` and delete the tagged line. The script is a safety net only; nothing else depends on it.
