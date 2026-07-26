{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.claudeWaybar;

  # ----- Script wrappers on PATH via home.packages -----
  # Each script is wrapped in a Nix-store derivation so:
  #   * bare `claude-waybar-*` resolves everywhere (waybar, hooks, hypr binds)
  #   * updates flow via `nix flake update claude-waybar` — no imperative symlinks
  claudeWaybarSession = pkgs.writeShellScriptBin "claude-waybar-session"
    (builtins.readFile ./scripts/claude-waybar-session);
  claudeWaybarPending = pkgs.writeShellScriptBin "claude-waybar-pending"
    (builtins.readFile ./scripts/claude-waybar-pending);
  claudeWaybarAccept = pkgs.writeShellScriptBin "claude-waybar-accept"
    (builtins.readFile ./scripts/claude-waybar-accept);
  claudeWaybarClipImg = pkgs.writeShellScriptBin "claude-waybar-clip-img"
    (builtins.readFile ./scripts/claude-waybar-clip-img);
  claudeWaybarPanel = pkgs.writeShellScriptBin "claude-waybar-panel"
    (builtins.readFile ./scripts/claude-waybar-panel);
  rofiWifiMenu = pkgs.writeShellScriptBin "rofi-wifi-menu"
    (builtins.readFile ./scripts/rofi-wifi-menu);
in {
  options.programs.claudeWaybar = {
    enable = lib.mkEnableOption "claude-waybar (waybar control panel for Claude Code)";

    wifi.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the rofi-based wifi picker (rofi-wifi-menu on PATH).";
    };

    registerClaudeHooks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Deep-merge Notification/Stop hooks into ~/.claude/settings.json on activation.
        Set false if you manage ~/.claude/settings.json elsewhere.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [
        claudeWaybarSession
        claudeWaybarPending
        claudeWaybarAccept
        claudeWaybarClipImg
        claudeWaybarPanel
        pkgs.tmux
        pkgs.libnotify
        pkgs.jq
        pkgs.wl-clipboard
        pkgs.rofi # used by claude-waybar-panel (session picker)
      ]
      ++ lib.optional cfg.wifi.enable rofiWifiMenu
      ++ lib.optionals cfg.wifi.enable [
        pkgs.networkmanager
        pkgs.networkmanagerapplet # provides nm-connection-editor for the ✏ menu entry
      ];

    # tmux is the host process for Claude Code sessions — hard dep.
    programs.tmux.enable = lib.mkDefault true;
    programs.tmux.extraConfig = builtins.readFile ./tmux/claude.conf;

    # Hyprland keybinds — appended to existing extraConfig by HM's module merge.
    wayland.windowManager.hyprland.extraConfig = builtins.readFile ./hypr/keybinds.conf;

    # Kitty: Shift+Enter should INSERT a newline in Claude Code's prompt.
    # By default kitty sends CR for both Enter and Shift+Enter, so Claude can't
    # distinguish them and both submit. This is exactly what Claude Code's own
    # /terminal-setup command writes into kitty.conf. Only applied if the user
    # actually uses home-manager's kitty module; otherwise the merge is a no-op.
    programs.kitty.extraConfig = lib.mkIf (config.programs.kitty.enable or false) ''

      # === claude-waybar: Shift+Enter → newline (instead of submit) ===
      map shift+enter send_text all \x1b\r
      map ctrl+enter  send_text all \x1b\r
    '';

    # Install hook scripts at stable ~/.config paths so settings.json never needs
    # updates when the flake's store path changes.
    xdg.configFile."claude-waybar/hooks/notification.sh" = {
      source = ./hooks/notification.sh;
      executable = true;
    };
    xdg.configFile."claude-waybar/hooks/stop.sh" = {
      source = ./hooks/stop.sh;
      executable = true;
    };

    # Deep-merge Notification/Stop hooks into ~/.claude/settings.json.
    # Non-destructive: preserves every other key in the JSON.
    home.activation.claudeWaybarSettings = lib.mkIf cfg.registerClaudeHooks (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        set -eu
        SETTINGS="$HOME/.claude/settings.json"
        mkdir -p "$(dirname "$SETTINGS")"
        [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
        NOTI="$HOME/.config/claude-waybar/hooks/notification.sh"
        STOP="$HOME/.config/claude-waybar/hooks/stop.sh"
        ${pkgs.jq}/bin/jq \
          --arg n "$NOTI" \
          --arg s "$STOP" \
          '.hooks = ((.hooks // {}) * {
            "Notification": [{"hooks":[{"type":"command","command":$n}]}],
            "Stop":         [{"hooks":[{"type":"command","command":$s}]}]
          })' \
          "$SETTINGS" > "$SETTINGS.tmp"
        mv "$SETTINGS.tmp" "$SETTINGS"
      ''
    );
  };
}
