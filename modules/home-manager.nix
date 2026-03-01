{
  config,
  lib,
  pkgs,
  flake,
  ...
}: {
  options.programs.direnv.new.enable =
    lib.mkEnableOption "direnv 'new' subcommand";

  config = lib.mkIf config.programs.direnv.new.enable {
    programs.direnv = {
      enable = true;
      package = lib.mkDefault flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
      nix-direnv.enable = lib.mkDefault true;
    };
  };
}
