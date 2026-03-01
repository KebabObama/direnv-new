flake: {
  lib,
  pkgs,
  ...
}: let
  flakePkgs = flake.packages.${pkgs.stdenv.hostPlatform.system};
in {
  config = {
    programs.direnv = {
      enable = true;
      package = lib.mkDefault flakePkgs.default;
      nix-direnv.enable = lib.mkDefault true;
    };
  };
}
