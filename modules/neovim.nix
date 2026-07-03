{ ... }:

{
  # Enable Neovim as the system default editor.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    configure = {
      customRC = ''
        set number
        set tabstop=2
        set shiftwidth=2
        set expandtab
      '';
      # Add plugins here as a list, e.g.:
      #   packages.myPlugins.start = with pkgs.vimPlugins; [ telescope-nvim ];
      # (The previous packer.nvim example was removed: packer is archived and
      #  its fetch used a placeholder hash that could not build.)
    };
  };
}
