{ nixpkgs ? <nixpkgs>
, configuration ? <linux-config>
, lib ? pkgs.lib
, pkgs ? import nixpkgs { inherit system; }
, system ? builtins.currentSystem
}:

let
  eval = import ./eval-config.nix {
    inherit lib;
    modules = [
      configuration
      { nixpkgs.source = lib.mkDefault nixpkgs; }
    ] ++ lib.optional (system != null) {
      nixpkgs.system = lib.mkDefault system;
    };
  };

  # The source code of this repo needed by the installer.
  nix-not-nixos = lib.cleanSource (
    lib.cleanSourceWith {
      # We explicitly specify a name here otherwise `cleanSource` will use the
      # basename of ./.  which might be different for different clones of this
      # repo leading to non-reproducible outputs.
      name = "nix-not-nixos";
      src = ./.;
    }
  );
in

eval // {
  installer = pkgs.callPackage ./pkgs/linux-installer { inherit nix-not-nixos; };
  uninstaller = pkgs.callPackage ./pkgs/linux-uninstaller { };
}
