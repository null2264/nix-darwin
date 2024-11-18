{ config, pkgs, ... }:

let
  font = pkgs.runCommand "font-0.0.0" {} ''
    mkdir -p $out
    touch $out/Font.ttf
  '';
in

{
  fonts.packages = [ font ];

  test = ''
    echo "checking fonts in /usr/share/fonts/nix-fonts" >&2
    test -e "${config.out}/usr/share/fonts/nix-fonts"/*/Font.ttf

    echo "checking activation of fonts in /activate" >&2
    grep '/usr/share/fonts/nix-fonts' ${config.out}/activate
  '';
}
