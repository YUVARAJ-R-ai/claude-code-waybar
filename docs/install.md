# Install (Nix flake — home-manager)

The reproducible path. `claude-code-waybar` is a home-manager flake, so everything (scripts, hooks, tmux config, hyprland binds, waybar wiring) is installed declaratively. Updates flow via `nix flake update`.

## 1. Add the input to your flake

```nix
# flake.nix
inputs.claude-waybar = {
  url = "github:YUVARAJ-R-ai/claude-code-waybar";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

If your flake doesn't already pass `inputs` down to home-manager, ensure it does — e.g. via `home-manager.extraSpecialArgs = { inherit inputs; }` in your nixosSystem, or by referencing `inputs.claude-waybar` from a NixOS module whose `specialArgs` already include `inputs` (the ZaneyOS default).

## 2. Import the module in your home-manager config

```nix
# somewhere inside home-manager.users.<you> = { ... }: { ... }
imports = [ inputs.claude-waybar.homeManagerModules.default ];

programs.claudeWaybar = {
  enable = true;
  wifi.enable = true;             # rofi-based wifi picker (default: true)
  registerClaudeHooks = true;     # deep-merge Notification/Stop hooks into ~/.claude/settings.json (default: true)
};
```

That gets you:
- `claude-waybar-session`, `claude-waybar-pending`, `claude-waybar-accept`, `claude-waybar-clip-img`, `rofi-wifi-menu` all on PATH
- `tmux` configured with `allow-passthrough on` (image paste survives tmux) + 50k scrollback
- Hyprland keybinds (`Super+C`, `Super+N`, `Super+Shift+A/X`, `Super+Ctrl+F`, `Super+Shift+V/P`)
- Claude Code hooks registered non-destructively (jq deep-merge preserves your other settings.json keys)

## 3. Wire the waybar module into your theme

The module handles everything **except** waybar rendering — because your waybar theme is opinionated (module order, styling), we don't want to fight it. Add three lines to your theme file:

```nix
# your-waybar-theme.nix
{ pkgs, inputs, ... }:
let cw = inputs.claude-waybar.lib.waybarSnippet;
in {
  programs.waybar.settings = [
    ({
      layer = "top";
      # ... your existing settings ...
      modules-right = [
        "custom/claude"    # NEW — add wherever you want it in the bar
        "network"          # NEW — same
        # ... your existing modules-right ...
      ];
      # ... your existing module configs ...
    } // cw.modules)   # ← merges "custom/claude" + "network" module definitions
  ];

  programs.waybar.style = ''
    /* ... your existing CSS ... */
    ${cw.style}          # ← appends claude-waybar + network styling
  '';
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#<host>
# or, if you use nh:
nh os switch
```

Reload waybar and hyprland to pick up the new config immediately:

```bash
killall -SIGUSR2 waybar
hyprctl reload
```

## 4. Try it

```bash
cd ~/some-project
claude-waybar-session       # spawns tmux session claude-<project> with `claude` inside
```

Ask Claude to run an un-preapproved shell command. Your waybar module lights up as `⏸ 1` within a second — left-click to accept, right-click to reject, middle-click to focus the terminal.

## Updates

```bash
nix flake update claude-waybar
nh os switch
```

## Uninstall

Flip the enable flag off:

```nix
programs.claudeWaybar.enable = false;
```

Then `nh os switch`. All packages, xdg files, tmux/hyprland extraConfig, and the ~/.claude/settings.json hook block get cleanly removed (the last requires re-running `nh os switch` once after disabling — HM's activation script rewrites settings.json without our hooks). Remove the waybar snippet paste from your theme manually.

## Requirements the module doesn't install for you

- **kitty** (or another terminal that speaks the kitty graphics protocol) — for image paste inside Claude Code.
- **grim + slurp** — for `Super+Shift+P` region-screenshot binding.
- **`claude`** binary on PATH — Claude Code itself.
- **Hyprland + waybar** — obviously.
- **NetworkManager** — if you use the wifi picker.

Most of these are already present on any Hyprland Wayland setup.

## Keybind cheat sheet

| Binding | Action |
| --- | --- |
| `Super + C` | Launch/attach Claude session in `$PWD` |
| `Super + N` | Wifi picker (rofi) |
| `Super + Shift + V` | Clipboard image → path (for pasting to Claude) |
| `Super + Shift + P` | Region screenshot → path |
| `Super + Shift + A` | Accept oldest pending prompt |
| `Super + Shift + X` | Reject oldest pending prompt |
| `Super + Ctrl + F` | Focus terminal of oldest pending session |
