# useful links:
#  - https://github.com/diamondburned/zmk-nix/blob/main/shell.nix
#  - https://github.com/lilyinstarlight/zmk-nix/tree/main
#  - https://www.reddit.com/r/ErgoMechKeyboards/comments/zxh6r7/zmk_has_anyone_managed_to_produce_working_uf2/
#  - https://zmk.dev/docs/development/setup
{ pkgs, config, ... }: let
  python = pkgs.python3.withPackages (ps: with ps; [
    # from zephyr/scripts/requirements.txt
    pyelftools
    pyyaml
    pykwalify
    canopen
    packaging
    progress
    psutil
    pylink-square
    anytree
    intelhex
    west
  ]);
in {
  packages = with pkgs; [
    python3Packages.west

    clang-tools
    coreutils
    cmake
    ninja
    dfu-programmer
    dfu-util
    gcc-arm-embedded-10
    git

    python
  ];

  enterShell = ''
    echo "--------------------------------------------"
    echo "Hello to zmk firmware shell"
    echo "Use 'zmk-init' to fetch deps"
    echo "Use 'zmk-build-left/right' to build firmware"
    echo "Use 'zmk-flash-left/right' to flash firmware"
    echo "--------------------------------------------"
  '';

  env = {
    ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
    GNUARMEMB_TOOLCHAIN_PATH = pkgs.gcc-arm-embedded;
    CMAKE_PREFIX_PATH        = "${config.devenv.root}/zephyr/share/zephyr-package/cmake";
  };

  scripts = let
    build = side:
      "west build --build-dir build/${side} --pristine --board nice_nano_v2 -s ${config.devenv.root}/zmk/app -- -DSHIELD=sofle_${side} -DZMK_CONFIG=${config.devenv.root}/config -DWEST_PYTHON=${python}/bin/python";
    flash = side: ''
      set -e

      firmware=build/${side}/zephyr/zmk.uf2

      [[ -e $firmware ]] || {
        echo "Firmware is not built."
        exit 1
      }

      device_name=NICENANO
      [[ -e /dev/disk/by-label/$device_name ]] || {
        echo "nice!nano is not yet plugged in."
        exit 1
      }

      device_path=$(cd /dev/disk/by-label; realpath $(readlink $device_name))
      regex_match="^''${device_path//\//\\/} on \(.*\) type .*"

      mount | grep "$regex_match" &> /dev/null || {
        udisksctl mount -b $device_path
      }

      mountpoint=$(mount | sed -n "s/$regex_match/\1/p")
      [[ ! $mountpoint ]] && {
        echo "Failed to mount nice!nano: mountpoint not found."
        exit 1
      }

      cp $firmware "$mountpoint/."

      echo "Flashed nice!nano."
      udisksctl unmount -b $device_path &> /dev/null  \
        && echo "Device is now safe to be unplugged." \
        || echo "Device not gracefully unmounted. It may have restarted."
    '';
  in {
    zmk-init.exec        = "west init -l config; west update";
    zmk-build-right.exec = build "right";
    zmk-build-left.exec  = build "left" ;
    zmk-flash-right.exec = flash "right";
    zmk-flash-left.exec  = flash "left" ;
  };
}
