{
  description = "NixOS configuration — WSL host 'nixos' (graphical) / 'nixos-headless', + non-WSL 'nixos-default'";

  inputs = {
    # Track nixos-unstable (this system reports 26.11pre / "Zokor").
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      # Build NixOS-WSL against the same nixpkgs pinned above.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nixos-wsl, ... }:
    {
      nixosConfigurations = {
        # WSL host, graphical (GNOME). This is the default.
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            ./hosts/nixos-wsl.nix
          ];
        };

        # Same WSL host, headless: no desktop, but GUI apps (Ghostty) still work.
        # Switch on demand:  nixos-rebuild switch --flake .#nixos-headless
        nixos-headless = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            ./hosts/nixos-wsl.nix
            { local.graphical.enable = false; }
          ];
        };

        # Non-WSL host: no WSL code at all, usable on real hardware.
        nixos-default = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/nixos-default.nix
          ];
        };
      };
    };
}
