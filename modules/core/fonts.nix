{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    fira-code
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];
}
