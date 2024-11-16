{
  description = "A collection of Linux but not nixOS modules";

  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
    forLinuxSystems = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];

    jobs = forAllSystems (system: import ./release.nix {
      inherit nixpkgs system;

      nix-not-nixos = self;
    });
  in {
    lib = {
      evalConfig = import ./eval-config.nix;

      linuxSystem = args@{ modules, ... }: self.lib.evalConfig (
        { inherit (nixpkgs) lib; }
        // nixpkgs.lib.optionalAttrs (args ? pkgs) { inherit (args.pkgs) lib; }
        // builtins.removeAttrs args [ "system" "pkgs" "inputs" ]
        // {
          modules = modules
            ++ nixpkgs.lib.optional (args ? pkgs) ({ lib, ... }: {
              _module.args.pkgs = lib.mkForce args.pkgs;
            })
            # Backwards compatibility shim; TODO: warn?
            ++ nixpkgs.lib.optional (args ? system) ({ lib, ... }: {
              nixpkgs.system = lib.mkDefault args.system;
            })
            # Backwards compatibility shim; TODO: warn?
            ++ nixpkgs.lib.optional (args ? inputs) {
              _module.args.inputs = args.inputs;
            }
            ++ [ ({ lib, ... }: {
              nixpkgs.source = lib.mkDefault nixpkgs;
              nixpkgs.flake.source = lib.mkDefault nixpkgs.outPath;

              system.checks.verifyNixPath = lib.mkDefault false;

              system.linuxVersionSuffix = ".${self.shortRev or self.dirtyShortRev or "dirty"}";
              system.linuxRevision = let
                rev = self.rev or self.dirtyRev or null;
              in
                lib.mkIf (rev != null) rev;
            }) ];
          });
    };

    overlays.default = final: prev: {
      inherit (prev.callPackage ./pkgs/nix-tools { }) linux-rebuild linux-option linux-version;

      linux-uninstaller = prev.callPackage ./pkgs/linux-uninstaller { };
    };

    linuxModules.hydra = ./modules/examples/hydra.nix;
    linuxModules.lnl = ./modules/examples/lnl.nix;
    linuxModules.simple = ./modules/examples/simple.nix;

    templates.default = {
      path = ./modules/examples/flake;
      description = "nix flake init -t nix-not-nixos";
    };

    checks = forLinuxSystems (system: jobs.${system}.tests // jobs.${system}.examples);

    packages = forAllSystems (system: {
      inherit (jobs.${system}.docs) manualHTML manpages optionsJSON;
    } // (nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "linux" system) (let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in {
      default = self.packages.${system}.linux-rebuild;

      inherit (pkgs) linux-option linux-rebuild linux-version linux-uninstaller;
    })));
  };
}
