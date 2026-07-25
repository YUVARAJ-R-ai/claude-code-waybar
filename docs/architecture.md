# Architecture

## Data flow

```
┌────────────────────────┐        1. asks for permission
│  Claude Code (tmux)    │───────────────────────────────────┐
│  session: claude-<proj>│                                   │
└────────────────────────┘                                   ▼
                                              ┌──────────────────────────┐
                                              │ Notification hook (bash) │
                                              │ hooks/notification.sh    │
                                              └──────────────────────────┘
                                                              │ 2. writes state file
                                                              ▼
                        ┌─────────────────────────────────────────────────────────┐
                        │  $XDG_STATE_HOME/claude-waybar/pending/<session>.json   │
                        │  { project, tmux_target, message, created_at }          │
                        └─────────────────────────────────────────────────────────┘
                                     ▲                             │
                                     │ 5. cleared by               │ 3. read on tick
                                     │ hooks/stop.sh               │ + on SIGRTMIN+8
                                     │                             ▼
                                     │                ┌──────────────────────────┐
                                     │                │ waybar custom/claude     │
                                     │                │ scripts/pending          │
                                     │                └──────────────────────────┘
                                     │                              │ 4. click routes to
                                     │                              ▼
                                     │                ┌──────────────────────────┐
                                     └────────────────│ scripts/accept           │
                                                      │ tmux send-keys Enter/Esc │
                                                      └──────────────────────────┘
```

## Why tmux is the pivot

Claude Code is a TUI running in a pty — permission prompts are just keystrokes waiting to be read. To answer them from outside the terminal, we need to inject keystrokes into that specific pty. Options considered:

| Approach | Why we didn't pick it |
|---|---|
| `ydotool`/`wtype` into focused window | Fragile — wrong focused window = wrong approval |
| VS Code extension `terminal.sendText` | Ties us to VS Code, needs a custom extension |
| Claude Agent SDK with custom `canUseTool` | Requires running headless, loses the interactive CLI |
| **tmux `send-keys -t <session>`** | Sessions are named + addressable, works over SSH, no GUI dependency |

## State model

- One file per waiting session, keyed by `session_id`.
- `Notification` hook writes it; `Stop` hook removes it.
- Waybar reads the directory every 5s (interval) and instantly on SIGRTMIN+8 (signal 8) — the accept/reject/hook scripts fire that signal for instant refresh.

## Naming convention

- tmux session name: `claude-<project>` (project = basename of Claude's cwd).
- Reason: tmux disallows `:` in session names (it's the session/window separator).
- The `claude-waybar-session` script uses the same convention so `Super+C` and the hook agree on target names.

## What it does *not* do

- **Does not** parse Claude's UI state — we assume "Enter = accept default" and "Escape = cancel". If the prompt has non-default options that need explicit selection, the user still has to focus the terminal.
- **Does not** run as a daemon. All logic is fired by external events (Claude hook, waybar interval, user click).
- **Does not** touch VS Code. VS Code is used only as an editor/diff viewer on the same folder.
