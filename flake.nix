{
  description = "NixOS configuration — WSL host 'nixos' (graphical) / 'nixos-headless', + non-WSL 'nixos-default'";

  inputs = {
    # Track nixos-unstable (this system reports 26.11pre / "Zokor").
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Stable channel, used only to swap in packages that are broken on
    # unstable (currently opencode on WSL2 — see modules/wsl.nix).
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

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
      nixpkgs-stable,
      nixos-wsl,
      home-manager,
      ...
    }:
    {
      nixosConfigurations = {
        # WSL host, graphical (GNOME). This is the default.
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit nixpkgs-stable; };
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
          specialArgs = { inherit nixpkgs-stable; };
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
    };
}
