# SSH client setup: a per-machine key with agent caching.
#
# Each machine gets its own key, generated once by running `generate-ssh-key`
# (not managed by nix, never in this repo — it lives in ~/.ssh). ssh-agent
# runs as a systemd user service and `AddKeysToAgent yes` adds the key on
# first use, so the passphrase is typed once per boot, not per connection.
#
# Future: keys/known hosts shared across machines can be checked in as an
# `ssh/` dir of *public* keys, wired via matchBlocks/IdentityFile here (or
# users.users.<name>.openssh.authorizedKeys.keyFiles on the server side);
# shared *private* keys would need agenix/sops-nix first.
#
# The GNOME/gcr agent that would fight over SSH_AUTH_SOCK is disabled at the
# system level (modules/desktop.nix).
{ pkgs, ... }:

{
  # ssh-agent as a systemd user service.
  services.ssh-agent.enable = true;

  # ~/.ssh/config. matchBlocks is the place for per-system keys later.
  programs.ssh = {
    enable = true;
    # Cache the key in the agent the first time it's used.
    addKeysToAgent = "yes";
  };

  # One-time, per-machine key generation. Interactive (prompts for a
  # passphrase); refuses to overwrite an existing key.
  home.packages = [
    (pkgs.writeShellScriptBin "generate-ssh-key" ''
      set -euo pipefail
      key="$HOME/.ssh/id_ed25519"
      if [ -e "$key" ]; then
        echo "generate-ssh-key: $key already exists, refusing to overwrite" >&2
        exit 1
      fi
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      ssh-keygen -t ed25519 -f "$key" -C "$USER@$(${pkgs.hostname}/bin/hostname)"
      echo
      echo "Public key (add this to GitHub / servers):"
      cat "$key.pub"
    '')
  ];
}
