# Home-manager config for joshjob42, ported from the macOS (nix-darwin) dotfiles.
# First cut: portable CLI tooling + shell/git/jj identity. The big GUI config
# drop-ins (nvim/kitty/zellij/etc.) are a deliberate follow-up step.
{ config, pkgs, lib, ... }:
{
  imports = [ ./gui.nix ]; # GUI/desktop dotfiles (kitty, nvim, zellij, btop, ncspot)

  home.stateVersion = "26.05";

  # --- Portable CLI packages (module-managed tools live under programs.* below) ---
  home.packages = with pkgs; [
    ripgrep fd jq lazygit
    duf tree dust procs broot
    tmux yt-dlp epr mosh # ncspot now managed via programs.ncspot in gui.nix
    neovim
    git-lfs shellcheck wget pandoc typst poppler w3m sox rclone monolith qrencode htop
    kanata
    go rustup zig uv
    cmake ninja gnumake
    texlive.combined.scheme-medium
  ];

  # --- PATH additions (portable subset; brew/Applications paths dropped) ---
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.bun/bin"
  ];

  # --- Non-secret env exports (real keys come from ~/.config/secrets.env) ---
  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
    LETTA_BASE_URL = "http://localhost:8283";
    ENABLE_LSP_TOOL = "1";
  };

  # --- Shell ---
  programs.fish = {
    enable = true;
    shellAliases = {
      # was `drs` (darwin-rebuild) — now rebuilds this NixOS host from the flake
      nrs = "sudo nixos-rebuild switch --flake ~/nix-config#geekbook14";
    };
    interactiveShellInit = ''
      # Fix delete key
      bind \177 backward-delete-char

      # Load secrets if present (KEY=value, one per line) — same contract as macOS
      if test -f $HOME/.config/secrets.env
        while read -l line
          string match -qr '^\s*#' -- $line; and continue
          test -z "$line"; and continue
          set -gx (string split -m1 '=' -- $line)
        end < $HOME/.config/secrets.env
      end
    '';
  };

  # --- Git ---
  programs.git = {
    enable = true;
    settings = {
      user.name = "Joshua Job";
      user.email = "joshjob42@gmail.com";
      init.defaultBranch = "main";
    };
    ignores = [ "**/.claude/settings.local.json" ];
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # --- Jujutsu ---
  programs.jujutsu = {
    enable = true;
    settings.user = {
      name = "Joshua Job";
      email = "joshjob42@gmail.com";
    };
  };

  # --- GitHub CLI ---
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
  };

  # --- Shell tooling (modules provide binary + fish integration) ---
  programs.starship.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.tealdeer.enable = true;
  programs.btop.enable = true;
  programs.zellij.enable = true; # raw KDL config ported later; no shell auto-start

  programs.home-manager.enable = true;
}
