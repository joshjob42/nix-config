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

  # --- Boot / Secure Boot (lanzaboote) ---------------------------------------
  # Secure Boot via lanzaboote: it installs a signed systemd-boot and signs every
  # generation with the keys in pkiBundle (/var/lib/sbctl, created once with
  # `sbctl create-keys`). GRUB is gone -- it can't be Secure-Booted on NixOS, so
  # we declare systemd-boot then force it off and let lanzaboote take its slot.
  #
  # Windows lives on its OWN ESP (p1); systemd-boot only scans the ESP it manages
  # (p7), so Windows is intentionally NOT in this menu. Boot it from the firmware
  # boot-menu key at power-on ("Windows Boot Manager"); its EFI entry is untouched.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = 10;
  # Boot straight into the default generation. The menu lists every kept
  # generation (up to configurationLimit) PLUS each one's specialisations, hence
  # the long list; this 1s window just hides it. Hold a key at power-on (or bump
  # this timeout) to reach the menu / nomodeset-rescue.
  boot.loader.timeout = 1;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.supportedFilesystems = [ "ntfs" "btrfs" ];

  # eDP panel (Meteor Lake): the stock 6.18.35 trained this panel only
  # intermittently under KMS ("failed to retrieve link info, disabling eDP" ->
  # black screen). Kernel 7.0.x (set below) fixes it on the i915 driver: KMS
  # comes up reliably with GPU acceleration at native 2880x1800.
  #
  # We use i915, NOT xe. On this Meteor Lake panel xe never drives the display:
  # it doesn't claim 8086:7d55 by default, and even xe.force_probe=7d55 failed
  # here -- both cases just fall back to the software framebuffer. i915 is also
  # the mature, upstream-default driver for this GPU generation.
  #
  # Rescue: if a future kernel regresses the panel to a black screen, boot the
  # "nomodeset-rescue" entry from GRUB for a working (software-rendered) desktop,
  # then `journalctl -b -1 -k | grep -iE 'edp|link|i915'` to see why.
  specialisation.nomodeset-rescue.configuration = {
    boot.kernelParams = [ "nomodeset" ];
  };

  # Run the latest packaged kernel (7.0.x). The stock 6.18.35 trained this Meteor
  # Lake eDP panel only intermittently under KMS; 7.0 carries the fix. Once
  # 26.05's default kernel advances to >= 7.0 this line can likely be dropped.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Allow unfree packages (1Password CLI + desktop app, and anything else later).
  # (home-manager shares this nixpkgs config via useGlobalPkgs.)
  nixpkgs.config.allowUnfree = true;

  # --- Nix / flakes ----------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  # Trusted users may use flake-requested binary caches without the y/N prompt
  # (the private config's claude-code cachix relies on this).
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

  # --- 1Password (secrets via `op inject`) -----------------------------------
  # CLI (op) + desktop app with CLI<->app integration, so `op` unlocks through
  # the app's system auth instead of a manual session token. Used to render
  # ~/.config/secrets.env from a template (see home config: `secrets-render`).
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "joshjob42" ];
  };

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
    sbctl # Secure Boot key management (create/enroll/verify; see boot.lanzaboote)
  ];

  system.stateVersion = "26.05";
}
