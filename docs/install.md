# Install

Personal-first install — the paths below assume ZaneyOS + Hyprland + waybar-jwt-transparent, but everything is portable.

## 1. Dependencies

The three packages that are typically missing on a stock ZaneyOS install — add these to `host-packages.nix`:

```nix
environment.systemPackages = with pkgs; [
  tmux       # host Claude Code sessions for send-keys accept/reject
  libnotify  # notify-send used by all scripts
];
```

**Note on rofi:** the wifi picker needs `rofi`, but on most Hyprland setups (including ZaneyOS) it's already installed as part of the bar/launcher stack. Check with `command -v rofi` before adding it. If you *do* need to add it, use `rofi` — **not** `rofi-wayland`. The `-wayland` variant was removed from nixpkgs (upstream merge); referencing it produces `error: 'rofi-wayland' has been merged into 'rofi'` during `nh os switch`.

Then `nh os switch`.

**Note on tmux:** ZaneyOS's `variables.nix` has `tmuxEnable = false` by default — that flag only skips ZaneyOS's bundled tmux *config*, not the binary. Adding `tmux` to `host-packages.nix` as above is the right path.

Already present in the standard ZaneyOS + Hyprland stack (verify with `command -v <name>` if unsure): `rofi`, `jq`, `wl-clipboard`, `wl-clip-persist`, `grim`, `slurp`, `nmcli` (NetworkManager), `kitty`, `claude`.

## 2. Clone

```bash
git clone https://github.com/<you>/claude-code-waybar ~/.config/claude-waybar
```

## 3. Put the scripts on $PATH

```bash
mkdir -p ~/.local/bin
for s in ~/.config/claude-waybar/scripts/claude-waybar-*; do
  ln -sf "$s" ~/.local/bin/
done
chmod +x ~/.config/claude-waybar/scripts/claude-waybar-* ~/.config/claude-waybar/hooks/*.sh
```

Ensure `~/.local/bin` is on `$PATH`.

## 4. Register the Claude Code hooks

Edit `~/.claude/settings.json` (create if missing):

```json
{
  "hooks": {
    "Notification": [
      { "hooks": [ { "type": "command", "command": "~/.config/claude-waybar/hooks/notification.sh" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "~/.config/claude-waybar/hooks/stop.sh" } ] }
    ]
  }
}
```

## 5. Wire tmux

Add to `~/.tmux.conf`:

```tmux
source-file ~/.config/claude-waybar/tmux/claude.conf
```

## 6. Wire waybar

- Copy the objects in `waybar/module.jsonc` into your waybar config JSON (merge into the `modules` map — brings both `custom/claude` and `network`).
- Add `"custom/claude"` and `"network"` into one of the `modules-left` / `modules-center` / `modules-right` arrays.
- Append the contents of `waybar/style.css` to your waybar style.css (or `@import` it).
- Reload: `killall -SIGUSR2 waybar`.

## 6b. Wifi picker (optional but bundled)

The `network` module points `on-click` at `~/.local/bin/rofi-wifi-menu` (installed in step 3). Also bind `Super+N` — the hypr snippet in step 7 does this.

- Left-click on the network module → rofi popup with nearby SSIDs, click to connect.
- Right-click → falls back to `nmtui` in kitty (for VPN, wired, or edge cases the rofi picker doesn't cover).

## 7. Wire Hyprland

In `~/.config/hypr/hyprland.conf`:

```conf
source = ~/.config/claude-waybar/hypr/keybinds.conf
```

Then `hyprctl reload`.

## 8. Try it

```bash
cd ~/some-project
claude-waybar-session            # opens a tmux-hosted Claude in this project
```

Ask Claude to run a Bash command it doesn't have pre-approved. The waybar module should light up. Left-click on the module → prompt approved from the bar.

## Uninstall

```bash
rm ~/.local/bin/claude-waybar-*
# Remove the hook block from ~/.claude/settings.json
# Remove the source line from ~/.tmux.conf and ~/.config/hypr/hyprland.conf
# Remove custom/claude from waybar config, killall -SIGUSR2 waybar
rm -rf ~/.config/claude-waybar
rm -rf ~/.local/state/claude-waybar
```
