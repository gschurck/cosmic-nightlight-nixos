# SPDX-License-Identifier: MPL-2.0
#
# NixOS packaging for cosmic-nightlight. Add it to environment.systemPackages:
#
#   (pkgs.callPackage /path/to/cosmic-nightlight/nix/package.nix { })
#
# Installed that way, the polkit rule under share/polkit-1 is picked up by
# NixOS without any other setting. Build it on its own with:
#
#   nix-build -E 'with import <nixpkgs> { }; callPackage ./nix/package.nix { }'
{
  lib,
  rustPlatform,
  libcosmicAppHook,
  libdrm,
}:
rustPlatform.buildRustPackage {
  pname = "cosmic-nightlight";
  # Read from Cargo.toml so the version isn't written in yet another place.
  version = (lib.importTOML ../Cargo.toml).workspace.package.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.gitTracked ../.;
  };

  cargoLock = {
    lockFile = ../Cargo.lock;
    # libcosmic and friends are git dependencies.
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [ libcosmicAppHook ];
  buildInputs = [ libdrm ];

  # pkexec checks the helper's real path against the polkit rule, and on NixOS
  # that is a store path rather than /usr/bin.
  postPatch = ''
    substituteInPlace crates/cosmic-nightlight/src/backend.rs polkit/49-cosmic-nightlight.rules \
      --replace-fail /usr/bin/cosmic-nightlight-helper "$out/bin/cosmic-nightlight-helper"
    substituteInPlace debian/cosmic-nightlight.user.service \
      --replace-fail /usr/bin/cosmic-nightlight "$out/bin/cosmic-nightlight"
  '';

  # Same as the other packages: the GUI crate's tests want a desktop session.
  cargoTestFlags = [ "-p" "nightlight-core" ];

  # Same file list as arch/PKGBUILD. The service ships disabled, as everywhere.
  postInstall = ''
    install -Dm0644 -t $out/share/applications data/*.desktop
    install -Dm0644 -t $out/share/metainfo data/io.github.cosmic_nightlight.metainfo.xml
    cp -r data/icons $out/share/icons
    install -Dm0644 -t $out/share/polkit-1/rules.d polkit/49-cosmic-nightlight.rules
    install -Dm0644 debian/cosmic-nightlight.user.service \
      $out/lib/systemd/user/cosmic-nightlight.service
  '';

  # Only the GUI needs the hook's wrapper. The helper runs as root, so pkexec
  # should run the real binary, not a wrapper around it.
  dontWrapLibcosmicApp = true;
  postFixup = ''
    wrapLibcosmicApp $out/bin/cosmic-nightlight
  '';

  meta = {
    description = "Night light and screen tint for the COSMIC desktop";
    homepage = "https://github.com/cosmic-nightlight/cosmic-nightlight";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    mainProgram = "cosmic-nightlight";
  };
}
