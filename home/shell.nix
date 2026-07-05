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

      # GitHub's hosted MCP endpoint needs a token in the Authorization header
      # (it doesn't support OAuth dynamic client registration, so Claude Code
      # can't self-authenticate). Reuse the token gh is already logged in with
      # rather than a separate PAT. This is a runtime lookup, not a literal
      # token, so no secret lands in the repo; agents/mcp.json reads it via
      # ''${GITHUB_MCP_PAT}.
      export GITHUB_MCP_PAT="$(gh auth token 2>/dev/null)"
    '';
  };

  programs.zsh.enable = true;

  # MCP servers for agent CLIs live in the tool-agnostic ~/.agents/mcp.json
  # (source of truth: agents/mcp.json). Claude Code has no global .mcp.json and
  # no settings.json key for servers, so it's proxied the same way skills are —
  # via an alias, here `--mcp-config`, rather than a duplicated config. This
  # merges the shared servers on top of Claude's own config.
  #
  # The GitHub server needs a token in the Authorization header (see initExtra
  # above, where GITHUB_MCP_PAT is exported from `gh auth token`); the config
  # references ${GITHUB_MCP_PAT} so no token is embedded in the repo.
  home.shellAliases.claude = "claude --mcp-config ~/.agents/mcp.json";
}
