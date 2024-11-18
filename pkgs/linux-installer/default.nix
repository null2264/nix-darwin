{ stdenv, nix, pkgs, nix-not-nixos }:

let
  nixPath = pkgs.lib.concatStringsSep ":" [
    "nix-not-nixos=${nix-not-nixos}"
    "nixpkgs=${pkgs.path}"
    "$HOME/.nix-defexpr/channels"
    "/nix/var/nix/profiles/per-user/root/channels"
    "$NIX_PATH"
  ];
in

stdenv.mkDerivation {
  name = "linux-installer";
  preferLocalBuild = true;

  unpackPhase = ":";

  installPhase = ''
    mkdir -p $out/bin
    echo "$shellHook" > $out/bin/linux-installer
    chmod +x $out/bin/linux-installer
  '';

  shellHook = ''
    #!${stdenv.shell}
    set -e

    _PATH=$PATH
    export PATH=/nix/var/nix/profiles/default/bin:${nix}/bin:${pkgs.gnused}/bin:${pkgs.openssh}/bin:/usr/bin:/bin:/usr/sbin:/sbin

    action=switch
    while [ "$#" -gt 0 ]; do
        i="$1"; shift 1
        case "$i" in
            --help)
                echo "linux-installer: [--help] [--check]"
                exit
                ;;
            --check)
                action=check
                ;;
        esac
    done

    echo >&2
    echo >&2 "Installing nix-not-nixos..."
    echo >&2

    config="$HOME/.nixpkgs/linux-configuration.nix"
    if ! test -f "$config"; then
        echo "copying example configuration.nix" >&2
        mkdir -p "$HOME/.nixpkgs"
        cp "${../../modules/examples/simple.nix}" "$config"
        chmod u+w "$config"
    fi

    # Skip when stdin is not a tty, eg.
    # $ yes | linux-installer
    if test -t 0; then
        read -p "Would you like to edit the default configuration.nix before starting? [y/N] " i
        case "$i" in
            y|Y)
                PATH=$_PATH ''${EDITOR:-nano} "$config"
                ;;
        esac
    fi

    i=y
    linuxPath=$(NIX_PATH=$HOME/.nix-defexpr/channels nix-instantiate --eval -E '<nix-not-nixos>' 2> /dev/null) || true
    if ! test -e "$linuxPath"; then
        if test -t 0; then
            read -p "Would you like to manage <nix-not-nixos> with nix-channel? [y/N] " i
        fi
        case "$i" in
            y|Y)
                nix-channel --add https://github.com/null2264/nix-darwin/archive/dev/nix-not-nixos.tar.gz nix-not-nixos
                nix-channel --update
                ;;
        esac
    fi

    export NIX_PATH=${nixPath}
    system=$(nix-build '<nix-not-nixos>' -I "linux-config=$config" -A system --no-out-link --show-trace)

    export PATH=$system/sw/bin:$PATH
    linux-rebuild "$action" -I "linux-config=$config"

    echo >&2
    echo >&2 "    Open '$config' to get started."
    echo >&2 "    See the README for more information: [0;34mhttps://github.com/null2264/nix-darwin/blob/nix-not-nixos/README.md[0m"
    echo >&2
    echo >&2 "    Please log out and log in again to make sure nix-not-nixos is properly loaded."
    echo >&2
    exit
  '';

  passthru.check = stdenv.mkDerivation {
     name = "run-linux-test";
     shellHook = ''
        set -e
        echo >&2 "running installer tests..."
        echo >&2

        echo >&2 "checking configuration.nix"
        test -f ~/.nixpkgs/linux-configuration.nix
        test -w ~/.nixpkgs/linux-configuration.nix
        echo >&2 "checking nix-not-nixos channel"
        readlink ~/.nix-defexpr/channels/nix-not-nixos
        test -e ~/.nix-defexpr/channels/nix-not-nixos
        echo >&2 "checking /etc"
        readlink /etc/static
        test -e /etc/static
        echo >&2 "checking profile"
        cat /etc/profile
        (! grep nix-daemon.sh /etc/profile)
        echo >&2 "checking /run/current-system"
        readlink /run/current-system
        test -e /run/current-system
        echo >&2 "checking system profile"
        readlink /nix/var/nix/profiles/system
        test -e /nix/var/nix/profiles/system

        echo >&2 "checking bash environment"
        env -i USER=john HOME=/Users/john bash -li -c 'echo $PATH'
        env -i USER=john HOME=/Users/john bash -li -c 'echo $PATH' | grep /Users/john/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
        env -i USER=john HOME=/Users/john bash -li -c 'echo $NIX_PATH'
        env -i USER=john HOME=/Users/john bash -li -c 'echo $NIX_PATH' | grep linux-config=/Users/john/.nixpkgs/linux-configuration.nix:/nix/var/nix/profiles/per-user/root/channels

        echo >&2 "checking zsh environment"
        env -i USER=john HOME=/Users/john zsh -l -c 'echo $PATH'
        env -i USER=john HOME=/Users/john zsh -l -c 'echo $PATH' | grep /Users/john/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
        env -i USER=john HOME=/Users/john zsh -l -c 'echo $NIX_PATH'
        env -i USER=john HOME=/Users/john zsh -l -c 'echo $NIX_PATH' | grep linux-config=/Users/john/.nixpkgs/linux-configuration.nix:/nix/var/nix/profiles/per-user/root/channels

        echo >&2 ok
        exit
    '';
  };
}
