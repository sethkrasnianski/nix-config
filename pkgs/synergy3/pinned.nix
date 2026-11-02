# Updates are pinned and proposed by the scheduled update PR.
# To use the latest upstream release on each rebuild instead, move release
# discovery and hash refresh into the rebuild helper before Nix evaluates.
# Nix cannot fetch an unpinned “latest” installer reproducibly.
{
  version = "3.9.1";
  linuxX86_64Hash = "sha256-946bwX679iRkuSL24B6Pc5sfTAiwTSVkMZp7L8A0+P0=";
  macosAarch64Hash = "sha256-xPDYgNebEIx+CPzvbGvBdEMini+QsuHRuAPD9g4KXFY=";
}
