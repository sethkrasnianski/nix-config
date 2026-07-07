# Shared configuration applied to every host (WSL and non-WSL).
{
  lib,
  pkgs,
  ...
}:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Tell NixOS it's ok to install these packages despite unfree license.
  # home-manager.useGlobalPkgs below makes this cover home.packages too.
  # KEEP IN SYNC with the copy in modules/darwin.nix (the macOS host has its
  # own list); the two drift silently otherwise. steam/steam-unwrapped are for
  # programs.steam (modules/desktop.nix); parsec-bin for home/linux.nix.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ngrok"
      "obsidian"
      "parsec-bin"
      "spotify"
      "steam"
      "steam-unwrapped"
    ];

  # NOTE: system.stateVersion is intentionally NOT set here — it is per-host
  # (the release each machine was first installed with). See hosts/*.nix.

  # home-manager runs as part of `nixos-rebuild switch`; per-user config lives
  # in home/ at the repo root and is wired up per-host (hosts/*.nix), since
  # usernames are host-specific.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # If a file home-manager wants to manage already exists, rename it aside
    # instead of failing the activation.
    backupFileExtension = "hm-bak";
  };

  # Zsh, enabled properly (completion + environment integration) rather than
  # just dropping the binary into systemPackages. User-level shell config is
  # in home/shell.nix; this system-level enable is what registers zsh as a
  # valid login shell.
  programs.zsh.enable = true;

  # Icon font used by Doom Emacs' UI (modeline, treemacs, dashboard). Fonts
  # stay system-level so fontconfig (and GNOME/GDM) sees them.
  fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

  # System-wide git ignore, covering every user on the host — root, system
  # scripts, and any login user — not just the home-manager user. Git consults a
  # single core.excludesFile, so setting it here in /etc/gitconfig makes the main
  # user resolve to /etc/gitignore too (home-manager leaves the key unset); to
  # keep the per-user ~/.config/git/ignore from home/git.nix independently usable,
  # that module pins its own excludesFile back to the XDG path. Keeps agent-shell
  # transcripts — where a pasted token or env dump can land — out of every working
  # tree by default.
  programs.git = {
    enable = true;
    config.core.excludesfile = "/etc/gitignore";
  };
  environment.etc."gitignore".text = ''
    .agent-shell/
  '';

  # Mullvad VPN. The daemon + CLI are system-level (a NixOS service, not a
  # home-manager package); the GUI ships in the same package and appears only
  # on graphical hosts — headless hosts still get a working daemon and
  # `mullvad` CLI. (On macOS Mullvad is a Homebrew cask; see modules/darwin.nix.)
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  # Base CLI tools, kept system-wide so root and system scripts have them too.
  # User-facing apps (editors, terminals, claude-code, ...) live in home/.
  environment.systemPackages =
    with pkgs;
    [
      nixfmt
      wget
      fd
      jq
      tree
      ripgrep
      gh
      unzip
    ]
    # macOS ships lsof by default; Linux does not, so pull it in there only.
    ++ lib.optionals stdenv.isLinux [ lsof ];
}
