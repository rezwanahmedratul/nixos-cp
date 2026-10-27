{
  pkgs,
  inputs,
  ...
}: {
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # Home Manager integration for the contestant user
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = false;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs pkgs; };
    users.contestant = {
      imports = [ ../home ];
      home = {
        username = "contestant";
        homeDirectory = "/home/contestant";
        stateVersion = "26.05";
      };
    };
  };

  users.mutableUsers = true;

  # Dedicated contest participant user (no sudo access)
  users.users.contestant = {
    isNormalUser = true;
    description = "Contestant";
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
}

