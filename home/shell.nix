# Shell config. Both shells are managed so their rc files source
# home-manager's session variables (SSH_AUTH_SOCK, COLORTERM, EDITOR,
# home.sessionPath) — bash because it's the login shell on the WSL host,
# zsh for interactive use. Without this, those variables never load.
{ ... }:

let
  # MCP servers for agent CLIs live in the tool-agnostic ~/.agents/mcp.json
  # (source of truth: agents/mcp.json). Claude Code has no global .mcp.json and
  # no settings.json key for servers, so it's proxied the same way skills are —
  # via `--mcp-config`, rather than a duplicated config. This merges the shared
  # servers on top of Claude's own config.
  #
  # The GitHub server needs a token in the Authorization header (the endpoint
  # doesn't support OAuth dynamic client registration, so the CLIs can't
  # self-authenticate). The token is looked up from `gh auth token` at
  # invocation time and set only in that command's environment — never exported
  # shell-wide, so arbitrary child processes don't inherit it and no secret
  # lands in the repo. Functions rather than aliases can set per-invocation
  # environment variables. Defined for both shells below.
  claudeWithMcp = ''
    claude() {
      GITHUB_MCP_PAT="$(gh auth token 2>/dev/null)" command claude --mcp-config ~/.agents/mcp.json "$@"
    }
    opencode() {
      GITHUB_MCP_PAT="$(gh auth token 2>/dev/null)" command opencode "$@"
    }
  '';
in
{
  programs.bash = {
    enable = true;
    # Minimal single-line prompt — hostname in mint green (truecolor), then
    # cwd — instead of the NixOS default (blank line + bold-green
    # [user@host:cwd]$). Lives in ~/.bashrc, which runs after /etc/bashrc,
    # so it wins over the default.
    initExtra = ''
      PS1='\[\e[38;2;159;226;191m\]\h\[\e[0m\]:\w\$ '
    ''
    + claudeWithMcp;
  };

  programs.zsh = {
    enable = true;
    initContent = claudeWithMcp;
  };
}
