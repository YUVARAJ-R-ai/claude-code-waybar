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
# Claude Code renders permission prompts like this (observed in the wild):
#     ──────────────────────────────────  <- top border: horizontal rule only
#      Bash command                        <- title (may have │ on left)
#
#      <the command>                       <- body: 1-2 indented lines
#      <description>
#
#      This command requires approval
#
#      Do you want to proceed?
#      ❯ 1. Yes
#        2. Yes, and don't ask again ...
#        3. No
#     (no bottom border on some renders)
#
# Algorithm: find the last "Do you want to proceed" line; walk back to the
# nearest all-horizontal-rule line (that's the top border); extract the
# content between them and pull out the first two non-empty lines.
capture_summary() {
  local target="$1"
  tmux has-session -t "$target" 2>/dev/null || return 0

  # The Notification hook fires BEFORE Claude finishes rendering the prompt
  # in the pane — a fixed sleep is a race. Poll for the "Do you want to
  # proceed" line up to ~3s, capturing after each short delay.
  local pane end top attempt
  for attempt in 1 2 3 4 5 6; do
    sleep 0.5
    pane=$(tmux capture-pane -p -J -t "$target" -S -200 2>/dev/null || true)
    end=$(printf '%s' "$pane" | grep -n 'Do you want to proceed' | tail -1 | cut -d: -f1)
    [ -n "$end" ] && break
  done
  [ -z "$end" ] && return 0

  # Top = last line that is essentially a horizontal rule (5+ ─ chars, maybe
  # with leading whitespace or a single leading │). Accept ─, ━, ═ variants.
  top=$(printf '%s' "$pane" | sed -n "1,${end}p" \
    | grep -nE '^[[:space:]│]*[─━═]{5,}' \
    | tail -1 | cut -d: -f1)
  [ -z "$top" ] && return 0

  # Strip left │ + surrounding whitespace, drop empty and rule-only lines.
  local content
  content=$(printf '%s' "$pane" | sed -n "$((top+1)),$((end-1))p" \
    | sed -E 's/^[[:space:]]*│?[[:space:]]*//; s/[[:space:]]*$//' \
    | grep -v '^$' \
    | grep -vE '^[─━═]+$')

  local title body
  title=$(printf '%s' "$content" | sed -n '1p')
  body=$(printf '%s'  "$content" | sed -n '2p' | cut -c1-70)

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
