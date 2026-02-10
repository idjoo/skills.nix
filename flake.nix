{
  description = "Declarative agent skills management for skills.sh via Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: {
    homeModules = rec {
      skills = import ./module.nix;
      default = skills;
    };

    packages = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        skills-cli = pkgs.callPackage ./package.nix {};
        default = pkgs.callPackage ./package.nix {};
      }
    );
  };
}
