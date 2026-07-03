# Shell config. Both shells are managed so their rc files source
# home-manager's session variables (SSH_AUTH_SOCK, COLORTERM, EDITOR,
# home.sessionPath) — bash because it's the login shell on the WSL host,
# zsh for interactive use. Without this, those variables never load.
{ ... }:

{
  programs.bash.enable = true;
  programs.zsh.enable = true;
}
