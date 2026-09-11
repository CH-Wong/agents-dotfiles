# firstmate config

Shared config for the interactive Firstmate Claude Code session, symlinked into `$FM_HOME` by `bootstrap.sh`.
`$FM_HOME` defaults to `~/code/firstmate` everywhere in this directory.

## Heartbeat watchdog

`bin/fm-nudge-heartbeat.sh` is an external watchdog for the interactive Firstmate session.

When that session hits the Claude usage limit it freezes until the limit resets, and then does not resume on its own.
Any in-flight worker agents just sit idle at their prompt.
This heartbeat runs from cron (outside Claude, so the limit cannot stop it), notices a frozen session that still has work in flight, and types one "drain the wake queue and continue" line into its tmux pane.
Firstmate then picks the work back up, including re-nudging the stalled workers.

It also covers other stalls, such as a crashed worker or a dropped connection, not just usage limits.

### What it does / does not do

It stays completely silent unless **all** of these hold:

1. Firstmate has in-flight tasks (`$FM_HOME/state/*.meta` exists).
2. Its tmux pane can be located unambiguously (a `claude` process whose working directory is exactly `$FM_HOME`).
3. That pane's visible content has not changed across the last ~3 runs (~40 minutes static = stalled, not merely parked waiting on a worker).

A healthy, actively-working session changes its pane every turn and is never nudged.
Worst-case latency to auto-resume after an overnight limit hit is roughly one hour (40 min static detection plus up to 20 min to the next cron tick).

- Log: `$FM_HOME/state/.nudge-heartbeat.log`
- State: `$FM_HOME/state/.nudge-heartbeat.{hash,hash.prev,last-nudge}`

### Setup on a new machine

Run `firstmate/install.sh` once.
It is a separate opt-in step, not run automatically by `bootstrap.sh`, because it edits your crontab.
`bootstrap.sh` still symlinks the script itself into `~/bin/` like every other `bin/*.sh`.

```
~/agents-dotfiles/firstmate/install.sh
```

The installer is idempotent: it adds a single `*/20 * * * *` line tagged `# agents-dotfiles: firstmate heartbeat`, and does nothing if that line is already present.

### Remove it

`crontab -e` and delete the tagged line.
The script is a safety net only; nothing else depends on it.

## Crew dispatch profile (model rubric)

`firstmate/crew-dispatch.json` is the standing rubric for which model Firstmate pins to a crewmate or scout task, symlinked by `bootstrap.sh` into `$FM_HOME/config/crew-dispatch.json`.
Firstmate's own docs (`docs/configuration.md` "Crew dispatch profiles" in the firstmate repo) own the exact schema; this file just holds the captain's actual rules.

Current rubric, three tiers:

- **Hard or ambiguous work** (architecture and cross-cutting design decisions, risky refactors, hard bug investigations, big multi-file features) pins `claude-fable-5-1` at `xhigh` effort - the strongest-reasoning model, for when getting the approach right matters more than speed or cost.
- **Trivial mechanical edits** (rote renames, formatting sweeps, targeted typo or string fixes, simple file gathering) pin `claude-haiku-4-5-20251001` at `low` effort - the cheapest fast model, for narrow, low-ambiguity work.
- **Everything else** (ordinary, well-scoped feature work - most day-to-day tasks) falls through to the `default` profile, `claude-sonnet-5` at `high` effort.

Firstmate matches the `when` condition with judgment rather than a script, so the rubric is meant to be read and adjusted in plain English.
Edit `firstmate/crew-dispatch.json` directly, then re-run `bootstrap.sh` if the symlink is missing (it is idempotent and safe to re-run any time).
No crontab or install step needed here, this one just needs `jq` on the target machine (firstmate's own bootstrap will ask before installing it).
