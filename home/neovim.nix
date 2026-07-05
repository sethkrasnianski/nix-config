{ ... }:

{
  # Neovim as the default editor (sets EDITOR). User-level, so root falls
  # back to nano for the rare system-file edit.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Adopt the new upstream defaults (was implicitly true under
    # home.stateVersion < 26.05); no Ruby/Python plugins here so the
    # provider wrappers are dead weight.
    withRuby = false;
    withPython3 = false;

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
