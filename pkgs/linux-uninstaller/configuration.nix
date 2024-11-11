{ lib, pkgs, ... }:

with lib;

{
  # We are uninstalling, disable sanity checks.
  assertions = mkForce [];
  system.activationScripts.checks.text = mkForce "";

  environment.etc = mkForce {};
  systemd.services = mkForce {};
  systemd.user.services = mkForce {};

  # Don't try to reload `nix-daemon`
  nix.useDaemon = mkForce false;

  system.activationScripts.postUserActivation.text = mkAfter ''
    if [[ -L ~/.nix-defexpr/channels/nix-not-nixos ]]; then
        nix-channel --remove nix-not-nixos || true
    fi
  '';

  system.activationScripts.postActivation.text = mkAfter ''
    if [[ -L /usr/share/fonts/nix-fonts ]]; then
        rm /usr/share/fonts/nix-fonts
    fi

    if [[ -L /etc/static ]]; then
        rm /etc/static
    fi

    # If the Nix Store is owned by root then we're on a multi-user system
    if [[ -O /nix/store ]]; then
        NIX_SHOULD_RESTART_DAEMON=0
        if [[ -e /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service ]]; then
            sudo cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.service
            NIX_SHOULD_RESTART_DAEMON=1
        fi
        if [[ -e /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.socket ]]; then
            sudo cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.socket /etc/systemd/system/nix-daemon.socket
            NIX_SHOULD_RESTART_DAEMON=1
        fi

        [ $NIX_SHOULD_RESTART_DAEMON = 1 ] && sudo systemctl restart nix-daemon
    fi

    # FIXME: Change users' shell back to /bin/zsh
    # grep will return 1 when no lines matched which makes this line fail with `set -eo pipefail`
    #dscl . -list /Users UserShell | { grep "\s/run/" || true; } | awk '{print $1}' | while read -r user; do
    #  shell=$(dscl . -read /Users/"$user" UserShell)
    #  if [[ "$shell" != */bin/zsh ]]; then
    #    echo >&2 "warning: changing $user's shell from $shell to /bin/zsh"
    #  fi

    #  dscl . -create /Users/"$user" UserShell /bin/zsh
    #done

    while IFS= read -r -d "" file; do
      mv "$file" "''${file%.*}"
    done < <(find /etc -name '*.before-nix-not-nixos' -follow -print0)
  '';
}
