# geekbook14 — declarative NixOS

NixOS for a Geekbook 14 (Intel Meteor Lake / Arc graphics), **dual-booting Windows**.
Reproducible from this flake; pinned via `flake.lock`.

## Layout

| File | Role |
|------|------|
| `flake.nix` | Inputs (nixpkgs 26.05, disko, home-manager) + the `geekbook14` system |
| `hosts/geekbook14/configuration.nix` | System: COSMIC desktop, dual-boot GRUB, power mgmt, user |
| `hosts/geekbook14/disko.nix` | **Leashed** disk layout — only touches `p6`/`p7`; Windows partitions are never named |
| `hosts/geekbook14/hardware-configuration.nix` | Placeholder — regenerate during install |
| `home/joshjob42.nix` | home-manager: fish, git/jj identity, portable CLI tooling |

Validate any time without installing:
```
nix flake lock
nix eval .#nixosConfigurations.geekbook14.config.system.build.toplevel.drvPath
```

## Install (from a NixOS 26.05 live USB)

### ⚠️ Before you boot the installer
1. **Secure Boot + BitLocker.** The stock NixOS kernel isn't signed, so you'll likely
   disable Secure Boot in BIOS to boot it. If Windows has **BitLocker / device
   encryption** on (common on Win11 laptops), changing Secure Boot can trigger a
   **BitLocker recovery prompt** at the next Windows boot. So FIRST, in Windows:
   either suspend BitLocker (`manage-bde -protectors -disable C:`) **or** save your
   recovery key (account.microsoft.com/devices/recoverykey). Then disable Secure Boot.
   (Later we can re-enable Secure Boot properly via `lanzaboote`.)
2. **Make this repo reachable from the installer** — push it to GitHub, or copy the
   folder onto the USB stick.

### In the live environment
```sh
# 1. Network (skip if on ethernet)
nmtui

# 2. Get this repo (git clone your GitHub copy, or cp from the USB)
cd /tmp && git clone <your-nix-config-url> nix-config && cd nix-config

# 3. Partition + format ONLY p6 (root) and p7 (/boot). Windows is untouched.
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#geekbook14

# 4. Capture the REAL hardware profile (filesystems come from disko, so skip them)
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > hosts/geekbook14/hardware-configuration.nix

# 5. Install (prompts for the root password)
sudo nixos-install --flake .#geekbook14

# 6. Set your user password before rebooting
sudo nixos-enter --root /mnt -c 'passwd joshjob42'

# 7. Reboot, pull the USB
reboot
```

### First boot
- GRUB shows **NixOS** and **Windows** (os-prober). Pick NixOS → log in via cosmic-greeter.
- After editing this config: `nrs`  (= `sudo nixos-rebuild switch --flake ~/nix-config#geekbook14`).

## Follow-ups (after first successful boot)
- [ ] **CachyOS kernel** via `chaotic-nyx` — uncomment the input in `flake.nix`, add its
      module, set `boot.kernelPackages = pkgs.linuxPackages_cachyos;`.
- [ ] **GUI dotfiles** — port nvim (LazyVim), kitty, zellij, btop, ncspot drop-ins into `home/`.
- [ ] **Secrets** — `sops-nix` or `op inject` to populate `~/.config/secrets.env`.
- [ ] **Push** this repo to GitHub (`joshjob42/nix-config`).
- [ ] (optional) **Secure Boot** via `lanzaboote`.
