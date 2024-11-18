{ config, lib, pkgs, ... }:

let
  cfg = config.fonts;
in

{
  imports = [
    (lib.mkRemovedOptionModule [ "fonts" "enableFontDir" ] "No nix-darwin equivalent to this NixOS option. This is not required to install fonts.")
    (lib.mkRemovedOptionModule [ "fonts" "fontDir" "enable" ] "No nix-darwin equivalent to this NixOS option. This is not required to install fonts.")
    (lib.mkRemovedOptionModule [ "fonts" "fonts" ] ''
      This option has been renamed to `fonts.packages' for consistency with NixOS.

      Note that the implementation now keeps fonts in `/Library/Fonts/Nix Fonts' to allow them to coexist with fonts not managed by nix-darwin; existing fonts will be left directly in `/Library/Fonts' without getting updates and should be manually removed.'')
  ];

  options = {
    fonts.packages = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = lib.literalExpression "[ pkgs.dejavu_fonts ]";
      description = ''
        List of fonts to install into {file}`/Library/Fonts/Nix Fonts`.
      '';
    };
  };

  config = {

    system.build.fonts = pkgs.runCommand "fonts"
      { preferLocalBuild = true; }
      ''
        mkdir -p $out/usr/share/fonts
        store_dir=${lib.escapeShellArg builtins.storeDir}
        while IFS= read -rd "" f; do
          dest="$out/usr/share/fonts/nix-fonts/''${f#"$store_dir/"}"
          mkdir -p "''${dest%/*}"
          ln -sf "$f" "$dest"
        done < <(
          find -L ${lib.escapeShellArgs cfg.packages} \
            -type f \
            -regex '.*\.\(ttf\|ttc\|otf\|dfont\)' \
            -print0
        )
      '';

    system.activationScripts.fonts.text = ''
      printf >&2 'setting up /usr/share/fonts/nix-fonts...\n'
      destParent="/usr/share/fonts"
      dest="''${destParent}/nix-fonts"

      # Some distro probably doesn't have this directory by default.
      mkdir -p "$destParent"

      ourLink () {
        local link
        link=$(readlink "$1")
        [ -L "$1" ] && [ "$link" = "$systemConfig/usr/share/fonts/nix-fonts" ]
      }

      if [ ! -e "$dest" ] \
         || ourLink "$dest"; then
         ln -sfn $systemConfig/usr/share/fonts/nix-fonts "$dest"
      else
        echo "warning: $dest is not owned by nix-not-nixos, skipping fonts linking..." >&2
      fi
    '';

  };
}
