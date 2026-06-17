{
  description = "geekbook14 — declarative NixOS (dual-boot alongside Windows)";

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
            ({ pkgs, ... }: {
              networking.wireless.iwd.enable = true;
              networking.wireless.iwd.settings.General.EnableNetworkConfiguration = true;
              environment.systemPackages = with pkgs; [ iw iwd ];
              system.stateVersion = "26.05";
            })
          ];
        }).config.system.build.kexecInstallerTarball;
    };
}
