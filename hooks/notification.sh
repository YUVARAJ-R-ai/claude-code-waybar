#!/usr/bin/env bash
# Claude Code Notification hook.
# Register in ~/.claude/settings.json:
#   {
#     "hooks": {
#       "Notification": [
#         { "hooks": [ { "type": "command", "command": "~/.config/claude-waybar/hooks/notification.sh" } ] }
#       ]
#     }
#   }
#
# Writes one JSON file per waiting session into $XDG_STATE_HOME/claude-waybar/pending/
# and pings waybar (SIGRTMIN+8) to refresh the module.

set -euo pipefail

json=$(cat)

session_id=$(echo "$json" | jq -r '.session_id // "unknown"')
cwd=$(echo "$json" | jq -r '.cwd // .transcript_path // "."')
message=$(echo "$json" | jq -r '.message // ""')

project=$(basename "$cwd")
tmux_target="claude-${project}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-waybar/pending"
mkdir -p "$state_dir"

jq -n \
  --arg sid  "$session_id" \
  --arg proj "$project" \
  --arg dir  "$cwd" \
  --arg tgt  "$tmux_target" \
  --arg msg  "$message" \
  --arg ts   "$(date -Iseconds)" \
  '{session_id:$sid, project:$proj, project_dir:$dir, tmux_target:$tgt, message:$msg, created_at:$ts}' \
  > "$state_dir/${session_id}.json"

notify-send -a claude-waybar -u normal \
  "Claude: $project" "${message:-Waiting for your input}"

pkill -RTMIN+8 waybar 2>/dev/null || true
