{ lib, path, stdenv, writeShellApplication }:

let
  uninstallSystem = import ../../eval-config.nix {
    inherit lib;
    modules = [
      ./configuration.nix
      {
        nixpkgs.source = path;
        nixpkgs.hostPlatform = stdenv.hostPlatform.system;
        system.includeUninstaller = false;
      }
    ];
  };
in writeShellApplication {
  name = "linux-uninstaller";
  text = ''
    while [ "$#" -gt 0 ]; do
      i="$1"; shift 1
      case "$i" in
        --help)
          echo "linux-uninstaller: [--help]"
          exit
          ;;
      esac
    done

    echo >&2
    echo >&2 "Uninstalling nix-not-nixos, this will:"
    echo >&2
    echo >&2 "    - cleanup static /etc files"
    echo >&2 "    - disable and remove all systemd services managed by nix-not-nixos"
    echo >&2 "    - restore daemon service from nix installer (only when this is a multi-user install)"
    echo >&2

    if [[ -t 0 ]]; then
      read -r -p "Proceed? [y/n] " i
      case "$i" in
        y|Y)
          ;;
        *)
          exit 3
          ;;
      esac
    fi

    ${uninstallSystem.system}/sw/bin/linux-rebuild activate

    if [[ -L /run/current-system ]]; then
      sudo rm /run/current-system
    fi

    echo >&2
    echo >&2 "NOTE: The /nix/var/nix/profiles/system* profiles still exist and won't be garbage collected."
    echo >&2
    echo >&2 "Done!"
    echo >&2
  '';

  derivationArgs.passthru.tests.uninstaller = writeShellApplication {
    name = "post-uninstall-test";
    text = ''
      echo >&2 "running uninstaller tests..."
      echo >&2

      echo >&2 "checking nix-not-nixos channel"
      test -e ~/.nix-defexpr/channels/nix-not-nixos && exit 1
      echo >&2 "checking /etc"
      test -e /etc/static && exit 1
      echo >&2 "checking /run/current-system"
      test -e /run/current-system && exit 1
      if [[ $(stat -f '%Su' /nix/store) == "root" ]]; then
        echo >&2 "checking nix-daemon service"
        systemctl cat nix-daemon
        pgrep -l nix-daemon
        test -e /etc/systemd/system/nix-daemon.service
        test -e /etc/systemd/system/nix-daemon.socket
        [[ "$(shasum -a 256 /etc/systemd/system/nix-daemon.service | awk '{print $1}')" == "$(shasum -a 256 /etc/systemd/system/nix-daemon.socket | awk '{print $1}')" ]]
        echo >&2 ok
      fi
    '';
  };
}