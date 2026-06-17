# Placeholder hardware profile for geekbook14 (Intel Meteor Lake / Arc).
# IMPORTANT: during the real install, regenerate the authoritative version with
#   nixos-generate-config --no-filesystems --root /mnt
# and merge anything new it detects. Filesystems are intentionally omitted here
# because disko.nix declares them.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Filesystems are declared in disko.nix.

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
}
