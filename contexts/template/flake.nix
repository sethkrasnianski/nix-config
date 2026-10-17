{
  description = "@NAME@ context";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: {
    context.name = "@NAME@";
    homeManagerModules.default = ./home.nix;
    nixosModules.default = ./nixos.nix;
    darwinModules.default = ./darwin.nix;
    devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (system: {
      default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShellNoCC {
          packages = with pkgs; [
            # Tools needed only inside this context's directory.
          ];
        };
    });
  };
}
