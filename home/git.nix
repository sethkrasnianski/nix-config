# Git with identity managed here instead of a hand-edited ~/.gitconfig.
{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Seth Krasnianski";
        email = "1910114+sethkrasnianski@users.noreply.github.com";
      };
      init.defaultBranch = "main";
    };
  };
}
