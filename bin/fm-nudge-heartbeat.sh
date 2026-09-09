#!/usr/bin/env bash
# fm-nudge-heartbeat.sh
#
# External heartbeat for the interactive Firstmate session.
#
# Purpose: when the Firstmate Claude Code session freezes - usually because the
# Claude usage limit was hit, sometimes a dropped connection or a crash - it does
# not resume on its own after the limit resets. This script runs from cron
# (outside Claude, so the limit cannot stop it), notices a frozen session that
# still has work in flight, and types one line into its tmux pane to wake it.
# Firstmate then drains its wake queue and continues, including nudging any
# workers that froze alongside it.
#
# Safe to run every 20 minutes. It stays silent unless ALL of these hold:
#   1. Firstmate has in-flight tasks         (state/*.meta exists)
#   2. its tmux pane can be located unambiguously
#   3. the pane's visible content has not changed across the last ~3 runs
#      (~40 min of no activity = stalled, not merely waiting on a worker)
# A healthy, actively-working session changes its pane and is never nudged.
#
# Install:  bootstrap.sh symlinks this into ~/bin/ and adds a `*/20 * * * *`
#           crontab entry idempotently (tagged "# agents-dotfiles: firstmate
#           heartbeat"). Nothing to do by hand.
# Log:      $FM_HOME/state/.nudge-heartbeat.log
# Remove:   `crontab -e` and delete the tagged line; this script is a safety net only.

set -u

FM_HOME="${FM_HOME:-$HOME/code/firstmate}"
STATE="$FM_HOME/state"
LOG="$STATE/.nudge-heartbeat.log"
HASH_CUR="$STATE/.nudge-heartbeat.hash"
HASH_PREV="$STATE/.nudge-heartbeat.hash.prev"
NUDGED_AT="$STATE/.nudge-heartbeat.last-nudge"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s  %s\n' "$(ts)" "$*" >> "$LOG" 2>/dev/null || true; }

# keep the log bounded
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 500 ]; then
  tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null || true
fi

[ -d "$STATE" ] || { log "no state dir at $STATE; aborting"; exit 0; }

# 1. in-flight work?
shopt -s nullglob
metas=("$STATE"/*.meta)
shopt -u nullglob
if [ "${#metas[@]}" -eq 0 ]; then
  log "no in-flight tasks; nothing to keep alive"
  : > "$HASH_CUR" 2>/dev/null || true
  : > "$HASH_PREV" 2>/dev/null || true
  exit 0
fi

# 2. locate the firstmate pane: a `claude` process whose cwd is exactly FM_HOME.
have_tmux=$(command -v tmux || true)
[ -n "$have_tmux" ] || { log "tmux not found; cannot nudge"; exit 0; }

# cron has no $TMUX; point tmux at this uid's default socket explicitly, and
# fall back to a plain invocation if that path does not exist.
TMUX_SOCK="/tmp/tmux-$(id -u)/default"
tm() { if [ -S "$TMUX_SOCK" ]; then tmux -S "$TMUX_SOCK" "$@"; else tmux "$@"; fi; }

mapfile -t candidates < <(
  tm list-panes -a -F '#{pane_id} #{pane_current_command} #{pane_current_path}' 2>/dev/null \
    | awk -v home="$FM_HOME" '$2=="claude" && $3==home {print $1}'
)
if [ "${#candidates[@]}" -eq 0 ]; then
  log "no claude pane with cwd=$FM_HOME found; skipping (session may be closed)"
  exit 0
fi
if [ "${#candidates[@]}" -gt 1 ]; then
  log "ambiguous: ${#candidates[@]} claude panes at $FM_HOME (${candidates[*]}); skipping to avoid nudging the wrong one"
  exit 0
fi
TARGET="${candidates[0]}"

# 3. static across the last two runs?
cur_hash=$(tm capture-pane -p -t "$TARGET" 2>/dev/null | sha1sum | cut -d' ' -f1)
prev_hash=$(cat "$HASH_CUR" 2>/dev/null || echo "")
prev2_hash=$(cat "$HASH_PREV" 2>/dev/null || echo "")

# roll the history
cp -f "$HASH_CUR" "$HASH_PREV" 2>/dev/null || true
printf '%s\n' "$cur_hash" > "$HASH_CUR" 2>/dev/null || true

if [ -z "$cur_hash" ]; then
  log "could not capture pane $TARGET; skipping"
  exit 0
fi
if [ "$cur_hash" != "$prev_hash" ] || [ "$cur_hash" != "$prev2_hash" ]; then
  log "pane $TARGET active (or first observations); healthy, not nudging"
  exit 0
fi

# 4. static + work in flight => stalled. Nudge, but not more than once per 15 min.
last_nudge=$(cat "$NUDGED_AT" 2>/dev/null || echo 0)
now=$(date +%s)
if [ $((now - last_nudge)) -lt 900 ]; then
  log "would nudge $TARGET but nudged ${last_nudge}s-epoch recently; holding off"
  exit 0
fi

MSG="Cron heartbeat (fm-nudge-heartbeat.sh): this session looks frozen with work still in flight. If you are resuming after a Claude usage-limit reset, a dropped connection, or any stall, drain the wake queue now, reconcile the in-flight tasks and their workers, and continue. If you are in fact already working normally, disregard this line."

tm send-keys -t "$TARGET" -l "$MSG" 2>/dev/null
tm send-keys -t "$TARGET" Enter 2>/dev/null
printf '%s\n' "$now" > "$NUDGED_AT" 2>/dev/null || true
log "NUDGED $TARGET (in-flight tasks: ${#metas[@]}; pane static across 2 prior checks)"
exit 0
