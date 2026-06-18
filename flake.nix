{
  description = "geekbook14 — declarative NixOS (dual-boot alongside Windows)";

  # Make the Claude Code flake's binary cache available at build time (so
  # `nixos-rebuild` fetches claude-code prebuilt instead of building it). Honored
  # for trusted users (root/joshjob42); also persisted in nix.settings.
  nixConfig = {
    extra-substituters = [ "https://claude-code.cachix.org" ];
    extra-trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Used only to build a Wi-Fi-capable kexec installer (see packages.kexec-wifi).
    # We import only its module and evaluate it under our own nixpkgs, so it has
    # no nixpkgs input of its own to pin here.
    nixos-images.url = "github:nix-community/nixos-images";

    # Helium browser (ungoogled-chromium fork). Not in nixpkgs -- upstream ships
    # only .deb releases, so this community flake builds it from the official
    # .deb (patchelf, no compile). Provides a NixOS module: programs.helium.
    helium-flake.url = "github:oxcl/nix-flake-helium-browser";
    helium-flake.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot for NixOS. Installs a signed systemd-boot and signs every
    # generation with our own enrolled keys (see boot.lanzaboote).
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # Claude Code CLI — tracked closely upstream (newer than nixpkgs') with its
    # own cachix. Intentionally does NOT follow nixpkgs (keeps binary-cache
    # hits). Its overlay provides pkgs.claude-code.
    claude-code.url = "github:sadjow/claude-code-nix";

    # CachyOS kernel + optimized binary cache for NixOS.
    # Wired up but NOT enabled yet — we turn this on AFTER the first boot.
    # chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

  outputs = { self, nixpkgs, disko, home-manager, nixos-images, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.geekbook14 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          inputs.helium-flake.nixosModules.default
          inputs.lanzaboote.nixosModules.lanzaboote
          ./hosts/geekbook14/configuration.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.joshjob42 = import ./home/joshjob42.nix;
          }
        ];
      };

      # Wi-Fi-capable kexec installer for the no-USB install on a Wi-Fi-only laptop.
      # The stock nixos-images kexec installer ships no Wi-Fi tools; this adds iwd
      # (iwctl) and lets iwd handle DHCP after you connect.
      #   nix build .#kexec-wifi
      packages.${system}.kexec-wifi =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            nixos-images.nixosModules.kexec-installer
            ({ pkgs, lib, ... }: {
              # iwd handles Wi-Fi *association* (iwctl); the installer's existing
              # `99-wireless-client-dhcp` systemd-networkd rule does the DHCP.
              networking.wireless.iwd.enable = true;
              # Include ONLY the firmware THIS machine needs, not all of
              # linux-firmware (which bloats the kexec initrd to ~1GB and won't
              # load). `enableRedistributableFirmware` is silently overridden by
              # the installer, so force these blobs in via mkOverride:
              #   * i915/  — Intel Meteor Lake GPU (GuC/HuC/DMC). Without it the
              #     GPU wedges ("failed to initialize GPU") and the console breaks.
              #   * mediatek/ — MT7922 Wi-Fi + Bluetooth.
              # `passthru.compressFirmware = false` is essential (checked in nixos
              # udev.nix): without it the firmware ends up as `*.bin.zst`, and the
              # installer kernel can't load compressed firmware — it asks for
              # `mtl_guc_70.bin`, finds only `.zst`, fails -ENOENT, and the GPU wedges.
              # (compressFirmwareZstd also only works on the real linux-firmware pkg,
              # silently emptying a hand-rolled one.) So: ship these UNCOMPRESSED.
              hardware.firmware = lib.mkOverride 10 [
                (pkgs.runCommandLocal "geekbook14-firmware" { passthru.compressFirmware = false; } ''
                  mkdir -p $out/lib/firmware/mediatek
                  cp -r ${pkgs.linux-firmware}/lib/firmware/i915 $out/lib/firmware/
                  cp ${pkgs.linux-firmware}/lib/firmware/mediatek/WIFI_RAM_CODE_MT7922_1.bin $out/lib/firmware/mediatek/
                  cp ${pkgs.linux-firmware}/lib/firmware/mediatek/WIFI_MT7922_patch_mcu_1_1_hdr.bin $out/lib/firmware/mediatek/
                  cp ${pkgs.linux-firmware}/lib/firmware/mediatek/BT_RAM_CODE_MT7922_1_1_hdr.bin $out/lib/firmware/mediatek/
                '')
              ];
              # USB tethering as a rock-solid wired fallback (no ethernet port needed):
              #   ipheth = iPhone, rndis_host/cdc_* = Android. usbmuxd pairs the iPhone.
              # The installer's 99-ethernet-default-dhcp rule then DHCPs the interface.
              services.usbmuxd.enable = true;
              boot.kernelModules = [ "mt7921e" "ipheth" "rndis_host" "cdc_ether" "cdc_ncm" ];
              environment.systemPackages = with pkgs; [ iw iwd libimobiledevice ];
              system.stateVersion = "26.05";
            })
          ];
        }).config.system.build.kexecInstallerTarball;
    };
}
