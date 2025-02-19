{ lib
, stdenv
, callPackage
, resholve
, bash
, coreutils
, e2fsprogs
, exfatprogs
, f3
, findutils
, gawk
, gnused
, jq
, parted
, procps
, systemd
, util-linux
}:

let
  src = callPackage ./src.nix { };

  solution = {
    scripts = [ "bin/*" "lib/hwsupport/*.sh" ];
    interpreter = "${bash}/bin/bash";
    inputs = [
      coreutils
      e2fsprogs
      exfatprogs
      f3
      findutils
      gawk
      gnused
      jq
      parted
      procps
      systemd
      util-linux

      "${placeholder "out"}/lib/hwsupport"
    ];
    execer = [
      "cannot:${e2fsprogs}/bin/fsck.ext4"
      "cannot:${e2fsprogs}/bin/mkfs.ext4"
      "cannot:${procps}/bin/pgrep"
      "cannot:${systemd}/bin/systemctl"
      "cannot:${systemd}/bin/udevadm"
      "cannot:${util-linux}/bin/flock"

      "cannot:${placeholder "out"}/lib/hwsupport/format-device.sh"
    ];
    fake = {
      # we're using wrappers for these
      external = [ "umount" ];
    };
    fix = {
      "/usr/lib/hwsupport/format-device.sh" = true;
    };
    keep = {
      # pre-applied via patch
      # FIXME: why do we need to discard string context here?
      "${builtins.unsafeDiscardStringContext "${systemd}/bin/systemd-run"}" = true;
    };
  };
in
stdenv.mkDerivation {
  pname = "jupiter-hw-support";

  inherit src;
  inherit (src) version;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp usr/bin/jupiter-check-support $out/bin

    mkdir -p $out/lib
    cp -r usr/lib/hwsupport $out/lib

    mkdir -p $out/share
    cp -r usr/share/alsa $out/share

    # ALSA lib main.c:844:(execute_sequence) exec 'echo Main Verb Config EnableSequence' failed (exit code -8)
    # ALSA lib main.c:2573:(set_verb_user) error: failed to initialize new use case: HiFi
    # alsaucm: error failed to set _verb=HiFi: Exec format error
    sed -i 's|exec "echo|#exec "echo|g' $out/share/alsa/ucm2/conf.d/acp5x/HiFi*.conf

    ${resholve.phraseSolution "jupiter-hw-support" solution}

    runHook postInstall
  '';

  meta = with lib; {
    description = ''
      Steam Deck (Jupiter) hardware support package

      This package only contains the utility scripts as well as UCM files.
      For the themes as well as unfree firmware, see the `steamdeck-theme`
      and `steamdeck-firmware` packages.
    '';
    license = licenses.mit;
  };
}
