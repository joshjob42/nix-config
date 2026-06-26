# PLACEHOLDER — regenerated during install by install-halo.sh
# (nixos-generate-config --no-filesystems). This hand-written stub lets the flake
# evaluate before the machine exists; the real file will overwrite it and carry
# the AMD/USB4 modules this box actually probes.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # USB4/Thunderbolt + NVMe must be available in initrd so the eGPU bus and the
  # root disk come up early. (nixos-generate-config will confirm/extend these.)
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
