{
  description = "NixOS configuration for university competitive programming lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations = {
      # Primary workstation configuration for university lab PCs
      lab-pc = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            home-manager.users.contestant = {
              imports = [ ./vscode.nix ];
              home.stateVersion = "26.05";
            };
          }
          ./hosts/lab-pc/configuration.nix
        ];
      };

      # Bootable live USB / installer ISO with pre-baked KDE Plasma & CP environment
      contest-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = {
              imports = [ ./vscode.nix ];
              home.stateVersion = "26.05";
            };
          }
          ./iso/configuration.nix
        ];
      };
    };

    # Package shortcuts: build installer ISO with `nix build .#iso`
    packages.${system} = {
      iso = self.nixosConfigurations.contest-iso.config.system.build.isoImage;
    };
  };
}

