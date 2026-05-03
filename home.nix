{ config, nixGL, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "admin";
  home.homeDirectory = "/home/admin";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  targets.genericLinux.enable = true;
  targets.genericLinux.nixGL.packages = nixGL.packages;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    pkgs.coreutils
    pkgs.emacs
    pkgs.fd
    pkgs.git
    pkgs.opencode
    pkgs.ripgrep
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    ".config/doom".source = ./doom;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/admin/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  home.sessionPath = [
    "$HOME/.emacs.d/bin"
    "$HOME/.nix-profile/bin"
  ];

  home.shellAliases = {
    # General shortcuts
    ll = "ls -l";
    update = "home-manager switch --flake ~/.config/home-manager";
    
    # Nix specific
    nconf = "vi ~/.config/home-manager/home.nix";
    nsearch = "nix search nixpkgs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # Let Home Manager manage the shell
  programs.bash.enable = true;
  programs.bash.initExtra = ''
    if [[ ":$PATH:" != *":$HOME/.emacs.d/bin:"* ]]; then
      export PATH="$HOME/.emacs.d/bin:$PATH"
    fi

    if [[ ":$PATH:" != *":$HOME/.nix-profile/bin:"* ]]; then
      export PATH="$HOME/.nix-profile/bin:$PATH"
    fi

    PS1='\[\e[38;2;159;226;191m\]\h\[\e[0m\]:\w\$ '
  '';

  programs.ghostty = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.ghostty;
  };

  home.activation.installDoomEmacs = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.emacs.d" ]; then
      ${pkgs.git}/bin/git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.emacs.d"
    fi
  '';
}
