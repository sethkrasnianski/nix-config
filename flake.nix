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
    {
      self,
      nixpkgs,
      nixos-wsl,
      home-manager,
      nix-darwin,
      nix-homebrew,
      local-config,
      ...
    }:
    let
      localConfigModule = import local-config.outPath;
    in
    {
      nixosConfigurations = {
        # WSL host, graphical (GNOME). This is the default.
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.home-manager
            ./modules/local-agents.nix
            ./modules/local-llm.nix
            ./modules/local-llm-nixos.nix
            localConfigModule
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
            ./modules/local-agents.nix
            ./modules/local-llm.nix
            ./modules/local-llm-nixos.nix
            localConfigModule
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
            ./modules/local-agents.nix
            ./modules/local-llm.nix
            ./modules/local-llm-nixos.nix
            localConfigModule
            ./hosts/nixos-default.nix
          ];
        };
      };

      # nix-darwin system for the Mac. home-manager runs as a darwin module
      # (like the NixOS hosts) and nix-homebrew manages Homebrew for the casks
      # nixpkgs can't build on darwin. Per-machine facts (username,
      # hostPlatform, stateVersion) live in hosts/macbook.nix; the shared
      # darwin system config in modules/darwin.nix. Apply on the Mac:
      #   sudo darwin-rebuild switch --flake ~/oss/nixos-config#macbook
      darwinConfigurations = {
        macbook = nix-darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            ./modules/local-agents.nix
            ./modules/local-llm.nix
            ./modules/local-llm-darwin.nix
            localConfigModule
            ./hosts/macbook.nix
          ];
        };
      };
    };
}
