# Declarative disk layout — LEASHED for dual-boot, same safety property as
# geekbook14: this targets ONLY the two NixOS partitions you create in the space
# freed by shrinking Windows, addressed by stable by-partuuid path. The whole-disk
# GPT is never rewritten, so the preinstalled Windows partitions (its ESP, MSR,
# Windows, Recovery) are physically never named here and cannot be touched.
#
#   espPart  -> NixOS ESP /boot (vfat)   — Windows keeps its OWN separate ESP
#   rootPart -> NixOS btrfs root         — subvols @ / @home / @nix
#
# !!! PLACEHOLDERS !!! Fill in the two PARTUUIDs after you create the partitions
# on the EVO X2 (see install-halo.sh — it prints them and refuses to run until
# the by-partuuid symlinks resolve to the partitions you expect).
{
  disko.devices = {
    disk = {
      esp = {
        type = "disk";
        device = "/dev/disk/by-partuuid/c0ffee00-0000-4000-a000-000000000001";
        content = {
          # Single existing partition — disko just runs mkfs.vfat on it; it does
          # NOT create a partition table here, so the GPT stays intact.
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };

      root = {
        type = "disk";
        device = "/dev/disk/by-partuuid/c0ffee00-0000-4000-a000-000000000002";
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
