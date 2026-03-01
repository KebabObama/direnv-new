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

  config = lib.mkMerge [
    {
      programs.direnv.config = {
        global = {
          log_format = "";
          hide_env_diff = true;
        };
      };
    }
    (lib.mkIf cfg.enable {
      programs.direnv = {
        enable = true;
        package = lib.mkDefault flakePkgs.default;
        nix-direnv.enable = lib.mkDefault true;
      };
    })
  ];
}
