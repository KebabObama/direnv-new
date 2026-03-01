flake: {
  config,
  lib,
  pkgs,
  ...
}: let
  flakePkgs = flake.packages.${pkgs.stdenv.hostPlatform.system};
in {
  config = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = lib.mkDefault true;
    };
    environment.systemPackages = [flakePkgs.default];
  };
}
