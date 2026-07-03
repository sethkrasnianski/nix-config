{ ... }:

{
  # Neovim as the default editor (sets EDITOR). User-level, so root falls
  # back to nano for the rare system-file edit.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraConfig = ''
      set number
      set tabstop=2
      set shiftwidth=2
      set expandtab
    '';
    # Add plugins via the `plugins` list, e.g.:
    #   plugins = with pkgs.vimPlugins; [ telescope-nvim ];
  };
}
