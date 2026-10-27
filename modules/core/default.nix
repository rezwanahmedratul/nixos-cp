{ ... }:

{
  imports = [
    ./boot.nix
    ./network.nix
    ./services.nix
    ./plasma.nix
    ./fonts.nix
    ./security.nix
    ./system.nix
    ./packages.nix
    ./contest-tools.nix
    ./user.nix
  ];
}
