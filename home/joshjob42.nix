# Minimal base home for joshjob42 (public bootstrap): shell + git/jj/gh identity,
# enough to authenticate and clone the private config. The full tool set, GUI
# dotfiles, and secrets workflow live in nix-config-private/home/full.nix, which
# is layered on top of this.
{ config, pkgs, lib, ... }:
{
  home.stateVersion = "26.05";

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Fix delete key
      bind \177 backward-delete-char

      # Load secrets if present (KEY=value, one per line). The file is rendered
      # by the private config's `secrets-render`; harmless if absent.
      if test -f $HOME/.config/secrets.env
        while read -l line
          string match -qr '^\s*#' -- $line; and continue
          test -z "$line"; and continue
          set -gx (string split -m1 '=' -- $line)
        end < $HOME/.config/secrets.env
      end
    '';
  };

  # Git / Jujutsu / GitHub identity (needed to authenticate + clone the private repo).
  programs.git = {
    enable = true;
    settings = {
      user.name = "Joshua Job";
      user.email = "joshjob42@gmail.com";
      init.defaultBranch = "main";
    };
    ignores = [ "**/.claude/settings.local.json" ];
  };
  programs.jujutsu = {
    enable = true;
    settings.user = {
      name = "Joshua Job";
      email = "joshjob42@gmail.com";
    };
  };
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
  };

  programs.home-manager.enable = true;
}
