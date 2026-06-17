# System configuration for geekbook14.
# Minimal, robust first cut: base NixOS + niri (Wayland) desktop + the user.
# The CachyOS kernel (chaotic-nyx) is intentionally NOT here yet — we add it
# after the first successful boot.
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # --- Boot / dual-boot with Windows -----------------------------------------
  # GRUB on the NixOS ESP (p7). useOSProber scans the other partitions and
  # adds a "Windows" entry automatically. ntfs support lets os-prober mount it.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.supportedFilesystems = [ "ntfs" "btrfs" ];

  # --- Nix / flakes ----------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  # A trusted user can use binary caches a flake requests (its `nixConfig`
  # extra-substituters) WITHOUT the interactive y/N prompt. cache.nixos.org is
  # always trusted. When we add the CachyOS kernel later, the chaotic-nyx NixOS
  # module wires up its own signed cache automatically — so no prompt, and the
  # kernel is fetched prebuilt instead of compiled.
  nix.settings.trusted-users = [ "root" "joshjob42" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # --- Networking ------------------------------------------------------------
  networking.hostName = "geekbook14";
  networking.networkmanager.enable = true;

  # --- Locale / time ---------------------------------------------------------
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Hardware: Intel Meteor Lake + Arc graphics ----------------------------
  hardware.cpu.intel.updateMicrocode = true;
  # REQUIRED on Meteor Lake: ships the i915 GuC/HuC/DMC firmware. Without it the
  # Arc GPU fails to initialize and the console wedges right as the desktop
  # starts (the exact "boots then hangs" failure the README warns about). Also
  # provides the MT7922 Wi-Fi/Bluetooth firmware. The installed kernel loads the
  # zstd-compressed blobs fine (unlike the minimal kexec installer image).
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # VAAPI on Arc / Xe
    ];
  };

  # --- Desktop: COSMIC (Wayland) ---------------------------------------------
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # --- Power management (laptop) ---------------------------------------------
  services.power-profiles-daemon.enable = true; # COSMIC's power panel hooks into this
  services.thermald.enable = true; # Intel thermal daemon (Meteor Lake)
  zramSwap.enable = true; # compressed RAM swap

  # --- Audio: PipeWire -------------------------------------------------------
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # --- Shell -----------------------------------------------------------------
  programs.fish.enable = true;

  # --- User ------------------------------------------------------------------
  # Note: set a login password during install with `passwd joshjob42`
  # (we can make this fully declarative later via a hashed secret).
  users.users.joshjob42 = {
    isNormalUser = true;
    description = "Josh";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.fish;
  };

  # --- Minimal system packages (most tooling lives in home.nix) --------------
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    pciutils
  ];

  system.stateVersion = "26.05";
}
