# Declarative disk layout — LEASHED for dual-boot.
#
# This targets ONLY the two former CachyOS partitions, addressed by stable
# by-id path. The whole-disk GPT is never rewritten, so the Windows
# partitions (p1 ESP, p2 MSR, p3 Windows, p5 Recovery) are physically
# never named here and cannot be touched by disko.
#
#   part6 -> NixOS btrfs root   (was CachyOS /)
#   part7 -> NixOS ESP /boot    (was CachyOS /boot; Windows has its OWN ESP at p1)
{
  disko.devices = {
    disk = {
      esp = {
        type = "disk";
        device = "/dev/disk/by-partuuid/1814dcf3-2e06-4b66-883d-f3c0b8e56c31"; # nvme0n1p7
        content = {
          # Treat this partition as a single filesystem (no partition table
          # is created here — disko just runs mkfs.vfat on this one partition).
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };

      root = {
        type = "disk";
        device = "/dev/disk/by-partuuid/d35b7008-1be4-43e0-a165-67683ecac70d"; # nvme0n1p6
        content = {
          type = "btrfs";
          extraArgs = [ "-f" "-L" "nixos" ];
          subvolumes = {
            "@" = {
              mountpoint = "/";
              mountOptions = [ "compress=zstd" "noatime" ];
            };
            "@home" = {
              mountpoint = "/home";
              mountOptions = [ "compress=zstd" "noatime" ];
            };
            "@nix" = {
              mountpoint = "/nix";
              mountOptions = [ "compress=zstd" "noatime" ];
            };
          };
        };
      };
    };
  };
}
