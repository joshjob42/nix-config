# kanata keyboard remapping (Linux port of the macOS layout).
# kanata (system service) grabs the internal keyboard via evdev and presents a
# remapped virtual keyboard via uinput. The layout is in ./kanata.kbd.
#
# Greek/Math symbols: kanata's unicode action is a no-op on Wayland, and a wtype
# spawned *by* kanata (mid-keypress, with the keyboard grabbed) doesn't land in
# COSMIC -- yet wtype run standalone in the session works fine. So the symbol
# layers use `(cmd kanata-emit X)` to drop the character into a per-user FIFO,
# and a `systemd --user` service in the COSMIC session (kanata-typer) reads it
# and runs wtype there. kanata returns instantly; the typing happens in-session.
{ pkgs, lib, ... }:
let
  # Drop the character into the user's FIFO and return immediately. (When logged
  # out, /run/user/1000 doesn't exist, so this just fails fast -- never blocks.)
  kanataEmit = pkgs.writeShellScriptBin "kanata-emit" ''
    printf '%s\n' "$1" > /run/user/1000/kanata-type.fifo 2>/dev/null || true
  '';
in
{
  services.kanata = {
    enable = true;
    package = pkgs.kanata-with-cmd; # `cmd` action (for kanata-emit); nixpkgs kanata lacks it
    keyboards.internal = {
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      extraDefCfg = "process-unmapped-keys yes concurrent-tap-hold yes danger-enable-cmd yes";
      config = builtins.readFile ./kanata.kbd;
    };
  };

  # Run kanata as root so kanata-emit can write the login user's FIFO under
  # /run/user/1000, and relax the module's sandbox enough to spawn it + write
  # there. (No Wayland here -- the typing happens in the user service below.)
  systemd.services.kanata-internal.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    SystemCallFilter = lib.mkForce [ ];
    ProtectSystem = lib.mkForce false;
    ProtectHome = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
    RestrictNamespaces = lib.mkForce false;
    # The module clears all capabilities; give back just CAP_DAC_OVERRIDE so the
    # root service can write the login user's FIFO under /run/user/1000.
    CapabilityBoundingSet = lib.mkForce [ "CAP_DAC_OVERRIDE" ];
    AmbientCapabilities = lib.mkForce [ "CAP_DAC_OVERRIDE" ];
  };
  systemd.services.kanata-internal.path = [ kanataEmit ];

  # Greek/Math typing happens HERE -- inside the COSMIC session, where wtype
  # works. Reads characters kanata drops into the FIFO and types them.
  systemd.user.services.kanata-typer = {
    description = "Type kanata Greek/Math characters via wtype (in-session)";
    wantedBy = [ "default.target" ];
    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      LANG = "en_US.UTF-8";
    };
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "kanata-typer" ''
        fifo="$XDG_RUNTIME_DIR/kanata-type.fifo"
        ${pkgs.coreutils}/bin/rm -f "$fifo"
        ${pkgs.coreutils}/bin/mkfifo "$fifo"
        # World-writable so the kanata service (root, but stripped of
        # CAP_DAC_OVERRIDE by its sandbox) can write without owning the FIFO.
        # Owner-only read: only this typer consumes it.
        ${pkgs.coreutils}/bin/chmod 622 "$fifo"
        # Hold the FIFO open read-write so writers (kanata-emit) never block.
        exec 3<>"$fifo"
        while IFS= read -r ch <&3; do
          [ -n "$ch" ] && ${pkgs.wtype}/bin/wtype "$ch"
        done
      '';
      Restart = "always";
    };
  };
}
