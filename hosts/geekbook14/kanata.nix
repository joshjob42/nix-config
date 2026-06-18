# kanata keyboard remapping (Linux port of the macOS layout).
# Runs kanata as a systemd service that grabs the internal keyboard via evdev
# and presents a remapped virtual keyboard via uinput (the module enables
# hardware.uinput automatically). The layout itself is in ./kanata.kbd.
{ pkgs, lib, ... }:
{
  services.kanata = {
    enable = true;
    # cmd-enabled build: the Greek/Math layers shell out to `wtype` (kanata's
    # own unicode action doesn't work on Wayland/COSMIC).
    package = pkgs.kanata-with-cmd;
    keyboards.internal = {
      # Stable by-path handle for the internal AT keyboard (event0).
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      # defchordsv2 (Copilot key) needs concurrent-tap-hold; danger-enable-cmd
      # allows the (cmd wtype ...) actions; process unmapped keys so the rest
      # passes through.
      extraDefCfg = "process-unmapped-keys yes concurrent-tap-hold yes danger-enable-cmd yes";
      config = builtins.readFile ./kanata.kbd;
    };
  };

  # The kanata module runs the service as a sandboxed DynamicUser, which can't
  # reach the login user's Wayland socket (/run/user/1000, mode 0700) -- so the
  # Greek/Math (cmd wtype ...) actions can't type into COSMIC. Run as root (which
  # *can* access it) and point it at the user's session. Also put wtype on PATH.
  # (Trade-off: kanata-as-root sees all input with full privilege. Acceptable on
  # a single-user laptop; the alternative is running it as joshjob42 with the
  # input/uinput groups.)
  systemd.services.kanata-internal = {
    path = [ pkgs.wtype ];
    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      # Relax the module's sandbox so the spawned `wtype` (Greek/Math) can run.
      # SystemCallFilter is an allowlist of kanata's OWN syscalls -- wtype calls
      # others and gets SIGSYS-killed silently; the namespace/home/net limits
      # also block its Wayland access. (Moot now that kanata runs as root.)
      SystemCallFilter = lib.mkForce [ ];
      RestrictNamespaces = lib.mkForce false;
      RestrictAddressFamilies = lib.mkForce [ ];
      PrivateNetwork = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      IPAddressDeny = lib.mkForce "";
    };
  };
}
