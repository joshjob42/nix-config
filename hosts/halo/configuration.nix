# System configuration for `halo` — GMKTec EVO X2 (Strix Halo: Ryzen AI Max+
# 395, Zen5 + Radeon 8060S iGPU / RDNA3.5 / gfx1151, 128 GB unified) with an
# external RX 9070 XT (RDNA4 / Navi48 / gfx1201) over USB4, dual-booting Windows.
#
# Mirrors geekbook14's base (COSMIC + 1Password + lanzaboote + the user), with
# the Intel/Meteor-Lake bits swapped for AMD/amdgpu + USB4(Thunderbolt) eGPU.
# Laptop-only concerns (battery/power tuning, kanata, brightness keys, fingerprint,
# narcolepsyd) are NOT here — they live in the private flake and aren't imported
# for this host.
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # --- Boot / Secure Boot (lanzaboote) ---------------------------------------
  # Identical stack to geekbook14: lanzaboote installs a signed systemd-boot and
  # signs every generation from keys in pkiBundle (/var/lib/sbctl). systemd-boot
  # is declared then forced off so lanzaboote takes its slot.
  #
  # Windows lives on its OWN ESP (its preinstalled p1); this systemd-boot only
  # scans the ESP it manages, so Windows is intentionally NOT in this menu —
  # boot it from the firmware boot-menu key ("Windows Boot Manager").
  #
  # FIRST-INSTALL NOTE: lanzaboote's bootloader install needs the sbctl keys to
  # already exist. install-halo.sh runs `sbctl create-keys` and seeds them into
  # the target before nixos-install. After first boot, enroll in firmware with
  # Secure Boot = Custom mode (see README's enrollment procedure).
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = 10;
  # A 3 s window (vs geekbook14's 1 s): this box is usually driven over the Comet
  # KVM, where a beat to catch the menu / nomodeset-rescue entry is worth it.
  boot.loader.timeout = 3;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.supportedFilesystems = [ "ntfs" "btrfs" ];

  # Latest packaged kernel (7.0.x). REQUIRED here: Strix Halo (Zen5 + RDNA3.5
  # iGPU) and the RX 9070 XT (RDNA4 / Navi48) both want a recent amdgpu; mainline
  # gained solid Navi48 + Strix Halo support across 6.13–6.15, and 7.0 is well
  # past that. Once 26.05's default kernel is >= 7.0 this line can be dropped.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bring amdgpu up in initrd so the iGPU console (and thus the Comet KVM picture)
  # lights up early, before the desktop starts.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Rescue path mirrored from geekbook14: if a future kernel regresses display
  # (eGPU enumeration or iGPU KMS), pick "nomodeset-rescue" at the boot menu for a
  # software-rendered desktop, then inspect `journalctl -b -1 -k | grep -i amdgpu`.
  specialisation.nomodeset-rescue.configuration = {
    boot.kernelParams = [ "nomodeset" ];
  };

  # Strix Halo big-model knob (Phase 5, left commented until needed): the iGPU can
  # use system RAM as GTT for large LLMs. Recent amdgpu auto-sizes GTT generously,
  # but if a model is refused for VRAM/GTT, raise the TTM page limit, e.g.:
  #   boot.kernelParams = [ "ttm.pages_limit=27648000" "ttm.page_pool_size=27648000" ];
  # (27648000 pages * 4 KiB ≈ 105 GiB.) Verify with `amdgpu_top` / dmesg afterwards.

  nixpkgs.config.allowUnfree = true;

  # --- Nix / flakes (same as base) -------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.trusted-users = [ "root" "joshjob42" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # --- Networking ------------------------------------------------------------
  networking.hostName = "halo";
  networking.networkmanager.enable = true;

  # --- Locale / time ---------------------------------------------------------
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Hardware: AMD Strix Halo + amdgpu (iGPU) + RX 9070 XT eGPU -------------
  hardware.cpu.amd.updateMicrocode = true;
  # Ships amdgpu firmware for both GPUs (and the Wi-Fi/BT radio).
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / 32-bit games on the 9070 XT (RADV is the default Vulkan driver)
    # ROCm/OpenCL compute (Phase 5) can be added here once we settle the stack,
    # e.g. extraPackages = [ pkgs.rocmPackages.clr.icd ]; for now llama.cpp's
    # Vulkan backend on the iGPU needs nothing beyond mesa.
  };

  # USB4 / Thunderbolt device authorization for the eGPU enclosure. boltd manages
  # the security handshake; authorize the enclosure once with:
  #   boltctl list                       # find the eGPU's UUID
  #   sudo boltctl enroll --policy auto <uuid>
  # so it auto-authorizes on every boot. (BIOS: enable Above 4G Decoding +
  # Resizable BAR, and set USB4/Thunderbolt security to a level boltd can handle.)
  services.hardware.bolt.enable = true;

  # --- Desktop: COSMIC (Wayland) ---------------------------------------------
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # --- 1Password (same as base) ----------------------------------------------
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "joshjob42" ];
  };

  # --- Power: desktop, not laptop --------------------------------------------
  # COSMIC's power panel still hooks power-profiles-daemon; keep it. No thermald
  # (Intel-only), no battery/TLP tuning, no zram (128 GB RAM makes it pointless).
  services.power-profiles-daemon.enable = true;

  # --- Audio: PipeWire (same as base) ----------------------------------------
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # --- Shell -----------------------------------------------------------------
  programs.fish.enable = true;

  # --- User ------------------------------------------------------------------
  # Set a login password during install with `passwd joshjob42`.
  users.users.joshjob42 = {
    isNormalUser = true;
    description = "Josh";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "render" ];
    shell = pkgs.fish;
  };

  # --- Minimal system packages (most tooling lives in home.nix) --------------
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    pciutils # lspci — confirm both GPUs enumerate
    usbutils # lsusb — USB4 topology
    bolt # boltctl — authorize the eGPU enclosure
    sbctl # Secure Boot key management (lanzaboote)
  ];

  system.stateVersion = "26.05";
}
