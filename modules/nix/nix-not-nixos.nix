{ config, pkgs, lib, ... }:

let
  nix-tools = pkgs.callPackage ../../pkgs/nix-tools {
    inherit (config.system) profile;
    inherit (config.environment) systemPath;
    nixPackage = config.nix.package;
  };

  linux-uninstaller = pkgs.callPackage ../../pkgs/linux-uninstaller { };

  inherit (nix-tools) linux-option linux-rebuild linux-version;
in

{
  options.system = {
    disableInstallerTools = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      default = false;
      description = ''
        Disable linux-rebuild and linux-option. This is useful to shrink
        systems which are not expected to rebuild or reconfigure themselves.
        Use at your own risk!
    '';
    };

    includeUninstaller = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      default = true;
    };
  };

  config = {
    environment.systemPackages =
      [ linux-version ]
      ++ lib.optionals (!config.system.disableInstallerTools) [
        linux-option
        linux-rebuild
      ] ++ lib.optional config.system.includeUninstaller linux-uninstaller;

    system.build = {
      inherit linux-option linux-rebuild linux-version;
    };
  };
}
