flake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.direnv.new;
  flakePkgs = flake.packages.${pkgs.stdenv.hostPlatform.system};
in {
  options.programs.direnv.new = {
    enable = lib.mkEnableOption "direnv 'new' subcommand for scaffolding .envrc files";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = lib.mkDefault true;
    };
    environment.systemPackages = [flakePkgs.default];
  };
}
