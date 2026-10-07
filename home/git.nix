# Git with identity managed here instead of a hand-edited ~/.gitconfig.
{ config, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Seth Krasnianski";
        email = "1910114+sethkrasnianski@users.noreply.github.com";
        # Never guess an identity from hostname/login: if the values above are
        # ever missing, git errors instead of committing with a private address
        # that GitHub would reject (GH007).
        useConfigOnly = true;
      };
      init.defaultBranch = "main";
      # The system config (modules/common.nix) sets core.excludesFile to
      # /etc/gitignore. Git honours only one excludesFile, so pin ours back to
      # the XDG path — otherwise this user would stop reading ~/.config/git/ignore
      # (the file `ignores` below writes) and inherit the system one instead.
      core.excludesFile = "${config.xdg.configHome}/git/ignore";
    };
    # Machine-level backstop: a repo's tracked .gitignore only covers that repo,
    # so a fresh clone or a new repo without the entry leaves transcripts and
    # local agent instructions one 'git add -A' from a commit. Written to
    # ~/.config/git/ignore; the list is shared with /etc/gitignore.
    ignores = import ../modules/git-ignores.nix;
  };
}
