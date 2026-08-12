# Prime Agent (https://github.com/PrimeIntellect-ai/prime-agent) — Prime
# Intellect's coding/research agent, built around a persistent IPython kernel
# and recursive sub-agents (RLM). Not in nixpkgs and not published to the
# public npm registry: upstream's only distribution path is
# `curl … install.sh | sh`, which shells out to `npm install -g` against a
# release tarball hosted on their own R2 bucket. This packages that same
# tarball with buildNpmPackage instead, so installing it is reproducible and
# doesn't require running an installer script at rebuild time.
#
# Non-obvious constraints:
# - Upstream ships no package-lock.json. package-lock.json here was generated
#   once from the release's own package.json (copied verbatim as package.json
#   in this directory, for provenance) via:
#     npm install --package-lock-only --ignore-scripts
#   The three `@earendil-works/pi-*` entries resolve to R2 tarball URLs rather
#   than the npm registry; fetchNpmDeps handles that transparently.
# - `dist/` in the release tarball is already built — dontNpmBuild = true.
# - The only native dependency is `zeromq` (Jupyter wire protocol), which
#   ships prebuilt addons for every supported platform/libc/Node-ABI
#   combination — no compiler needed. `npm rebuild` (part of npmConfigHook)
#   re-triggers zeromq's own install script, which picks the matching prebuilt
#   addon; verified this succeeds offline with nodejs_22 on x86_64-linux
#   glibc. postInstall then deletes every prebuild except this platform's, so
#   autoPatchelfHook isn't run over foreign-arch/OS binaries and the closure
#   isn't needlessly multiplied.
# - KNOWN GAP: as of zeromq 6.6.0, upstream ships no darwin build for Node's
#   ABI 127 (Node 22) — only ABI 115/72 (Node 20/18). Node 20 was removed from
#   nixpkgs (EOL), so there is no nixpkgs nodejs that matches a darwin
#   prebuilt addon today. `npm rebuild` on aarch64-darwin will likely fall
#   back to zeromq's from-source cmake-ts build, which needs network + cmake/
#   ninja/vcpkg — unavailable in the Nix sandbox — and fail. This has only
#   been verified end-to-end on x86_64-linux (real build + `--version`/
#   `--help`/`doctor` run); the darwin output only round-trips through `nix
#   eval` (see README "macOS"), so this gap won't surface until an actual
#   `darwin-rebuild switch`. If it does: wait for upstream's next zeromq
#   prebuild, or add a from-source darwin build (nixpkgs zeromq + cmake +
#   ninja, bypassing cmake-ts's vcpkg fetch).
#
# Bumping the version: update `version` and `src.hash` (from upstream's
# published `releases/vX.Y.Z/SHA256SUMS`), then regenerate package.json +
# package-lock.json the same way and refresh `npmDepsHash` (the build's error
# message on mismatch prints the correct value).
{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  autoPatchelfHook,
  makeWrapper,
  uv,
  git,
}:

buildNpmPackage rec {
  pname = "prime-agent";
  version = "0.7.2";

  src = fetchurl {
    url = "https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev/releases/v${version}/prime-agent-${version}.tgz";
    hash = "sha256-vFRx8qYm1ye4ikXrdF//k7EMVUo8T8WRLyXYxkuYf14=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nodejs = nodejs_22; # engines.node >=22.8; matches zeromq's ABI-127 linux prebuild
  npmDepsHash = "sha256-ERqldTKWZ9F8wfB8S0NCdQtR7ry5jfijCu5oMl/TfpQ=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  postInstall =
    let
      packageOut = "$out/lib/node_modules/prime-agent";
      osDir = if stdenv.isLinux then "linux" else "darwin";
      archDir = if stdenv.isAarch64 then "arm64" else "x64";
      libc = if stdenv.isLinux then "glibc" else "libc"; # zeromq's own naming, not nixpkgs'
      nodeAbi = "127"; # NODE_MODULE_VERSION for nodejs_22 above; bump alongside it
      zeromqDir = "${packageOut}/node_modules/zeromq/build";
      zeromqAddon = "${zeromqDir}/${osDir}/${archDir}/node/${libc}-${nodeAbi}-Release/addon.node";
      koffiDir = "${packageOut}/node_modules/koffi/build/koffi";
    in
    ''
      # Keep only this platform's prebuilt native addon for each bundled
      # native dependency (see header comment), so autoPatchelfHook only ever
      # looks at one real binary and the closure isn't needlessly multiplied.
      if [ -d ${zeromqDir} ]; then
        if [ ! -f ${zeromqAddon} ]; then
          echo "prime-agent: no zeromq prebuilt addon at ${zeromqAddon} -- see default.nix header comment" >&2
          exit 1
        fi
        find ${zeromqDir} -mindepth 1 -maxdepth 1 ! -name ${osDir} ! -name manifest.json -exec rm -rf {} +
        find ${zeromqDir}/${osDir} -mindepth 1 -maxdepth 1 ! -name ${archDir} -exec rm -rf {} +
        find ${zeromqDir}/${osDir}/${archDir}/node -mindepth 1 -maxdepth 1 \
          ! -name '${libc}-${nodeAbi}-Release' -exec rm -rf {} +
      fi
      if [ -d ${koffiDir} ]; then
        find ${koffiDir} -mindepth 1 -maxdepth 1 -type d ! -name '${osDir}_${archDir}' -exec rm -rf {} +
      fi

      # uv bootstraps the IPython kernel venv on first use (~/.prime/agent/kernel-venv);
      # git is used for repo context. Neither belongs in home.packages just for this.
      wrapProgram $out/bin/prime-agent \
        --set PI_SKIP_VERSION_CHECK 1 \
        --prefix PATH : ${
          lib.makeBinPath [
            uv
            git
          ]
        }
    '';

  meta = {
    description = "Open-source coding and research agent built on a Recursive Language Model (RLM)";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
