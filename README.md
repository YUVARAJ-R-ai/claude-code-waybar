# claude-code-waybar

**A waybar control panel for [Claude Code](https://claude.ai/code) on Hyprland — approve permission prompts across every concurrent tmux session with one click, without ever leaving your workspace. Bundles a rofi wifi picker as a bonus.**

![placeholder — add a GIF: waybar counter increments as a Claude session hits a prompt, click accepts it](docs/demo.gif)

---

## The problem

If you run Claude Code inside VS Code's integrated terminal, every permission prompt drags you back to that specific VS Code window. Open three projects in three windows and you spend the day hunting for whichever one is blocked on a `Bash` approval. Flow gone.

## The idea

Decouple the **approval UI** from the **execution surface**:

- Claude Code runs in a **tmux session** named after the project (`claude-<name>`) — addressable from anywhere via `tmux send-keys`.
- VS Code stays open on the same folder as a pure viewer/diff surface. File changes reload live, diffs render in the gutter and Source Control panel.
- A **Claude Code Notification hook** writes a state file whenever any session needs input.
- A **waybar custom module** aggregates state across every session — one glyph, N pending. Left-click accepts, right-click rejects, middle-click focuses the terminal.
- **Image paste still works** — kitty graphics protocol passes through tmux (`allow-passthrough on`), and a clipboard→path helper turns screenshots into paste-ready file references.

## Highlights

- One waybar entry aggregates **N Claude Code sessions**.
- Left / right / middle click = accept / reject / focus.
- Instant refresh via `SIGRTMIN+8` — no polling delay on new prompts.
- Keyboard fallbacks via Hyprland (`Super+Shift+A/X/F`).
- Region screenshot → path helper (`Super+Shift+S`) — paste a UI mock into Claude in one shortcut.
- **Bonus: rofi wifi picker** for the `network` module — click the bar (or `Super+N`) to open a scannable SSID list. Right-click falls back to `nmtui` in kitty for VPN/edge cases.
- Zero VS Code plugin. Editor is untouched.
- Small footprint: bash + jq + tmux + waybar. No daemons, no background processes.

## Requirements

| Component | Purpose |
| --- | --- |
| Hyprland + waybar | Tested with `waybar-jwt-transparent` on ZaneyOS; portable to any waybar config. |
| kitty | Or any terminal that speaks the kitty graphics protocol (for image paste). |
| tmux | Host process for Claude Code sessions. |
| jq, wl-clipboard, libnotify | State parsing, clipboard I/O, desktop notifications. |
| Claude Code (`claude` on `$PATH`) | The thing being controlled. |
| grim + slurp | *Optional* — needed for the region-screenshot binding. |
| rofi + NetworkManager (`nmcli`) | *Optional* — needed for the bundled wifi picker. |

## Install

Full walkthrough in [`docs/install.md`](docs/install.md). Short version:

```bash
git clone https://github.com/<you>/claude-code-waybar ~/.config/claude-waybar
mkdir -p ~/.local/bin
ln -sf ~/.config/claude-waybar/scripts/claude-waybar-* ~/.local/bin/
ln -sf ~/.config/claude-waybar/scripts/rofi-wifi-menu   ~/.local/bin/
chmod +x ~/.config/claude-waybar/scripts/* ~/.config/claude-waybar/hooks/*.sh
```

Then wire four things:

1. **Claude Code hooks** — add the block from [`docs/install.md#4`](docs/install.md) to `~/.claude/settings.json`.
2. **tmux** — `source-file ~/.config/claude-waybar/tmux/claude.conf` in `~/.tmux.conf`.
3. **waybar** — paste [`waybar/module.jsonc`](waybar/module.jsonc) into your waybar config, append [`waybar/style.css`](waybar/style.css) to your stylesheet, then `killall -SIGUSR2 waybar`.
4. **Hyprland** — `source = ~/.config/claude-waybar/hypr/keybinds.conf` in `~/.config/hypr/hyprland.conf`, then `hyprctl reload`.

A NixOS/home-manager flake for one-line install is on the roadmap.

## Usage

```bash
cd ~/some-project
claude-waybar-session          # opens (or attaches to) a tmux-hosted Claude in this project
```

Ask Claude to run a shell command it doesn't have pre-approved. The waybar module lights up as `⏸ 1`. Left-click → prompt approved from the bar. Alt-Tab not required.

| Binding | Action |
| --- | --- |
| `Super+C` | Launch/attach a Claude session in `$PWD` |
| `Super+Shift+V` | Convert clipboard image → file path (for pasting into Claude) |
| `Super+Shift+S` | Region screenshot → clipboard as file path |
| `Super+Shift+A` | Accept the oldest pending prompt |
| `Super+Shift+X` | Reject the oldest pending prompt |
| `Super+Shift+F` | Focus the terminal of the oldest pending session |
| `Super+N` | Open the rofi wifi picker |

## Architecture

Detailed diagram + data flow in [`docs/architecture.md`](docs/architecture.md). Summary:

```
Claude Code ─▶ Notification hook ─▶ $XDG_STATE_HOME/claude-waybar/pending/<id>.json
                     │
                     └─▶ pkill -RTMIN+8 waybar  (instant refresh)
                                          │
                                          ▼
                       waybar custom/claude module reads state
                                          │
                       click ─▶ tmux send-keys ─▶ claude-<project> session
```

State model:

- One JSON file per pending prompt in `$XDG_STATE_HOME/claude-waybar/pending/`.
- Written by `hooks/notification.sh`, cleared by `hooks/stop.sh`, read by `scripts/claude-waybar-pending`.
- No shared state, no locking — one file per session, atomic writes.

## Why tmux and not a wrapper daemon

- Claude Code is designed to be interactive. Wrapping it strips the terminal control it needs for image paste, streaming diffs, and TUI prompts.
- `tmux send-keys` is a 30-year-old, boringly reliable IPC.
- Sessions survive terminal window crashes. Reopen kitty, `tmux attach -t claude-<project>`, continue where you were.

## Roadmap

- Nix flake + `homeManagerModules.default` for one-line declarative install (NixOS/home-manager).
- Config file (`~/.config/claude-waybar/config.toml`) for tmux naming scheme, urgency thresholds, custom paths.
- Sway / river / niri support (waybar module is already portable; only the hypr binds need per-WM equivalents).
- Per-project "auto-accept this tool" rules layered on top of Claude Code's own allowlist.
- Optional rofi/wofi picker for "which pending prompt to accept" when multiple are queued.

## Contributing

Issues and PRs welcome. This is a personal itch-scratch first, generalize-later project — if you're using a different WM/bar and want it supported, open an issue with what you'd need and I'll help design the portable seam.

## Credits

Built on top of [Claude Code](https://claude.ai/code) by Anthropic, [waybar](https://github.com/Alexays/Waybar), [tmux](https://github.com/tmux/tmux), and [rofi](https://github.com/davatorium/rofi). Developed on [ZaneyOS](https://gitlab.com/Zaney/zaneyos) (a NixOS + Hyprland distro).

## License

MIT — see [`LICENSE`](LICENSE).
