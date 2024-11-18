{
  description = "Example nix-not-nixos system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-not-nixos.url = "github:null2264/nix-darwin";
    nix-not-nixos.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-not-nixos, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ pkgs.vim
        ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-not-nixos.
      # programs.fish.enable = true;

      # Set Git commit hash for linux-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ linux-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "x86_64-linux";
    };
  in
  {
    # Build linux flake using:
    # $ linux-rebuild build --flake .#simple
    linuxConfigurations."simple" = nix-not-nixos.lib.linuxSystem {
      modules = [ configuration ];
    };

    # Expose the package set, including overlays, for convenience.
    linuxPackages = self.linuxConfigurations."simple".pkgs;
  };
}
