# Shell config. Both shells are managed so their rc files source
# home-manager's session variables (SSH_AUTH_SOCK, COLORTERM, EDITOR,
# home.sessionPath) — bash because it's the login shell on the WSL host,
# zsh for interactive use. Without this, those variables never load.
{ ... }:

{
  programs.bash = {
    enable = true;
    # Minimal single-line prompt — hostname in mint green (truecolor), then
    # cwd — instead of the NixOS default (blank line + bold-green
    # [user@host:cwd]$). Lives in ~/.bashrc, which runs after /etc/bashrc,
    # so it wins over the default.
    initExtra = ''
      PS1='\[\e[38;2;159;226;191m\]\h\[\e[0m\]:\w\$ '
    '';
  };

  programs.zsh.enable = true;
}
