{ lib
, coreutils
, jq
, git
, substituteAll
, stdenv
, profile ? "/nix/var/nix/profiles/system"
, nixPackage ? "/nix/var/nix/profiles/default"
, systemPath ? "$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
}:

let
  extraPath = lib.makeBinPath [ nixPackage coreutils jq git ];

  writeProgram = name: env: src:
    substituteAll ({
      inherit name src;
      dir = "bin";
      isExecutable = true;
    } // env);

  path = "${extraPath}:${systemPath}";
in
{
  linux-option = writeProgram "linux-option"
    {
      inherit path;
      inherit (stdenv) shell;
    }
    ./linux-option.sh;

  linux-rebuild = writeProgram "linux-rebuild"
    {
      inherit path profile;
      inherit (stdenv) shell;
      postInstall = ''
        mkdir -p $out/share/zsh/site-functions
        cp ${./linux-rebuild.zsh-completions} $out/share/zsh/site-functions/_linux-rebuild
      '';
    }
    ./linux-rebuild.sh;

  linux-version = writeProgram "linux-version"
    {
      inherit (stdenv) shell;
      path = lib.makeBinPath [ jq ];
    }
    ./linux-version.sh;
}
