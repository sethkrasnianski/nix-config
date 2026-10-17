# Prime Agent 0.10 uses Rust. Its npm package runs a migration installer.
# Package the native releases directly and keep their runtime assets beside
# the executable. Hashes come from the release's published SHA256SUMS.
# Match upstream's Rust-only daemon socket so an older TypeScript daemon can
# coexist. The Python kernel uses Nix Python and uv for its user-owned environment.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  writeShellScriptBin,
  coreutils,
  python311,
  uv,
  git,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-wWvSr153tT9JuRSkR0LEz2pnxe1QAAQUMLeNvUw7y+w=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-5Bi99i/LAAJ3e/OsQ7zBNlErJnY/KrXFAHkvJuNylOU=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};

  # Upstream always requests a managed Python, which cannot run on NixOS.
  # Satisfy that request with Nix Python and use it for the kernel's venv.
  kernelUv = writeShellScriptBin "uv" ''
    if [ "$#" -eq 3 ] && [ "$1" = python ] && [ "$2" = install ] && [ "$3" = 3.11 ]; then
      exec ${lib.getExe python311} --version
    fi
    export UV_PYTHON_PREFERENCE=only-system
    export PATH="${lib.makeBinPath [ python311 ]}:$PATH"
    exec ${lib.getExe uv} "$@"
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "prime-agent";
  version = "0.10.0";

  src = fetchurl {
    url = "https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev/releases/v${finalAttrs.version}/prime-agent-${finalAttrs.version}-${source.platform}.tar.gz";
    inherit (source) hash;
  };

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xf "$src" -C source
    cd source
    runHook postUnpack
  '';

  dontBuild = true;
  dontStrip = true;
  strictDeps = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/prime-agent"
    cp -R . "$out/share/prime-agent"
    makeWrapper "$out/share/prime-agent/prime-agent" "$out/bin/prime-agent" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --prefix PATH : ${
        lib.makeBinPath [
          kernelUv
          git
        ]
      } \
      --run 'export PRIME_AGENT_DAEMON_SOCKET="''${PRIME_AGENT_DAEMON_SOCKET:-''${TMPDIR:-/tmp}/prime-agent-rust-$(${lib.getExe' coreutils "id"} -u)/daemon.sock}"'

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Open-source coding and research agent built on a Recursive Language Model (RLM)";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    changelog = "https://github.com/PrimeIntellect-ai/prime-agent/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "prime-agent";
    platforms = builtins.attrNames sources;
  };
})
