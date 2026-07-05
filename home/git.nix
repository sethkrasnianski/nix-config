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
    # Machine-level backstop for agent-shell session transcripts: a repo's
    # tracked .gitignore only covers that repo, so a fresh clone or a new repo
    # without the entry leaves transcripts one 'git add -A' from a commit.
    # Session logs are where a pasted token or env dump lands, so ignore them
    # globally (~/.config/git/ignore) across every repo on this environment.
    ignores = [ ".agent-shell/" ];
  };
}
