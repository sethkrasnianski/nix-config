# Updates are pinned and proposed by the scheduled update PR.
# To use the latest upstream release on each rebuild instead, move release
# discovery and hash refresh into the rebuild helper before Nix evaluates.
# Nix cannot fetch an unpinned “latest” installer reproducibly.
{
  version = "3.7.2";
  linuxX86_64Hash = "sha256-gq+MnUUC/Vx4mTGrQXDn6/90JdMzEt0rjzf/UdRF09s=";
  macosAarch64Hash = "sha256-O8D7zB7YtkbIMKtLAq0MZrNkR9NIgxKkIkO7HnqCKp8=";
}
