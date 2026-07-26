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

# ---- Grab a short summary of the *actual* pending action from the tmux pane.
# Claude Code renders permission prompts inside a unicode box:
#     ╭─────────────────╮
#     │ Bash command    │      <- title
#     │                 │
#     │   rm -rf /tmp   │      <- body
#     │                 │
#     │ Do you want to proceed?
#     ╰─────────────────╯
# We locate the last "Do you want to proceed" line, walk back to the matching
# top border "╭", and pull the title + first body line out.
capture_summary() {
  local target="$1"
  tmux has-session -t "$target" 2>/dev/null || return 0
  # Small delay: the prompt sometimes isn't fully rendered when the hook fires.
  sleep 0.3
  local pane
  pane=$(tmux capture-pane -p -J -t "$target" -S -120 2>/dev/null || true)
  [ -z "$pane" ] && return 0

  local end top
  end=$(printf '%s' "$pane" | grep -n 'Do you want to proceed' | tail -1 | cut -d: -f1)
  [ -z "$end" ] && return 0
  top=$(printf '%s' "$pane" | sed -n "1,${end}p" | grep -n '╭' | tail -1 | cut -d: -f1)
  [ -z "$top" ] && return 0

  # Strip box-drawing chars, trim, drop empty lines and horizontal-rule lines.
  local content
  content=$(printf '%s' "$pane" | sed -n "$((top+1)),$((end-1))p" \
    | tr -d '│╭╮╰╯' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$' \
    | grep -v '^─\+$')

  local title body
  title=$(printf '%s' "$content" | sed -n '1p')
  body=$(printf '%s' "$content"  | sed -n '2p' | cut -c1-70)

  if [ -n "$title" ] && [ -n "$body" ]; then
    printf '%s: %s' "$title" "$body"
  elif [ -n "$title" ]; then
    printf '%s' "$title"
  fi
}

summary=$(capture_summary "$tmux_target" || true)
[ -z "$summary" ] && summary="$message"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-waybar/pending"
mkdir -p "$state_dir"

jq -n \
  --arg sid  "$session_id" \
  --arg proj "$project" \
  --arg dir  "$cwd" \
  --arg tgt  "$tmux_target" \
  --arg msg  "$message" \
  --arg sum  "$summary" \
  --arg ts   "$(date -Iseconds)" \
  '{session_id:$sid, project:$proj, project_dir:$dir, tmux_target:$tgt, message:$msg, summary:$sum, created_at:$ts}' \
  > "$state_dir/${session_id}.json"

notify-send -a claude-waybar -u normal \
  "Claude: $project" "${summary:-Waiting for your input}"

pkill -RTMIN+8 waybar 2>/dev/null || true
