# SSH client setup: a per-machine key with agent caching.
#
# Each machine gets its own key, generated once by running `generate-ssh-key`
# (not managed by nix, never in this repo — it lives in ~/.ssh). ssh-agent
# runs as a systemd user service and `AddKeysToAgent yes` adds the key on
# first use, so the passphrase is typed once per boot, not per connection.
#
# Future: keys/known hosts shared across machines can be checked in as an
# `ssh/` dir of *public* keys (wired via users.users.<name>.openssh
# .authorizedKeys.keyFiles or programs.ssh.knownHosts); shared *private*
# keys would need agenix/sops-nix first.
{ pkgs, ... }:

{
  # Classic ssh-agent as a systemd user service, on every variant.
  programs.ssh.startAgent = true;

  # GNOME enables gcr's ssh-agent by default, which hard-conflicts (nixpkgs
  # assertion) with startAgent. On WSL there's no GNOME login session to
  # unlock the keyring anyway, so use the classic agent everywhere.
  services.gnome.gcr-ssh-agent.enable = false;

  # Cache the key in the agent the first time it's used.
  programs.ssh.extraConfig = ''
    AddKeysToAgent yes
  '';

  # One-time, per-machine key generation. Interactive (prompts for a
  # passphrase); refuses to overwrite an existing key.
  environment.systemPackages = [
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
