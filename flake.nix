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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-wsl,
      home-manager,
      ...
    }:
    {
      nixosConfigurations = {
        # WSL host, graphical (GNOME). This is the default.
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.home-manager
            ./hosts/nixos-wsl.nix
          ];
        };

        # Same WSL host, headless: no desktop, but GUI apps (Ghostty) still work.
        # Switch on demand:  nixos-rebuild switch --flake .#nixos-headless
        nixos-headless = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.home-manager
            ./hosts/nixos-wsl.nix
            { local.graphical.enable = false; }
          ];
        };

        # Non-WSL host: no WSL code at all, usable on real hardware. The
        # home-manager module is wired but no home-manager.users.* entry
        # exists yet — add one when this host gets a real user.
        nixos-default = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            ./hosts/nixos-default.nix
          ];
        };
      };

      # Standalone home-manager for the Mac — home directory only, no
      # nix-darwin. Username and other per-machine facts live in
      # home/darwin.nix. Apply on the Mac:
      #   home-manager switch --flake ~/oss/nixos-config#macbook
      homeConfigurations = {
        macbook = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [ ./home/darwin.nix ];
        };
      };
    };
}
