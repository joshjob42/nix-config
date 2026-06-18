# GUI / desktop dotfiles ported from the macOS dotfiles repo (joshjob42/dotfiles).
#
# Split (agreed approach):
#   * native programs.*  for simple key/value configs (btop, ncspot)
#   * raw files via xdg.configFile for configs that don't map to Nix attrs:
#       - nvim  (LazyVim; lazy.nvim manages plugins at runtime)
#       - zellij (KDL)
#   * hybrid for kitty: home-manager owns kitty + its kitty.conf (read from the
#     vendored file), with the Python kittens dropped in alongside it.
#
# Vendored source configs live in ./dotfiles/. macOS-only bits (karabiner,
# raycast, hammerspoon, the kanata launchd plist) are intentionally not ported.
{ config, pkgs, lib, ... }:
{
  # Fonts referenced by kitty (JetBrains Mono) and the prompt (Nerd Font glyphs).
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # --- kitty (hybrid) --------------------------------------------------------
  # home-manager installs kitty and generates ~/.config/kitty/kitty.conf from the
  # vendored config (read verbatim). The Python kittens / helper scripts that the
  # config references by path are dropped in next to it below.
  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile ./dotfiles/kitty/kitty.conf;
  };

  xdg.configFile = {
    # kitty kittens / helpers (referenced from kitty.conf via ~/.config/kitty/*)
    "kitty/onepassword_kitten.py".source = ./dotfiles/kitty/onepassword_kitten.py;
    "kitty/pass_keys.py".source = ./dotfiles/kitty/pass_keys.py;
    "kitty/get_layout.py".source = ./dotfiles/kitty/get_layout.py;
    "kitty/grab.conf".source = ./dotfiles/kitty/grab.conf;
    "kitty/kitty_grab".source = ./dotfiles/kitty/kitty_grab;
    "kitty/quick-access-terminal.conf".source = ./dotfiles/kitty/quick-access-terminal.conf;
    "kitty/tab-switcher.sh" = {
      source = ./dotfiles/kitty/tab-switcher.sh;
      executable = true;
    };

    # --- zellij (raw KDL) ---
    "zellij/config.kdl".source = ./dotfiles/zellij/config.kdl;

    # --- nvim (LazyVim) ---
    # Whole config dir is symlinked read-only into the store; lazy.nvim installs
    # plugins under ~/.local/share/nvim at runtime (needs network on first run).
    "nvim".source = ./dotfiles/nvim;
  };

  # --- btop (native) ---------------------------------------------------------
  # programs.btop.enable is set in joshjob42.nix; this supplies the settings,
  # translated 1:1 from the vendored btop.conf.
  programs.btop.settings = {
    color_theme = "Default";
    theme_background = true;
    truecolor = true;
    force_tty = false;
    presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
    vim_keys = false;
    rounded_corners = true;
    terminal_sync = true;
    graph_symbol = "braille";
    graph_symbol_cpu = "default";
    graph_symbol_mem = "default";
    graph_symbol_net = "default";
    graph_symbol_proc = "default";
    shown_boxes = "cpu mem net proc";
    update_ms = 2000;
    proc_sorting = "cpu direct";
    proc_reversed = false;
    proc_tree = false;
    proc_colors = true;
    proc_gradient = true;
    proc_per_core = false;
    proc_mem_bytes = true;
    proc_cpu_graphs = true;
    proc_info_smaps = false;
    proc_left = false;
    proc_filter_kernel = false;
    proc_aggregate = false;
    keep_dead_proc_usage = false;
    cpu_graph_upper = "Auto";
    cpu_graph_lower = "Auto";
    cpu_invert_lower = true;
    cpu_single_graph = false;
    cpu_bottom = false;
    show_uptime = true;
    show_cpu_watts = true;
    check_temp = true;
    cpu_sensor = "Auto";
    show_coretemp = true;
    cpu_core_map = "";
    temp_scale = "celsius";
    base_10_sizes = false;
    show_cpu_freq = true;
    clock_format = "%X";
    background_update = true;
    custom_cpu_name = "";
    disks_filter = "";
    mem_graphs = true;
    mem_below_net = false;
    zfs_arc_cached = true;
    show_swap = true;
    swap_disk = true;
    show_disks = true;
    only_physical = true;
    use_fstab = true;
    zfs_hide_datasets = false;
    disk_free_priv = false;
    show_io_stat = true;
    io_mode = false;
    io_graph_combined = false;
    io_graph_speeds = "";
    net_download = 100;
    net_upload = 100;
    net_auto = true;
    net_sync = true;
    net_iface = "";
    base_10_bitrate = "Auto";
    show_battery = true;
    selected_battery = "Auto";
    show_battery_watts = true;
    log_level = "WARNING";
    save_config_on_exit = true;
  };

  # --- ncspot (native) -------------------------------------------------------
  # Replaces the bare `ncspot` package entry in joshjob42.nix; this manages the
  # binary plus ~/.config/ncspot/config.toml (theme translated from the dotfile).
  programs.ncspot = {
    enable = true;
    settings.theme = {
      background = "#191414";
      primary = "#FFFFFF";
      secondary = "light black";
      title = "#1DB954";
      playing = "#1DB954";
      playing_selected = "#1ED760";
      playing_bg = "#191414";
      highlight = "#FFFFFF";
      highlight_bg = "#484848";
      error = "#FFFFFF";
      error_bg = "red";
      statusbar = "#191414";
      statusbar_progress = "#1DB954";
      statusbar_bg = "#1DB954";
      cmdline = "#FFFFFF";
      cmdline_bg = "#191414";
      search_match = "light red";
    };
  };
}
