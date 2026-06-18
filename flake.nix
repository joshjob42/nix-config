{
  description = "geekbook14 — public base (bootstrap) NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Used only to build a Wi-Fi-capable kexec installer (see packages.kexec-wifi).
    nixos-images.url = "github:nix-community/nixos-images";

    # Secure Boot for NixOS. Installs a signed systemd-boot and signs every
    # generation with our own enrolled keys (see boot.lanzaboote).
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, nixos-images, lanzaboote, ... }@inputs:
    let
      system = "x86_64-linux";
      # The base system + minimal home. Exposed as nixosModules.base so the
      # private full config (github:joshjob42/nix-config-private) can layer on
      # top; also built standalone below as the bootstrap install target.
      baseModules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote
        ./hosts/geekbook14/configuration.nix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.joshjob42 = import ./home/joshjob42.nix;
        }
      ];
    in
    {
      nixosModules.base = { imports = baseModules; };

      nixosConfigurations.geekbook14 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = baseModules;
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
              services.usbmuxd.enable = true;
              boot.kernelModules = [ "mt7921e" "ipheth" "rndis_host" "cdc_ether" "cdc_ncm" ];
              environment.systemPackages = with pkgs; [ iw iwd libimobiledevice ];
              system.stateVersion = "26.05";
            })
          ];
        }).config.system.build.kexecInstallerTarball;
    };
}
