# Updates are pinned and proposed by the scheduled update PR.
# To use the latest upstream release on each rebuild instead, move release
# discovery and hash refresh into the rebuild helper before Nix evaluates.
# Nix cannot fetch an unpinned “latest” installer reproducibly.
{
  version = "3.8.4";
  linuxX86_64Hash = "sha256-GHJh2Sj48D5ZLMVDYIoNszrxbsDxajr/x7oxG/OSRRw=";
  macosAarch64Hash = "sha256-31/WXMjzeUX72n76JlEceH2/IajxCN3/xWKvA2b/EJc=";
}
