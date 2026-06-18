# kanata keyboard remapping (Linux port of the macOS layout).
# Runs kanata as a systemd service that grabs the internal keyboard via evdev
# and presents a remapped virtual keyboard via uinput (the module enables
# hardware.uinput automatically). The layout itself is in ./kanata.kbd.
{ ... }:
{
  services.kanata = {
    enable = true;
    keyboards.internal = {
      # Stable by-path handle for the internal AT keyboard (event0).
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      # defchordsv2 (Copilot key) requires concurrent-tap-hold; process all keys
      # so unmapped keys still pass through.
      extraDefCfg = "process-unmapped-keys yes concurrent-tap-hold yes";
      config = builtins.readFile ./kanata.kbd;
    };
  };
}
