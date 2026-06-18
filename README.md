# geekbook14 — declarative NixOS

NixOS for a Geekbook 14 (Intel Meteor Lake / Arc graphics), **dual-booting Windows**,
installed **without a USB stick** via kexec. Reproducible from this flake; pinned by `flake.lock`.

## Layout

| File | Role |
|------|------|
| `flake.nix` | Inputs (nixpkgs 26.05, disko, home-manager) + the `geekbook14` system |
| `hosts/geekbook14/configuration.nix` | System: COSMIC desktop, dual-boot GRUB, power mgmt, user |
| `hosts/geekbook14/disko.nix` | **Leashed** disk layout — only `p6`/`p7` (by PARTUUID); Windows never named |
| `hosts/geekbook14/hardware-configuration.nix` | Placeholder — regenerated during install |
| `home/joshjob42.nix` | home-manager: fish, git/jj identity, portable CLI tooling |
| `install.sh` | Guarded one-shot installer (run inside the kexec installer) |

Validate without installing:
```
nix flake lock
nix eval .#nixosConfigurations.geekbook14.config.system.build.toplevel.drvPath
```

---

## Install — no USB, via kexec

> Secure Boot and BitLocker are already disabled on this machine, so there's no
> Windows-recovery risk. The only destructive step is `disko`, which formats just
> `p6` + `p7`. Windows lives on its own partitions and is never touched.

### A. From the running CachyOS (last steps before the jump)

> These are **bash** commands. CachyOS's default shell is **fish**, which doesn't
> understand `$(...)` — so the build line is wrapped in `bash -c '…'`.
>
> We use this repo's **`kexec-wifi`** image, which adds `iwd`/`iwctl` — the stock
> nixos-images kexec installer has **no Wi-Fi tools**, a dead end on a Wi-Fi-only laptop.

```sh
# Build + stage the Wi-Fi-capable kexec installer from this repo
bash -c 'TGZ=$(nix build --no-link --print-out-paths github:joshjob42/nix-config#kexec-wifi)/nixos-kexec-installer-x86_64-linux.tar.gz; sudo tar -xf "$TGZ" -C /root'

# Launch it. THIS REBOOTS the machine into a NixOS installer in RAM.
# Your CachyOS session ends here — keep this guide open on another device.
sudo /root/kexec/run
```
After ~30 s you land in a **NixOS installer**, auto-logged-in as `root` on the laptop
console. (Prefer your iMac? In the console run `passwd` then `ip a` to get the address,
and `ssh root@<that-ip>` from the Mac.)

### B. Inside the kexec installer
```sh
# 1. Network. Wired = automatic. Wi-Fi (this image ships iwctl):
iwctl
#   [iwd]# device list                     # note your device name (wlan0 or wlp...)
#   [iwd]# station <dev> scan
#   [iwd]# station <dev> get-networks
#   [iwd]# station <dev> connect "<SSID>"   # prompts for the password
#   [iwd]# exit
ping -c1 github.com    # confirm you're online

# 2. Grab this repo (public, no auth)
git clone https://github.com/joshjob42/nix-config /tmp/nix-config
cd /tmp/nix-config

# 3. Run the guarded installer (it shows you the partitions and asks before erasing)
bash install.sh

# 4. When it finishes:
reboot
```

`install.sh` does, in order: `disko` formats `p6`/`p7` → regenerates the hardware
profile → `nixos-install` → sets your user password. If you'd rather run it by hand,
the four commands are listed inside that script.

### C. First boot
- The **GRUB** menu shows **NixOS** and **Windows** (auto-detected). Pick NixOS.
- Log in via `cosmic-greeter` → COSMIC desktop.
- After editing this config later: `nrs` (= `sudo nixos-rebuild switch --flake ~/nix-config#geekbook14`).

### If kexec misbehaves
You're not stuck: just reboot. Limine drops you back into CachyOS exactly as before
(nothing is formatted until you type `ERASE` in `install.sh`). Windows is safe throughout.

---

## Follow-ups (after first successful boot)
- [x] **Display** — the stock 6.18.35 kernel black-screened this Meteor Lake eDP panel
      under KMS; fixed by `boot.kernelPackages = pkgs.linuxPackages_latest` (7.0.x) + i915.
- [ ] **CachyOS kernel** — evaluated `chaotic-nyx` (archived) and `xddxdd/nix-cachyos-kernel`;
      chose mainline `linuxPackages_latest` instead (fixes the panel, no third-party cache).
- [x] **GUI dotfiles** — kitty / nvim (LazyVim) / zellij / btop / ncspot ported into
      `home/gui.nix` (+ vendored configs in `home/dotfiles/`).
- [x] **Secure Boot** via `lanzaboote` — see firmware notes below.
- [ ] **Secrets** — `sops-nix` or `op inject` to populate `~/.config/secrets.env`.
- Also added: **Helium** browser (`oxcl/nix-flake-helium-browser`), **Tailscale**.

### Secure Boot (lanzaboote) — geekbook14 firmware quirks
This GEEKOM's AMI firmware is finicky; the setup that works:
- It **drops** lanzaboote's "Linux Boot Manager" EFI entry, and instead auto-creates a
  fallback-path entry (`\EFI\BOOT\BOOTX64.EFI` on `p7`, shown as "UEFI OS"). Keep that
  entry first in `efibootmgr` BootOrder. The old GRUB `NixOS-boot` entry was deleted.
- Enroll/enable keys with Secure Boot Mode = **Custom**. **Standard mode reloads the
  firmware's factory keys** and breaks trust in the lanzaboote-signed bootloader.
  Procedure: BIOS → Custom mode → erase keys (Setup Mode) → boot →
  `sudo sbctl enroll-keys --microsoft` → reboot → BIOS (still Custom) → enable Secure Boot.
  Verify with `sudo sbctl status` (`Secure Boot: ✓ Enabled`, `Vendor Keys: microsoft`).
