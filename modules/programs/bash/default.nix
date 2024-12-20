{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.bash;

  bashrc = ''
    # /etc/bashrc: DO NOT EDIT -- this file has been generated automatically.
    # This file is read for interactive shells.

    [ -r "/etc/bashrc_$TERM_PROGRAM" ] && . "/etc/bashrc_$TERM_PROGRAM"

    # Only execute this file once per shell.
    if [ -n "$__ETC_BASHRC_SOURCED" -o -n "$NOSYSBASHRC" ]; then return; fi
    __ETC_BASHRC_SOURCED=1

    if [ -z "$__NIX_LINUX_SET_ENVIRONMENT_DONE" ]; then
      . ${config.system.build.setEnvironment}
    fi

    # Return early if not running interactively, but after basic nix setup.
    [[ $- != *i* ]] && return

    # Make bash check its window size after a process completes
    shopt -s checkwinsize

    ${config.system.build.setAliases.text}

    ${config.environment.interactiveShellInit}
    ${cfg.interactiveShellInit}

    ${optionalString cfg.completion.enable ''
      if [ "$TERM" != "dumb" ]; then
        source "${cfg.completion.package}/etc/profile.d/bash_completion.sh"

        nullglobStatus=$(shopt -p nullglob)
        shopt -s nullglob
        for p in $NIX_PROFILES; do
          for m in "$p/etc/bash_completion.d/"*; do
            source $m
          done
        done
        eval "$nullglobStatus"
        unset nullglobStatus p m
      fi
    ''}

    # Read system-wide modifications.
    if test -f /etc/bash.local; then
      source /etc/bash.local
    fi
  '';
in

{
  imports = [
    (mkRenamedOptionModule [ "programs" "bash" "enableCompletion" ] [ "programs" "bash" "completion" "enable" ])
  ];

  options = {

    programs.bash.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure bash as an interactive shell.";
    };

    programs.bash.interactiveShellInit = mkOption {
      default = "";
      description = "Shell script code called during interactive bash shell initialisation.";
      type = types.lines;
    };

    programs.bash.completion = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable bash completion for all interactive bash shells.

          NOTE: This doesn't work with bash 3.2, which is installed by default on macOS by Apple.
        '';
      };

      package = mkPackageOption pkgs "bash-completion" { };
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages =
      [ # Include bash package
        pkgs.bashInteractive
      ] ++ optional cfg.completion.enable cfg.completion.package;

    environment.pathsToLink = optionals cfg.completion.enable
      [ "/etc/bash_completion.d"
        "/share/bash-completion/completions"
      ];

    environment.etc."bashrc".text = bashrc;
    environment.etc."bash.bashrc".text = bashrc;

    environment.etc."bashrc".knownSha256Hashes = [
      "444c716ac2ccd9e1e3347858cb08a00d2ea38e8c12fdc5798380dc261e32e9ef"  # macOS
      "af4f09eb27cb7f140dfee7f3285574a68ca50ac1db2019652cef4196ee346307"  # Debian
      "29128d49b590338131373ec431a59c0b5318330050aac9ac61d5098517ac9a25"  # Ubuntu
      "89053ee31f8607bf4371cba46864bda07c51625fd19c6806a9b7bbf526aaf7f4"  # Arch Linux
      "617b39e36fa69270ddbee19ddc072497dbe7ead840cbd442d9f7c22924f116f4"  # official Nix installer
      "6be16cf7c24a3c6f7ae535c913347a3be39508b3426f5ecd413e636e21031e66"  # official Nix installer
      "87809e49352a19224ab3ecf88d5f3869581e8c3391331570b0d1febb8800578f"  # official Nix installer
      "a8d25482dbf03f13221c6b32654021a1ca23dcc179d9447b936dca19258cb9be"  # official Nix installer
      "08ffbf991a9e25839d38b80a0d3bce3b5a6c84b9be53a4b68949df4e7e487bb7"  # DeterminateSystems installer
    ];
    environment.etc."bash.bashrc".knownSha256Hashes = config.environment.etc."bashrc".knownSha256Hashes;

  };
}
