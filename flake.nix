{
  description = "NixOS configuration — WSL host 'nixos' (graphical) / 'nixos-headless', non-WSL 'nixos-default', + macOS home 'macbook'";

  inputs = {
    # Track nixos-unstable (this system reports 26.11pre / "Zokor").
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      # Build NixOS-WSL against the same nixpkgs pinned above.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      # master tracks nixos-unstable, matching the nixpkgs pin above.
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS system layer (darwinConfigurations.macbook). Only the Mac uses it;
    # the NixOS hosts don't reference it at all.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Homebrew for the macOS GUI apps nixpkgs can't build on darwin
    # (Parsec, Steam, Mullvad). Manages the Homebrew install itself; the cask
    # list lives in modules/darwin.nix.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Disabled by default; rebuild tooling can replace this pure path input with
    # the user's ~/.config/nix/local.nix for host-specific settings.
    local-config = {
      url = "path:./local-config/default.nix";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      ...
    }:
    let
      mkHost = import ./lib/mk-host.nix { inherit inputs; };
    in
    {
      lib = { inherit mkHost; };
      devShells =
        nixpkgs.lib.genAttrs
          [
            "aarch64-darwin"
            "x86_64-linux"
          ]
          (
            system:
            let
              pkgs = import nixpkgs { inherit system; };
            in
            {
              default = pkgs.mkShell { };
            }
          );

      nixosConfigurations = nixpkgs.lib.genAttrs [ "nixos" "nixos-headless" "nixos-default" ] (
        target: mkHost { inherit target; }
      );

      # nix-darwin system for the Mac. home-manager runs as a darwin module
      # (like the NixOS hosts) and nix-homebrew manages Homebrew for the casks
      # nixpkgs can't build on darwin. Per-machine facts (username,
      # hostPlatform, stateVersion) live in hosts/macbook.nix; the shared
      # darwin system config in modules/darwin.nix. Apply on the Mac:
      #   sudo darwin-rebuild switch --flake path:/Users/sethkrasnianski/oss/nix-config#macbook
      darwinConfigurations = {
        macbook = mkHost { target = "macbook"; };
      };
    };
}
