{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  participant = config.lab.user;
in {
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  options.lab.user = lib.mkOption {
    type = lib.types.str;
    default = "contestant";
    description = "Username for the competition participant / lab user account.";
  };

  config = {
    # Home Manager integration for the participant user
    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = false;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs pkgs; };
      users.${participant} = {
        imports = [ ../home ];
        home = {
          username = participant;
          homeDirectory = "/home/${participant}";
          stateVersion = "26.05";
        };
      };
    };

    users.mutableUsers = true;

    # Dedicated contest participant user (no sudo access)
    users.users.${participant} = {
      isNormalUser = true;
      description = "Contest Participant";
      extraGroups = [ "networkmanager" "video" "audio" ];
      initialPassword = "contest";
    };

    # Lab administrator account (with sudo / wheel access)
    users.users.admin = {
      isNormalUser = true;
      description = "Lab Administrator";
      extraGroups = [ "wheel" "networkmanager" ];
      initialPassword = "admin";
      homeMode = "0700";
    };
  };
}

