#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifest="$repo_root/pkgs/synergy3/pinned.nix"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

latest_page="$(curl --fail --silent --show-error --location --retry 3 \
  --user-agent 'Mozilla/5.0' https://symless.com/synergy/download)"
version="$(printf '%s' "$latest_page" | perl -0777 -ne \
  'print "$1\n" if /<h3>Synergy 3<\/h3>.*?cardMeta[^>]*>v([0-9]+(?:\.[0-9]+)+)/s')"

if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  printf 'Could not discover the latest Synergy 3 version.\n' >&2
  exit 1
fi

installer_hash() {
  local platform="$1"
  local file_name="$2"
  local page token installer

  page="https://symless.com/synergy/download/package/synergy-personal-v3/${platform}/${file_name}"
  token="$(curl --fail --silent --show-error --location --retry 3 \
    --user-agent 'Mozilla/5.0' "$page" \
    | perl -0777 -ne 'print "$1\n" if /\\\"token\\\":\\\"([^\\\"]+)\\\"/')"

  if [ -z "$token" ]; then
    printf 'Could not extract a guest download token from %s\n' "$page" >&2
    return 1
  fi

  installer="$temporary_directory/$file_name"
  curl --fail --silent --show-error --location --retry 3 \
    "https://symless.com/synergy/api/download/${file_name}?token=$token" \
    --output "$installer"
  nix hash file --type sha256 --sri "$installer"
}

linux_hash="$(installer_hash flatpak "synergy-${version}-linux-noble-x86_64.flatpak")"
macos_hash="$(installer_hash mac "synergy-${version}-macos-arm64.dmg")"

VERSION="$version" \
  LINUX_X86_64_HASH="$linux_hash" \
  MACOS_AARCH64_HASH="$macos_hash" \
  perl -0pe '
    my $version = s/^  version = "[^"]+";/  version = "$ENV{VERSION}";/m;
    my $linux = s/^  linuxX86_64Hash = "[^"]+";/  linuxX86_64Hash = "$ENV{LINUX_X86_64_HASH}";/m;
    my $macos = s/^  macosAarch64Hash = "[^"]+";/  macosAarch64Hash = "$ENV{MACOS_AARCH64_HASH}";/m;
    die "Synergy pin manifest format changed; refusing a partial update\n"
      unless $version == 1 && $linux == 1 && $macos == 1;
  ' "$manifest" > "$temporary_directory/pinned.nix"
mv "$temporary_directory/pinned.nix" "$manifest"
