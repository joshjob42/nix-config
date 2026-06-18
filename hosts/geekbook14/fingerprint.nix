# Fingerprint reader: Focaltech FTE4800 (SPI; ACPI id FTE4800).
#
# STATUS: NOT WORKING — kept as documented groundwork; NOT imported by
# configuration.nix. Re-add the import to experiment further.
#
# What works (the whole NixOS packaging problem is solved here):
#   * focal_spi out-of-tree kernel module builds on kernel 7.0 (header rename +
#     drop SPI_CS_HIGH) and binds the FTE4800, creating /dev/focal_moh_spi.
#   * The proprietary libfprint blob is extracted, patchelf'd, and swapped into
#     nixpkgs' libfprint; fprintd is rebuilt against it and ENUMERATES the device.
#   * The blob needs gusb's g_usb_* getters at symbol-version @LIBGUSB_0.1.0
#     (Ubuntu's libgusb), which upstream gusb 0.3.10 puts in LIBGUSB_0.2.8 -- so
#     gusb03 below surgically remaps just those 6 symbols. ldd -r is then clean.
#
# Why it ultimately fails (hardware, not packaging):
#   fprintd opens the device but sensor init fails -- "configure spi mode failed"
#   and the SPI device-ID reads return garbage (0xcece with SPI_CS_HIGH; 0x0000/
#   0xffff without). The sensor never answers on SPI. The driver/blob officially
#   support FT9769/FT9365/FT9391/FT9369; this panel is an FTE4800 (probes as
#   fw9362), which appears unsupported (and/or needs a board-specific GPIO
#   power/reset sequence the driver doesn't do on this GEEKOM).
#
# Leads for a future attempt: try the older 20240620 blob in oneXfive/ubuntu_spi;
# check ACPI GPIO resources for the FTE4800 vs what focal_spi drives; watch for a
# newer Focaltech driver release that lists FTE4800/fw9362.
#
# This sensor has NO open/mainline libfprint driver. Working support requires
# two third-party pieces (translated here from the Arch AUR recipe):
#   1. focal_spi  — an out-of-tree GPL SPI kernel module (open C source) that
#      exposes the device node /dev/focal_moh_spi.
#   2. a PROPRIETARY libfprint build with the Focaltech driver baked in,
#      extracted from a community-hosted Ubuntu .deb and patchelf'd. It replaces
#      the .so inside nixpkgs' libfprint so fprintd loads it at runtime.
#
# Trust note: both are third-party (a hobbyist kernel module + a closed blob of
# OEM provenance) running with high privilege. Secure Boot does not block the
# module here because the lockdown LSM is not enabled. To remove all of this,
# drop the ./fingerprint.nix import from configuration.nix.
{ config, pkgs, lib, ... }:
let
  # 1) SPI kernel module, built against the running kernel.
  focalSpi = config.boot.kernelPackages.callPackage (
    { stdenv, kernel }:
    stdenv.mkDerivation {
      name = "focal-spi-${kernel.version}";
      src = pkgs.fetchFromGitHub {
        owner = "vobademi";
        repo = "FTEXX00-Ubuntu";
        rev = "d4fbbf901aff44b92d4fa212d9b99e43cda00563";
        sha256 = "0fqmf7rqqwgh71wlqjd7s5kcpqpahzjnkc74ybrllnfj108xfsfj";
      };
      nativeBuildInputs = kernel.moduleBuildDependencies;
      postPatch = ''
        # Kernel 6.12+ moved this header.
        sed -i 's#<asm/unaligned.h>#<linux/unaligned.h>#' focal_spi.c
        # On this Meteor Lake SPI controller the default mode (SPI_MODE_0 |
        # SPI_CS_HIGH) fails: "configure spi mode failed(14)" + garbage device
        # IDs. The upstream (oneXfive) README says to drop SPI_CS_HIGH on SPI
        # transfer errors. That makes the sensor handshake succeed.
        sed -i 's/spi->mode = SPI_MODE_0|SPI_CS_HIGH;/spi->mode = SPI_MODE_0;/' focal_spi.c
      '';
      buildPhase = ''
        runHook preBuild
        make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$(pwd) modules
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        install -Dm644 focal_spi.ko \
          $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/spi/focal_spi.ko
        runHook postInstall
      '';
      meta.license = lib.licenses.gpl2Only;
    }
  ) { };
in
{
  # Build the module and load it at boot. It probes the ACPI FTE4800 SPI device
  # and creates /dev/focal_moh_spi.
  boot.extraModulePackages = [ focalSpi ];
  boot.kernelModules = [ "focal_spi" ];

  # 2) Replace libfprint's runtime .so with the proprietary Focaltech build,
  #    keeping nixpkgs' headers so fprintd still compiles against it normally.
  nixpkgs.overlays = [
    (final: prev:
      let
        # The blob was built against Ubuntu 22.04's libgusb 0.3.x; gusb 0.4.x
        # removed the GUsbInterface getters it needs (g_usb_interface_get_*),
        # so the system's gusb 0.4.9 can't satisfy it. Build an old 0.3.x ONLY
        # for the blob (system gusb stays 0.4.9); the blob's patchelf'd RUNPATH
        # then points here for those symbols.
        gusb03 = prev.stdenv.mkDerivation {
          pname = "gusb";
          version = "0.3.10";
          outputs = [ "out" "dev" ];
          src = prev.fetchFromGitHub {
            owner = "hughsie";
            repo = "libgusb";
            rev = "0.3.10";
            sha256 = "040nr7mjddh7mrnaa3mnq893sgsig9my0iiipkdajpqr45f303ld";
          };
          nativeBuildInputs = [ prev.meson prev.ninja prev.pkg-config prev.gobject-introspection ];
          # Propagated so downstream pkg-config (libfprint) resolves gusb's
          # Requires: (glib, libusb-1.0, json-glib).
          propagatedBuildInputs = [ prev.glib prev.libusb1 prev.json-glib ];
          # introspection=true: libfprint's own g-ir-scanner needs GUsb-1.0.gir.
          mesonFlags = [ "-Ddocs=false" "-Dtests=false" "-Dvapi=false" "-Dintrospection=true" ];
          # SYMBOL-VERSION SURGERY: the Focaltech blob references these 6 getters
          # at @LIBGUSB_0.1.0 (the node Ubuntu's libgusb exported them at), but
          # upstream 0.3.10 puts them in LIBGUSB_0.2.8. Move ONLY these 6 to the
          # 0.1.0 node so the blob's versioned refs resolve; every other symbol
          # keeps its upstream node (the blob references those at the right ver).
          # Safe because this gusb is used ONLY by the blob, never the system.
          postPatch = ''
            for s in g_usb_device_get_interfaces g_usb_device_get_release \
                     g_usb_interface_get_class g_usb_interface_get_number \
                     g_usb_interface_get_protocol g_usb_interface_get_subclass; do
              sed -i "/^[[:space:]]*$s;[[:space:]]*$/d" gusb/libgusb.ver
            done
            sed -i '0,/^[[:space:]]*global:/s//&\
                g_usb_device_get_interfaces;\
                g_usb_device_get_release;\
                g_usb_interface_get_class;\
                g_usb_interface_get_number;\
                g_usb_interface_get_protocol;\
                g_usb_interface_get_subclass;/' gusb/libgusb.ver
          '';
        };
        libfprintBlob = prev.stdenv.mkDerivation {
          pname = "libfprint-ftexx00-blob";
          version = "1.94.4-spi20250112";
          src = prev.fetchurl {
            url = "https://github.com/oneXfive/ubuntu_spi/raw/refs/heads/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_20250112_amd64.deb";
            sha256 = "b48c93c3732f90aabbcc520e5538faeffbb87bb6847a01d03e14ea157f1d36c1";
          };
          nativeBuildInputs = [ prev.dpkg prev.autoPatchelfHook ];
          buildInputs = [
            (lib.getLib prev.stdenv.cc.cc)
            prev.glib
            gusb03 # 0.3.x for the blob's removed-in-0.4 GUsbInterface symbols
            prev.pixman
            prev.nss
            prev.libgudev
          ];
          unpackPhase = "dpkg-deb -x $src src";
          installPhase = ''
            mkdir -p $out/lib
            cp src/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 $out/lib/
            ln -s libfprint-2.so.2.0.0 $out/lib/libfprint-2.so.2
            ln -s libfprint-2.so.2.0.0 $out/lib/libfprint-2.so
          '';
          meta.license = lib.licenses.unfree;
        };
      in
      {
        # Build libfprint against gusb 0.3.x so it *propagates* gusb03 (not the
        # system's 0.4.9). Then fprintd, built against this libfprint, links the
        # blob's g_usb_*@LIBGUSB_0.1.0 symbols against gusb03 and resolves them.
        # (We discard libfprint's own .so in postFixup, replacing it with the
        # blob, but it must still compile against gusb 0.3.x's headers.)
        libfprint = (prev.libfprint.override { gusb = gusb03; }).overrideAttrs (old: {
          # Flaky VirtualDevice tests in a fresh sandbox; we replace the .so
          # anyway. (Don't set doCheck=false — meson still needs the test deps to
          # *configure* the suite.)
          checkPhase = "true";
          installCheckPhase = "true";
          postFixup = (old.postFixup or "") + ''
            rm -f "$out"/lib/libfprint-2.so*
            cp -P ${libfprintBlob}/lib/libfprint-2.so* "$out"/lib/
          '';
        });

        # Build fprintd against our blob libfprint, and put gusb03's libgusb.so.2
        # (which exports g_usb_*@LIBGUSB_0.1.0) directly in its link path, so ld
        # can resolve the blob's versioned gusb symbols. (fprintd takes no `gusb`
        # arg, so it must be injected via buildInputs.)
        fprintd = (prev.fprintd.override { libfprint = final.libfprint; }).overrideAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ gusb03 ];
          # fprintd links with -Wl,--no-undefined, which hard-fails on the blob
          # libfprint's gusb symbols (they resolve at runtime via the blob's own
          # RUNPATH -> gusb03). --allow-shlib-undefined defers a *shared lib's*
          # undefined symbols to runtime, which is exactly correct here.
          NIX_LDFLAGS = (old.NIX_LDFLAGS or "") + " --allow-shlib-undefined";
        });
      })
  ];

  # Fingerprint daemon (uses the overlaid libfprint above).
  services.fprintd.enable = true;

  # The proprietary driver talks to /dev/focal_moh_spi; let fprintd reach it and
  # make it accessible to the logged-in user.
  services.udev.extraRules = ''
    KERNEL=="focal_moh_spi", MODE="0660", TAG+="uaccess"
  '';
  systemd.services.fprintd.serviceConfig.DeviceAllow = [ "/dev/focal_moh_spi rw" ];
}
