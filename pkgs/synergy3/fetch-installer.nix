{
  stdenvNoCC,
  curl,
  cacert,
  perl,
}:
{
  version,
  platform,
  fileName,
  hash,
}:
stdenvNoCC.mkDerivation {
  pname = "synergy3-${platform}-installer";
  inherit version;
  name = fileName;

  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = hash;
  allowSubstitutes = false;

  nativeBuildInputs = [
    curl
    perl
  ];

  buildCommand = ''
    set -euo pipefail

    page="https://symless.com/synergy/download/package/synergy-personal-v3/${platform}/${fileName}"
    token="$(${curl}/bin/curl --cacert ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --fail --silent --show-error --location \
      --retry 3 --user-agent 'Mozilla/5.0' "$page" \
      | ${perl}/bin/perl -0777 -ne 'print "$1\n" if /\\\"token\\\":\\\"([^\\\"]+)\\\"/')"

    if [ -z "$token" ]; then
      echo "Could not extract a guest download token from $page" >&2
      exit 1
    fi

    ${curl}/bin/curl --cacert ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --fail --silent --show-error --location --retry 3 \
      "https://symless.com/synergy/api/download/${fileName}?token=$token" \
      --output "$out"
  '';
}
