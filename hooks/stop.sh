#!/usr/bin/env bash
# Claude Code Stop hook — clears the pending entry for a session when Claude finishes a turn.
# Register in ~/.claude/settings.json alongside Notification:
#   "Stop": [ { "hooks": [ { "type": "command", "command": "~/.config/claude-waybar/hooks/stop.sh" } ] } ]

set -euo pipefail

json=$(cat)
session_id=$(echo "$json" | jq -r '.session_id // "unknown"')

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-waybar/pending"
rm -f "$state_dir/${session_id}.json"

pkill -RTMIN+8 waybar 2>/dev/null || true
