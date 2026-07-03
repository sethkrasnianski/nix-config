# Git with identity managed here instead of a hand-edited ~/.gitconfig.
{ ... }:

{
  programs.git = {
    enable = true;
    userName = "Seth Krasnianski";
    userEmail = "1910114+sethkrasnianski@users.noreply.github.com";
  };
}
