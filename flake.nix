{
  description = "claude-code-waybar — waybar control panel for Claude Code on Hyprland (+ bonus rofi wifi picker)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    # Home-manager module — import in your HM config to get scripts on PATH,
    # tmux + hyprland wiring, and Claude Code hook registration.
    homeManagerModules.default = import ./module.nix;
    homeManagerModules.claudeWaybar = import ./module.nix;

    # Waybar snippet — pure data, system-independent. Import into your waybar theme:
    #   let cw = inputs.claude-waybar.lib.waybarSnippet; in ...
    lib.waybarSnippet = import ./lib/waybar-snippet.nix;
  };
}
