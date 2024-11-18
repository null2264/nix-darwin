# FIXME: Re-enable users/groups management
{ config, lib, pkgs, ... }:

let
  inherit (lib) concatStringsSep concatMapStringsSep elem escapeShellArg
    escapeShellArgs filter filterAttrs flatten flip mapAttrs' mapAttrsToList
    mkAfter mkIf mkMerge mkOption mkOrder mkRemovedOptionModule optionals
    optionalString types;

  cfg = config.users;

  group = import ./group.nix;
  user = import ./user.nix;

  toGID = v: { "${toString v.gid}" = v.name; };
  toUID = v: { "${toString v.uid}" = v.name; };

  isCreated = list: name: elem name list;
  isDeleted = attrs: name: ! elem name (mapAttrsToList (n: v: v.name) attrs);

  gids = mapAttrsToList (n: toGID) (filterAttrs (n: v: isCreated cfg.knownGroups v.name) cfg.groups);
  uids = mapAttrsToList (n: toUID) (filterAttrs (n: v: isCreated cfg.knownUsers v.name) cfg.users);

  createdGroups = mapAttrsToList (n: v: cfg.groups."${v}") cfg.gids;
  createdUsers = mapAttrsToList (n: v: cfg.users."${v}") cfg.uids;
  deletedGroups = filter (n: isDeleted cfg.groups n) cfg.knownGroups;
  deletedUsers = filter (n: isDeleted cfg.users n) cfg.knownUsers;

  packageUsers = filterAttrs (_: u: u.packages != []) cfg.users;

  # convert a valid argument to user.shell into a string that points to a shell
  # executable. Logic copied from modules/system/shells.nix.
  shellPath = v:
    if types.shellPackage.check v
    then "/run/current-system/sw${v.shellPath}"
    else v;

  systemShells =
    let
      shells = mapAttrsToList (_: u: u.shell) cfg.users;
    in
      filter types.shellPackage.check shells;

in

{
  imports = [
    (mkRemovedOptionModule [ "users" "forceRecreate" ] "")
  ];

  options = {
    users.knownGroups = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of groups owned and managed by nix-darwin. Used to indicate
        what users are safe to create/delete based on the configuration.
        Don't add system groups to this.
      '';
    };

    users.knownUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of users owned and managed by nix-darwin. Used to indicate
        what users are safe to create/delete based on the configuration.
        Don't add the admin user or other system users to this.
      '';
    };

    users.groups = mkOption {
      type = types.attrsOf (types.submodule group);
      default = {};
      description = "Configuration for groups.";
    };

    users.users = mkOption {
      type = types.attrsOf (types.submodule user);
      default = {};
      description = "Configuration for users.";
    };

    users.gids = mkOption {
      internal = true;
      type = types.attrsOf types.str;
      default = {};
    };

    users.uids = mkOption {
      internal = true;
      type = types.attrsOf types.str;
      default = {};
    };
  };

  config = {
    assertions = [
      {
        # We don't check `root` like the rest of the users as on some systems `root`'s
        # home directory is set to `/var/root /private/var/root`
        assertion = cfg.users ? root -> (cfg.users.root.home == null || cfg.users.root.home == "/var/root");
        message = "`users.users.root.home` must be set to either `null` or `/var/root`.";
      }
      {
        assertion = !builtins.elem "root" deletedUsers;
        message = "Remove `root` from `users.knownUsers` if you no longer want nix-darwin to manage it.";
      }
    ] ++ flatten (flip mapAttrsToList cfg.users (name: user:
      map (shell: {
        assertion = let
          s = user.shell.pname or null;
        in
          !user.ignoreShellProgramCheck -> (s == shell || (shell == "bash" && s == "bash-interactive")) -> (config.programs.${shell}.enable == true);
        message = ''
          users.users.${user.name}.shell is set to ${shell}, but
          programs.${shell}.enable is not true. This will cause the ${shell}
          shell to lack the basic Nix directories in its PATH and might make
          logging in as that user impossible. You can fix it with:
          programs.${shell}.enable = true;

          If you know what you're doing and you are fine with the behavior,
          set users.users.${user.name}.ignoreShellProgramCheck = true;
          instead.
        '';
      }) [
        "bash"
        "fish"
        "zsh"
      ]
    ));

    warnings = flatten (flip mapAttrsToList cfg.users (name: user:
      mkIf
        (user.shell.pname or null == "bash")
        "Set `users.users.${name}.shell = pkgs.bashInteractive;` instead of `pkgs.bash` as it does not include `readline`."
    ));

    users.gids = mkMerge gids;
    users.uids = mkMerge uids;

    # NOTE: We put this in `system.checks` as we want this to run first to avoid partial activations
    # however currently that runs at user level activation as that runs before system level activation
    # TODO: replace `$USER` with `$SUDO_USER` when system.checks runs from system level
    system.checks.text = mkIf (builtins.length (createdUsers ++ deletedUsers) > 0) (mkAfter ''
    '');

    system.activationScripts.groups.text = mkIf (cfg.knownGroups != []) ''
    '';

    system.activationScripts.users.text = mkIf (cfg.knownUsers != []) ''
    '';

    # Install all the user shells
    environment.systemPackages = systemShells;

    environment.etc = mapAttrs' (name: { packages, ... }: {
      name = "profiles/per-user/${name}";
      value.source = pkgs.buildEnv {
        name = "user-environment";
        paths = packages;
        inherit (config.environment) pathsToLink extraOutputsToInstall;
        inherit (config.system.path) postBuild;
      };
    }) packageUsers;

    environment.profiles = mkIf (packageUsers != {}) (mkOrder 900 [ "/etc/profiles/per-user/$USER" ]);
  };
}
