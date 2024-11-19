{
  description = "Flake for building a Raspberry Pi Zero 2 SD image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
  }: let 
    inherit (nixpkgs) lib;
      # The platform to build on.
      buildPlatform = "x86_64-linux";
      # We use this to build derivations for the build platform.
      buildPkgs = nixpkgs.legacyPackages."${buildPlatform}";
      crossPkgs = import "${nixpkgs}" { 
        localSystem = buildPlatform;
        crossSystem = "aarch64-linux";
      };

                                            
  in
  rec {
    nixosConfigurations = {
      zero2w = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
        ];
      };
      zero2w-cross = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ./zero2w.nix
          {
            nixpkgs.pkgs = crossPkgs;
          }
        ];
      };
    };

    sdImage-zero2w = self.nixosConfigurations.zero2w.config.system.build.sdImage;
    sdImage-zero2w-cross = self.nixosConfigurations.zero2w-cross.config.system.build.sdImage;
    
    deploy = {
      user = "root";
      nodes = {
        zero2w = {
          hostname = "zero2w";
          profiles.system.path =
            deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.zero2w;
        };
      };
    };
  };
}
