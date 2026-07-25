# Waybar snippet for the claude-waybar module + wifi picker.
#
# Consumed by your waybar theme (a Nix file):
#
#   { pkgs, inputs, ... }:
#   let cw = inputs.claude-waybar.lib.waybarSnippet;
#   in {
#     programs.waybar.settings = [
#       ({
#         layer = "top";
#         modules-right = [ "custom/claude" "custom/swaync" "network" ... ];
#         # ... your other module configs ...
#       } // cw.modules)
#     ];
#     programs.waybar.style = ''
#       /* ... your existing CSS ... */
#       ${cw.style}
#     '';
#   }
#
# Bare command names ("claude-waybar-pending", "rofi-wifi-menu") resolve via PATH
# because the claude-waybar home-manager module installs them as writeShellScriptBins.
{
  modules = {
    "custom/claude" = {
      exec = "claude-waybar-pending";
      interval = 5;
      signal = 8;
      return-type = "json";
      format = "{}";
      tooltip = true;
      on-click = "claude-waybar-accept accept";
      on-click-right = "claude-waybar-accept reject";
      on-click-middle = "claude-waybar-accept focus";
    };

    network = {
      interval = 5;
      format-wifi = "󰖩  {essid} ({signalStrength}%)";
      format-ethernet = "󰈀  {ifname}";
      format-linked = "󰈀  {ifname} (no IP)";
      format-disconnected = "󰖪  offline";
      format-disabled = "󰖪  wifi off";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}\ngateway: {gwaddr}";
      tooltip-format-wifi = "{essid} — {signalStrength}%\n{ifname}: {ipaddr}\ngateway: {gwaddr}\nfreq: {frequency} MHz";
      tooltip-format-disconnected = "click to pick a network";
      on-click = "rofi-wifi-menu";
      on-click-right = "kitty --title 'nmtui' -e nmtui";
    };
  };

  style = ''
    /* -------- claude-waybar -------- */
    #custom-claude {
      padding: 1px 10px;
      color: rgba(255, 255, 255, 0.85);
      background: rgba(255, 255, 255, 0.05);
      border-radius: 7px;
      transition: background 200ms ease, color 200ms ease;
    }
    #custom-claude.idle {
      padding: 0;
      min-width: 0;
      color: transparent;
      background: transparent;
    }
    #custom-claude.pending {
      color: #ffb86c;
      background: rgba(255, 184, 108, 0.18);
      animation: claude-pulse 1.6s ease-in-out infinite;
    }
    @keyframes claude-pulse {
      0% {
        background: rgba(255, 184, 108, 0.18);
      }
      50% {
        background: rgba(255, 184, 108, 0.42);
      }
      100% {
        background: rgba(255, 184, 108, 0.18);
      }
    }
    #network.disconnected,
    #network.disabled {
      color: #f2564b;
    }
    #network.linked {
      color: #ffd166;
    }
  '';
}
